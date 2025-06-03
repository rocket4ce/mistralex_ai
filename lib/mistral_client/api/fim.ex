defmodule MistralClient.API.FIM do
  @moduledoc """
  FIM (Fill-in-the-Middle) API for code completion.

  This module provides functions for FIM completion using Mistral's Codestral models.
  FIM is specifically designed for code completion tasks where you have a prefix
  and optionally a suffix, and need the model to fill in the middle.

  ## Supported Models

  - `codestral-2405`
  - `codestral-latest`

  ## Examples

      # Basic FIM completion
      {:ok, completion} = MistralClient.API.FIM.complete(
        client,
        "codestral-2405",
        "def fibonacci(n):",
        suffix: "return result"
      )

      # Streaming FIM completion
      {:ok, stream} = MistralClient.API.FIM.stream(
        client,
        "codestral-2405",
        "def fibonacci(n):",
        suffix: "return result",
        callback: fn chunk -> IO.puts(chunk.content) end
      )
  """

  alias MistralClient.Client
  alias MistralClient.Models.{FIMCompletionRequest, FIMCompletionResponse}

  @fim_endpoint "/fim/completions"

  @doc """
  Perform FIM (Fill-in-the-Middle) completion.

  ## Parameters

    * `client` - The MistralClient.Client instance
    * `model` - Model ID (only codestral models supported)
    * `prompt` - The text/code prefix to complete
    * `opts` - Optional parameters

  ## Options

    * `:suffix` - Optional text/code suffix for context
    * `:temperature` - Sampling temperature (0.0-0.7 recommended)
    * `:top_p` - Nucleus sampling parameter
    * `:max_tokens` - Maximum tokens to generate
    * `:min_tokens` - Minimum tokens to generate
    * `:stop` - Stop sequences (string or list of strings)
    * `:random_seed` - Seed for deterministic results

  ## Examples

      # Basic completion
      {:ok, completion} = MistralClient.API.FIM.complete(
        client,
        "codestral-2405",
        "def fibonacci(n):"
      )

      # With suffix for better context
      {:ok, completion} = MistralClient.API.FIM.complete(
        client,
        "codestral-2405",
        "def fibonacci(n):",
        suffix: "return result",
        max_tokens: 100,
        temperature: 0.2
      )

  ## Returns

    * `{:ok, FIMCompletionResponse.t()}` - On success
    * `{:error, term()}` - On failure
  """
  @spec complete(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, FIMCompletionResponse.t()} | {:error, term()}
  def complete(client, model, prompt, opts \\ []) do
    with :ok <- validate_model(model),
         :ok <- validate_prompt(prompt) do
      request = FIMCompletionRequest.new(model, prompt, opts)
      body = FIMCompletionRequest.to_map(request)

      case Client.request(client, :post, @fim_endpoint, body) do
        {:ok, response_body} ->
          completion = FIMCompletionResponse.from_map(response_body)
          {:ok, completion}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Stream FIM completion with real-time results.

  ## Parameters

    * `client` - The MistralClient.Client instance
    * `model` - Model ID (only codestral models supported)
    * `prompt` - The text/code prefix to complete
    * `opts` - Optional parameters

  ## Options

    * `:suffix` - Optional text/code suffix for context
    * `:temperature` - Sampling temperature (0.0-0.7 recommended)
    * `:top_p` - Nucleus sampling parameter
    * `:max_tokens` - Maximum tokens to generate
    * `:min_tokens` - Minimum tokens to generate
    * `:stop` - Stop sequences (string or list of strings)
    * `:random_seed` - Seed for deterministic results
    * `:callback` - Function to call with each chunk

  ## Examples

      # Stream with callback
      {:ok, stream} = MistralClient.API.FIM.stream(
        client,
        "codestral-2405",
        "def fibonacci(n):",
        suffix: "return result",
        callback: fn chunk ->
          if chunk.content do
            IO.write(chunk.content)
          end
        end
      )

      # Collect all chunks
      {:ok, chunks} = MistralClient.API.FIM.stream(
        client,
        "codestral-2405",
        "def fibonacci(n):"
      )

  ## Returns

    * `{:ok, list()}` - List of stream chunks when no callback provided
    * `{:ok, :done}` - When callback is provided and streaming completes
    * `{:error, term()}` - On failure
  """
  @spec stream(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, list() | :done} | {:error, term()}
  def stream(client, model, prompt, opts \\ []) do
    with :ok <- validate_model(model),
         :ok <- validate_prompt(prompt) do
      # Force streaming and remove callback from request body
      {callback, request_opts} = Keyword.pop(opts, :callback)
      request_opts = Keyword.put(request_opts, :stream, true)

      request = FIMCompletionRequest.new(model, prompt, request_opts)
      body = FIMCompletionRequest.to_map(request)

      case Client.stream_request(client, :post, @fim_endpoint, body, callback) do
        {:ok, result} -> {:ok, result}
        :ok -> {:ok, :done}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # New structured API interface
  @doc """
  Perform FIM completion using structured request.

  ## Parameters

    * `client` - The MistralClient.Client instance
    * `request` - FIMCompletionRequest struct

  ## Examples

      request = MistralClient.Models.FIMCompletionRequest.new(
        "codestral-2405",
        "def fibonacci(n):",
        suffix: "return result",
        max_tokens: 100
      )

      {:ok, completion} = MistralClient.API.FIM.complete(client, request)

  ## Returns

    * `{:ok, FIMCompletionResponse.t()}` - On success
    * `{:error, term()}` - On failure
  """
  @spec complete(Client.t(), FIMCompletionRequest.t()) ::
          {:ok, FIMCompletionResponse.t()} | {:error, term()}
  def complete(client, %FIMCompletionRequest{} = request) do
    with :ok <- validate_model(request.model),
         :ok <- validate_prompt(request.prompt) do
      body = FIMCompletionRequest.to_map(request)

      case Client.request(client, :post, @fim_endpoint, body) do
        {:ok, response_body} ->
          completion = FIMCompletionResponse.from_map(response_body)
          {:ok, completion}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Stream FIM completion using structured request.

  ## Parameters

    * `client` - The MistralClient.Client instance
    * `request` - FIMCompletionRequest struct
    * `callback` - Optional callback function for streaming

  ## Examples

      request = MistralClient.Models.FIMCompletionRequest.new(
        "codestral-2405",
        "def fibonacci(n):",
        suffix: "return result",
        stream: true
      )

      {:ok, chunks} = MistralClient.API.FIM.stream_request(client, request)

  ## Returns

    * `{:ok, list() | :done}` - Stream result
    * `{:error, term()}` - On failure
  """
  @spec stream_request(Client.t(), FIMCompletionRequest.t(), function() | nil) ::
          {:ok, list() | :done} | {:error, term()}
  def stream_request(client, %FIMCompletionRequest{} = request, callback \\ nil) do
    with :ok <- validate_model(request.model),
         :ok <- validate_prompt(request.prompt) do
      # Ensure streaming is enabled
      request = %{request | stream: true}
      body = FIMCompletionRequest.to_map(request)

      case Client.stream_request(client, :post, @fim_endpoint, body, callback) do
        {:ok, result} -> {:ok, result}
        :ok -> {:ok, :done}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Validation functions
  defp validate_model(model) when is_binary(model) do
    if model in ["codestral-2405", "codestral-latest"] do
      :ok
    else
      {:error, "FIM completion only supports codestral models: codestral-2405, codestral-latest"}
    end
  end

  defp validate_model(_), do: {:error, "Model must be a string"}

  defp validate_prompt(prompt) when is_binary(prompt) and byte_size(prompt) > 0, do: :ok
  defp validate_prompt(_), do: {:error, "Prompt must be a non-empty string"}
end
