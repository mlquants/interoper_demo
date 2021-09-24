defmodule InteroperDemo.Queue do
  use GenServer
  alias InteroperDemo.PubSub

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Phoenix.PubSub.subscribe(PubSub, "trade")
    {:ok, Qex.new()}
  end

  def handle_info(msg, state) do
    IO.inspect(label: "got event")
    {:noreply, Qex.push(state, msg)}
  end
end
