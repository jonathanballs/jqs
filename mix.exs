defmodule Jqs.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.11"},
      {:flake_id, "~> 0.1.0"},
      {:mix_test_watch, "~> 1.2"},
      {:hammox, "~> 0.7", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["cmd mix setup"]
    ]
  end
end
