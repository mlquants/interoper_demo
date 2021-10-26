defmodule InteroperDemo.Broadway do
  @moduledoc """
  A Broadway pipeline.
  """
  use Broadway

  alias Broadway.Message
  alias InteroperDemo.Queue
  alias InteroperDemo.PaperTrading
  alias InteroperDemo.Aggregator
  alias InteroperDemo.Utils
  alias InteroperDemo.Interchange

  require Logger

  @path_to_python_script Path.relative_to_cwd("lib/python/predict.py")

  def start_link(opts) do
    {:ok, medio_name} = Medio.start(Medio.Primo, "python", @path_to_python_script, "model foo")

    table =
      opts
      |> Keyword.fetch!(:name)
      |> Utils.table_init(Keyword.fetch!(opts, :ticker), medio_name)

    agg_type = opts |> Keyword.fetch!(:agg_type)

    batchers =
      case agg_type do
        "time" ->
          [default: [concurrency: 1, batch_size: 1_000_000, batch_timeout: :timer.minutes(1)]]

        "size" ->
          [default: [concurrency: 1, batch_size: 100, batch_timeout: :timer.hours(1)]]
          # [default: [concurrency: 1, batch_size: 1000, batch_timeout: :timer.hours(1)]]
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

  @impl true
  def handle_batch(
        :default,
        messages,
        _batch_info,
        %{table: table, filepath: filepath, agg_type: agg_type, ticker: ticker} = _context
      ) do
    Logger.info("processing batch of #{length(messages)}")

    row =
      messages
      |> Enum.map(fn e -> e.data end)
      |> Aggregator.aggregate_row_from_batch(agg_type)

    # Utils.append_row_to_csv(row, filepath)

    order = Interchange.obtain_order(agg_type, table, row)
    PaperTrading.execute_order(order, table, ticker)

    messages
  end

  def transform(event, _opts) do
    %Message{data: event, acknowledger: {__MODULE__, :ack_id, :ack_data}}
  end

  # Write acknowledge code here:
  def ack(:ack_id, _successful, _failed), do: :noop
end
