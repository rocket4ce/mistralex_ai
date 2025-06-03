defmodule MistralClient.HttpClient.Req do
  @moduledoc """
  Req-based HTTP client implementation.

  This module implements the HttpClient behaviour using the Req library
  for making actual HTTP requests to the Mistral API.
  """

  @behaviour MistralClient.Behaviours.HttpClient

  @impl true
  def request(method, url, headers, body, options) do
    request_options = build_request_options(method, url, headers, body, options)

    case Req.request(request_options) do
      {:ok, %Req.Response{status: status, body: response_body, headers: response_headers}} ->
        {:ok, %{status: status, body: response_body, headers: Map.new(response_headers)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def stream_request(method, url, headers, body, options) do
    stream_options =
      options
      |> Keyword.put(:into, :self)

    request_options = build_request_options(method, url, headers, body, stream_options)

    case Req.request(request_options) do
      {:ok, %Req.Response{status: status, body: response_body, headers: response_headers}} ->
        if status in 200..299 do
          # For streaming, return a stream that yields the response
          stream =
            Stream.unfold(:start, fn
              :start -> {response_body, :done}
              :done -> nil
            end)

          {:ok, stream}
        else
          {:ok, %{status: status, body: response_body, headers: Map.new(response_headers)}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp build_request_options(method, url, headers, body, options) do
    base_options = [
      method: method,
      url: url,
      headers: headers
    ]

    # Add body if present
    base_options =
      case body do
        nil -> base_options
        body when is_map(body) -> Keyword.put(base_options, :json, body)
        body when is_binary(body) -> Keyword.put(base_options, :body, body)
        body -> Keyword.put(base_options, :json, body)
      end

    # Merge with additional options
    Keyword.merge(base_options, options)
  end
end
