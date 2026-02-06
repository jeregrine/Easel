defmodule Canvas.MixProject do
  use Mix.Project

  def project do
    [
      app: :canvas,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.0"},
      {:benchee, "~> 1.0", only: :test}
    ]
  end
end
