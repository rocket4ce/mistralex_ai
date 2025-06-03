defmodule MistralClient.API.ClassifiersTest do
  use ExUnit.Case, async: true

  alias MistralClient.API.Classifiers
  alias MistralClient.Client
  alias MistralClient.Test.{ClassifierFixtures, TestHelpers}

  import Mox
  import TestHelpers

  setup :verify_on_exit!

  describe "moderate/3" do
    setup do
      client = Client.new(test_config())
      %{client: client}
    end

    test "moderates single text successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _options ->
        assert Jason.decode!(body) == ClassifierFixtures.moderation_request_fixture()

        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.moderation_response_fixture()
         }}
      end)

      assert {:ok, response} =
               Classifiers.moderate(
                 client,
                 "mistral-moderation-latest",
                 "This is some text to moderate"
               )

      assert response.id == "mod-123456789"
      assert response.model == "mistral-moderation-latest"
      assert length(response.results) == 1

      result = hd(response.results)
      assert result.categories["hate"] == false
      assert result.category_scores["hate"] == 0.0001
    end

    test "moderates multiple texts successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _options ->
        assert Jason.decode!(body) == ClassifierFixtures.moderation_request_list_fixture()

        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.moderation_response_multiple_fixture()
         }}
      end)

      assert {:ok, response} =
               Classifiers.moderate(client, "mistral-moderation-latest", [
                 "Text 1",
                 "Text 2",
                 "Text 3"
               ])

      assert response.id == "mod-123456789"
      assert response.model == "mistral-moderation-latest"
      assert length(response.results) == 3
    end

    test "handles moderation with violations", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.moderation_violation_response_fixture()
         }}
      end)

      assert {:ok, response} =
               Classifiers.moderate(client, "mistral-moderation-latest", "Hate speech content")

      assert response.id == "mod-violation-123"
      result = hd(response.results)
      assert result.categories["hate"] == true
      assert result.category_scores["hate"] == 0.8
    end

    test "handles validation errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 422,
           body: ClassifierFixtures.validation_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.moderate(client, "", "text")
      assert is_binary(error)
    end

    test "handles unauthorized errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 401,
           body: ClassifierFixtures.unauthorized_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.moderate(client, "mistral-moderation-latest", "text")
      assert is_binary(error)
    end

    test "handles rate limit errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 429,
           body: ClassifierFixtures.rate_limit_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.moderate(client, "mistral-moderation-latest", "text")
      assert is_binary(error)
    end

    test "handles server errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 500,
           body: ClassifierFixtures.server_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.moderate(client, "mistral-moderation-latest", "text")
      assert is_binary(error)
    end

    test "validates model parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.moderate(client, nil, "text")
      end
    end

    test "validates inputs parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.moderate(client, "model", nil)
      end
    end
  end

  describe "moderate_chat/3" do
    setup do
      client = Client.new(test_config())
      %{client: client}
    end

    test "moderates chat conversation successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _options ->
        assert Jason.decode!(body) == ClassifierFixtures.chat_moderation_request_fixture()

        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.chat_moderation_response_fixture()
         }}
      end)

      chat_inputs = [
        [
          %{role: "user", content: "Hello"},
          %{role: "assistant", content: "Hi there!"}
        ]
      ]

      assert {:ok, response} =
               Classifiers.moderate_chat(client, "mistral-moderation-latest", chat_inputs)

      assert response.id == "mod-chat-123456789"
      assert response.model == "mistral-moderation-latest"
      assert length(response.results) == 1

      result = hd(response.results)
      assert result.categories["hate"] == false
      assert result.category_scores["hate"] == 0.0001
    end

    test "handles validation errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 422,
           body: ClassifierFixtures.validation_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.moderate_chat(client, "", [])
      assert is_binary(error)
    end

    test "validates model parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.moderate_chat(client, nil, [])
      end
    end

    test "validates inputs parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.moderate_chat(client, "model", nil)
      end
    end
  end

  describe "classify/3" do
    setup do
      client = Client.new(test_config())
      %{client: client}
    end

    test "classifies single text successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _options ->
        assert Jason.decode!(body) == ClassifierFixtures.classification_request_fixture()

        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.classification_response_fixture()
         }}
      end)

      assert {:ok, response} =
               Classifiers.classify(
                 client,
                 "mistral-classifier-latest",
                 "This is some text to classify"
               )

      assert response.id == "cls-123456789"
      assert response.model == "mistral-classifier-latest"
      assert length(response.results) == 1

      result = hd(response.results)
      assert Map.has_key?(result, "category_1")
    end

    test "classifies multiple texts successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _options ->
        assert Jason.decode!(body) == ClassifierFixtures.classification_request_list_fixture()

        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.classification_response_multiple_fixture()
         }}
      end)

      assert {:ok, response} =
               Classifiers.classify(client, "mistral-classifier-latest", [
                 "Text 1",
                 "Text 2",
                 "Text 3"
               ])

      assert response.id == "cls-123456789"
      assert response.model == "mistral-classifier-latest"
      assert length(response.results) == 3

      Enum.each(response.results, fn result ->
        assert Map.has_key?(result, "sentiment")
      end)
    end

    test "handles complex classification with multiple categories", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.complex_classification_response_fixture()
         }}
      end)

      assert {:ok, response} =
               Classifiers.classify(
                 client,
                 "mistral-classifier-latest",
                 "Complex text to classify"
               )

      assert response.id == "cls-complex-123"
      result = hd(response.results)

      assert Map.has_key?(result, "sentiment")
      assert Map.has_key?(result, "topic")
      assert Map.has_key?(result, "urgency")

      assert result["sentiment"].scores["positive"] == 0.7
      assert result["topic"].scores["technology"] == 0.8
      assert result["urgency"].scores["low"] == 0.6
    end

    test "handles validation errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 422,
           body: ClassifierFixtures.validation_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.classify(client, "", "text")
      assert is_binary(error)
    end

    test "handles unauthorized errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 401,
           body: ClassifierFixtures.unauthorized_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.classify(client, "mistral-classifier-latest", "text")
      assert is_binary(error)
    end

    test "validates model parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.classify(client, nil, "text")
      end
    end

    test "validates inputs parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.classify(client, "model", nil)
      end
    end
  end

  describe "classify_chat/3" do
    setup do
      client = Client.new(test_config())
      %{client: client}
    end

    test "classifies chat conversation successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _options ->
        assert Jason.decode!(body) == ClassifierFixtures.chat_classification_request_fixture()

        {:ok,
         %{
           status: 200,
           body: ClassifierFixtures.chat_classification_response_fixture()
         }}
      end)

      chat_inputs = [
        %{
          messages: [
            %{role: "user", content: "Hello"}
          ]
        }
      ]

      assert {:ok, response} =
               Classifiers.classify_chat(client, "mistral-classifier-latest", chat_inputs)

      assert response.id == "cls-chat-123456789"
      assert response.model == "mistral-classifier-latest"
      assert length(response.results) == 1

      result = hd(response.results)
      assert Map.has_key?(result, "intent")
      assert result["intent"].scores["greeting"] == 0.9
    end

    test "handles validation errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _options ->
        {:ok,
         %{
           status: 422,
           body: ClassifierFixtures.validation_error_fixture()
         }}
      end)

      assert {:error, error} = Classifiers.classify_chat(client, "", [])
      assert is_binary(error)
    end

    test "validates model parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.classify_chat(client, nil, [])
      end
    end

    test "validates inputs parameter", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Classifiers.classify_chat(client, "model", nil)
      end
    end
  end
end
