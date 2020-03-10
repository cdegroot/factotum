defmodule Factotum.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    broker_opts = [
      broker_id: "factotum",
      packet_processor: Creep.InMemProcessor,
      transports: [
        {Creep.RanchTransport, [port: 1883]}]]

    children = [
      # Start the PubSub system
      {Phoenix.PubSub, name: Factotum.PubSub},
      {Creep, broker_opts},
      Factotum.AvahiPublisher]

    Supervisor.start_link(children, strategy: :one_for_one, name: Factotum.Supervisor)
  end
end
