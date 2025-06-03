defmodule InfrastructureTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.HttpClientMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "testing infrastructure" do
    test "Mox behavior is working" do
      # Set up a mock expectation
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: %{"test" => "success"}}}
      end)

      # Call the mock
      result =
        MistralClient.HttpClientMock.request(:post, "https://api.mistral.ai/test", [], %{}, [])

      # Assert the result
      assert {:ok, %{status: 200, body: %{"test" => "success"}}} = result
    end

    test "TestHelpers module is available" do
      config = MistralClient.Test.TestHelpers.test_config()
      assert %MistralClient.Config{} = config
      assert config.api_key == "test-api-key-12345"
    end

    test "ChatFixtures module is available" do
      request = ChatFixtures.chat_completion_request()
      assert is_map(request)
      assert request["model"] == "mistral-tiny"
    end

    test "ErrorFixtures module is available" do
      error = ErrorFixtures.validation_error()
      assert is_map(error)
      assert error["error"]["type"] == "invalid_request_error"
    end

    test "TestHelpers mock setup works" do
      response = %{"test" => "mock_response"}
      MistralClient.Test.TestHelpers.setup_mock_response(:get, "test", response)

      # The mock should be set up correctly
      result = MistralClient.HttpClientMock.request(:get, "test_url", [], nil, [])
      assert {:ok, %{status: 200, body: %{"test" => "mock_response"}}} = result
    end
  end
end
