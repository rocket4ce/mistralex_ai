defmodule MistralClient.API.AgentsTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.API.Agents
  alias MistralClient.{Client, Models, Errors}
  alias MistralClient.Test.Fixtures.AgentFixtures
  alias MistralClient.Test.TestHelpers

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "complete/2 with config and request" do
    test "creates agent completion successfully" do
      config = TestHelpers.test_config()
      request = AgentFixtures.basic_agent_request()
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-123"

        assert decoded_body["messages"] == [
                 %{"role" => "user", "content" => "Hello, how are you?"}
               ]

        assert decoded_body["stream"] == false

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
      assert completion.id == "cmpl-agent-123456789"
      assert completion.model == "mistral-large-latest"
      assert length(completion.choices) == 1

      assert hd(completion.choices).message.content ==
               "Hello! I'm an AI agent. How can I help you today?"
    end

    test "creates agent completion with options" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_request_with_options()
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-456"
        assert decoded_body["temperature"] == 0.7
        assert decoded_body["max_tokens"] == 150
        assert decoded_body["top_p"] == 0.9

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
    end

    test "creates agent completion with tools" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_request_with_tools()
      response = AgentFixtures.agent_completion_with_tools()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-789"
        assert is_list(decoded_body["tools"])
        assert decoded_body["tool_choice"] == "auto"

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
      assert hd(completion.choices).message.tool_calls != nil
    end

    test "creates agent completion with structured output" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_request_with_structured_output()
      response = AgentFixtures.agent_completion_with_structured_output()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-structured"
        assert decoded_body["response_format"]["type"] == "json_object"

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
    end

    test "creates agent completion with penalties and multiple choices" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_request_with_penalties()
      response = AgentFixtures.agent_completion_multiple_choices()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-penalties"
        assert decoded_body["presence_penalty"] == 0.5
        assert decoded_body["frequency_penalty"] == 0.3
        assert decoded_body["n"] == 2

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
      assert length(completion.choices) == 2
    end

    test "returns error when agent_id is missing" do
      config = TestHelpers.test_config()
      request = %{"messages" => [%{"role" => "user", "content" => "Hello"}]}

      assert {:error, %Errors.ValidationError{} = error} = Agents.complete(config, request)
      assert error.message == "Request must contain 'agent_id' field"
      assert error.field == "agent_id"
    end

    test "returns error when messages are missing" do
      config = TestHelpers.test_config()
      request = %{"agent_id" => "agent-123"}

      assert {:error, %Errors.ValidationError{} = error} = Agents.complete(config, request)
      assert error.message == "Request must contain 'messages' field"
      assert error.field == "messages"
    end

    test "handles 401 unauthorized error" do
      config = TestHelpers.test_config()
      request = AgentFixtures.basic_agent_request()
      error_response = AgentFixtures.agent_unauthorized_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 401, body: Jason.encode!(error_response)}}
      end)

      assert {:error, %Errors.AuthenticationError{}} = Agents.complete(config, request)
    end

    test "handles 422 validation error" do
      config = TestHelpers.test_config()
      request = AgentFixtures.basic_agent_request()
      error_response = AgentFixtures.agent_validation_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 422, body: Jason.encode!(error_response)}}
      end)

      assert {:error, %Errors.ValidationError{}} = Agents.complete(config, request)
    end

    test "handles 429 rate limit error" do
      config = TestHelpers.test_config()
      request = AgentFixtures.basic_agent_request()
      error_response = AgentFixtures.agent_rate_limit_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 429, body: Jason.encode!(error_response)}}
      end)

      assert {:error, %Errors.RateLimitError{}} = Agents.complete(config, request)
    end

    test "handles 500 server error" do
      config = TestHelpers.test_config()
      request = AgentFixtures.basic_agent_request()
      error_response = AgentFixtures.agent_server_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 500, body: Jason.encode!(error_response)}}
      end)

      assert {:error, %Errors.ServerError{}} = Agents.complete(config, request)
    end
  end

  describe "complete/4 legacy interface" do
    test "creates agent completion with agent_id and messages" do
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-123"
        assert decoded_body["messages"] == [%{"role" => "user", "content" => "Hello!"}]

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      messages = [%{role: "user", content: "Hello!"}]
      assert {:ok, completion} = Agents.complete("agent-123", messages)
      assert %Models.ChatCompletion{} = completion
    end

    test "creates agent completion with options" do
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-456"
        assert decoded_body["temperature"] == 0.8
        assert decoded_body["max_tokens"] == 200

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      messages = [%{role: "user", content: "Hello!"}]
      options = %{temperature: 0.8, max_tokens: 200}
      assert {:ok, completion} = Agents.complete("agent-456", messages, options)
      assert %Models.ChatCompletion{} = completion
    end

    test "validates agent_id parameter" do
      messages = [%{role: "user", content: "Hello!"}]

      assert {:error, %Errors.ValidationError{} = error} = Agents.complete("", messages)
      assert error.message == "Agent ID must be a non-empty string"
      assert error.field == "agent_id"
    end

    test "validates messages parameter" do
      assert {:error, %Errors.ValidationError{} = error} = Agents.complete("agent-123", [])
      assert error.message == "Messages must be a non-empty list"
      assert error.field == "messages"
    end

    test "validates temperature parameter" do
      messages = [%{role: "user", content: "Hello!"}]
      options = %{temperature: 3.0}

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.complete("agent-123", messages, options)

      assert error.message == "Temperature must be a number between 0 and 2"
      assert error.field == "temperature"
    end

    test "validates max_tokens parameter" do
      messages = [%{role: "user", content: "Hello!"}]
      options = %{max_tokens: -10}

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.complete("agent-123", messages, options)

      assert error.message == "Max tokens must be a positive integer"
      assert error.field == "max_tokens"
    end

    test "validates top_p parameter" do
      messages = [%{role: "user", content: "Hello!"}]
      options = %{top_p: 1.5}

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.complete("agent-123", messages, options)

      assert error.message == "Top-p must be a number between 0 and 1"
      assert error.field == "top_p"
    end

    test "validates presence_penalty parameter" do
      messages = [%{role: "user", content: "Hello!"}]
      options = %{presence_penalty: 3.0}

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.complete("agent-123", messages, options)

      assert error.message == "Presence penalty must be a number between -2 and 2"
      assert error.field == "presence_penalty"
    end

    test "validates frequency_penalty parameter" do
      messages = [%{role: "user", content: "Hello!"}]
      options = %{frequency_penalty: -3.0}

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.complete("agent-123", messages, options)

      assert error.message == "Frequency penalty must be a number between -2 and 2"
      assert error.field == "frequency_penalty"
    end

    test "validates n parameter" do
      messages = [%{role: "user", content: "Hello!"}]
      options = %{n: 0}

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.complete("agent-123", messages, options)

      assert error.message == "N must be a positive integer"
      assert error.field == "n"
    end
  end

  describe "stream/3 with config and request" do
    test "creates streaming agent completion successfully" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_stream_request()
      stream_response = AgentFixtures.agent_stream_response()

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-stream"
        assert decoded_body["stream"] == true

        {:ok, [stream_response]}
      end)

      assert {:ok, stream} = Agents.stream(config, request)
      assert is_list(stream)
    end

    test "creates streaming agent completion with callback" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_stream_request()

      chunks = [
        AgentFixtures.agent_stream_chunk_start(),
        AgentFixtures.agent_stream_chunk_content(),
        AgentFixtures.agent_stream_chunk_end()
      ]

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, callback ->
        body_string = if is_binary(body), do: body, else: Jason.encode!(body)
        decoded_body = Jason.decode!(body_string)
        assert decoded_body["agent_id"] == "agent-stream"
        assert decoded_body["stream"] == true

        # Simulate streaming by calling the callback with each chunk
        Enum.each(chunks, fn chunk ->
          callback.(chunk)
        end)

        :ok
      end)

      collected_chunks = []

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      assert :ok = Agents.stream(config, request, callback)

      # Verify we received the chunks
      Enum.each(chunks, fn _chunk ->
        assert_receive {:chunk, _received_chunk}
      end)
    end

    test "handles streaming with tools" do
      config = TestHelpers.test_config()
      request = AgentFixtures.agent_request_with_tools()
      stream_response = AgentFixtures.agent_stream_response_with_tools()

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-789"
        assert is_list(decoded_body["tools"])

        {:ok, [stream_response]}
      end)

      assert {:ok, stream} = Agents.stream(config, request)
      assert is_list(stream)
    end

    test "returns error when agent_id is missing in stream request" do
      config = TestHelpers.test_config()
      request = %{"messages" => [%{"role" => "user", "content" => "Hello"}]}

      assert {:error, %Errors.ValidationError{} = error} = Agents.stream(config, request)
      assert error.message == "Request must contain 'agent_id' field"
      assert error.field == "agent_id"
    end
  end

  describe "stream_legacy/5 legacy interface" do
    test "creates streaming agent completion with callback" do
      chunks = [
        AgentFixtures.agent_stream_chunk_start(),
        AgentFixtures.agent_stream_chunk_content(),
        AgentFixtures.agent_stream_chunk_end()
      ]

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, callback ->
        body_string = if is_binary(body), do: body, else: Jason.encode!(body)
        decoded_body = Jason.decode!(body_string)
        assert decoded_body["agent_id"] == "agent-stream"
        assert decoded_body["stream"] == true

        # Simulate streaming by calling the callback with each chunk
        Enum.each(chunks, fn chunk ->
          callback.(chunk)
        end)

        :ok
      end)

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      messages = [%{role: "user", content: "Tell me a story"}]
      assert :ok = Agents.stream_legacy("agent-stream", messages, callback)

      # Verify we received the chunks
      Enum.each(chunks, fn _chunk ->
        assert_receive {:chunk, _received_chunk}
      end)
    end

    test "creates streaming agent completion with options" do
      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, callback ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-stream"
        assert decoded_body["temperature"] == 0.9
        assert decoded_body["max_tokens"] == 300

        callback.(AgentFixtures.agent_stream_chunk_content())
        :ok
      end)

      callback = fn _chunk -> :ok end
      messages = [%{role: "user", content: "Tell me a story"}]
      options = %{temperature: 0.9, max_tokens: 300}

      assert :ok = Agents.stream_legacy("agent-stream", messages, callback, options)
    end

    test "validates agent_id in streaming" do
      callback = fn _chunk -> :ok end
      messages = [%{role: "user", content: "Hello!"}]

      assert {:error, %Errors.ValidationError{} = error} =
               Agents.stream_legacy("", messages, callback)

      assert error.message == "Agent ID must be a non-empty string"
      assert error.field == "agent_id"
    end
  end

  describe "with_tools/5" do
    test "creates agent completion with tools" do
      response = AgentFixtures.agent_completion_with_tools()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-tools"
        assert is_list(decoded_body["tools"])
        assert length(decoded_body["tools"]) == 1

        tool = hd(decoded_body["tools"])
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "get_weather"

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      messages = [%{role: "user", content: "What's the weather?"}]

      tools = [
        %{
          type: "function",
          function: %{
            name: "get_weather",
            description: "Get weather",
            parameters: %{
              type: "object",
              properties: %{location: %{type: "string"}},
              required: ["location"]
            }
          }
        }
      ]

      assert {:ok, completion} = Agents.with_tools("agent-tools", messages, tools)
      assert %Models.ChatCompletion{} = completion
      assert hd(completion.choices).message.tool_calls != nil
    end

    test "creates agent completion with tools and options" do
      response = AgentFixtures.agent_completion_with_tools()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-tools"
        assert decoded_body["temperature"] == 0.5
        assert is_list(decoded_body["tools"])

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      messages = [%{role: "user", content: "What's the weather?"}]
      tools = [%{type: "function", function: %{name: "get_weather"}}]
      options = %{temperature: 0.5}

      assert {:ok, completion} = Agents.with_tools("agent-tools", messages, tools, options)
      assert %Models.ChatCompletion{} = completion
    end
  end

  describe "Message struct handling" do
    test "handles Message structs in messages list" do
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)

        assert decoded_body["messages"] == [
                 %{"role" => "user", "content" => "Hello from struct!"}
               ]

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      message_struct = Models.Message.new("user", "Hello from struct!")
      assert {:ok, completion} = Agents.complete("agent-123", [message_struct])
      assert %Models.ChatCompletion{} = completion
    end

    test "handles mixed Message structs and maps" do
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)

        expected_messages = [
          %{"role" => "user", "content" => "Hello from struct!"},
          %{"role" => "assistant", "content" => "Hello from map!"}
        ]

        assert decoded_body["messages"] == expected_messages

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      messages = [
        Models.Message.new("user", "Hello from struct!"),
        %{role: "assistant", content: "Hello from map!"}
      ]

      assert {:ok, completion} = Agents.complete("agent-123", messages)
      assert %Models.ChatCompletion{} = completion
    end

    test "returns error for invalid message types" do
      messages = [
        %{role: "user", content: "Valid message"},
        "invalid message",
        %{role: "assistant", content: "Another valid message"}
      ]

      assert {:error, %Errors.ValidationError{} = error} = Agents.complete("agent-123", messages)
      assert error.message == "All messages must be maps or Message structs"
      assert error.field == "messages"
    end
  end

  describe "Client struct handling" do
    test "accepts Client struct as first parameter" do
      client = Client.new(TestHelpers.test_config())
      request = AgentFixtures.basic_agent_request()
      response = AgentFixtures.agent_completion_success()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-123"

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(client, request)
      assert %Models.ChatCompletion{} = completion
    end

    test "accepts Client struct for streaming" do
      client = Client.new(TestHelpers.test_config())
      request = AgentFixtures.agent_stream_request()
      stream_response = AgentFixtures.agent_stream_response()

      MistralClient.HttpClientMock
      |> expect(:stream_request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-stream"

        {:ok, [stream_response]}
      end)

      assert {:ok, stream} = Agents.stream(client, request)
      assert is_list(stream)
    end
  end

  describe "String key conversion" do
    test "converts known string keys to atoms" do
      config = TestHelpers.test_config()
      response = AgentFixtures.agent_completion_success()

      # Request with string keys
      request = %{
        "agent_id" => "agent-string-keys",
        "messages" => [%{"role" => "user", "content" => "Hello"}],
        "temperature" => 0.7,
        "max_tokens" => 100,
        "top_p" => 0.9,
        "random_seed" => 42,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.2,
        "n" => 1
      }

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-string-keys"
        assert decoded_body["temperature"] == 0.7
        assert decoded_body["max_tokens"] == 100
        assert decoded_body["top_p"] == 0.9
        assert decoded_body["random_seed"] == 42
        assert decoded_body["presence_penalty"] == 0.1
        assert decoded_body["frequency_penalty"] == 0.2
        assert decoded_body["n"] == 1

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
    end

    test "preserves unknown string keys" do
      config = TestHelpers.test_config()
      response = AgentFixtures.agent_completion_success()

      request = %{
        "agent_id" => "agent-unknown-keys",
        "messages" => [%{"role" => "user", "content" => "Hello"}],
        "custom_field" => "custom_value"
      }

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["agent_id"] == "agent-unknown-keys"
        assert decoded_body["custom_field"] == "custom_value"

        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, completion} = Agents.complete(config, request)
      assert %Models.ChatCompletion{} = completion
    end
  end
end
