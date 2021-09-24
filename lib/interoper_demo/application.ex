defmodule InteroperDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # url = "wss://stream.binance.com:9443/ws/btcusdt@trade"
    url = "wss://stream.binance.com:9443/ws/ethbtc@trade"

    children = [
      # Starts a worker by calling: InteroperDemo.Worker.start_link(arg)
      {Phoenix.PubSub, name: InteroperDemo.PubSub},
      {InteroperDemo.Queue, []},
      {InteroperDemo.Socket, url}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: InteroperDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
