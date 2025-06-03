defmodule MistralClient.Behaviours.HttpClient do
  @moduledoc """
  Behaviour for HTTP client implementations.

  This behaviour defines the contract for HTTP clients used by the Mistral SDK.
  It allows for easy mocking in tests while maintaining a consistent interface.
  """

  @type method :: :get | :post | :put | :patch | :delete
  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t() | map() | nil
  @type options :: keyword()
  @type response :: {:ok, map()} | {:error, term()}

  @doc """
  Performs an HTTP request.

  ## Parameters

  - `method` - HTTP method (:get, :post, :put, :patch, :delete)
  - `url` - Request URL
  - `headers` - List of request headers as tuples
  - `body` - Request body (string, map, or nil)
  - `options` - Additional options (timeout, etc.)

  ## Returns

  - `{:ok, response}` - Successful response with parsed body
  - `{:error, reason}` - Error response
  """
  @callback request(method(), url(), headers(), body(), options()) :: response()

  @doc """
  Performs a streaming HTTP request for Server-Sent Events.

  ## Parameters

  - `method` - HTTP method (typically :post for streaming)
  - `url` - Request URL
  - `headers` - List of request headers as tuples
  - `body` - Request body (string, map, or nil)
  - `options` - Additional options including stream handling

  ## Returns

  - `{:ok, stream}` - Stream of events
  - `{:error, reason}` - Error response
  """
  @callback stream_request(method(), url(), headers(), body(), options()) ::
              {:ok, Enumerable.t()} | {:error, term()}
end
