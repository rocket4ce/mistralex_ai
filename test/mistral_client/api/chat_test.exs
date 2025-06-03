defmodule MistralClient.API.ChatTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.API.Chat
  alias MistralClient.HttpClientMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "complete/2" do
    test "returns successful chat completion response" do
      request = ChatFixtures.chat_completion_request()
      response = ChatFixtures.chat_completion_response()

      MistralClient.Test.TestHelpers.setup_mock_response(:post, ~r/chat\/completions/, response)

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_chat_completion_response(
        result,
        "Hello! How can I assist you today?"
      )
    end

    test "returns chat completion with tools" do
      request = ChatFixtures.chat_completion_with_tools_request()
      response = ChatFixtures.chat_completion_with_tools_response()

      MistralClient.Test.TestHelpers.setup_mock_response(:post, ~r/chat\/completions/, response)

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      assert {:ok, completion} = result

      case completion do
        %MistralClient.Models.ChatCompletion{choices: [choice]} ->
          assert %MistralClient.Models.ChatCompletionChoice{message: message} = choice
          assert %MistralClient.Models.Message{tool_calls: tool_calls} = message
          assert length(tool_calls) == 1

          tool_call = List.first(tool_calls)
          assert %MistralClient.Models.ToolCall{function: function} = tool_call
          assert %MistralClient.Models.ToolCallFunction{name: "get_weather"} = function

        %{"choices" => [choice]} ->
          assert %{"message" => message} = choice
          assert %{"tool_calls" => tool_calls} = message
          assert length(tool_calls) == 1

          tool_call = List.first(tool_calls)
          assert %{"function" => %{"name" => "get_weather"}} = tool_call
      end
    end

    test "handles validation errors" do
      request = %{"model" => "", "messages" => []}
      # No mock setup needed - validation happens client-side

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 422)
    end

    test "handles unauthorized errors" do
      request = ChatFixtures.chat_completion_request()
      _error_response = ErrorFixtures.unauthorized_error()

      MistralClient.Test.TestHelpers.setup_mock_error(
        :post,
        ~r/chat\/completions/,
        401,
        "Unauthorized"
      )

      config = MistralClient.Test.TestHelpers.test_config(api_key: "invalid-key")
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 401)
    end

    test "handles rate limit errors" do
      request = ChatFixtures.chat_completion_request()
      _error_response = ErrorFixtures.rate_limit_error()

      MistralClient.Test.TestHelpers.setup_mock_error(
        :post,
        ~r/chat\/completions/,
        429,
        "Rate limit exceeded"
      )

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 429)
    end

    test "handles server errors" do
      request = ChatFixtures.chat_completion_request()
      _error_response = ErrorFixtures.internal_server_error()

      MistralClient.Test.TestHelpers.setup_mock_error(
        :post,
        ~r/chat\/completions/,
        500,
        "Internal server error"
      )

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 500)
    end
  end

  describe "stream/2" do
    test "returns streaming chat completion response" do
      request = ChatFixtures.streaming_chat_request()
      events = ChatFixtures.streaming_chat_events()

      MistralClient.Test.TestHelpers.setup_mock_stream(:post, ~r/chat\/completions/, events)

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.stream(config, request)

      assert {:ok, stream} = result
      assert is_function(stream, 2) or is_struct(stream, Stream)

      # Collect all events from the stream
      collected_events = Enum.to_list(stream)
      assert length(collected_events) == length(events)

      # Verify the structure of streamed events
      first_event = List.first(collected_events)
      assert {:ok, %{data: data}} = first_event
      assert is_binary(data)

      # Parse the JSON data
      parsed_data = Jason.decode!(data)
      assert %{"choices" => choices} = parsed_data
      assert is_list(choices)
    end

    test "handles streaming errors" do
      request = ChatFixtures.streaming_chat_request()

      expect(MistralClient.HttpClientMock, :stream_request, fn :post,
                                                               _url,
                                                               _headers,
                                                               _body,
                                                               _options ->
        {:error, :connection_failed}
      end)

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.stream(config, request)

      assert {:error, :connection_failed} = result
    end
  end

  describe "parameter validation" do
    test "validates required model parameter" do
      request = %{"model" => "", "messages" => [%{"role" => "user", "content" => "Hello"}]}
      # No mock setup needed - validation happens client-side

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 422)
    end

    test "validates required messages parameter" do
      request = %{"model" => "mistral-tiny"}
      # No mock setup needed - validation happens client-side

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 422)
    end

    test "validates temperature range" do
      request = %{
        "model" => "mistral-tiny",
        "messages" => [%{"role" => "user", "content" => "Hello"}],
        "temperature" => 3.0
      }

      # No mock setup needed - validation happens client-side

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 422)
    end

    test "validates max_tokens parameter" do
      request = %{
        "model" => "mistral-tiny",
        "messages" => [%{"role" => "user", "content" => "Hello"}],
        "max_tokens" => -1
      }

      # No mock setup needed - validation happens client-side

      config = MistralClient.Test.TestHelpers.test_config()
      result = Chat.complete(config, request)

      MistralClient.Test.TestHelpers.assert_error_response(result, 422)
    end
  end
end
