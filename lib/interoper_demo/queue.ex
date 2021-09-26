defmodule InteroperDemo.Queue do
  @moduledoc """
  Subscribes to pub-sub event stream, buffers events into the queue
  and produces them on demand.
  """
  use GenStage
  require Logger

  def start_link(arg), do: GenStage.start_link(__MODULE__, arg)

  def init(demand) when demand >= 0 do
    Phoenix.PubSub.subscribe(InteroperDemo.PubSub, "trade")
    {:producer, %{demand: demand, queue: Qex.new()}}
  end

  def handle_demand(incoming_demand, %{demand: demand} = state) when incoming_demand > 0 do
    fetch_events(%{state | demand: demand + incoming_demand})
  end

  def handle_info(:fetch, state), do: fetch_events(state)

  def handle_info(event, %{queue: queue} = state) do
    Logger.info("Queue: received event #{event["t"]}, pushing to queue")
    {:noreply, [], %{state | queue: Qex.push(queue, event)}}
  end

  defp fetch_events(%{demand: 0} = state), do: {:noreply, [], state}

  defp fetch_events(%{demand: demand, queue: queue} = state) do
    {messages, queue} = pop(queue, demand)
    new_demand = demand - length(messages)
    if new_demand > 0, do: schedule_fetch()
    {:noreply, messages, %{state | demand: new_demand, queue: queue}}
  end

  defp schedule_fetch(), do: Process.send_after(self(), :fetch, 1)

  def pop(queue, n, result \\ [])
  def pop(queue, 0, result), do: {Enum.reverse(result), queue}

  def pop(queue, n, result) do
    case Qex.pop(queue) do
      {{:value, item}, new_queue} -> pop(new_queue, n - 1, [item | result])
      {:empty, new_queue} -> pop(new_queue, n - 1, result)
    end
  end
end
