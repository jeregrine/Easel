defmodule Easel.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/jasonstiebs/easel"

  def project do
    [
      app: :easel,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: ["test"],
      test_pattern: "*_test.exs",
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger] ++ optional_apps()
    ]
  end

  defp optional_apps do
    if match?({:module, _}, Code.ensure_compiled(:wx)), do: [:wx], else: []
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.0"},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:benchee, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Canvas 2D API for Elixir. Build draw operations as data, render to
    Phoenix LiveView, native wx windows, or your own backend.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv/compat.json priv/easel.webidl priv/static mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
