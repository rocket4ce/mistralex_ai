defmodule MistralClient.Test.Fixtures.AgentFixtures do
  @moduledoc """
  Test fixtures for Agents API responses.
  """

  def agent_completion_success do
    %{
      "id" => "cmpl-agent-123456789",
      "object" => "chat.completion",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "Hello! I'm an AI agent. How can I help you today?"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 10,
        "completion_tokens" => 15,
        "total_tokens" => 25
      }
    }
  end

  def agent_completion_with_tools do
    %{
      "id" => "cmpl-agent-tools-123",
      "object" => "chat.completion",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => nil,
            "tool_calls" => [
              %{
                "id" => "call_123",
                "type" => "function",
                "function" => %{
                  "name" => "get_weather",
                  "arguments" => "{\"location\": \"Paris\"}"
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 25,
        "completion_tokens" => 20,
        "total_tokens" => 45
      }
    }
  end

  def agent_completion_multiple_choices do
    %{
      "id" => "cmpl-agent-multi-123",
      "object" => "chat.completion",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "First response option."
          },
          "finish_reason" => "stop"
        },
        %{
          "index" => 1,
          "message" => %{
            "role" => "assistant",
            "content" => "Second response option."
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 15,
        "completion_tokens" => 12,
        "total_tokens" => 27
      }
    }
  end

  def agent_stream_chunk_start do
    %{
      "id" => "cmpl-agent-stream-123",
      "object" => "chat.completion.chunk",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
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

  def agent_stream_chunk_content do
    %{
      "id" => "cmpl-agent-stream-123",
      "object" => "chat.completion.chunk",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{
            "content" => "Hello from agent!"
          },
          "finish_reason" => nil
        }
      ]
    }
  end

  def agent_stream_chunk_end do
    %{
      "id" => "cmpl-agent-stream-123",
      "object" => "chat.completion.chunk",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{},
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 8,
        "completion_tokens" => 12,
        "total_tokens" => 20
      }
    }
  end

  def agent_stream_chunk_tool_call do
    %{
      "id" => "cmpl-agent-stream-tool-123",
      "object" => "chat.completion.chunk",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "delta" => %{
            "tool_calls" => [
              %{
                "index" => 0,
                "id" => "call_456",
                "type" => "function",
                "function" => %{
                  "name" => "search_web",
                  "arguments" => "{\"query\": \"Elixir programming\"}"
                }
              }
            ]
          },
          "finish_reason" => nil
        }
      ]
    }
  end

  def agent_completion_with_structured_output do
    %{
      "id" => "cmpl-agent-structured-123",
      "object" => "chat.completion",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "{\"name\": \"John Doe\", \"age\": 30, \"city\": \"Paris\"}"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 20,
        "completion_tokens" => 18,
        "total_tokens" => 38
      }
    }
  end

  def agent_completion_with_stop_sequence do
    %{
      "id" => "cmpl-agent-stop-123",
      "object" => "chat.completion",
      "created" => 1_640_995_200,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "This is a response that was stopped by"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 12,
        "completion_tokens" => 10,
        "total_tokens" => 22
      }
    }
  end

  # Error responses
  def agent_validation_error do
    %{
      "detail" => [
        %{
          "loc" => ["body", "agent_id"],
          "msg" => "field required",
          "type" => "value_error.missing"
        }
      ]
    }
  end

  def agent_not_found_error do
    %{
      "detail" => "Agent not found",
      "type" => "agent_not_found"
    }
  end

  def agent_unauthorized_error do
    %{
      "detail" => "Invalid API key",
      "type" => "unauthorized"
    }
  end

  def agent_rate_limit_error do
    %{
      "detail" => "Rate limit exceeded",
      "type" => "rate_limit_exceeded"
    }
  end

  def agent_server_error do
    %{
      "detail" => "Internal server error",
      "type" => "internal_server_error"
    }
  end

  # Request examples
  def basic_agent_request do
    %{
      "agent_id" => "agent-123",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Hello, how are you?"
        }
      ]
    }
  end

  def agent_request_with_options do
    %{
      "agent_id" => "agent-456",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Tell me about Elixir programming"
        }
      ],
      "temperature" => 0.7,
      "max_tokens" => 150,
      "top_p" => 0.9
    }
  end

  def agent_request_with_tools do
    %{
      "agent_id" => "agent-789",
      "messages" => [
        %{
          "role" => "user",
          "content" => "What's the weather in Paris?"
        }
      ],
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_weather",
            "description" => "Get current weather for a location",
            "parameters" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{
                  "type" => "string",
                  "description" => "City name"
                }
              },
              "required" => ["location"]
            }
          }
        }
      ],
      "tool_choice" => "auto"
    }
  end

  def agent_request_with_structured_output do
    %{
      "agent_id" => "agent-structured",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Extract person info: John Doe is 30 years old and lives in Paris"
        }
      ],
      "response_format" => %{
        "type" => "json_object",
        "schema" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "age" => %{"type" => "integer"},
            "city" => %{"type" => "string"}
          },
          "required" => ["name", "age", "city"]
        }
      }
    }
  end

  def agent_request_with_penalties do
    %{
      "agent_id" => "agent-penalties",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Write a creative story"
        }
      ],
      "presence_penalty" => 0.5,
      "frequency_penalty" => 0.3,
      "n" => 2
    }
  end

  def agent_stream_request do
    %{
      "agent_id" => "agent-stream",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Tell me a story"
        }
      ],
      "stream" => true
    }
  end

  # SSE formatted responses for streaming tests
  def agent_sse_chunk(data) do
    "data: #{Jason.encode!(data)}\n\n"
  end

  def agent_sse_done do
    "data: [DONE]\n\n"
  end

  def agent_stream_response do
    [
      agent_sse_chunk(agent_stream_chunk_start()),
      agent_sse_chunk(agent_stream_chunk_content()),
      agent_sse_chunk(agent_stream_chunk_end()),
      agent_sse_done()
    ]
    |> Enum.join("")
  end

  def agent_stream_response_with_tools do
    [
      agent_sse_chunk(agent_stream_chunk_start()),
      agent_sse_chunk(agent_stream_chunk_tool_call()),
      agent_sse_chunk(agent_stream_chunk_end()),
      agent_sse_done()
    ]
    |> Enum.join("")
  end
end
