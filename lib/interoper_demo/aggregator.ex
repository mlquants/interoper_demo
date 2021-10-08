defmodule InteroperDemo.Aggregator do
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
end
