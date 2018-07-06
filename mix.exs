defmodule Pigeon.Mixfile do
  use Mix.Project

  def project do
    [app: :pigeon,
     version: "1.0.0",
     elixir: "~> 1.5",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [mod: {Pigeon, []},
     applications: [:logger, :hackney, :poison, :sweet_xml, :httpotion, :porcelain]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:httpotion, "~> 3.0"},
      {:hackney, "~> 1.10"},
      {:ibrowse, "~> 4.2", override: true},
      {:sweet_xml, "~> 0.6"},
      {:porcelain, "~> 2.0"},
      {:geoip, "~> 0.1"},
    ]
  end
end
