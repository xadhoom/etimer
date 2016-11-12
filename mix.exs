defmodule Etimer.Mixfile do
  use Mix.Project

  def project do
    [app: :etimer,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, 
      "coveralls.post": :test, "coveralls.travis": :test],
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
      {:gproc, "~> 0.6.1"},
      {:dialyxir, "~> 0.4", only: [:dev]},
      {:ex_doc, "~> 0.14.3"},
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:meck, "~> 0.8", only: [:test]},
      {:excoveralls, "~> 0.5", only: [:test]}
    ]
  end
end
