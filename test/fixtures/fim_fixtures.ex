defmodule MistralClient.Test.Fixtures.FIMFixtures do
  @moduledoc """
  Test fixtures for FIM (Fill-in-the-Middle) API responses.
  """

  def fim_completion_response do
    %{
      "id" => "fim_cmpl_123456789",
      "object" => "fim.completion",
      "created" => 1_640_995_200,
      "model" => "codestral-2405",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" =>
              "    if n <= 1:\n        return n\n    else:\n        return fibonacci(n-1) + fibonacci(n-2)\n"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 15,
        "completion_tokens" => 25,
        "total_tokens" => 40
      }
    }
  end

  def fim_completion_response_with_suffix do
    %{
      "id" => "fim_cmpl_987654321",
      "object" => "fim.completion",
      "created" => 1_640_995_300,
      "model" => "codestral-2405",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" =>
              "    if n <= 1:\n        result = n\n    else:\n        result = fibonacci(n-1) + fibonacci(n-2)\n    "
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 20,
        "completion_tokens" => 30,
        "total_tokens" => 50
      }
    }
  end

  def fim_completion_response_max_tokens do
    %{
      "id" => "fim_cmpl_max_tokens",
      "object" => "fim.completion",
      "created" => 1_640_995_400,
      "model" => "codestral-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "    if n <= 1:\n        return n\n"
          },
          "finish_reason" => "length"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 15,
        "completion_tokens" => 10,
        "total_tokens" => 25
      }
    }
  end

  def fim_stream_chunk_start do
    %{
      "id" => "fim_cmpl_stream_123",
      "object" => "fim.completion.chunk",
      "created" => 1_640_995_500,
      "model" => "codestral-2405",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{
            "role" => "assistant",
            "content" => ""
          },
          "finish_reason" => nil
        }
      ]
    }
  end

  def fim_stream_chunk_content do
    %{
      "id" => "fim_cmpl_stream_123",
      "object" => "fim.completion.chunk",
      "created" => 1_640_995_500,
      "model" => "codestral-2405",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{
            "content" => "    if n <= 1:\n"
          },
          "finish_reason" => nil
        }
      ]
    }
  end

  def fim_stream_chunk_more_content do
    %{
      "id" => "fim_cmpl_stream_123",
      "object" => "fim.completion.chunk",
      "created" => 1_640_995_500,
      "model" => "codestral-2405",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{
            "content" => "        return n\n"
          },
          "finish_reason" => nil
        }
      ]
    }
  end

  def fim_stream_chunk_final do
    %{
      "id" => "fim_cmpl_stream_123",
      "object" => "fim.completion.chunk",
      "created" => 1_640_995_500,
      "model" => "codestral-2405",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{
            "content" => "    else:\n        return fibonacci(n-1) + fibonacci(n-2)\n"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 15,
        "completion_tokens" => 25,
        "total_tokens" => 40
      }
    }
  end

  def fim_stream_chunks do
    [
      fim_stream_chunk_start(),
      fim_stream_chunk_content(),
      fim_stream_chunk_more_content(),
      fim_stream_chunk_final()
    ]
  end

  # Error responses
  def fim_error_invalid_model do
    %{
      "error" => %{
        "message" =>
          "Model 'gpt-4' is not supported for FIM completion. Only codestral models are supported.",
        "type" => "invalid_request_error",
        "param" => "model",
        "code" => "model_not_supported"
      }
    }
  end

  def fim_error_missing_prompt do
    %{
      "error" => %{
        "message" => "Missing required parameter: 'prompt'",
        "type" => "invalid_request_error",
        "param" => "prompt",
        "code" => "missing_parameter"
      }
    }
  end

  def fim_error_unauthorized do
    %{
      "error" => %{
        "message" => "Invalid API key provided",
        "type" => "authentication_error",
        "code" => "invalid_api_key"
      }
    }
  end

  def fim_error_rate_limit do
    %{
      "error" => %{
        "message" => "Rate limit exceeded. Please try again later.",
        "type" => "rate_limit_error",
        "code" => "rate_limit_exceeded"
      }
    }
  end

  def fim_error_server_error do
    %{
      "error" => %{
        "message" => "Internal server error",
        "type" => "server_error",
        "code" => "internal_error"
      }
    }
  end

  # Request fixtures for testing
  def fim_request_basic do
    %{
      "model" => "codestral-2405",
      "prompt" => "def fibonacci(n):"
    }
  end

  def fim_request_with_suffix do
    %{
      "model" => "codestral-2405",
      "prompt" => "def fibonacci(n):",
      "suffix" => "return result"
    }
  end

  def fim_request_with_options do
    %{
      "model" => "codestral-latest",
      "prompt" => "def fibonacci(n):",
      "suffix" => "return result",
      "temperature" => 0.2,
      "max_tokens" => 100,
      "top_p" => 0.9,
      "stop" => ["\n\n"],
      "random_seed" => 42
    }
  end

  def fim_request_streaming do
    %{
      "model" => "codestral-2405",
      "prompt" => "def fibonacci(n):",
      "suffix" => "return result",
      "stream" => true
    }
  end

  # Validation test cases
  def invalid_model_requests do
    [
      %{"model" => "gpt-4", "prompt" => "def test():"},
      %{"model" => "mistral-large", "prompt" => "def test():"},
      %{"model" => "", "prompt" => "def test():"},
      %{"model" => nil, "prompt" => "def test():"}
    ]
  end

  def invalid_prompt_requests do
    [
      %{"model" => "codestral-2405", "prompt" => ""},
      %{"model" => "codestral-2405", "prompt" => nil},
      %{"model" => "codestral-2405"}
    ]
  end

  # Helper functions for tests
  def mock_http_response(status, body) do
    %{status: status, body: body}
  end

  def mock_stream_response(chunks) do
    chunks
    |> Enum.map(&Jason.encode!/1)
    |> Enum.map(&("data: " <> &1 <> "\n\n"))
    |> Enum.join()
    |> Kernel.<>("data: [DONE]\n\n")
  end
end
