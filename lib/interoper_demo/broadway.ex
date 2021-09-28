defmodule InteroperDemo.Broadway do
  @moduledoc """
  A Broadway pipeline.
  """
  use Broadway

  alias Broadway.Message
  alias InteroperDemo.Queue

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Queue, 0},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [default: [concurrency: 3]],
      batchers: [default: [concurrency: 1, batch_size: 1_000_000, batch_timeout: :timer.minutes(1)]]
      # batchers: [default: [concurrency: 1, batch_size: 100, batch_timeout: :timer.hours(1)]]
    )
  end

  @impl true
  def handle_message(_, %Message{data: _data} = message, _), do: message

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    # do some batch processing here
    Logger.info("processing batch of #{length(messages)}")
    batch = Enum.map(messages, fn e -> e.data end)

    prices = batch |> Enum.map(fn %{"p" => price} -> String.to_float(price) end)

    open = List.first(prices)
    close = List.last(prices)
    high = Enum.max(prices)
    low = Enum.min(prices)

    volume = batch
    |> Enum.map(fn %{"p" => price, "q" => quantity} -> String.to_float(price) * String.to_float(quantity) end)
    |> Enum.sum

    timestamp = batch
    |> Enum.map(fn %{"T" => t} -> t end)
    |> List.first()

    buy_to_sell_ratio = batch
    |> Enum.map(fn %{"m" => buy} -> buy end)
    |> Enum.count(fn x -> x end)

    # total_trades = length(batch)

    file = File.open!("test_ethusd.csv", [:append, :utf8])
    _row = [[open, high, low, close, volume, timestamp, buy_to_sell_ratio #,
    #  total_trades
     ]]
    |> CSV.encode |> Enum.each(&IO.write(file, &1))

    messages
  end

  def transform(event, _opts) do
    %Message{data: event, acknowledger: {__MODULE__, :ack_id, :ack_data}}
  end

  # Write acknowledge code here:
  def ack(:ack_id, _successful, _failed), do: :noop
end
