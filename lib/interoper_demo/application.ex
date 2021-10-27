defmodule InteroperDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @agg_type Application.compile_env!(:interoper_demo, [:aggregation_type])
  @ticker Application.compile_env!(:interoper_demo, [:ticker])
  @url Application.compile_env!(:interoper_demo, [:url])
  @persist Application.compile_env!(:interoper_demo, [:flags, :persist])
  @only_gather Application.compile_env!(:interoper_demo, [:flags, :only_gather])
  @batch_size Application.compile_env!(:interoper_demo, [:batch_size])
  @observations_cache_file Application.compile_env!(:interoper_demo, [:observations_cache_file])
  @model_pickle Application.compile_env!(:interoper_demo, [:model_pickle])

  @impl true
  def start(_type, _args) do
    url = "#{@url}#{@ticker}@trade"
    filepath = "test_#{@ticker}_#{@agg_type}.csv"

    children = [
      # Starts a worker by calling: InteroperDemo.Worker.start_link(arg)
      {Phoenix.PubSub, name: InteroperDemo.PubSub},
      {InteroperDemo.Broadway,
       [
         agg_type: @agg_type,
         ticker: @ticker,
         name: String.to_atom("#{@ticker}_#{@agg_type}"),
         filepath: filepath,
         persist?: @persist,
         only_gather?: @only_gather,
         batch_size: @batch_size,
         observations_cache_file: @observations_cache_file,
         model_pickle: @model_pickle
       ]},
      {InteroperDemo.Socket, url}
    ]

    opts = [strategy: :one_for_one, name: InteroperDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
