defmodule InteroperDemo.Interchange do
  require Logger
  def obtain_order() do
    random_order_generation()
  end

  def random_order_generation() do
    Enum.random([1, 0, -1])
  end

  @spec preprocess_row(<<_::32>>, [...]) :: any
  def preprocess_row("time", [values] = _row) do
    ["open", "high", "low", "close", "volume", "timestamp", "b2s", "batch_len"]
    |> Enum.zip(values) |> Enum.into(%{})
  end

  def preprocess_row("size", [values] = _row) do
    ["open", "high", "low", "close", "volume", "timestamp", "b2s"]
    |> Enum.zip(values) |> Enum.into(%{})
  end

  def obtain_order(agg_type, table, row) do
    row = preprocess_row(agg_type, row)
    [{"medio_name", name}] = :ets.lookup(table, "medio_name")
    pred = Medio.predict(name, row)
    response = case pred do
      {:ok, %{"prediction" => order }} -> order
      resp -> Logger.warn(inspect(resp))
    end
    response
  end

end
