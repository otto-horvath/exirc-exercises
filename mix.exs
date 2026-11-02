defmodule ExircExercises.MixProject do
  use Mix.Project

  def project do
    [
      app: :exirc_exercises,
      version: "0.1.0",
      elixir: "~> 1.20.0",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end
end
