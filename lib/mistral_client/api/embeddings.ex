defmodule MistralClient.API.Embeddings do
  @moduledoc """
  Embeddings API for the Mistral AI client.

  This module provides functions for generating text embeddings using Mistral's
  embedding models. Embeddings are useful for semantic search, clustering,
  classification, and other NLP tasks.

  ## Features

    * Single and batch text embedding
    * Multiple encoding formats
    * Configurable output dimensions
    * Token usage tracking
    * Async processing support

  ## Usage

      # Single text embedding
      {:ok, response} = MistralClient.API.Embeddings.create("Hello, world!")

      # Batch embeddings
      {:ok, response} = MistralClient.API.Embeddings.create([
        "First text",
        "Second text",
        "Third text"
      ])

      # With custom options
      {:ok, response} = MistralClient.API.Embeddings.create(
        "Hello, world!",
        %{model: "mistral-embed", dimensions: 1024}
      )
  """

  alias MistralClient.{Client, Models, Errors}
  require Logger

  @default_model "mistral-embed"
  @endpoint "/embeddings"

  @type inputs :: String.t() | list(String.t())
  @type options :: %{
          model: String.t(),
          output_dimension: integer() | nil,
          output_dtype: String.t() | nil
        }

  @doc """
  Create embeddings for the given inputs.

  ## Parameters

    * `inputs` - Text string or list of strings to embed
    * `options` - Optional parameters for the embedding
    * `client` - HTTP client (optional, uses default if not provided)

  ## Options

    * `:model` - Model to use (default: "mistral-embed")
    * `:output_dimension` - Number of dimensions for the output embeddings
    * `:output_dtype` - Data type for embeddings ("float", "int8", "uint8", "binary", "ubinary")

  ## Examples

      # Single text
      {:ok, response} = MistralClient.API.Embeddings.create("Hello, world!")

      # Multiple texts
      {:ok, response} = MistralClient.API.Embeddings.create([
        "First document",
        "Second document"
      ])

      # With options
      {:ok, response} = MistralClient.API.Embeddings.create(
        "Hello, world!",
        %{model: "mistral-embed", output_dimension: 512}
      )
  """
  @spec create(inputs(), options(), Client.t() | nil) ::
          {:ok, Models.EmbeddingResponse.t()} | {:error, Exception.t()}
  def create(inputs, options \\ %{}, client \\ nil) do
    client = client || Client.new()

    with {:ok, request_body} <- build_request_body(inputs, options),
         {:ok, response} <- Client.request(client, :post, @endpoint, request_body) do
      embedding_response = Models.EmbeddingResponse.from_map(response)
      {:ok, embedding_response}
    end
  end

  @doc """
  Create embeddings for a single text string.

  ## Parameters

    * `text` - Text string to embed
    * `options` - Optional parameters for the embedding
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, response} = MistralClient.API.Embeddings.create_single(
        "Hello, world!",
        %{dimensions: 1024}
      )
  """
  @spec create_single(String.t(), options(), Client.t() | nil) ::
          {:ok, Models.EmbeddingResponse.t()} | {:error, Exception.t()}
  def create_single(text, options \\ %{}, client \\ nil) when is_binary(text) do
    create(text, options, client)
  end

  @doc """
  Create embeddings for multiple text strings.

  ## Parameters

    * `texts` - List of text strings to embed
    * `options` - Optional parameters for the embedding
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, response} = MistralClient.API.Embeddings.create_batch([
        "First document",
        "Second document",
        "Third document"
      ])
  """
  @spec create_batch(list(String.t()), options(), Client.t() | nil) ::
          {:ok, Models.EmbeddingResponse.t()} | {:error, Exception.t()}
  def create_batch(texts, options \\ %{}, client \\ nil) when is_list(texts) do
    create(texts, options, client)
  end

  @doc """
  Extract embeddings from a response.

  ## Parameters

    * `response` - Embedding response from the API

  ## Examples

      {:ok, response} = MistralClient.API.Embeddings.create("Hello")
      embeddings = MistralClient.API.Embeddings.extract_embeddings(response)
      # Returns: [[0.1, 0.2, 0.3, ...], ...]
  """
  @spec extract_embeddings(Models.EmbeddingResponse.t()) :: list(list(float()))
  def extract_embeddings(%Models.EmbeddingResponse{data: data}) do
    Enum.map(data, fn %Models.Embedding{embedding: embedding} -> embedding end)
  end

  @doc """
  Extract the first embedding from a response.

  Useful when you know you only embedded a single text.

  ## Parameters

    * `response` - Embedding response from the API

  ## Examples

      {:ok, response} = MistralClient.API.Embeddings.create("Hello")
      embedding = MistralClient.API.Embeddings.extract_first_embedding(response)
      # Returns: [0.1, 0.2, 0.3, ...]
  """
  @spec extract_first_embedding(Models.EmbeddingResponse.t()) :: list(float()) | nil
  def extract_first_embedding(%Models.EmbeddingResponse{data: [first | _]}) do
    first.embedding
  end

  def extract_first_embedding(%Models.EmbeddingResponse{data: []}) do
    nil
  end

  @doc """
  Calculate cosine similarity between two embeddings.

  ## Parameters

    * `embedding1` - First embedding vector
    * `embedding2` - Second embedding vector

  ## Examples

      similarity = MistralClient.API.Embeddings.cosine_similarity(
        [0.1, 0.2, 0.3],
        [0.2, 0.3, 0.4]
      )
  """
  @spec cosine_similarity(list(float()), list(float())) :: float()
  def cosine_similarity(embedding1, embedding2) when length(embedding1) == length(embedding2) do
    dot_product =
      embedding1
      |> Enum.zip(embedding2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.map(embedding1, &(&1 * &1)) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(embedding2, &(&1 * &1)) |> Enum.sum())

    if magnitude1 == 0 or magnitude2 == 0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end

  def cosine_similarity(_embedding1, _embedding2) do
    raise ArgumentError, "Embeddings must have the same length"
  end

  @doc """
  Calculate euclidean distance between two embeddings.

  ## Parameters

    * `embedding1` - First embedding vector
    * `embedding2` - Second embedding vector

  ## Examples

      distance = MistralClient.API.Embeddings.euclidean_distance(
        [0.1, 0.2, 0.3],
        [0.2, 0.3, 0.4]
      )
  """
  @spec euclidean_distance(list(float()), list(float())) :: float()
  def euclidean_distance(embedding1, embedding2) when length(embedding1) == length(embedding2) do
    embedding1
    |> Enum.zip(embedding2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  def euclidean_distance(_embedding1, _embedding2) do
    raise ArgumentError, "Embeddings must have the same length"
  end

  # Private functions

  defp build_request_body(inputs, options) do
    with {:ok, formatted_inputs} <- format_inputs(inputs) do
      request_body =
        %{
          "model" => Map.get(options, :model, @default_model),
          "inputs" => formatted_inputs
        }
        |> add_optional_field("output_dimension", Map.get(options, :output_dimension))
        |> add_optional_field("output_dtype", Map.get(options, :output_dtype))

      case validate_request_body(request_body) do
        :ok -> {:ok, request_body}
        {:error, _} = error -> error
      end
    end
  end

  defp format_inputs(inputs) when is_binary(inputs) and byte_size(inputs) > 0 do
    {:ok, inputs}
  end

  defp format_inputs(inputs) when is_list(inputs) do
    if length(inputs) > 0 and Enum.all?(inputs, &(is_binary(&1) and byte_size(&1) > 0)) do
      {:ok, inputs}
    else
      {:error,
       Errors.ValidationError.exception(
         message: "All input texts must be non-empty strings",
         field: "inputs"
       )}
    end
  end

  defp format_inputs(_inputs) do
    {:error,
     Errors.ValidationError.exception(
       message: "Inputs must be a string or list of strings",
       field: "inputs"
     )}
  end

  defp add_optional_field(body, field, value) do
    case value do
      nil -> body
      value -> Map.put(body, field, value)
    end
  end

  defp validate_request_body(body) do
    cond do
      not is_binary(body["model"]) or body["model"] == "" ->
        {:error,
         Errors.ValidationError.exception(
           message: "Model must be a non-empty string",
           field: "model"
         )}

      body["output_dtype"] && not is_binary(body["output_dtype"]) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Output dtype must be a string",
           field: "output_dtype"
         )}

      body["output_dtype"] &&
          body["output_dtype"] not in ["float", "int8", "uint8", "binary", "ubinary"] ->
        {:error,
         Errors.ValidationError.exception(
           message: "Output dtype must be one of: float, int8, uint8, binary, ubinary",
           field: "output_dtype"
         )}

      body["output_dimension"] &&
          (not is_integer(body["output_dimension"]) or body["output_dimension"] <= 0) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Output dimension must be a positive integer",
           field: "output_dimension"
         )}

      true ->
        :ok
    end
  end
end
