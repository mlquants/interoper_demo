defmodule InteroperDemo.Socket do
  use WebSockex
  alias InteroperDemo.PubSub

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{})
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
