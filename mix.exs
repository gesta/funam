defmodule Funam.Mixfile do
  use Mix.Project

  def project do
    [app: :funam,
     version: "0.0.1",
     elixir: "~> 1.4",
     deps: deps()]
  end

  def application do
    [mod: {Funam, []},
     applications: [:logger, :httpotion, :poison]]
  end

  defp deps do
    [
      {:httpotion, "~> 3.0.2"},
      {:poison, "~> 3.1.0"},
    ]
  end
end
