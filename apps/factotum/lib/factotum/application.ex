defmodule Factotum.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the PubSub system
      {Phoenix.PubSub, name: Factotum.PubSub}
      # Start a worker by calling: Factotum.Worker.start_link(arg)
      # {Factotum.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Factotum.Supervisor)
  end
end
