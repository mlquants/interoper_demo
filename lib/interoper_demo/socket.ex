defmodule InteroperDemo.Socket do
  @moduledoc """
  Opens a event-stream socket and broadcasts received events to the pub-sub
  """
  use WebSockex
  alias InteroperDemo.PubSub

  @enabled Application.compile_env!(:interoper_demo, [__MODULE__, :enabled])

  def start_link(url) do
    if @enabled do
      WebSockex.start_link(url, __MODULE__, %{})
    else
      :ignore
    end
  end

  @doc """
  {
    "e": "trade",     // Event type
    "E": 123456789,   // Event time
    "s": "BNBBTC",    // Symbol
    "t": 12345,       // Trade ID
    "p": "0.001",     // Price
    "q": "100",       // Quantity
    "b": 88,          // Buyer order ID
    "a": 50,          // Seller order ID
    "T": 123456785,   // Trade time
    "m": true,        // Is the buyer the market maker?
    "M": true         // Ignore
  }
  """
  def handle_frame({:text, message}, state) do
    Phoenix.PubSub.broadcast(PubSub, "trade", Jason.decode!(message))
    {:ok, state}
  end

  def handle_frame({_type, _msg}, state), do: {:ok, state}
end
