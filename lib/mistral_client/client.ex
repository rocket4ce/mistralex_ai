defmodule MistralClient.Client do
  @moduledoc """
  HTTP client for the Mistral AI API.

  This module provides the core HTTP functionality for making requests to the
  Mistral API, including authentication, retry logic, error handling, and
  response parsing.

  ## Features

    * Automatic authentication with API key
    * Exponential backoff retry logic
    * Comprehensive error handling
    * Request/response logging
    * Rate limit handling
    * Timeout management

  ## Usage

      # Create a client with default configuration
      client = MistralClient.Client.new()

      # Create a client with custom configuration
      client = MistralClient.Client.new(api_key: "custom-key", timeout: 60_000)

      # Make a request
      {:ok, response} = MistralClient.Client.request(client, :post, "/chat/completions", body)
  """

  alias MistralClient.{Config, Errors}
  require Logger

  @type t :: %__MODULE__{
          config: Config.t(),
          req_options: keyword(),
          http_client: module()
        }

  defstruct [:config, :req_options, :http_client]

  @doc """
  Create a new HTTP client.

  ## Parameters

    * `options` - Configuration options (keyword list) or Config struct (optional)

  ## Examples

      client = MistralClient.Client.new()
      client = MistralClient.Client.new(api_key: "custom-key")
      client = MistralClient.Client.new(config_struct)
  """
  @spec new(keyword() | Config.t()) :: t()
  def new(options \\ [])

  def new(%Config{} = config) do
    case Config.validate(config) do
      :ok ->
        req_options = build_req_options(config)
        http_client = get_http_client()
        %__MODULE__{config: config, req_options: req_options, http_client: http_client}

      {:error, reason} ->
        raise Errors.ConfigurationError, message: reason
    end
  end

  def new(options) when is_list(options) do
    config = Config.new(options)

    case Config.validate(config) do
      :ok ->
        req_options = build_req_options(config)
        http_client = get_http_client()
        %__MODULE__{config: config, req_options: req_options, http_client: http_client}

      {:error, reason} ->
        raise Errors.ConfigurationError, message: reason
    end
  end

  @doc """
  Make an HTTP request to the Mistral API.

  ## Parameters

    * `client` - The HTTP client
    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path
    * `body` - Request body (optional)
    * `options` - Additional request options (optional)

  ## Examples

      {:ok, response} = MistralClient.Client.request(client, :get, "/models")
      {:ok, response} = MistralClient.Client.request(client, :post, "/chat/completions", %{...})
  """
  @spec request(t(), atom(), String.t(), map() | nil, keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def request(%__MODULE__{} = client, method, path, body \\ nil, options \\ []) do
    # Only add query params to URL if they're not passed as :params
    url =
      if Keyword.has_key?(options, :params) do
        build_url(client.config.base_url, path)
      else
        build_url_with_query(client.config.base_url, path, options)
      end

    req_options = merge_options(client.req_options, options)

    request_data = %{
      method: method,
      url: url,
      body: body,
      options: req_options
    }

    Logger.debug("Making #{method} request to #{url}")

    case make_request_with_retry(request_data, client.config.max_retries, client.http_client) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        # Check if we should skip JSON parsing (for binary responses like file downloads)
        if Keyword.get(options, :raw_response, false) do
          {:ok, response_body}
        else
          case parse_response_body(response_body) do
            {:ok, parsed_body} ->
              {:ok, parsed_body}

            {:error, _} = error ->
              error
          end
        end

      {:ok, %{status: status, body: response_body} = response} ->
        headers = Map.get(response, :headers, [])
        error = Errors.from_response(status, response_body, headers)
        Logger.warning("API request failed: #{Exception.message(error)}")
        {:error, error}

      {:error, reason} ->
        error = handle_request_error(reason)
        Logger.error("Request error: #{Exception.message(error)}")
        {:error, error}
    end
  end

  @doc """
  Make a streaming request to the Mistral API.

  ## Parameters

    * `client` - The HTTP client
    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path
    * `body` - Request body (optional)
    * `callback` - Function to handle each chunk
    * `options` - Additional request options (optional)

  ## Examples

      MistralClient.Client.stream_request(client, :post, "/chat/completions", body, fn chunk ->
        IO.write(chunk)
      end)
  """
  @spec stream_request(t(), atom(), String.t(), map() | nil, function(), keyword()) ::
          :ok | {:error, Exception.t()}
  def stream_request(%__MODULE__{} = client, method, path, body \\ nil, callback, options \\ []) do
    url = build_url(client.config.base_url, path)

    # Convert body to JSON if it's a map and not nil
    json_body =
      case body do
        nil -> nil
        body when is_map(body) -> Jason.encode!(body)
        body when is_binary(body) -> body
        _ -> Jason.encode!(body)
      end

    _stream_options =
      client.req_options
      |> merge_options(options)
      # Remove json option for streaming
      |> Keyword.drop([:json])

    Logger.debug("Making streaming #{method} request to #{url}")

    case client.http_client.stream_request(
           method,
           url,
           build_headers(client.config),
           json_body,
           callback
         ) do
      {:ok, stream} ->
        # For successful streaming, return the stream directly
        handle_stream_response(stream, callback)

      :ok ->
        # If the HTTP client returns :ok, it means streaming was successful
        :ok

      {:error, reason} ->
        error = handle_request_error(reason)
        Logger.error("Streaming request error: #{Exception.message(error)}")
        {:error, error}
    end
  end

  # Private functions

  defp get_http_client do
    Application.get_env(:mistralex_ai, :http_client, MistralClient.HttpClient.Req)
  end

  defp build_req_options(config) do
    [
      base_url: config.base_url,
      headers: build_headers(config),
      receive_timeout: config.timeout,
      retry: false,
      json: true
    ]
  end

  defp build_headers(config) do
    [
      {"authorization", "Bearer #{config.api_key}"},
      {"user-agent", config.user_agent},
      {"content-type", "application/json"}
    ]
  end

  defp merge_options(base_options, additional_options) do
    Keyword.merge(base_options, additional_options)
  end

  defp build_url(base_url, path) do
    base_url = String.trim_trailing(base_url, "/")

    # If path already starts with /v1, don't add it again
    if String.starts_with?(path, "/v1") do
      base_url <> path
    else
      base_url <> "/v1" <> path
    end
  end

  defp build_url_with_query(base_url, path, options) do
    base_url = build_url(base_url, path)

    # Check for query parameters in different formats
    query_params =
      cond do
        Keyword.has_key?(options, :query) ->
          Keyword.get(options, :query)

        Keyword.has_key?(options, :params) ->
          Keyword.get(options, :params)

        # Handle direct query parameters in options (for backward compatibility)
        Enum.any?(options, fn {k, _v} ->
          k not in [
            :headers,
            :json,
            :base_url,
            :receive_timeout,
            :retry,
            :raw_response,
            :params,
            :stream_callback,
            # Add :form to excluded keys
            :form
          ]
        end) ->
          options
          |> Keyword.drop([
            :headers,
            :json,
            :base_url,
            :receive_timeout,
            :retry,
            :raw_response,
            :params,
            :stream_callback,
            # Add :form to excluded keys
            :form
          ])
          |> Enum.into(%{})

        true ->
          nil
      end

    case query_params do
      nil ->
        base_url

      query_params when is_map(query_params) and map_size(query_params) > 0 ->
        query_string = URI.encode_query(query_params)
        "#{base_url}?#{query_string}"

      query_params when is_list(query_params) and length(query_params) > 0 ->
        query_string = URI.encode_query(query_params)
        "#{base_url}?#{query_string}"

      _ ->
        base_url
    end
  end

  defp make_request_with_retry(request_data, retries_left, http_client) do
    case make_single_request(request_data, http_client) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} when retries_left > 0 ->
        if should_retry?(reason) do
          delay = calculate_retry_delay(retries_left)
          Logger.debug("Retrying request in #{delay}ms (#{retries_left} retries left)")
          Process.sleep(delay)
          make_request_with_retry(request_data, retries_left - 1, http_client)
        else
          {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_single_request(%{method: method, url: url, body: body, options: options}, http_client) do
    headers = Keyword.get(options, :headers, [])
    request_options = Keyword.drop(options, [:headers])

    # Convert body to JSON if it's a map and not nil
    json_body =
      case body do
        nil -> nil
        body when is_map(body) -> Jason.encode!(body)
        body when is_binary(body) -> body
        _ -> Jason.encode!(body)
      end

    http_client.request(method, url, headers, json_body, request_options)
  end

  defp should_retry?(%{status: status}) when status in [429, 500, 502, 503, 504], do: true

  defp should_retry?(%Req.TransportError{reason: reason})
       when reason in [:timeout, :econnrefused],
       do: true

  defp should_retry?(_), do: false

  defp calculate_retry_delay(retries_left) do
    # Exponential backoff: 1s, 2s, 4s
    base_delay = 1000
    exponential_delay = base_delay * :math.pow(2, 3 - retries_left)
    # Add jitter (±25%)
    jitter = :rand.uniform(500) - 250
    round(exponential_delay + jitter)
  end

  defp parse_response_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, reason} ->
        {:error,
         Errors.ValidationError.exception(message: "Invalid JSON response: #{inspect(reason)}")}
    end
  end

  defp parse_response_body(body) when is_map(body), do: {:ok, body}
  defp parse_response_body(body), do: {:ok, body}

  defp handle_request_error(%Req.TransportError{reason: :timeout}) do
    Errors.NetworkError.exception(message: "Network request timed out", reason: :timeout)
  end

  defp handle_request_error(%Req.TransportError{reason: :econnrefused}) do
    Errors.NetworkError.exception(reason: :econnrefused)
  end

  defp handle_request_error(%Req.TransportError{reason: :nxdomain}) do
    Errors.NetworkError.exception(reason: :nxdomain)
  end

  defp handle_request_error(%Req.TransportError{reason: reason}) do
    Errors.NetworkError.exception(reason: reason)
  end

  defp handle_request_error(%{__struct__: struct_name} = reason)
       when struct_name in [
              MistralClient.Errors.APIError,
              MistralClient.Errors.AuthenticationError,
              MistralClient.Errors.PermissionError,
              MistralClient.Errors.NotFoundError,
              MistralClient.Errors.RateLimitError,
              MistralClient.Errors.ServerError,
              MistralClient.Errors.ValidationError
            ] do
    # Return the error as-is if it's already a proper MistralClient error
    reason
  end

  defp handle_request_error(reason) do
    Errors.NetworkError.exception(reason: reason)
  end

  defp handle_stream_response(stream, callback) do
    try do
      case stream do
        # Handle when stream is a list or enumerable
        stream when is_list(stream) ->
          Enum.each(stream, fn event ->
            case event do
              {:ok, %{data: data}} ->
                case parse_stream_chunk(data) do
                  {:ok, chunk} -> if callback, do: callback.(chunk)
                  :skip -> :ok
                  :done -> :ok
                  # Continue processing other chunks
                  {:error, _reason} -> :ok
                end

              _ ->
                :ok
            end
          end)

          {:ok, stream}

        # Handle when stream is already processed (like :done)
        :done ->
          :ok

        # Handle other enumerable streams
        stream ->
          if Enumerable.impl_for(stream) do
            Enum.each(stream, fn event ->
              case event do
                {:ok, %{data: data}} ->
                  case parse_stream_chunk(data) do
                    {:ok, chunk} -> if callback, do: callback.(chunk)
                    :skip -> :ok
                    :done -> :ok
                    {:error, _reason} -> :ok
                  end

                _ ->
                  :ok
              end
            end)

            {:ok, stream}
          else
            # Return the stream as-is if it's not enumerable
            {:ok, stream}
          end
      end
    rescue
      error ->
        {:error, Errors.NetworkError.exception(reason: error)}
    end
  end

  defp parse_stream_chunk(data) when is_binary(data) do
    data
    |> String.trim()
    |> String.split("\n")
    |> Enum.reduce_while(:skip, fn line, _acc ->
      case parse_sse_line(line) do
        {:ok, chunk} -> {:halt, {:ok, chunk}}
        :skip -> {:cont, :skip}
        :done -> {:halt, :done}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp parse_sse_line("data: [DONE]"), do: :done

  defp parse_sse_line("data: " <> json_data) do
    case Jason.decode(json_data) do
      {:ok, chunk} ->
        {:ok, chunk}

      {:error, reason} ->
        {:error,
         Errors.ValidationError.exception(message: "Invalid SSE JSON: #{inspect(reason)}")}
    end
  end

  defp parse_sse_line(_line), do: :skip
end
