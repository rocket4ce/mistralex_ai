defmodule MistralClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :mistralex_ai,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/rocket4ce/mistralex_ai",
      homepage_url: "https://github.com/rocket4ce/mistralex_ai",
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5.0"},
      # JSON handling
      {:jason, "~> 1.4"},
      # Development and testing
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end

  defp description do
    "Elixir client for the Mistral AI API with complete feature parity to the Python SDK."
  end

  defp package do
    [
      name: "mistralex_ai",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/rocket4ce/mistralex_ai"}
    ]
  end

  defp docs do
    [
      main: "MistralClient",
      extras: ["README.md"]
    ]
  end
end
