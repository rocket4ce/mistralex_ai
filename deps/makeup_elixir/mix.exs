defmodule MakeupElixir.Mixfile do
  use Mix.Project

  @version "1.0.1"
  @url "https://github.com/elixir-makeup/makeup_elixir"

  def project do
    [
      app: :makeup_elixir,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      aliases: aliases()
    ]
  end

  defp description do
    """
    Elixir lexer for the Makeup syntax highlighter.
    """
  end

  defp package do
    [
      name: :makeup_elixir,
      licenses: ["BSD-2-Clause"],
      maintainers: ["Tiago Barroso <tmbb@campus.ul.pt>"],
      links: %{"GitHub" => @url}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [],
      mod: {Makeup.Lexers.ElixirLexer.Application, []},
      env: [sigil_lexers: %{}]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:makeup, "~> 1.0"},
      {:nimble_parsec, "~> 1.2.3 or ~> 1.3"},
      # Generate unicode character lists
      {:unicode_set, "~> 1.4", only: :dev},
      # Benchmarking utilities
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_markdown, "~> 0.2", only: :dev}
    ]
  end

  defp aliases do
    [docs: &build_docs/1]
  end

  defp build_docs(_) do
    Mix.Task.run("compile")
    ex_doc = Path.join(Mix.path_for(:escripts), "ex_doc")

    unless File.exists?(ex_doc) do
      raise "cannot build docs because escript for ex_doc is not installed, run \"mix escript.install hex ex_doc\""
    end

    paths = Path.join(Mix.Project.build_path(), "lib/*/ebin")
    args = ["MakeupElixir", @version, Mix.Project.compile_path()]
    opts = ~w[--main Makeup.Lexers.ElixirLexer --source-ref v#{@version} --source-url #{@url}]
    System.cmd(ex_doc, args ++ ["--paths", paths] ++ opts)
    Mix.shell().info("Docs built successfully")
  end
end
