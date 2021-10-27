import Config

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :interoper_demo,
  aggregation_type: "size",
  # "time"
  ticker: "ethusdt",
  # "btcusdt", "ethbtc"
  url: "wss://stream.binance.com:9443/ws/",
  batch_size: 1000,
  observations_cache_file: "test_ethusdt_size.csv",
  model_pickle: "rf_model.pickle"

config :interoper_demo, :flags,
  persist: true,
  only_gather: false

import_config "#{Mix.env()}.exs"
