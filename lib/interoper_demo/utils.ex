defmodule InteroperDemo.Utils do
  def append_row_to_csv(row, filepath) do
    file = File.open!(filepath, [:append, :utf8])

    row
    |> CSV.encode()
    |> Enum.each(&IO.write(file, &1))
  end

  def table_init(name, <<base_coin::binary-size(3)>> <> quote_coin = _ticker, medio_name) do
    :ets.new(name, [:named_table, :public])
    :ets.insert(name, {"amount_" <> base_coin, 0})
    :ets.insert(name, {"amount_" <> quote_coin, 100})
    :ets.insert(name, {"amount_borrowed_" <> quote_coin, 0})
    :ets.insert(name, {"medio_name", medio_name})
    :ets.insert(name, {"commission", 0.001})
    :ets.insert(name, {"previous_order", 0})
    :ets.insert(name, {"amount_to_repay_" <> base_coin, 0})
    name
  end
end
