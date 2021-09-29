defmodule InteroperDemo.Broadway do
  @moduledoc """
  A Broadway pipeline.
  """
  use Broadway

  alias Broadway.Message
  alias InteroperDemo.Queue
  alias InteroperDemo.TradingCycle

  require Logger

  def table_init(name, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    :ets.new(name, [:named_table, :public])
    :ets.insert(name, {"amount_" <> base_coin, 0})
    :ets.insert(name, {"amount_" <> quote_coin, 100})
    :ets.insert(name, {"amount_borrowed_" <> base_coin, 0})
    name
  end

  def start_link(opts) do
    table =
      opts
      |> Keyword.fetch!(:name)
      |> table_init(Keyword.fetch!(opts, :ticker))

    agg_type = opts |> Keyword.fetch!(:agg_type)

    batchers =
      case agg_type do
        "time" ->
          [default: [concurrency: 1, batch_size: 1_000_000, batch_timeout: :timer.minutes(1)]]

        "size" ->
          [default: [concurrency: 1, batch_size: 100, batch_timeout: :timer.hours(1)]]
      end

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Queue, 0},
        transformer: {__MODULE__, :transform, []}
      ],
      context: %{
        table: table,
        filepath: opts |> Keyword.fetch!(:filepath),
        agg_type: agg_type,
        ticker: opts |> Keyword.fetch!(:ticker)
      },
      processors: [default: [concurrency: 3]],
      batchers: batchers
    )
  end

  @impl true
  def handle_message(
        _,
        %Message{data: %{"p" => price} = _data} = message,
        %{table: table} = _context
      ) do
    :ets.insert(table, {"price", price})
    message
  end

  def aggregate_row_from_batch(batch, agg_type) do
    prices = batch |> Enum.map(fn %{"p" => price} -> String.to_float(price) end)

    open = List.first(prices)
    close = List.last(prices)
    high = Enum.max(prices)
    low = Enum.min(prices)

    volume =
      batch
      |> Enum.map(fn %{"p" => price, "q" => quantity} ->
        String.to_float(price) * String.to_float(quantity)
      end)
      |> Enum.sum()

    timestamp =
      batch
      |> Enum.map(fn %{"T" => t} -> t end)
      |> List.first()

    buy_to_sell_ratio =
      batch
      |> Enum.map(fn %{"m" => buy} -> buy end)
      |> Enum.count(fn x -> x end)

    row =
      case agg_type do
        "time" -> [[open, high, low, close, volume, timestamp, buy_to_sell_ratio, length(batch)]]
        "size" -> [[open, high, low, close, volume, timestamp, buy_to_sell_ratio]]
      end

    row
  end

  def append_row_to_csv(row, file) do
    row
    |> CSV.encode()
    |> Enum.each(&IO.write(file, &1))
  end

  @impl true
  def handle_batch(
        :default,
        messages,
        _batch_info,
        %{table: table, filepath: filepath, agg_type: agg_type, ticker: ticker} = _context
      ) do
    Logger.info("processing batch of #{length(messages)}")

    file = File.open!(filepath, [:append, :utf8])

    messages
    |> Enum.map(fn e -> e.data end)
    |> aggregate_row_from_batch(agg_type)
    |> append_row_to_csv(file)

    order = TradingCycle.random_order_generation()
    TradingCycle.execute_order(order, table, ticker)

    messages
  end

  def transform(event, _opts) do
    %Message{data: event, acknowledger: {__MODULE__, :ack_id, :ack_data}}
  end

  # Write acknowledge code here:
  def ack(:ack_id, _successful, _failed), do: :noop
end
