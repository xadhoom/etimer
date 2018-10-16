defmodule Etimer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :etimer,
      version: "1.0.0",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.travis": :test
      ],
      # Docs
      name: "Etimer",
      source_url: "https://github.com/xadhoom/etimer",
      docs: [main: "Etimer", extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  def application do
    [applications: [:gproc]]
  end

  defp deps do
    [
      {:gproc, "~> 0.6"},
      {:dialyxir, "~> 0.4", only: [:dev]},
      {:ex_doc, "~> 0.14"},
      {:credo, "~> 0.6", only: [:dev, :test]},
      {:excoveralls, "~> 0.6", only: [:test]}
    ]
  end
end
