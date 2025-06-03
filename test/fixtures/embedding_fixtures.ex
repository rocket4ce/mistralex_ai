defmodule MistralClient.Test.EmbeddingFixtures do
  @moduledoc """
  Test fixtures for embedding API responses.
  """

  def embedding_response_single do
    %{
      "id" => "embd-aad6fc62b17349b192ef09225058bc91",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.0023064255,
            -0.009327292,
            -0.0028842222,
            0.017649648,
            -0.0199067,
            0.009146335,
            -0.0010943893,
            0.0041462765,
            0.0071931146,
            -0.0047942493
          ],
          "index" => 0
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 5,
        "total_tokens" => 5
      }
    }
  end

  def embedding_response_batch do
    %{
      "id" => "embd-aad6fc62b17349b192ef09225058bc92",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.0023064255,
            -0.009327292,
            -0.0028842222,
            0.017649648,
            -0.0199067
          ],
          "index" => 0
        },
        %{
          "object" => "embedding",
          "embedding" => [
            0.0012345678,
            -0.008765432,
            -0.0034567890,
            0.021098765,
            -0.0156789
          ],
          "index" => 1
        },
        %{
          "object" => "embedding",
          "embedding" => [
            0.0098765432,
            -0.001234567,
            -0.0087654321,
            0.012345678,
            -0.0234567
          ],
          "index" => 2
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 15,
        "total_tokens" => 15
      }
    }
  end

  def embedding_response_with_dimensions do
    %{
      "id" => "embd-aad6fc62b17349b192ef09225058bc93",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.0023064255,
            -0.009327292,
            -0.0028842222
          ],
          "index" => 0
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 5,
        "total_tokens" => 5
      }
    }
  end

  def embedding_request_single do
    %{
      "model" => "mistral-embed",
      "inputs" => "Hello, world!"
    }
  end

  def embedding_request_batch do
    %{
      "model" => "mistral-embed",
      "inputs" => [
        "First document",
        "Second document",
        "Third document"
      ]
    }
  end

  def embedding_request_with_options do
    %{
      "model" => "mistral-embed",
      "inputs" => "Hello, world!",
      "output_dimension" => 512,
      "output_dtype" => "float"
    }
  end

  def embedding_error_422 do
    %{
      "detail" => [
        %{
          "loc" => ["body", "inputs"],
          "msg" => "field required",
          "type" => "value_error.missing"
        }
      ]
    }
  end

  def embedding_error_401 do
    %{
      "message" => "Unauthorized",
      "request_id" => "req_123456789"
    }
  end

  def embedding_error_429 do
    %{
      "message" => "Rate limit exceeded",
      "type" => "rate_limit_exceeded",
      "request_id" => "req_987654321"
    }
  end

  def embedding_error_500 do
    %{
      "message" => "Internal server error",
      "type" => "internal_error",
      "request_id" => "req_555666777"
    }
  end

  # Helper functions for creating structured responses
  def create_embedding_response(opts \\ []) do
    id = Keyword.get(opts, :id, "embd-test-#{:rand.uniform(999_999)}")
    model = Keyword.get(opts, :model, "mistral-embed")
    embeddings = Keyword.get(opts, :embeddings, [[0.1, 0.2, 0.3]])
    prompt_tokens = Keyword.get(opts, :prompt_tokens, 5)

    data =
      embeddings
      |> Enum.with_index()
      |> Enum.map(fn {embedding, index} ->
        %{
          "object" => "embedding",
          "embedding" => embedding,
          "index" => index
        }
      end)

    %{
      "id" => id,
      "object" => "list",
      "data" => data,
      "model" => model,
      "usage" => %{
        "prompt_tokens" => prompt_tokens,
        "total_tokens" => prompt_tokens
      }
    }
  end

  def create_embedding_request(inputs, opts \\ []) do
    model = Keyword.get(opts, :model, "mistral-embed")
    output_dimension = Keyword.get(opts, :output_dimension)
    output_dtype = Keyword.get(opts, :output_dtype)

    request = %{
      "model" => model,
      "inputs" => inputs
    }

    request =
      if output_dimension do
        Map.put(request, "output_dimension", output_dimension)
      else
        request
      end

    request =
      if output_dtype do
        Map.put(request, "output_dtype", output_dtype)
      else
        request
      end

    request
  end
end
