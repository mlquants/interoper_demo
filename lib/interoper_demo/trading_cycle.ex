defmodule InteroperDemo.TradingCycle do
  require Logger

  def get_prices_amounts(table, base_coin, quote_coin) do
    [{"price", p}] = :ets.lookup(table, "price")
    [{"amount_" <> ^base_coin, amount_base}] = :ets.lookup(table, "amount_" <> base_coin)
    [{"amount_" <> ^quote_coin, amount_quote}] = :ets.lookup(table, "amount_" <> quote_coin)

    [{"amount_borrowed_" <> ^base_coin, amount_borrowed}] =
      :ets.lookup(table, "amount_borrowed_" <> base_coin)

    %{}
    |> Map.put(:price, String.to_float(p))
    |> Map.put(:amount_base, amount_base)
    |> Map.put(:amount_quote, amount_quote)
    |> Map.put(:amount_borrowed, amount_borrowed)
  end

  def cash_flow_from_sell(
        %{amount_quote: amount_quote, amount_borrowed: amount_borrowed, price: price} =
          _prices_amounts
      ) do
    amount_quote - amount_borrowed * price
  end

  def flatten_all(:buy, table, base_coin, quote_coin, prices_amounts) do
    :ets.insert(
      table,
      {"amount_" <> quote_coin, prices_amounts[:amount_base] * prices_amounts[:price]}
    )

    :ets.insert(table, {"amount_" <> base_coin, 0})
  end

  def flatten_all(:sell, table, base_coin, quote_coin, prices_amounts) do
    :ets.insert(table, {"amount_borrowed_" <> base_coin, 0})

    :ets.insert(
      table,
      {"amount_" <> quote_coin,
       prices_amounts[:amount_quote] + cash_flow_from_sell(prices_amounts)}
    )
  end

  def flatten_all(table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)

    cond do
      prices_amounts[:amount_borrowed] != 0 ->
        flatten_all(:sell, table, base_coin, quote_coin, prices_amounts)

      prices_amounts[:amount_base] != 0 ->
        flatten_all(:buy, table, base_coin, quote_coin, prices_amounts)

      true ->
        :noop
    end

    prices_amounts[:amount_quote]
  end

  def execute_order(:buy, table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)
    :ets.insert(table, {"amount_" <> quote_coin, 0})

    :ets.insert(
      table,
      {"amount_" <> base_coin, prices_amounts[:amount_quote] / prices_amounts[:price]}
    )
  end

  def execute_order(:sell, table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)

    :ets.insert(
      table,
      {"amount_borrowed_" <> base_coin, prices_amounts[:amount_quote] / prices_amounts[:price]}
    )
  end

  def execute_order(order, table, ticker) do
    _amount_quote = flatten_all(table, ticker)

    case order do
      1 -> execute_order(:buy, table, ticker)
      0 -> :noop
      -1 -> execute_order(:sell, table, ticker)
    end

    log_amounts(table, ticker, order)
  end

  def log_amounts(table, <<base_coin::binary-size(3)>> <> quote_coin = _ticker, order) do
    prices_amounts = get_prices_amounts(table, base_coin, quote_coin)
    Logger.info("Amounts: #{inspect(prices_amounts)}, order: #{order}")
  end

  def random_order_generation() do
    Enum.random([1, 0, -1])
  end
end
