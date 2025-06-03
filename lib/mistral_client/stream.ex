defmodule MistralClient.Stream do
  @moduledoc """
  Server-Sent Events (SSE) streaming support for the Mistral AI client.

  This module provides utilities for handling streaming responses from the
  Mistral API, particularly for chat completions that return data in real-time.

  ## Features

    * SSE parsing and handling
    * Chunk processing and validation
    * Stream error recovery
    * Callback-based processing
    * Stream completion detection

  ## Usage

      # Process a stream with a callback
      MistralClient.Stream.process_stream(stream_data, fn chunk ->
        content = get_in(chunk, ["choices", Access.at(0), "delta", "content"])
        if content, do: IO.write(content)
      end)

      # Parse individual SSE chunks
      {:ok, chunk} = MistralClient.Stream.parse_chunk("data: {...}")
  """

  alias MistralClient.Errors
  require Logger

  @type chunk :: map()
  @type callback :: (chunk() -> any())

  @doc """
  Process a stream of Server-Sent Events.

  ## Parameters

    * `stream_data` - Raw stream data
    * `callback` - Function to process each chunk
    * `options` - Processing options (optional)

  ## Options

    * `:validate` - Validate chunks before processing (default: true)
    * `:skip_empty` - Skip empty chunks (default: true)
    * `:timeout` - Stream timeout in milliseconds (default: 30_000)

  ## Examples

      MistralClient.Stream.process_stream(data, fn chunk ->
        case get_in(chunk, ["choices", Access.at(0), "delta", "content"]) do
          nil -> :ok
          content -> IO.write(content)
        end
      end)
  """
  @spec process_stream(binary(), callback(), keyword()) :: :ok | {:error, Exception.t()}
  def process_stream(stream_data, callback, options \\ []) when is_binary(stream_data) do
    validate? = Keyword.get(options, :validate, true)
    skip_empty? = Keyword.get(options, :skip_empty, true)

    stream_data
    |> String.split("\n")
    |> Enum.reduce_while(:ok, fn line, _acc ->
      case parse_line(line, validate?, skip_empty?) do
        {:ok, chunk} ->
          try do
            callback.(chunk)
            {:cont, :ok}
          rescue
            error ->
              Logger.error("Stream callback error: #{Exception.message(error)}")
              {:halt, {:error, error}}
          end

        :skip ->
          {:cont, :ok}

        :done ->
          {:halt, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Parse a single SSE chunk.

  ## Parameters

    * `chunk_data` - Raw chunk data
    * `options` - Parsing options (optional)

  ## Options

    * `:validate` - Validate the parsed chunk (default: true)

  ## Examples

      {:ok, chunk} = MistralClient.Stream.parse_chunk("data: {...}")
      :done = MistralClient.Stream.parse_chunk("data: [DONE]")
  """
  @spec parse_chunk(binary(), keyword()) :: {:ok, chunk()} | :done | {:error, Exception.t()}
  def parse_chunk(chunk_data, options \\ []) when is_binary(chunk_data) do
    validate? = Keyword.get(options, :validate, true)
    parse_line(chunk_data, validate?, false)
  end

  @doc """
  Validate a parsed chunk.

  ## Parameters

    * `chunk` - Parsed chunk data

  ## Examples

      :ok = MistralClient.Stream.validate_chunk(%{"choices" => [...]})
      {:error, reason} = MistralClient.Stream.validate_chunk(%{})
  """
  @spec validate_chunk(chunk()) :: :ok | {:error, Exception.t()}
  def validate_chunk(chunk) when is_map(chunk) do
    cond do
      not Map.has_key?(chunk, "choices") ->
        {:error,
         Errors.ValidationError.exception(
           message: "Stream chunk missing 'choices' field",
           field: "choices"
         )}

      not is_list(chunk["choices"]) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Stream chunk 'choices' must be a list",
           field: "choices"
         )}

      true ->
        validate_choices(chunk["choices"])
    end
  end

  def validate_chunk(_chunk) do
    {:error, Errors.ValidationError.exception(message: "Stream chunk must be a map")}
  end

  @doc """
  Extract content from a stream chunk.

  ## Parameters

    * `chunk` - Parsed chunk data
    * `choice_index` - Index of the choice to extract (default: 0)

  ## Examples

      "Hello" = MistralClient.Stream.extract_content(chunk)
      nil = MistralClient.Stream.extract_content(chunk_without_content)
  """
  @spec extract_content(chunk(), integer()) :: String.t() | nil
  def extract_content(chunk, choice_index \\ 0) when is_map(chunk) do
    get_in(chunk, ["choices", Access.at(choice_index), "delta", "content"])
  end

  @doc """
  Extract tool calls from a stream chunk.

  ## Parameters

    * `chunk` - Parsed chunk data
    * `choice_index` - Index of the choice to extract (default: 0)

  ## Examples

      [%{"id" => "call_123", ...}] = MistralClient.Stream.extract_tool_calls(chunk)
      nil = MistralClient.Stream.extract_tool_calls(chunk_without_tools)
  """
  @spec extract_tool_calls(chunk(), integer()) :: list() | nil
  def extract_tool_calls(chunk, choice_index \\ 0) when is_map(chunk) do
    get_in(chunk, ["choices", Access.at(choice_index), "delta", "tool_calls"])
  end

  @doc """
  Extract finish reason from a stream chunk.

  ## Parameters

    * `chunk` - Parsed chunk data
    * `choice_index` - Index of the choice to extract (default: 0)

  ## Examples

      "stop" = MistralClient.Stream.extract_finish_reason(chunk)
      nil = MistralClient.Stream.extract_finish_reason(incomplete_chunk)
  """
  @spec extract_finish_reason(chunk(), integer()) :: String.t() | nil
  def extract_finish_reason(chunk, choice_index \\ 0) when is_map(chunk) do
    get_in(chunk, ["choices", Access.at(choice_index), "finish_reason"])
  end

  @doc """
  Check if a chunk indicates the stream is complete.

  ## Parameters

    * `chunk` - Parsed chunk data

  ## Examples

      true = MistralClient.Stream.stream_complete?(final_chunk)
      false = MistralClient.Stream.stream_complete?(intermediate_chunk)
  """
  @spec stream_complete?(chunk()) :: boolean()
  def stream_complete?(chunk) when is_map(chunk) do
    case chunk["choices"] do
      [%{"finish_reason" => reason} | _] when not is_nil(reason) -> true
      _ -> false
    end
  end

  @doc """
  Accumulate content from multiple stream chunks.

  ## Parameters

    * `chunks` - List of parsed chunks
    * `choice_index` - Index of the choice to accumulate (default: 0)

  ## Examples

      "Hello world!" = MistralClient.Stream.accumulate_content([chunk1, chunk2, chunk3])
  """
  @spec accumulate_content(list(chunk()), integer()) :: String.t()
  def accumulate_content(chunks, choice_index \\ 0) when is_list(chunks) do
    chunks
    |> Enum.map(&extract_content(&1, choice_index))
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  @doc """
  Make a streaming HTTP request.

  ## Parameters

    * `config` - Client configuration
    * `method` - HTTP method
    * `path` - API path
    * `body` - Request body
    * `query_params` - Query parameters
    * `callback` - Function to handle each chunk

  ## Examples

      MistralClient.Stream.request_stream(config, :post, "/v1/chat/completions", body, [], callback)
  """
  @spec request_stream(MistralClient.Config.t(), atom(), String.t(), map(), list(), callback()) ::
          {:ok, term()} | {:error, term()}
  def request_stream(config, method, path, body, query_params, callback) do
    alias MistralClient.Client

    # Create client from config
    client = get_or_create_client(config)

    # Add stream_callback to options for the HTTP client
    # Also add raw_response: true to skip JSON parsing for streaming responses
    opts = [stream_callback: callback, raw_response: true] ++ query_params

    case Client.request(client, method, path, body, opts) do
      {:ok, ""} -> {:ok, :stream_complete}
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, error}
    end
  end

  # Private helper functions

  defp get_or_create_client(config) when is_list(config) do
    MistralClient.Client.new(config)
  end

  defp get_or_create_client(%MistralClient.Client{} = client), do: client

  defp get_or_create_client(%MistralClient.Config{} = config) do
    MistralClient.Client.new(config)
  end

  # Private functions

  defp parse_line("", _validate?, true), do: :skip
  defp parse_line("data: [DONE]", _validate?, _skip_empty?), do: :done

  defp parse_line("data: " <> json_data, validate?, _skip_empty?) do
    case Jason.decode(json_data) do
      {:ok, chunk} ->
        if validate? do
          case validate_chunk(chunk) do
            :ok -> {:ok, chunk}
            {:error, _} = error -> error
          end
        else
          {:ok, chunk}
        end

      {:error, reason} ->
        {:error,
         Errors.ValidationError.exception(
           message: "Invalid JSON in stream chunk: #{inspect(reason)}"
         )}
    end
  end

  defp parse_line("event: " <> _event, _validate?, _skip_empty?), do: :skip
  defp parse_line("id: " <> _id, _validate?, _skip_empty?), do: :skip
  defp parse_line("retry: " <> _retry, _validate?, _skip_empty?), do: :skip
  defp parse_line(line, _validate?, true) when byte_size(line) == 0, do: :skip
  defp parse_line(_line, _validate?, _skip_empty?), do: :skip

  defp validate_choices([]), do: :ok

  defp validate_choices([choice | rest]) when is_map(choice) do
    case validate_choice(choice) do
      :ok -> validate_choices(rest)
      {:error, _} = error -> error
    end
  end

  defp validate_choices(_choices) do
    {:error,
     Errors.ValidationError.exception(
       message: "All choices must be maps",
       field: "choices"
     )}
  end

  defp validate_choice(choice) when is_map(choice) do
    cond do
      not Map.has_key?(choice, "index") ->
        {:error,
         Errors.ValidationError.exception(
           message: "Choice missing 'index' field",
           field: "index"
         )}

      not is_integer(choice["index"]) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Choice 'index' must be an integer",
           field: "index"
         )}

      Map.has_key?(choice, "delta") and not is_map(choice["delta"]) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Choice 'delta' must be a map",
           field: "delta"
         )}

      true ->
        :ok
    end
  end
end
