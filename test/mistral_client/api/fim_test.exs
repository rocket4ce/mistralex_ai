defmodule MistralClient.API.FIMTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.{Client, API.FIM}
  alias MistralClient.Models.{FIMCompletionRequest, FIMCompletionResponse}
  alias MistralClient.Test.Fixtures.FIMFixtures
  alias MistralClient.Test.TestHelpers

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    client = Client.new(TestHelpers.test_config())
    {:ok, client: client}
  end

  describe "complete/3 - basic interface" do
    test "performs basic FIM completion", %{client: client} do
      response_body = FIMFixtures.fim_completion_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        _decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, completion} = FIM.complete(client, "codestral-2405", "def fibonacci(n):")

      assert %FIMCompletionResponse{} = completion
      assert completion.id == "fim_cmpl_123456789"
      assert completion.model == "codestral-2405"
      assert completion.object == "fim.completion"
      assert length(completion.choices) == 1

      choice = hd(completion.choices)
      assert choice.index == 0
      assert choice.finish_reason == "stop"
      assert choice.message.role == "assistant"
      assert String.contains?(choice.message.content, "if n <= 1:")
      assert String.contains?(choice.message.content, "fibonacci(n-1) + fibonacci(n-2)")

      assert completion.usage.prompt_tokens == 15
      assert completion.usage.completion_tokens == 25
      assert completion.usage.total_tokens == 40
    end

    test "performs FIM completion with suffix", %{client: client} do
      response_body = FIMFixtures.fim_completion_response_with_suffix()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        # Verify suffix is included in request
        assert decoded_body["suffix"] == "return result"
        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, completion} =
               FIM.complete(client, "codestral-2405", "def fibonacci(n):",
                 suffix: "return result"
               )

      assert completion.id == "fim_cmpl_987654321"
      choice = hd(completion.choices)
      assert String.contains?(choice.message.content, "result = n")
    end

    test "performs FIM completion with all options", %{client: client} do
      response_body = FIMFixtures.fim_completion_response_max_tokens()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        # Verify all options are included
        assert decoded_body["model"] == "codestral-latest"
        assert decoded_body["prompt"] == "def fibonacci(n):"
        assert decoded_body["suffix"] == "return result"
        assert decoded_body["temperature"] == 0.2
        assert decoded_body["max_tokens"] == 100
        assert decoded_body["top_p"] == 0.9
        assert decoded_body["stop"] == ["\n\n"]
        assert decoded_body["random_seed"] == 42

        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, completion} =
               FIM.complete(client, "codestral-latest", "def fibonacci(n):",
                 suffix: "return result",
                 temperature: 0.2,
                 max_tokens: 100,
                 top_p: 0.9,
                 stop: ["\n\n"],
                 random_seed: 42
               )

      assert completion.model == "codestral-latest"
      choice = hd(completion.choices)
      assert choice.finish_reason == "length"
    end

    test "validates model parameter", %{client: client} do
      assert {:error, error} = FIM.complete(client, "gpt-4", "def test():")
      assert String.contains?(error, "FIM completion only supports codestral models")

      assert {:error, error} = FIM.complete(client, "mistral-large", "def test():")
      assert String.contains?(error, "FIM completion only supports codestral models")

      assert {:error, "Model must be a string"} = FIM.complete(client, nil, "def test():")
    end

    test "validates prompt parameter", %{client: client} do
      assert {:error, "Prompt must be a non-empty string"} =
               FIM.complete(client, "codestral-2405", "")

      assert {:error, "Prompt must be a non-empty string"} =
               FIM.complete(client, "codestral-2405", nil)
    end

    test "handles API errors", %{client: client} do
      error_body = FIMFixtures.fim_error_unauthorized()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 401, body: Jason.encode!(error_body)}}
      end)

      assert {:error, error} = FIM.complete(client, "codestral-2405", "def test():")
      assert %MistralClient.Errors.AuthenticationError{} = error
      assert String.contains?(error.message, "Invalid API key")
    end

    test "handles rate limit errors", %{client: client} do
      error_body = FIMFixtures.fim_error_rate_limit()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 429, body: Jason.encode!(error_body)}}
      end)

      assert {:error, error} = FIM.complete(client, "codestral-2405", "def test():")
      assert %MistralClient.Errors.RateLimitError{} = error
      assert String.contains?(error.message, "Rate limit exceeded")
    end

    test "handles server errors", %{client: client} do
      error_body = FIMFixtures.fim_error_server_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 500, body: Jason.encode!(error_body)}}
      end)

      assert {:error, error} = FIM.complete(client, "codestral-2405", "def test():")
      assert %MistralClient.Errors.ServerError{} = error
      assert String.contains?(error.message, "Internal server error")
    end

    test "handles network errors", %{client: client} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, error} = FIM.complete(client, "codestral-2405", "def test():")
      assert %MistralClient.Errors.NetworkError{} = error
    end
  end

  describe "stream/3 - basic interface" do
    test "streams FIM completion without callback", %{client: client} do
      chunks = FIMFixtures.fim_stream_chunks()

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, nil ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        # Verify streaming is enabled
        assert decoded_body["stream"] == true
        {:ok, chunks}
      end)

      assert {:ok, result_chunks} =
               FIM.stream(client, "codestral-2405", "def fibonacci(n):", suffix: "return result")

      assert is_list(result_chunks)
      assert length(result_chunks) == 4

      # Check first chunk
      first_chunk = hd(result_chunks)
      assert first_chunk["id"] == "fim_cmpl_stream_123"
      assert first_chunk["object"] == "fim.completion.chunk"

      # Check final chunk has usage
      final_chunk = List.last(result_chunks)
      assert final_chunk["usage"]["total_tokens"] == 40
    end

    test "streams FIM completion with callback", %{client: client} do
      chunks = FIMFixtures.fim_stream_chunks()

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, ^callback ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        # Verify streaming is enabled and callback is passed
        assert decoded_body["stream"] == true
        # Simulate calling the callback for each chunk
        Enum.each(chunks, callback)
        {:ok, :done}
      end)

      assert {:ok, :done} =
               FIM.stream(client, "codestral-2405", "def fibonacci(n):",
                 suffix: "return result",
                 callback: callback
               )

      # Verify we received all chunks
      assert_received {:chunk, chunk1}
      assert_received {:chunk, _chunk2}
      assert_received {:chunk, _chunk3}
      assert_received {:chunk, chunk4}

      assert chunk1["choices"] |> hd() |> get_in(["delta", "role"]) == "assistant"
      assert chunk4["choices"] |> hd() |> get_in(["finish_reason"]) == "stop"
    end

    test "validates parameters for streaming", %{client: client} do
      assert {:error, error} = FIM.stream(client, "gpt-4", "def test():")
      assert String.contains?(error, "FIM completion only supports codestral models")

      assert {:error, "Prompt must be a non-empty string"} =
               FIM.stream(client, "codestral-2405", "")
    end

    test "handles streaming errors", %{client: client} do
      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, _body, _opts ->
        {:error, :connection_failed}
      end)

      assert {:error, error} = FIM.stream(client, "codestral-2405", "def test():")
      assert %MistralClient.Errors.NetworkError{} = error
    end
  end

  describe "complete/2 - structured interface" do
    test "performs FIM completion with structured request", %{client: client} do
      response_body = FIMFixtures.fim_completion_response()

      request =
        FIMCompletionRequest.new("codestral-2405", "def fibonacci(n):",
          suffix: "return result",
          max_tokens: 100
        )

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        assert decoded_body["model"] == "codestral-2405"
        assert decoded_body["prompt"] == "def fibonacci(n):"
        assert decoded_body["suffix"] == "return result"
        assert decoded_body["max_tokens"] == 100
        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, completion} = FIM.complete(client, request)
      assert %FIMCompletionResponse{} = completion
      assert completion.id == "fim_cmpl_123456789"
    end

    test "validates structured request", %{client: client} do
      request = FIMCompletionRequest.new("gpt-4", "def test():")

      assert {:error, error} = FIM.complete(client, request)
      assert String.contains?(error, "FIM completion only supports codestral models")
    end
  end

  describe "stream/2 and stream/3 - structured interface" do
    test "streams FIM completion with structured request", %{client: client} do
      chunks = FIMFixtures.fim_stream_chunks()

      request =
        FIMCompletionRequest.new("codestral-2405", "def fibonacci(n):",
          suffix: "return result",
          stream: true
        )

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, nil ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        assert decoded_body["stream"] == true
        {:ok, chunks}
      end)

      assert {:ok, result_chunks} = FIM.stream_request(client, request)
      assert is_list(result_chunks)
      assert length(result_chunks) == 4
    end

    test "streams FIM completion with structured request and callback", %{client: client} do
      chunks = FIMFixtures.fim_stream_chunks()

      request =
        FIMCompletionRequest.new("codestral-2405", "def fibonacci(n):", suffix: "return result")

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, ^callback ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        # Verify streaming is forced
        assert decoded_body["stream"] == true
        Enum.each(chunks, callback)
        {:ok, :done}
      end)

      assert {:ok, :done} = FIM.stream_request(client, request, callback)

      # Verify we received chunks
      assert_received {:chunk, _chunk1}
      assert_received {:chunk, _chunk2}
      assert_received {:chunk, _chunk3}
      assert_received {:chunk, _chunk4}
    end
  end

  describe "model validation" do
    test "accepts valid codestral models", %{client: client} do
      response_body = FIMFixtures.fim_completion_response()

      for model <- ["codestral-2405", "codestral-latest"] do
        MistralClient.HttpClientMock
        |> expect(:request, fn :post, _url, _headers, body, _opts ->
          decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
          assert decoded_body["model"] == model
          {:ok, %{status: 200, body: Jason.encode!(response_body)}}
        end)

        assert {:ok, _completion} = FIM.complete(client, model, "def test():")
      end
    end

    test "rejects invalid models", %{client: client} do
      invalid_models = ["gpt-4", "mistral-large", "claude-3", "", nil, 123]

      for model <- invalid_models do
        assert {:error, _error} = FIM.complete(client, model, "def test():")
      end
    end
  end

  describe "request body validation" do
    test "includes only non-nil parameters in request body", %{client: client} do
      response_body = FIMFixtures.fim_completion_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
        # Should include required parameters
        assert Map.has_key?(decoded_body, "model")
        assert Map.has_key?(decoded_body, "prompt")

        # Should include provided optional parameters
        assert Map.has_key?(decoded_body, "suffix")
        assert Map.has_key?(decoded_body, "temperature")

        # Should not include nil parameters
        refute Map.has_key?(decoded_body, "max_tokens")
        refute Map.has_key?(decoded_body, "top_p")
        refute Map.has_key?(decoded_body, "stop")

        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, _completion} =
               FIM.complete(client, "codestral-2405", "def test():",
                 suffix: "return x",
                 temperature: 0.5,
                 max_tokens: nil,
                 top_p: nil,
                 stop: nil
               )
    end
  end

  describe "response parsing" do
    test "correctly parses FIM completion response", %{client: client} do
      response_body = FIMFixtures.fim_completion_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, completion} = FIM.complete(client, "codestral-2405", "def test():")

      # Verify response structure
      assert completion.id == "fim_cmpl_123456789"
      assert completion.object == "fim.completion"
      assert completion.created == 1_640_995_200
      assert completion.model == "codestral-2405"

      # Verify choices
      assert length(completion.choices) == 1
      choice = hd(completion.choices)
      assert choice.index == 0
      assert choice.finish_reason == "stop"

      # Verify message
      assert choice.message.role == "assistant"
      assert is_binary(choice.message.content)

      # Verify usage
      assert completion.usage.prompt_tokens == 15
      assert completion.usage.completion_tokens == 25
      assert completion.usage.total_tokens == 40
    end

    test "handles response without usage information", %{client: client} do
      response_body =
        FIMFixtures.fim_completion_response()
        |> Map.delete("usage")

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!(response_body)}}
      end)

      assert {:ok, completion} = FIM.complete(client, "codestral-2405", "def test():")
      assert is_nil(completion.usage)
    end
  end

  describe "error handling" do
    test "handles various HTTP error codes", %{client: client} do
      error_cases = [
        {401, FIMFixtures.fim_error_unauthorized(), "Invalid API key"},
        {422, FIMFixtures.fim_error_missing_prompt(), "Missing required parameter"},
        {429, FIMFixtures.fim_error_rate_limit(), "Rate limit exceeded"},
        {500, FIMFixtures.fim_error_server_error(), "Internal server error"}
      ]

      for {status_code, error_body, expected_message} <- error_cases do
        MistralClient.HttpClientMock
        |> expect(:request, fn :post, _url, _headers, _body, _opts ->
          {:ok, %{status: status_code, body: Jason.encode!(error_body)}}
        end)

        assert {:error, error} = FIM.complete(client, "codestral-2405", "def test():")
        assert is_struct(error)
        assert String.contains?(error.message, expected_message)
      end
    end

    test "handles malformed error responses", %{client: client} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 500, body: Jason.encode!(%{"invalid" => "response"})}}
      end)

      assert {:error, error} = FIM.complete(client, "codestral-2405", "def test():")
      assert is_struct(error)
    end
  end
end
