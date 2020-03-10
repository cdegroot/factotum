defmodule Factotum.AvahiPublisher do
  @moduledoc """
  Simple task to keep a avahi publish process live.
  """
  use Task, restart: :permanent
  require Logger

  # TODO link to the actual MQTT process, restarts, etcetera

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    priv = Application.app_dir(:factotum) |> Path.join("priv")
    port = Port.open({:spawn_executable, "#{priv}/port-wrapper.sh"},
      args: ["avahi-publish-service", "factotum", "_mqtt._tcp", "1833"])
    Port.monitor(port)
    # We're now done, so we just need to stay alive
    handle_messages
  end

  defp handle_messages do
    receive do
      {:DOWN, _ref, :port, _port, reason} ->
        Logger.error("Avahi publish process died, reason: #{inspect reason}. Exiting publisher")
      msg ->
        Logger.info("Received unknown message: #{inspect msg}. Ignoring")
        handle_messages
    end
  end

end
