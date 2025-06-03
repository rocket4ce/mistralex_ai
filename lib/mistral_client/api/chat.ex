defmodule MistralClient.API.Chat do
  @moduledoc """
  Chat completions API for the Mistral AI client.

  This module provides functions for creating chat completions, both streaming
  and non-streaming, with support for tools, function calling, and structured outputs.

  ## Features

    * Standard chat completions
    * Streaming chat completions
    * Tool/function calling support
    * Structured output parsing
    * Temperature and sampling controls
    * Token usage tracking

  ## Usage

      # Basic chat completion
      {:ok, response} = MistralClient.API.Chat.complete([
        %{role: "user", content: "Hello, how are you?"}
      ])

      # Chat with options
      {:ok, response} = MistralClient.API.Chat.complete(
        [%{role: "user", content: "Hello!"}],
        %{model: "mistral-large-latest", temperature: 0.7}
      )

      # Streaming chat
      MistralClient.API.Chat.stream([
        %{role: "user", content: "Tell me a story"}
      ], fn chunk ->
        content = get_in(chunk, ["choices", Access.at(0), "delta", "content"])
        if content, do: IO.write(content)
      end)
  """

  alias MistralClient.{Client, Models, Errors}
  require Logger

  @default_model "mistral-large-latest"
  @endpoint "/chat/completions"

  @type message :: Models.Message.t() | map()
  @type options :: %{
          model: String.t(),
          temperature: float() | nil,
          max_tokens: integer() | nil,
          top_p: float() | nil,
          stream: boolean() | nil,
          tools: list() | nil,
          tool_choice: String.t() | map() | nil,
          response_format: map() | nil,
          safe_prompt: boolean() | nil,
          random_seed: integer() | nil
        }

  @doc """
  Create a chat completion.

  ## Parameters

    * `config` - Configuration keyword list or Client struct
    * `request` - Request map with messages and options

  ## Request Options

    * `:model` - Model to use (default: "mistral-large-latest")
    * `:messages` - List of message maps (required)
    * `:temperature` - Sampling temperature (0.0 to 1.0)
    * `:max_tokens` - Maximum tokens to generate
    * `:top_p` - Nucleus sampling parameter
    * `:tools` - List of available tools/functions
    * `:tool_choice` - Tool choice strategy
    * `:response_format` - Structured output format
    * `:safe_prompt` - Enable safety filtering
    * `:random_seed` - Random seed for reproducibility

  ## Examples

      config = [api_key: "your-api-key"]
      request = %{
        "messages" => [%{"role" => "user", "content" => "Hello!"}],
        "model" => "mistral-tiny"
      }
      {:ok, response} = MistralClient.API.Chat.complete(config, request)
  """
  @spec complete(keyword() | Client.t(), map()) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def complete(config, request)
      when (is_list(config) or is_struct(config, Client) or
              is_struct(config, MistralClient.Config)) and is_map(request) do
    client = get_or_create_client(config)

    with {:ok, request_body} <- build_request_body_from_request(request, false),
         {:ok, response} <- Client.request(client, :post, @endpoint, request_body) do
      completion = Models.ChatCompletion.from_map(response)
      {:ok, completion}
    end
  end

  @doc """
  Create a chat completion (legacy interface).

  ## Parameters

    * `messages` - List of message maps or structs
    * `options` - Optional parameters for the completion
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, response} = MistralClient.API.Chat.complete([
        %{role: "user", content: "What is the capital of France?"}
      ])
  """
  @spec complete(list(message()), options(), Client.t() | nil) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def complete(messages, options \\ %{}, client \\ nil)
      when is_list(messages) and is_map(options) do
    client = client || Client.new()

    with {:ok, request_body} <- build_request_body(messages, options, false),
         {:ok, response} <- Client.request(client, :post, @endpoint, request_body) do
      completion = Models.ChatCompletion.from_map(response)
      {:ok, completion}
    end
  end

  @doc """
  Create a streaming chat completion.

  ## Parameters

    * `config` - Configuration keyword list or Client struct
    * `request` - Request map with messages and options
    * `callback` - Function to handle each chunk (optional, returns stream if not provided)

  ## Examples

      config = [api_key: "your-api-key"]
      request = %{
        "messages" => [%{"role" => "user", "content" => "Tell me a story"}],
        "model" => "mistral-tiny"
      }
      {:ok, stream} = MistralClient.API.Chat.stream(config, request)
  """
  @spec stream(keyword() | Client.t(), map(), function() | nil) ::
          {:ok, Enumerable.t()} | :ok | {:error, Exception.t()}
  def stream(config, request, callback \\ nil)

  def stream(config, request, callback)
      when is_list(config) or is_struct(config, Client) or is_struct(config, MistralClient.Config) do
    client = get_or_create_client(config)

    with {:ok, request_body} <- build_request_body_from_request(request, true) do
      if callback do
        Client.stream_request(client, :post, @endpoint, request_body, callback)
      else
        # Return a stream for testing - delegate to the HTTP client
        client.http_client.stream_request(
          :post,
          build_url(client.config.base_url, @endpoint),
          build_headers(client.config),
          request_body,
          []
        )
      end
    end
  end

  @doc """
  Create a chat completion with structured output parsing.

  ## Parameters

    * `messages` - List of message maps or structs
    * `response_format` - JSON schema for structured output
    * `options` - Optional parameters for the completion
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      schema = %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          age: %{type: "integer"}
        },
        required: ["name", "age"]
      }

      {:ok, response} = MistralClient.API.Chat.parse(
        [%{role: "user", content: "Extract: John is 25 years old"}],
        schema
      )
  """
  @spec parse(list(message()), map(), options(), Client.t() | nil) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def parse(messages, response_format, options \\ %{}, client \\ nil) do
    options_with_format = Map.put(options, :response_format, response_format)
    complete(messages, options_with_format, client)
  end

  @doc """
  Create a chat completion with tool/function calling.

  ## Parameters

    * `messages` - List of message maps or structs
    * `tools` - List of available tools/functions
    * `options` - Optional parameters for the completion
    * `client` - HTTP client (optional, uses default if not provided)

  ## Tool Format

      tools = [
        %{
          type: "function",
          function: %{
            name: "get_weather",
            description: "Get current weather for a location",
            parameters: %{
              type: "object",
              properties: %{
                location: %{type: "string", description: "City name"}
              },
              required: ["location"]
            }
          }
        }
      ]

  ## Examples

      {:ok, response} = MistralClient.API.Chat.with_tools(
        [%{role: "user", content: "What's the weather in Paris?"}],
        tools
      )
  """
  @spec with_tools(list(message()), list(map()), options(), Client.t() | nil) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def with_tools(messages, tools, options \\ %{}, client \\ nil) do
    options_with_tools = Map.put(options, :tools, tools)
    complete(messages, options_with_tools, client)
  end

  # Private functions

  defp get_or_create_client(config) when is_list(config) do
    Client.new(config)
  end

  defp get_or_create_client(%Client{} = client), do: client

  defp get_or_create_client(%MistralClient.Config{} = config) do
    Client.new(config)
  end

  defp build_request_body_from_request(request, stream?) do
    messages = Map.get(request, "messages") || Map.get(request, :messages)

    if messages do
      # Convert string keys to atoms for consistency
      options =
        request
        |> Map.drop(["messages", :messages])
        |> convert_string_keys_to_atoms()

      build_request_body(messages, options, stream?)
    else
      {:error,
       Errors.ValidationError.exception(
         message: "Request must contain 'messages' field",
         field: "messages"
       )}
    end
  end

  defp convert_string_keys_to_atoms(map) when is_map(map) do
    # Known string keys that should be converted to atoms
    known_keys = %{
      "model" => :model,
      "temperature" => :temperature,
      "max_tokens" => :max_tokens,
      "top_p" => :top_p,
      "tools" => :tools,
      "tool_choice" => :tool_choice,
      "response_format" => :response_format,
      "safe_prompt" => :safe_prompt,
      "random_seed" => :random_seed,
      "stream" => :stream
    }

    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_binary(key) ->
        case Map.get(known_keys, key) do
          # Keep unknown string keys as-is
          nil -> Map.put(acc, key, value)
          atom_key -> Map.put(acc, atom_key, value)
        end

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp build_request_body(messages, options, stream?) do
    with {:ok, formatted_messages} <- format_messages(messages) do
      request_body =
        %{
          model: Map.get(options, :model, @default_model),
          messages: formatted_messages,
          stream: stream?
        }
        |> add_optional_field(:temperature, options)
        |> add_optional_field(:max_tokens, options)
        |> add_optional_field(:top_p, options)
        |> add_optional_field(:tools, options)
        |> add_optional_field(:tool_choice, options)
        |> add_optional_field(:response_format, options)
        |> add_optional_field(:safe_prompt, options)
        |> add_optional_field(:random_seed, options)

      case validate_request_body(request_body) do
        :ok -> {:ok, request_body}
        {:error, _} = error -> error
      end
    end
  end

  defp format_messages(messages) when is_list(messages) do
    formatted =
      Enum.map(messages, fn
        %Models.Message{} = message -> Models.Message.to_map(message)
        message when is_map(message) -> message
        _ -> nil
      end)

    if Enum.any?(formatted, &is_nil/1) do
      {:error,
       Errors.ValidationError.exception(
         message: "All messages must be maps or Message structs",
         field: "messages"
       )}
    else
      {:ok, formatted}
    end
  end

  defp format_messages(_messages) do
    {:error,
     Errors.ValidationError.exception(
       message: "Messages must be a list",
       field: "messages"
     )}
  end

  defp add_optional_field(body, field, options) do
    case Map.get(options, field) do
      nil -> body
      value -> Map.put(body, field, value)
    end
  end

  defp validate_request_body(body) do
    cond do
      not is_binary(body[:model]) or body[:model] == "" ->
        {:error,
         Errors.ValidationError.exception(
           message: "Model must be a non-empty string",
           field: "model"
         )}

      not is_list(body[:messages]) or body[:messages] == [] ->
        {:error,
         Errors.ValidationError.exception(
           message: "Messages must be a non-empty list",
           field: "messages"
         )}

      body[:temperature] &&
          (not is_number(body[:temperature]) or
             body[:temperature] < 0 or body[:temperature] > 2) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Temperature must be a number between 0 and 2",
           field: "temperature"
         )}

      body[:max_tokens] && (not is_integer(body[:max_tokens]) or body[:max_tokens] <= 0) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Max tokens must be a positive integer",
           field: "max_tokens"
         )}

      body[:top_p] &&
          (not is_number(body[:top_p]) or
             body[:top_p] <= 0 or body[:top_p] > 1) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Top-p must be a number between 0 and 1",
           field: "top_p"
         )}

      true ->
        :ok
    end
  end

  # Helper functions for building URLs and headers
  defp build_url(base_url, path) do
    base_url
    |> String.trim_trailing("/")
    |> Kernel.<>("/v1")
    |> Kernel.<>(path)
  end

  defp build_headers(config) do
    [
      {"authorization", "Bearer #{config.api_key}"},
      {"user-agent", config.user_agent},
      {"content-type", "application/json"}
    ]
  end
end
