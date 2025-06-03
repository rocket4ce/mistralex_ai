defmodule MistralClient.Errors do
  @moduledoc """
  Error definitions and handling for the Mistral AI client.

  This module defines standardized error types that can occur when interacting
  with the Mistral API, providing consistent error handling across the SDK.

  ## Error Types

    * `APIError` - General API errors (4xx, 5xx responses)
    * `AuthenticationError` - Authentication failures (401)
    * `PermissionError` - Permission denied (403)
    * `NotFoundError` - Resource not found (404)
    * `RateLimitError` - Rate limit exceeded (429)
    * `ServerError` - Server-side errors (5xx)
    * `NetworkError` - Network connectivity issues
    * `TimeoutError` - Request timeout
    * `ValidationError` - Request validation failures
    * `ConfigurationError` - Configuration issues

  ## Usage

      case MistralClient.chat(messages) do
        {:ok, response} -> handle_success(response)
        {:error, %MistralClient.Errors.RateLimitError{} = rate_limit_error} ->
          # Handle rate limiting
          retry_after_delay(rate_limit_error.retry_after)
        {:error, other_error} ->
          # Handle other errors
           Logger.error("API error: inspect(other_error)")
      end
  """

  defmodule APIError do
    @moduledoc """
    General API error for HTTP 4xx and 5xx responses.
    """
    defexception [:message, :status_code, :response_body, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            status_code: integer(),
            response_body: String.t() | nil,
            request_id: String.t() | nil
          }

    def exception(opts) do
      status_code = Keyword.get(opts, :status_code)
      response_body = Keyword.get(opts, :response_body)
      request_id = Keyword.get(opts, :request_id)

      message =
        Keyword.get(opts, :message) ||
          "API request failed with status #{status_code}"

      %__MODULE__{
        message: message,
        status_code: status_code,
        response_body: response_body,
        request_id: request_id
      }
    end
  end

  defmodule AuthenticationError do
    @moduledoc """
    Authentication error (HTTP 401).
    """
    defexception [:message, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            request_id: String.t() | nil
          }

    def exception(opts) do
      message =
        Keyword.get(opts, :message) ||
          "Authentication failed. Please check your API key."

      %__MODULE__{
        message: message,
        request_id: Keyword.get(opts, :request_id)
      }
    end
  end

  defmodule PermissionError do
    @moduledoc """
    Permission denied error (HTTP 403).
    """
    defexception [:message, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            request_id: String.t() | nil
          }

    def exception(opts) do
      message =
        Keyword.get(opts, :message) ||
          "Permission denied. You don't have access to this resource."

      %__MODULE__{
        message: message,
        request_id: Keyword.get(opts, :request_id)
      }
    end
  end

  defmodule NotFoundError do
    @moduledoc """
    Resource not found error (HTTP 404).
    """
    defexception [:message, :resource_type, :resource_id, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            resource_type: String.t() | nil,
            resource_id: String.t() | nil,
            request_id: String.t() | nil
          }

    def exception(opts) do
      resource_type = Keyword.get(opts, :resource_type)
      resource_id = Keyword.get(opts, :resource_id)

      message =
        Keyword.get(opts, :message) ||
          case {resource_type, resource_id} do
            {type, id} when not is_nil(type) and not is_nil(id) ->
              "#{String.capitalize(type)} '#{id}' not found"

            {type, nil} when not is_nil(type) ->
              "#{String.capitalize(type)} not found"

            _ ->
              "Resource not found"
          end

      %__MODULE__{
        message: message,
        resource_type: resource_type,
        resource_id: resource_id,
        request_id: Keyword.get(opts, :request_id)
      }
    end
  end

  defmodule RateLimitError do
    @moduledoc """
    Rate limit exceeded error (HTTP 429).
    """
    defexception [:message, :retry_after, :limit_type, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            retry_after: integer() | nil,
            limit_type: String.t() | nil,
            request_id: String.t() | nil
          }

    def exception(opts) do
      retry_after = Keyword.get(opts, :retry_after)
      limit_type = Keyword.get(opts, :limit_type)

      message =
        Keyword.get(opts, :message) ||
          case {limit_type, retry_after} do
            {type, seconds} when not is_nil(type) and not is_nil(seconds) ->
              "#{String.capitalize(type)} rate limit exceeded. Retry after #{seconds} seconds."

            {type, nil} when not is_nil(type) ->
              "#{String.capitalize(type)} rate limit exceeded."

            {nil, seconds} when not is_nil(seconds) ->
              "Rate limit exceeded. Retry after #{seconds} seconds."

            _ ->
              "Rate limit exceeded."
          end

      %__MODULE__{
        message: message,
        retry_after: retry_after,
        limit_type: limit_type,
        request_id: Keyword.get(opts, :request_id)
      }
    end
  end

  defmodule ServerError do
    @moduledoc """
    Server-side error (HTTP 5xx).
    """
    defexception [:message, :status_code, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            status_code: integer(),
            request_id: String.t() | nil
          }

    def exception(opts) do
      status_code = Keyword.get(opts, :status_code)

      message =
        Keyword.get(opts, :message) ||
          "Server error (#{status_code}). Please try again later."

      %__MODULE__{
        message: message,
        status_code: status_code,
        request_id: Keyword.get(opts, :request_id)
      }
    end
  end

  defmodule NetworkError do
    @moduledoc """
    Network connectivity error.
    """
    defexception [:message, :reason]

    @type t :: %__MODULE__{
            message: String.t(),
            reason: term()
          }

    def exception(opts) do
      reason = Keyword.get(opts, :reason)

      message =
        Keyword.get(opts, :message) ||
          case reason do
            :timeout -> "Network request timed out"
            :econnrefused -> "Connection refused"
            :nxdomain -> "Domain name resolution failed"
            _ -> "Network error: #{inspect(reason)}"
          end

      %__MODULE__{
        message: message,
        reason: reason
      }
    end
  end

  defmodule TimeoutError do
    @moduledoc """
    Request timeout error.
    """
    defexception [:message, :timeout_ms]

    @type t :: %__MODULE__{
            message: String.t(),
            timeout_ms: integer() | nil
          }

    def exception(opts) do
      timeout_ms = Keyword.get(opts, :timeout_ms)

      message =
        Keyword.get(opts, :message) ||
          case timeout_ms do
            nil -> "Request timed out"
            ms -> "Request timed out after #{ms}ms"
          end

      %__MODULE__{
        message: message,
        timeout_ms: timeout_ms
      }
    end
  end

  defmodule ValidationError do
    @moduledoc """
    Request validation error.
    """
    defexception [:message, :field, :value, :constraint]

    @type t :: %__MODULE__{
            message: String.t(),
            field: String.t() | nil,
            value: term(),
            constraint: String.t() | nil
          }

    def exception(opts) do
      field = Keyword.get(opts, :field)
      value = Keyword.get(opts, :value)
      constraint = Keyword.get(opts, :constraint)

      message =
        Keyword.get(opts, :message) ||
          case {field, constraint} do
            {field, constraint} when not is_nil(field) and not is_nil(constraint) ->
              "Validation failed for field '#{field}': #{constraint}"

            {field, nil} when not is_nil(field) ->
              "Validation failed for field '#{field}'"

            _ ->
              "Validation failed"
          end

      %__MODULE__{
        message: message,
        field: field,
        value: value,
        constraint: constraint
      }
    end
  end

  defmodule ConfigurationError do
    @moduledoc """
    Configuration error.
    """
    defexception [:message, :setting]

    @type t :: %__MODULE__{
            message: String.t(),
            setting: String.t() | nil
          }

    def exception(opts) do
      setting = Keyword.get(opts, :setting)

      message =
        Keyword.get(opts, :message) ||
          case setting do
            nil -> "Configuration error"
            setting -> "Configuration error for setting '#{setting}'"
          end

      %__MODULE__{
        message: message,
        setting: setting
      }
    end
  end

  @doc """
  Convert an HTTP response to an appropriate error.

  ## Parameters

    * `status_code` - HTTP status code
    * `response_body` - Response body (optional)
    * `headers` - Response headers (optional)

  ## Examples

      error = MistralClient.Errors.from_response(401, "Unauthorized")
      %MistralClient.Errors.AuthenticationError{}
  """
  @spec from_response(integer(), String.t() | nil, list() | map()) :: Exception.t()
  def from_response(status_code, response_body \\ nil, headers \\ %{}) do
    headers_map = normalize_headers(headers)
    request_id = Map.get(headers_map, "x-request-id")

    case status_code do
      401 ->
        AuthenticationError.exception(
          message: extract_error_message(response_body),
          request_id: request_id
        )

      403 ->
        PermissionError.exception(
          message: extract_error_message(response_body),
          request_id: request_id
        )

      404 ->
        NotFoundError.exception(
          message: extract_error_message(response_body),
          request_id: request_id
        )

      422 ->
        ValidationError.exception(
          message: extract_error_message(response_body),
          request_id: request_id
        )

      429 ->
        retry_after = parse_retry_after(Map.get(headers_map, "retry-after"))

        RateLimitError.exception(
          message: extract_error_message(response_body),
          retry_after: retry_after,
          request_id: request_id
        )

      status when status >= 500 ->
        ServerError.exception(
          message: extract_error_message(response_body),
          status_code: status_code,
          request_id: request_id
        )

      _ ->
        APIError.exception(
          message: extract_error_message(response_body),
          status_code: status_code,
          response_body: response_body,
          request_id: request_id
        )
    end
  end

  # Private helpers

  defp normalize_headers(headers) when is_list(headers) do
    Enum.into(headers, %{}, fn
      {key, value} when is_binary(key) -> {String.downcase(key), value}
      {key, value} when is_atom(key) -> {String.downcase(to_string(key)), value}
      _ -> {"unknown", ""}
    end)
  end

  defp normalize_headers(headers) when is_map(headers), do: headers
  defp normalize_headers(_), do: %{}

  defp extract_error_message(nil), do: nil

  defp extract_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> extract_error_message(parsed)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp extract_error_message(body) when is_map(body) do
    cond do
      Map.has_key?(body, "error") and is_map(body["error"]) and
          Map.has_key?(body["error"], "message") ->
        body["error"]["message"]

      Map.has_key?(body, "message") ->
        body["message"]

      Map.has_key?(body, "detail") ->
        body["detail"]

      true ->
        nil
    end
  end

  defp extract_error_message(_), do: nil

  defp parse_retry_after(nil), do: nil

  defp parse_retry_after(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, ""} -> seconds
      _ -> nil
    end
  end

  defp parse_retry_after(value) when is_integer(value), do: value
  defp parse_retry_after(_), do: nil
end
