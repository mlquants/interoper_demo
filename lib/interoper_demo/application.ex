defmodule InteroperDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    agg_type = "time"
    # agg_type = "size"
    ticker = "ethusdt"
    # ticker = "btcusdt"
    # ticker = "ethbtc"
    url = "wss://stream.binance.com:9443/ws/#{ticker}@trade"
    filepath = "test_#{ticker}_#{agg_type}.csv"

    children = [
      # Starts a worker by calling: InteroperDemo.Worker.start_link(arg)
      {Phoenix.PubSub, name: InteroperDemo.PubSub},
      {InteroperDemo.Broadway,
       [
         agg_type: agg_type,
         ticker: ticker,
         name: String.to_atom("#{ticker}_#{agg_type}"),
         filepath: filepath
       ]},
      {InteroperDemo.Socket, url}
    ]

    opts = [strategy: :one_for_one, name: InteroperDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
