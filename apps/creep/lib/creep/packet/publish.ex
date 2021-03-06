defmodule Creep.Packet.Publish do
  alias Creep.Packet.Publish

  @type t() :: %Publish{
          dup: boolean(),
          qos: 0..2,
          retain: boolean(),
          topic: String.t(),
          payload: binary(),
          packet_id: nil | integer()
        }

  defstruct [
    :dup,
    :qos,
    :retain,
    :topic,
    :payload,
    :packet_id
  ]

  def validate_topic!(topic) do
    Enum.each(Path.split(topic), fn
      "#" -> raise "Can not publish to wildcard topic"
      _ -> :ok
    end)

    :ok
  end

  defimpl Creep.Packet.Encode, for: Publish do
    import Creep.Packet.Util
    @type_publish 0x03

    def encode(%Publish{qos: 0} = publish) do
      :ok = Publish.validate_topic!(publish.topic)

      payload =
        <<
          byte_size(publish.topic)::16
        >> <> publish.topic <> publish.payload

      <<
        @type_publish::4,
        bool(publish.dup)::1,
        0::2,
        bool(publish.retain)::1,
        byte_size(payload)::8
      >> <> payload
    end
  end

  defimpl Creep.Packet.Decode, for: Publish do
    import Creep.Packet.Util
    @type_publish 0x03

    # QOS 0
    def decode(%Publish{} = packet, <<
          @type_publish::4,
          dup::1,
          0::2,
          retain::1,
          payload_size::8,
          payload::binary-size(payload_size),
          rest::binary
        >>) do
      <<topic_size::16, topic::binary-size(topic_size), payload::binary>> = payload
      :ok = Publish.validate_topic!(topic)
      {%{packet | dup: bool(dup), retain: bool(retain), qos: 0, topic: topic, payload: payload}, rest}
    end

    # QOS 1
    def decode(%Publish{} = packet, <<
          @type_publish::4,
          dup::1,
          qos::2,
          retain::1,
          payload_size::8,
          payload::binary-size(payload_size),
          rest::binary
        >>)
        when qos in [1, 2] do
      <<
        topic_size::16,
        topic::binary-size(topic_size),
        packet_id::16,
        payload::binary
      >> = payload

      :ok = Publish.validate_topic!(topic)

      {%{
        packet
        | dup: bool(dup),
          retain: bool(retain),
          qos: qos,
          topic: topic,
          payload: payload,
          packet_id: packet_id
      }, rest}
    end
  end
end
