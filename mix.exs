defmodule HnScraper.MixProject do
  use Mix.Project

  def project do
    [
      app: :hn_scraper,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {HnScraper.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:floki, "~> 0.35"},
      {:postgrex, "~> 0.17"}
    ]
  end
end
