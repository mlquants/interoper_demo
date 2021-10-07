defmodule InteroperDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :interoper_demo,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {InteroperDemo.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.0.0"},
      {:jason, "~> 1.2.2"},
      {:websockex, "~> 0.4.3"},
      {:qex, "~> 0.5"},
      {:gen_stage, "~> 1.1.1"},
      {:broadway, "~> 1.0.0"},
      {:csv, "~> 2.4"},
      {:medio, path: "/home/andriy/Code/VSCodeProjects/medio"},
      {:credo, "~> 1.5", only: [:test, :dev], runtime: false}
    ]
  end
end
