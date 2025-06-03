defmodule MistralClient.Test.TestHelpers do
  @moduledoc """
  Helper functions for testing the Mistral SDK.

  This module provides utilities for setting up tests, creating test data,
  and asserting on common patterns in the Mistral API responses.
  """

  import ExUnit.Assertions
  import Mox

  alias MistralClient.Client

  @doc """
  Sets up a mock HTTP response for testing.

  ## Parameters

  - `method` - HTTP method to mock
  - `url_pattern` - URL pattern to match (can be a string or regex)
  - `response` - The response to return
  - `status` - HTTP status code (default: 200)

  ## Examples

      setup_mock_response(:post, ~r/chat\/completions/, %{
        "choices" => [%{"message" => %{"content" => "Hello"}}]
      })
  """
  def setup_mock_response(method, url_pattern, response, status \\ 200) do
    expect(MistralClient.HttpClientMock, :request, fn ^method, url, _headers, _body, _options ->
      if url_matches?(url, url_pattern) do
        {:ok, %{status: status, body: response, headers: %{}}}
      else
        {:error, :url_mismatch}
      end
    end)
  end

  @doc """
  Sets up a mock streaming HTTP response for testing.

  ## Parameters

  - `method` - HTTP method to mock
  - `url_pattern` - URL pattern to match
  - `events` - List of events to stream

  ## Examples

      setup_mock_stream(:post, ~r/chat\/completions/, [
        %{"choices" => [%{"delta" => %{"content" => "Hello"}}]},
        %{"choices" => [%{"delta" => %{"content" => " world"}}]}
      ])
  """
  def setup_mock_stream(method, url_pattern, events) do
    expect(MistralClient.HttpClientMock, :stream_request, fn ^method,
                                                             url,
                                                             _headers,
                                                             _body,
                                                             _options ->
      if url_matches?(url, url_pattern) do
        stream =
          Stream.map(events, fn event ->
            {:ok, %{data: Jason.encode!(event)}}
          end)

        {:ok, stream}
      else
        {:error, :url_mismatch}
      end
    end)
  end

  @doc """
  Sets up a mock error response for testing.

  ## Parameters

  - `method` - HTTP method to mock
  - `url_pattern` - URL pattern to match
  - `error_code` - HTTP error code
  - `error_message` - Error message

  ## Examples

      setup_mock_error(:post, ~r/chat\/completions/, 401, "Unauthorized")
  """
  def setup_mock_error(method, url_pattern, error_code, error_message) do
    expect(MistralClient.HttpClientMock, :request, fn ^method, url, _headers, _body, _options ->
      if url_matches?(url, url_pattern) do
        {:ok,
         %{
           status: error_code,
           body: %{
             "error" => %{
               "message" => error_message,
               "type" => "invalid_request_error",
               "code" => error_code
             }
           },
           headers: %{}
         }}
      else
        {:error, :url_mismatch}
      end
    end)
  end

  @doc """
  Asserts that a response has the expected structure for a chat completion.

  ## Parameters

  - `response` - The response to check
  - `expected_content` - Expected content (optional)
  """
  def assert_chat_completion_response(response, expected_content \\ nil) do
    assert {:ok, result} = response

    # Handle both raw maps and structured models
    case result do
      %MistralClient.Models.ChatCompletion{choices: choices} ->
        assert is_list(choices)
        assert length(choices) > 0

        choice = List.first(choices)
        assert %MistralClient.Models.ChatCompletionChoice{message: message} = choice
        assert %MistralClient.Models.Message{content: content} = message

        if expected_content do
          assert content == expected_content
        end

      %{"choices" => choices} ->
        assert is_list(choices)
        assert length(choices) > 0

        choice = List.first(choices)
        assert %{"message" => message} = choice
        assert %{"content" => content} = message

        if expected_content do
          assert content == expected_content
        end
    end

    result
  end

  @doc """
  Asserts that a response has the expected structure for embeddings.

  ## Parameters

  - `response` - The response to check
  - `expected_count` - Expected number of embeddings (optional)
  """
  def assert_embeddings_response(response, expected_count \\ nil) do
    assert {:ok, result} = response
    assert %{"data" => embeddings} = result
    assert is_list(embeddings)

    if expected_count do
      assert length(embeddings) == expected_count
    end

    # Check first embedding structure
    if length(embeddings) > 0 do
      embedding = List.first(embeddings)
      assert %{"embedding" => vector} = embedding
      assert is_list(vector)
      assert length(vector) > 0
      assert Enum.all?(vector, &is_number/1)
    end

    result
  end

  @doc """
  Asserts that a response is an error with the expected code and message.

  ## Parameters

  - `response` - The response to check
  - `expected_code` - Expected error code
  - `expected_message` - Expected error message (optional)
  """
  def assert_error_response(response, expected_code, expected_message \\ nil) do
    assert {:error, error} = response

    case error do
      # Handle APIError with status_code field
      %{status_code: ^expected_code} ->
        if expected_message do
          assert error.message == expected_message
        end

      # Handle specific error types that have status_code in their name/type
      %MistralClient.Errors.AuthenticationError{} when expected_code == 401 ->
        if expected_message do
          assert error.message == expected_message
        end

      %MistralClient.Errors.PermissionError{} when expected_code == 403 ->
        if expected_message do
          assert error.message == expected_message
        end

      %MistralClient.Errors.NotFoundError{} when expected_code == 404 ->
        if expected_message do
          assert error.message == expected_message
        end

      %MistralClient.Errors.RateLimitError{} when expected_code == 429 ->
        if expected_message do
          assert error.message == expected_message
        end

      %MistralClient.Errors.ServerError{status_code: ^expected_code} ->
        if expected_message do
          assert error.message == expected_message
        end

      %MistralClient.Errors.ValidationError{} when expected_code == 422 ->
        if expected_message do
          assert error.message == expected_message
        end

      _ ->
        flunk("Expected error with code #{expected_code}, got: #{inspect(error)}")
    end

    error
  end

  @doc """
  Creates a valid API key for testing.
  """
  def valid_api_key, do: "test-api-key-12345"

  @doc """
  Creates test configuration for the Mistral client.
  """
  def test_config(overrides \\ []) do
    base_config = [
      api_key: valid_api_key(),
      base_url: "https://api.mistral.ai",
      timeout: 30_000
    ]

    config_options = Keyword.merge(base_config, overrides)
    MistralClient.Config.new(config_options)
  end

  # Private helper functions

  defp url_matches?(url, pattern) when is_binary(pattern) do
    String.contains?(url, pattern)
  end

  defp url_matches?(url, %Regex{} = pattern) do
    Regex.match?(pattern, url)
  end

  defp url_matches?(_url, _pattern), do: false

  @doc """
  Creates a mock client for testing.
  """
  def mock_client do
    config = [
      api_key: valid_api_key(),
      base_url: "https://api.mistral.ai",
      timeout: 30_000,
      http_client: MistralClient.HttpClientMock
    ]

    Client.new(config)
  end
end
