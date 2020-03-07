defmodule Creep.RanchTransport do
  @moduledoc """
  ranch protocol for handling tcp connections
  """
  require Logger

  alias Creep.Packet

  alias Packet.{
    Connect,
    Publish,
    Pubrel,
    Subscribe,
    Unsubscribe,
    Pingreq,
    Disconnect
  }

  # Ranch 1.7 does not allow this unfortunately
  # @behaviour Creep.PacketTransport

  @behaviour :ranch_protocol
  @behaviour :gen_statem

  # Ranch 1.7 does not allow this unfortunately
  # @impl Creep.PacketTransport
  @doc false
  def child_spec(opts) do
    transport_opts = Keyword.get(opts, :transport_opts, [])
    {ssl?, transport_opts} = Keyword.pop(transport_opts, :ssl, false)

    if ssl? do
      :ranch.child_spec(make_ref(), :ranch_ssl, transport_opts, __MODULE__, opts)
    else
      :ranch.child_spec(make_ref(), :ranch_tcp, transport_opts, __MODULE__, opts)
    end
  end

  @impl :ranch_protocol
  def start_link(ref, _socket, transport, protocol_opts) do
    {:ok, :proc_lib.spawn_link(__MODULE__, :init, [{ref, transport, protocol_opts}])}
  end

  # @impl :ranch_protocol
  # compat for ranch 2.x
  def start_link(ref, transport, protocol_opts) do
    {:ok, :proc_lib.spawn_link(__MODULE__, :init, [{ref, transport, protocol_opts}])}
  end

  @impl :gen_statem
  def callback_mode() do
    :state_functions
  end

  @impl :gen_statem
  def init({ref, transport, protocol_opts}) do
    {:ok, socket} = :ranch.handshake(ref)
    :ok = transport.setopts(socket, [{:active, :once}])
    broker_id = Keyword.fetch!(protocol_opts, :broker_id)
    packet_processor = Keyword.fetch!(protocol_opts, :packet_processor)

    data = %{
      socket: socket,
      transport: transport,
      broker_id: broker_id,
      packet_processor: packet_processor,
      session: nil,
      transport_type: :tcp
    }

    :gen_statem.enter_loop(__MODULE__, [], :decode, data, [])
  end

  def decode(:info, {type, socket, message}, data) when type in [:tcp, :ssl] do
    case Packet.decode(message) do
      {:ok, packet, rest} ->
        actions = [{:next_event, :internal, {packet, socket, rest}}]
        {:next_state, :process, %{data | transport_type: type}, actions}

      # Unless stated otherwise, if either the Server or Client encounters a
      # protocol violation, it MUST close the Network Connection on which it
      # received that Control Packet which caused the protocol violation [MQTT-4.8.0-1].
      {:error, reason} ->
        {:stop, reason, data}
    end
  end

  def decode(:info, %Publish{} = publish, data) do
    _ = reply(publish, data.socket, data, <<>>)
    {:keep_state_and_data, []}
  end

  def decode(:info, {:tcp_closed, _socket}, data) do
    {:stop, :normal, data}
  end

  def process(:internal, {%Connect{} = connect, socket, rest}, data) do
    _ = Logger.metadata(client_id: connect.client_id)
    Logger.info("New TCP Broker connection")
    :ok = data.transport.setopts(socket, [{:active, true}])
    {connack, session} = data.packet_processor.connect(data.broker_id, connect)
    reply(connack, socket, %{data | session: session}, rest)
  end

  def process(:internal, {%Publish{} = publish, socket, rest}, data) do
    # TODO(Connor) Validate topic here somewhere
    data.packet_processor.publish(data.broker_id, data.session, publish)
    |> reply(socket, data, rest)
  end

  def process(:internal, {%Pubrel{} = pubrel, socket, rest}, data) do
    data.packet_processor.pubrel(data.broker_id, data.session, pubrel)
    |> reply(socket, data, rest)
  end

  def process(:internal, {%Subscribe{} = subscribe, socket, rest}, data) do
    data.packet_processor.subscribe(data.broker_id, data.session, subscribe)
    |> reply(socket, data, rest)
  end

  def process(:internal, {%Unsubscribe{} = unsubscribe, socket, rest}, data) do
    data.packet_processor.unsubscribe(data.broker_id, data.session, unsubscribe)
    |> reply(socket, data, rest)
  end

  def process(:internal, {%Pingreq{} = pingreq, socket, rest}, data) do
    data.packet_processor.pingreq(data.broker_id, data.session, pingreq)
    |> reply(socket, data, rest)
  end

  def process(:internal, {%Disconnect{} = disconnect, _socket, _rest}, data) do
    _ = data.packet_processor.disconnect(data.broker_id, data.session, disconnect)
    {:stop, :normal, data}
  end

  defp reply(nil, socket, data, rest) do
    process_rest_or_next(rest, socket, data)
  end

  defp reply(reply, socket, data, rest) do
    case Packet.encode(reply) do
      {:ok, packet} ->
        :ok = data.transport.send(socket, packet)
        process_rest_or_next(rest, socket, data)

      {:error, reason} ->
        {:stop, reason, data}
    end
  end

  # TODO cees This is not very clean but works as long as the state machine stays as simple as it is
  defp process_rest_or_next(<<>>, _socket, data), do: {:next_state, :decode, data,[]}
  defp process_rest_or_next(rest, socket, data) do
    # More work to be done...
    decode(:info, {data.transport_type, socket, rest}, data)
  end
end
