defmodule MistralClient.API.Agents do
  @moduledoc """
  Agents API for the Mistral AI client.

  This module provides functions for creating agent completions, both streaming
  and non-streaming, with support for tools, function calling, and agent-specific
  configurations.

  ## Features

    * Agent-based chat completions
    * Streaming agent completions
    * Tool/function calling support for agents
    * Agent-specific configurations
    * Temperature and sampling controls
    * Token usage tracking

  ## Usage

      # Basic agent completion
      {:ok, response} = MistralClient.API.Agents.complete(
        "agent-123",
        [%{role: "user", content: "Hello, how are you?"}]
      )

      # Agent completion with options
      {:ok, response} = MistralClient.API.Agents.complete(
        "agent-123",
        [%{role: "user", content: "Hello!"}],
        %{temperature: 0.7, max_tokens: 100}
      )

      # Streaming agent completion
      MistralClient.API.Agents.stream(
        "agent-123",
        [%{role: "user", content: "Tell me a story"}],
        fn chunk ->
          content = get_in(chunk, ["choices", Access.at(0), "delta", "content"])
          if content, do: IO.write(content)
        end
      )
  """

  alias MistralClient.{Client, Models, Errors}
  require Logger

  @endpoint "/agents/completions"

  @type message :: Models.Message.t() | map()
  @type options :: %{
          temperature: float() | nil,
          max_tokens: integer() | nil,
          top_p: float() | nil,
          stream: boolean() | nil,
          tools: list() | nil,
          tool_choice: String.t() | map() | nil,
          response_format: map() | nil,
          random_seed: integer() | nil,
          stop: String.t() | list(String.t()) | nil,
          presence_penalty: float() | nil,
          frequency_penalty: float() | nil,
          n: integer() | nil,
          prediction: map() | nil,
          parallel_tool_calls: boolean() | nil
        }

  @doc """
  Create an agent completion.

  ## Parameters

    * `config` - Configuration keyword list or Client struct
    * `request` - Request map with agent_id, messages and options

  ## Request Options

    * `:agent_id` - Agent ID to use for completion (required)
    * `:messages` - List of message maps (required)
    * `:temperature` - Sampling temperature (0.0 to 2.0)
    * `:max_tokens` - Maximum tokens to generate
    * `:top_p` - Nucleus sampling parameter
    * `:tools` - List of available tools/functions
    * `:tool_choice` - Tool choice strategy
    * `:response_format` - Structured output format
    * `:random_seed` - Random seed for reproducibility
    * `:stop` - Stop sequences
    * `:presence_penalty` - Presence penalty (-2.0 to 2.0)
    * `:frequency_penalty` - Frequency penalty (-2.0 to 2.0)
    * `:n` - Number of completions to return
    * `:prediction` - Prediction configuration
    * `:parallel_tool_calls` - Enable parallel tool calls

  ## Examples

      config = [api_key: "your-api-key"]
      request = %{
        "agent_id" => "agent-123",
        "messages" => [%{"role" => "user", "content" => "Hello!"}]
      }
      {:ok, response} = MistralClient.API.Agents.complete(config, request)
  """
  @spec complete(keyword() | Client.t() | MistralClient.Config.t(), map()) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def complete(config, request)
      when is_list(config) or is_struct(config, Client) or is_struct(config, MistralClient.Config) do
    client = get_or_create_client(config)

    with {:ok, request_body} <- build_request_body_from_request(request, false),
         {:ok, response} <- Client.request(client, :post, @endpoint, request_body) do
      completion = Models.ChatCompletion.from_map(response)
      {:ok, completion}
    end
  end

  @doc """
  Create an agent completion (legacy interface).

  ## Parameters

    * `agent_id` - Agent ID to use for completion
    * `messages` - List of message maps or structs
    * `options` - Optional parameters for the completion
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, response} = MistralClient.API.Agents.complete(
        "agent-123",
        [%{role: "user", content: "What is the capital of France?"}]
      )
  """
  @spec complete(String.t(), list(message()), options(), Client.t() | nil) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def complete(agent_id, messages, options \\ %{}, client \\ nil)
      when is_binary(agent_id) and is_list(messages) do
    client = client || get_default_client()

    with {:ok, request_body} <- build_request_body(agent_id, messages, options, false),
         {:ok, response} <- Client.request(client, :post, @endpoint, request_body) do
      completion = Models.ChatCompletion.from_map(response)
      {:ok, completion}
    end
  end

  @doc """
  Create a streaming agent completion.

  ## Parameters

    * `config` - Configuration keyword list or Client struct
    * `request` - Request map with agent_id, messages and options
    * `callback` - Function to handle each chunk (optional, returns stream if not provided)

  ## Examples

      config = [api_key: "your-api-key"]
      request = %{
        "agent_id" => "agent-123",
        "messages" => [%{"role" => "user", "content" => "Tell me a story"}]
      }
      {:ok, stream} = MistralClient.API.Agents.stream(config, request)
  """
  @spec stream(keyword() | Client.t() | MistralClient.Config.t(), map(), function() | nil) ::
          {:ok, Enumerable.t()} | :ok | {:error, Exception.t()}
  def stream(config, request, callback \\ nil)
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
          Jason.encode!(request_body),
          []
        )
      end
    end
  end

  # Legacy streaming interface - separate function name to avoid conflicts
  @doc """
  Create a streaming agent completion (legacy interface).

  ## Parameters

    * `agent_id` - Agent ID to use for completion
    * `messages` - List of message maps or structs
    * `callback` - Function to handle each chunk
    * `options` - Optional parameters for the completion
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      MistralClient.API.Agents.stream_legacy(
        "agent-123",
        [%{role: "user", content: "Tell me a story"}],
        fn chunk ->
          content = get_in(chunk, ["choices", Access.at(0), "delta", "content"])
          if content, do: IO.write(content)
        end
      )
  """
  @spec stream_legacy(String.t(), list(message()), function(), options(), Client.t() | nil) ::
          :ok | {:error, Exception.t()}
  def stream_legacy(agent_id, messages, callback, options \\ %{}, client \\ nil)
      when is_binary(agent_id) and is_list(messages) and is_function(callback) do
    client = client || get_default_client()

    with {:ok, request_body} <- build_request_body(agent_id, messages, options, true) do
      Client.stream_request(client, :post, @endpoint, request_body, callback)
    end
  end

  @doc """
  Create an agent completion with tool/function calling.

  ## Parameters

    * `agent_id` - Agent ID to use for completion
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

      {:ok, response} = MistralClient.API.Agents.with_tools(
        "agent-123",
        [%{role: "user", content: "What's the weather in Paris?"}],
        tools
      )
  """
  @spec with_tools(String.t(), list(message()), list(map()), options(), Client.t() | nil) ::
          {:ok, Models.ChatCompletion.t()} | {:error, Exception.t()}
  def with_tools(agent_id, messages, tools, options \\ %{}, client \\ nil) do
    options_with_tools = Map.put(options, :tools, tools)
    complete(agent_id, messages, options_with_tools, client)
  end

  # Private functions

  defp get_or_create_client(config) when is_list(config) do
    Client.new(config)
  end

  defp get_or_create_client(%Client{} = client), do: client

  defp get_or_create_client(%MistralClient.Config{} = config) do
    Client.new(config)
  end

  defp get_default_client do
    # Try to get API key from application environment for testing
    api_key = Application.get_env(:mistral_client, :api_key)
    http_client = Application.get_env(:mistral_client, :http_client)

    config = []
    # Always provide a default API key for testing if none is set
    config =
      if api_key,
        do: Keyword.put(config, :api_key, api_key),
        else: Keyword.put(config, :api_key, "test-api-key")

    config = if http_client, do: Keyword.put(config, :http_client, http_client), else: config

    Client.new(config)
  end

  defp build_request_body_from_request(request, stream?) do
    agent_id = Map.get(request, "agent_id") || Map.get(request, :agent_id)
    messages = Map.get(request, "messages") || Map.get(request, :messages)

    cond do
      is_nil(agent_id) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Request must contain 'agent_id' field",
           field: "agent_id"
         )}

      is_nil(messages) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Request must contain 'messages' field",
           field: "messages"
         )}

      true ->
        # Convert string keys to atoms for consistency, but preserve unknown string keys
        options =
          request
          |> Map.drop(["agent_id", :agent_id, "messages", :messages])
          |> convert_string_keys_to_atoms()

        # Build request body and then merge back any unknown string keys
        case build_request_body(agent_id, messages, options, stream?) do
          {:ok, request_body} ->
            # Add any unknown string keys back to the request body
            unknown_keys =
              request
              |> Map.drop(["agent_id", :agent_id, "messages", :messages])
              |> Enum.filter(fn {key, _value} ->
                is_binary(key) and
                  not Map.has_key?(
                    %{
                      "temperature" => true,
                      "max_tokens" => true,
                      "top_p" => true,
                      "tools" => true,
                      "tool_choice" => true,
                      "response_format" => true,
                      "random_seed" => true,
                      "stream" => true,
                      "stop" => true,
                      "presence_penalty" => true,
                      "frequency_penalty" => true,
                      "n" => true,
                      "prediction" => true,
                      "parallel_tool_calls" => true
                    },
                    key
                  )
              end)
              |> Enum.into(%{})

            final_request_body = Map.merge(request_body, unknown_keys)
            {:ok, final_request_body}

          error ->
            error
        end
    end
  end

  defp convert_string_keys_to_atoms(map) when is_map(map) do
    # Known string keys that should be converted to atoms
    known_keys = %{
      "temperature" => :temperature,
      "max_tokens" => :max_tokens,
      "top_p" => :top_p,
      "tools" => :tools,
      "tool_choice" => :tool_choice,
      "response_format" => :response_format,
      "random_seed" => :random_seed,
      "stream" => :stream,
      "stop" => :stop,
      "presence_penalty" => :presence_penalty,
      "frequency_penalty" => :frequency_penalty,
      "n" => :n,
      "prediction" => :prediction,
      "parallel_tool_calls" => :parallel_tool_calls
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

  defp build_request_body(agent_id, messages, options, stream?) do
    with {:ok, formatted_messages} <- format_messages(messages) do
      request_body =
        %{
          agent_id: agent_id,
          messages: formatted_messages,
          stream: stream?
        }
        |> add_optional_field(:temperature, options)
        |> add_optional_field(:max_tokens, options)
        |> add_optional_field(:top_p, options)
        |> add_optional_field(:tools, options)
        |> add_optional_field(:tool_choice, options)
        |> add_optional_field(:response_format, options)
        |> add_optional_field(:random_seed, options)
        |> add_optional_field(:stop, options)
        |> add_optional_field(:presence_penalty, options)
        |> add_optional_field(:frequency_penalty, options)
        |> add_optional_field(:n, options)
        |> add_optional_field(:prediction, options)
        |> add_optional_field(:parallel_tool_calls, options)

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
      not is_binary(body[:agent_id]) or body[:agent_id] == "" ->
        {:error,
         Errors.ValidationError.exception(
           message: "Agent ID must be a non-empty string",
           field: "agent_id"
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

      body[:presence_penalty] &&
          (not is_number(body[:presence_penalty]) or
             body[:presence_penalty] < -2 or body[:presence_penalty] > 2) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Presence penalty must be a number between -2 and 2",
           field: "presence_penalty"
         )}

      body[:frequency_penalty] &&
          (not is_number(body[:frequency_penalty]) or
             body[:frequency_penalty] < -2 or body[:frequency_penalty] > 2) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Frequency penalty must be a number between -2 and 2",
           field: "frequency_penalty"
         )}

      body[:n] && (not is_integer(body[:n]) or body[:n] <= 0) ->
        {:error,
         Errors.ValidationError.exception(
           message: "N must be a positive integer",
           field: "n"
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
