defmodule MistralClient.API.EmbeddingsTest do
  use ExUnit.Case, async: true
  import Mox
  import MistralClient.Test.TestHelpers

  alias MistralClient.API.Embeddings
  alias MistralClient.{Client, Models, Errors}
  alias MistralClient.Test.EmbeddingFixtures

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "create/3" do
    test "creates embeddings for single text" do
      response = EmbeddingFixtures.embedding_response_single()
      expected_request = EmbeddingFixtures.embedding_request_single()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        assert Jason.decode!(body) == expected_request
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:ok, %Models.EmbeddingResponse{} = embedding_response} =
               Embeddings.create("Hello, world!", %{}, client)

      assert embedding_response.id == "embd-aad6fc62b17349b192ef09225058bc91"
      assert embedding_response.object == "list"
      assert embedding_response.model == "mistral-embed"
      assert length(embedding_response.data) == 1

      [embedding] = embedding_response.data
      assert embedding.object == "embedding"
      assert embedding.index == 0
      assert is_list(embedding.embedding)
      assert length(embedding.embedding) == 10
    end

    test "creates embeddings for multiple texts" do
      response = EmbeddingFixtures.embedding_response_batch()
      expected_request = EmbeddingFixtures.embedding_request_batch()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        assert Jason.decode!(body) == expected_request
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())
      texts = ["First document", "Second document", "Third document"]

      assert {:ok, %Models.EmbeddingResponse{} = embedding_response} =
               Embeddings.create(texts, %{}, client)

      assert embedding_response.id == "embd-aad6fc62b17349b192ef09225058bc92"
      assert length(embedding_response.data) == 3

      embedding_response.data
      |> Enum.with_index()
      |> Enum.each(fn {embedding, index} ->
        assert embedding.object == "embedding"
        assert embedding.index == index
        assert is_list(embedding.embedding)
        assert length(embedding.embedding) == 5
      end)
    end

    test "creates embeddings with custom options" do
      response = EmbeddingFixtures.embedding_response_with_dimensions()
      expected_request = EmbeddingFixtures.embedding_request_with_options()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        assert Jason.decode!(body) == expected_request
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())

      options = %{
        model: "mistral-embed",
        output_dimension: 512,
        output_dtype: "float"
      }

      assert {:ok, %Models.EmbeddingResponse{} = embedding_response} =
               Embeddings.create("Hello, world!", options, client)

      assert embedding_response.id == "embd-aad6fc62b17349b192ef09225058bc93"
      assert length(embedding_response.data) == 1

      [embedding] = embedding_response.data
      assert length(embedding.embedding) == 3
    end

    test "uses default client when none provided" do
      response = EmbeddingFixtures.embedding_response_single()
      expected_request = EmbeddingFixtures.embedding_request_single()

      # Set up environment for default client
      Application.put_env(:mistral_client, :api_key, valid_api_key())

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        assert Jason.decode!(body) == expected_request
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      assert {:ok, %Models.EmbeddingResponse{}} = Embeddings.create("Hello, world!")

      # Clean up
      Application.delete_env(:mistral_client, :api_key)
    end

    test "handles API errors" do
      error_response = EmbeddingFixtures.embedding_error_422()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, _body, _options ->
        assert String.ends_with?(url, "/embeddings")
        {:ok, %{status: 422, body: error_response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:error, _error} = Embeddings.create("Hello, world!", %{}, client)
    end

    test "validates empty input" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "inputs"}} =
               Embeddings.create("", %{}, client)
    end

    test "validates empty list input" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "inputs"}} =
               Embeddings.create([], %{}, client)
    end

    test "validates list with empty strings" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "inputs"}} =
               Embeddings.create(["hello", "", "world"], %{}, client)
    end

    test "validates invalid input type" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "inputs"}} =
               Embeddings.create(123, %{}, client)
    end

    test "validates invalid model" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "model"}} =
               Embeddings.create("Hello", %{model: ""}, client)
    end

    test "validates invalid output_dtype" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "output_dtype"}} =
               Embeddings.create("Hello", %{output_dtype: "invalid"}, client)
    end

    test "validates invalid output_dimension" do
      client = Client.new(test_config())

      assert {:error, %Errors.ValidationError{field: "output_dimension"}} =
               Embeddings.create("Hello", %{output_dimension: -1}, client)
    end
  end

  describe "create_single/3" do
    test "creates embedding for single text" do
      response = EmbeddingFixtures.embedding_response_single()
      expected_request = EmbeddingFixtures.embedding_request_single()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        assert Jason.decode!(body) == expected_request
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:ok, %Models.EmbeddingResponse{}} =
               Embeddings.create_single("Hello, world!", %{}, client)
    end
  end

  describe "create_batch/3" do
    test "creates embeddings for multiple texts" do
      response = EmbeddingFixtures.embedding_response_batch()
      expected_request = EmbeddingFixtures.embedding_request_batch()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        assert Jason.decode!(body) == expected_request
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())
      texts = ["First document", "Second document", "Third document"]

      assert {:ok, %Models.EmbeddingResponse{}} =
               Embeddings.create_batch(texts, %{}, client)
    end
  end

  describe "extract_embeddings/1" do
    test "extracts embeddings from response" do
      response = EmbeddingFixtures.embedding_response_batch()
      embedding_response = Models.EmbeddingResponse.from_map(response)

      embeddings = Embeddings.extract_embeddings(embedding_response)

      assert length(embeddings) == 3
      assert Enum.all?(embeddings, &is_list/1)
      assert Enum.all?(embeddings, fn embedding -> length(embedding) == 5 end)
    end
  end

  describe "extract_first_embedding/1" do
    test "extracts first embedding from response" do
      response = EmbeddingFixtures.embedding_response_single()
      embedding_response = Models.EmbeddingResponse.from_map(response)

      embedding = Embeddings.extract_first_embedding(embedding_response)

      assert is_list(embedding)
      assert length(embedding) == 10
    end

    test "returns nil for empty response" do
      empty_response = %Models.EmbeddingResponse{data: []}

      assert Embeddings.extract_first_embedding(empty_response) == nil
    end
  end

  describe "cosine_similarity/2" do
    test "calculates cosine similarity between embeddings" do
      embedding1 = [1.0, 0.0, 0.0]
      embedding2 = [0.0, 1.0, 0.0]

      similarity = Embeddings.cosine_similarity(embedding1, embedding2)

      assert similarity == 0.0
    end

    test "calculates cosine similarity for identical embeddings" do
      embedding = [1.0, 2.0, 3.0]

      similarity = Embeddings.cosine_similarity(embedding, embedding)

      assert similarity == 1.0
    end

    test "raises error for different length embeddings" do
      embedding1 = [1.0, 2.0]
      embedding2 = [1.0, 2.0, 3.0]

      assert_raise ArgumentError, "Embeddings must have the same length", fn ->
        Embeddings.cosine_similarity(embedding1, embedding2)
      end
    end

    test "handles zero magnitude embeddings" do
      embedding1 = [0.0, 0.0, 0.0]
      embedding2 = [1.0, 2.0, 3.0]

      similarity = Embeddings.cosine_similarity(embedding1, embedding2)

      assert similarity == 0.0
    end
  end

  describe "euclidean_distance/2" do
    test "calculates euclidean distance between embeddings" do
      embedding1 = [0.0, 0.0, 0.0]
      embedding2 = [3.0, 4.0, 0.0]

      distance = Embeddings.euclidean_distance(embedding1, embedding2)

      assert distance == 5.0
    end

    test "calculates distance for identical embeddings" do
      embedding = [1.0, 2.0, 3.0]

      distance = Embeddings.euclidean_distance(embedding, embedding)

      assert distance == 0.0
    end

    test "raises error for different length embeddings" do
      embedding1 = [1.0, 2.0]
      embedding2 = [1.0, 2.0, 3.0]

      assert_raise ArgumentError, "Embeddings must have the same length", fn ->
        Embeddings.euclidean_distance(embedding1, embedding2)
      end
    end
  end

  describe "error handling" do
    test "handles 401 unauthorized error" do
      error_response = EmbeddingFixtures.embedding_error_401()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, _body, _options ->
        assert String.ends_with?(url, "/embeddings")
        {:ok, %{status: 401, body: error_response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:error, _error} = Embeddings.create("Hello, world!", %{}, client)
    end

    test "handles 429 rate limit error" do
      error_response = EmbeddingFixtures.embedding_error_429()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, _body, _options ->
        assert String.ends_with?(url, "/embeddings")
        {:ok, %{status: 429, body: error_response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:error, _error} = Embeddings.create("Hello, world!", %{}, client)
    end

    test "handles 500 server error" do
      error_response = EmbeddingFixtures.embedding_error_500()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, _body, _options ->
        assert String.ends_with?(url, "/embeddings")
        {:ok, %{status: 500, body: error_response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:error, _error} = Embeddings.create("Hello, world!", %{}, client)
    end
  end

  describe "integration with different output types" do
    test "handles float output type" do
      response = EmbeddingFixtures.create_embedding_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        decoded_body = Jason.decode!(body)
        assert decoded_body["output_dtype"] == "float"
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:ok, %Models.EmbeddingResponse{}} =
               Embeddings.create("Hello", %{output_dtype: "float"}, client)
    end

    test "handles int8 output type" do
      response = EmbeddingFixtures.create_embedding_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        decoded_body = Jason.decode!(body)
        assert decoded_body["output_dtype"] == "int8"
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:ok, %Models.EmbeddingResponse{}} =
               Embeddings.create("Hello", %{output_dtype: "int8"}, client)
    end

    test "handles custom dimensions" do
      response = EmbeddingFixtures.create_embedding_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _options ->
        assert String.ends_with?(url, "/embeddings")
        decoded_body = Jason.decode!(body)
        assert decoded_body["output_dimension"] == 256
        {:ok, %{status: 200, body: response, headers: %{}}}
      end)

      client = Client.new(test_config())

      assert {:ok, %Models.EmbeddingResponse{}} =
               Embeddings.create("Hello", %{output_dimension: 256}, client)
    end
  end
end
