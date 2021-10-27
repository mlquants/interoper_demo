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
    observations_cache_file = opts |> Keyword.fetch!(:observations_cache_file)
    model_pickle = opts |> Keyword.fetch!(:model_pickle)
    {:ok, medio_name} = Medio.start(Medio.Primo, "python", @path_to_python_script, "#{observations_cache_file} #{model_pickle}")

    table =
      opts
      |> Keyword.fetch!(:name)
      |> Utils.table_init(Keyword.fetch!(opts, :ticker), medio_name)

    agg_type = opts |> Keyword.fetch!(:agg_type)
    batch_size = opts |> Keyword.fetch!(:batch_size)

    batchers =
      case agg_type do
        "time" ->
          [default: [concurrency: 1, batch_size: 1_000_000, batch_timeout: :timer.minutes(1)]]

        "size" ->
          [default: [concurrency: 1, batch_size: batch_size, batch_timeout: :timer.hours(1)]]
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
        ticker: opts |> Keyword.fetch!(:ticker),
        persist?: opts |> Keyword.fetch!(:persist?),
        only_gather?: opts |> Keyword.fetch!(:only_gather?)
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
        %{
          table: table,
          filepath: filepath,
          agg_type: agg_type,
          ticker: ticker,
          persist?: persist?,
          only_gather?: only_gather?
        } = _context
      ) do
    Logger.info("processing batch of #{length(messages)}")

    row =
      messages
      |> Enum.map(fn e -> e.data end)
      |> Aggregator.aggregate_row_from_batch(agg_type)

    if persist? do
      Utils.append_row_to_csv(row, filepath)
    end

    if not only_gather? do
      order = Interchange.obtain_order(agg_type, table, row)
      PaperTrading.execute_order(order, table, ticker)
    end

    messages
  end

  def transform(event, _opts) do
    %Message{data: event, acknowledger: {__MODULE__, :ack_id, :ack_data}}
  end

  # Write acknowledge code here:
  def ack(:ack_id, _successful, _failed), do: :noop
end
