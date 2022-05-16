defmodule TokenCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :token_cache,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {TokenCache.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_options, "~> 0.4.0"}
    ]
  end
end
