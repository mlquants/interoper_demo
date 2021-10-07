defmodule InteroperDemo.TradingCycle do
  require Logger

  def get_prices_amounts(table, base_coin, quote_coin) do
    [{"price", p}] = :ets.lookup(table, "price")
    [{"amount_" <> ^base_coin, amount_base}] = :ets.lookup(table, "amount_" <> base_coin)
    [{"amount_" <> ^quote_coin, amount_quote}] = :ets.lookup(table, "amount_" <> quote_coin)
    [{"commission", commission}] = :ets.lookup(table, "commission")
    [{"previous_order", order}] = :ets.lookup(table, "previous_order")
    [{"amount_to_repay_" <> ^base_coin, amount_to_repay}] =
      :ets.lookup(table, "amount_to_repay_" <> base_coin)


    [{"amount_borrowed_" <> ^quote_coin, amount_borrowed}] =
      :ets.lookup(table, "amount_borrowed_" <> quote_coin)

    %{}
    |> Map.put(:price, String.to_float(p))
    |> Map.put(:amount_base, amount_base)
    |> Map.put(:amount_quote, amount_quote)
    |> Map.put(:amount_borrowed, amount_borrowed)
    |> Map.put(:commission, commission)
    |> Map.put(:order, order)
    |> Map.put(:amount_to_repay, amount_to_repay)
  end

  # TODO: debug commission on paper
  # TODO: implement staying in position for consecutive orders that match

  def cash_flow_from_sell(:no_commission,
        %{amount_to_repay: amount_to_repay, amount_borrowed: amount_borrowed, price: price} =
          _prices_amounts
      ) do
    amount_borrowed - amount_to_repay * price
  end

  def cash_flow_from_sell(:with_commission,
        %{amount_to_repay: amount_to_repay, amount_borrowed: amount_borrowed, price: price, commission: commission} =
          _prices_amounts
      ) do
        (1-commission) * amount_borrowed - amount_to_repay * price
      end

  def flatten_all(:buy, table, base_coin, quote_coin, prices_amounts) do

    new_amount_no_commission = prices_amounts[:amount_base] * prices_amounts[:price]
    new_amount_with_commission = (1-prices_amounts[:commission]) * new_amount_no_commission
    Logger.info("Flatten new amount no commission: #{new_amount_no_commission}, flatten new amount with commission: #{new_amount_with_commission}")

    :ets.insert(
      table,
      {"amount_" <> quote_coin, new_amount_with_commission}
    )

    :ets.insert(table, {"amount_" <> base_coin, 0})
  end

  def flatten_all(:sell, table, base_coin, quote_coin, prices_amounts) do
    :ets.insert(table, {"amount_borrowed_" <> quote_coin, 0})
    :ets.insert(table, {"amount_to_repay_" <> base_coin, 0})

    new_amount_no_commission = prices_amounts[:amount_quote] + cash_flow_from_sell(:no_commission, prices_amounts)
    new_amount_with_commission = prices_amounts[:amount_quote] + cash_flow_from_sell(:with_commission, prices_amounts)
    Logger.info("Flatten new amount no commission: #{new_amount_no_commission}, flatten new amount with commission: #{new_amount_with_commission}")


    :ets.insert(
      table,
      {"amount_" <> quote_coin, new_amount_with_commission}
    )
  end

  def maybe_flatten_all(order, table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)

    cond do
      prices_amounts[:order] == -1 and order != -1 ->
        flatten_all(:sell, table, base_coin, quote_coin, prices_amounts)

      prices_amounts[:order] == 1 and order != 1 ->
        flatten_all(:buy, table, base_coin, quote_coin, prices_amounts)

      true ->
        :noop
    end

    prices_amounts[:order]
  end

  def execute_order(:buy, table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)
    :ets.insert(table, {"amount_" <> quote_coin, 0})

    new_amount_no_commission = prices_amounts[:amount_quote] / prices_amounts[:price]
    new_amount_with_commission = (1-prices_amounts[:commission]) * new_amount_no_commission
    Logger.info("New amount no commission: #{new_amount_no_commission}, new amount with commission: #{new_amount_with_commission}")

    :ets.insert(
      table,
      {"amount_" <> base_coin, new_amount_with_commission}
    )
  end

  def execute_order(:sell, table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)

    new_amount_no_commission = prices_amounts[:amount_quote]
    amount_to_repay = prices_amounts[:amount_quote] / prices_amounts[:price]
    new_amount_with_commission = (1-prices_amounts[:commission]) * new_amount_no_commission
    Logger.info("New amount no commission: #{new_amount_no_commission}, new amount with commission: #{new_amount_with_commission}")

    :ets.insert(
      table,
      {"amount_borrowed_" <> quote_coin, new_amount_with_commission}
    )
    :ets.insert(
      table,
      {"amount_to_repay_" <> base_coin, amount_to_repay}
    )
  end

  def execute_order(order, table, ticker) do
    previous_order = maybe_flatten_all(order, table, ticker)

    log_amounts(table, ticker, order, "after flatten")
    Logger.info("Previous order: #{inspect(previous_order)}, current order: #{order}")

    cond do
      order == 1 and previous_order != 1 -> execute_order(:buy, table, ticker)
      order == -1 and previous_order != -1 -> execute_order(:sell, table, ticker)
      true -> :noop
    end

    :ets.insert(table, {"previous_order", order})

    log_amounts(table, ticker, order, "end")
  end

  def log_amounts(table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker, order, label \\ "") do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)
    Logger.info("Amounts: #{inspect(prices_amounts)}, order: #{order}, label: #{label}")
  end

  def random_order_generation() do
    Enum.random([1, 0, -1])
  end
end
