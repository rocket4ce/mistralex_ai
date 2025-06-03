defmodule ChatFixtures do
  @moduledoc """
  Test fixtures for Chat API responses.

  These fixtures are based on the actual Mistral API documentation
  and provide realistic test data for various chat scenarios.
  """

  @doc """
  Basic chat completion response fixture.
  """
  def chat_completion_response do
    %{
      "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
      "model" => "mistral-tiny",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "Hello! How can I assist you today?"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 14,
        "completion_tokens" => 9,
        "total_tokens" => 23
      }
    }
  end

  @doc """
  Chat completion response with function calling.
  """
  def chat_completion_with_tools_response do
    %{
      "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
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
                  "arguments" => "{\"location\": \"Paris\", \"unit\": \"celsius\"}"
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 89,
        "completion_tokens" => 32,
        "total_tokens" => 121
      }
    }
  end

  @doc """
  Streaming chat completion response events.
  """
  def streaming_chat_events do
    [
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-tiny",
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
      },
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-tiny",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{
              "content" => "Hello"
            },
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-tiny",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{
              "content" => "! How can I help you today?"
            },
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-tiny",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{},
            "finish_reason" => "stop"
          }
        ]
      }
    ]
  end

  @doc """
  Basic chat completion request payload.
  """
  def chat_completion_request do
    %{
      "model" => "mistral-tiny",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Hello, how are you?"
        }
      ],
      "temperature" => 0.7,
      "max_tokens" => 100
    }
  end

  @doc """
  Chat completion request with tools.
  """
  def chat_completion_with_tools_request do
    %{
      "model" => "mistral-large-latest",
      "messages" => [
        %{
          "role" => "user",
          "content" => "What's the weather like in Paris?"
        }
      ],
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_weather",
            "description" => "Get the current weather in a given location",
            "parameters" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{
                  "type" => "string",
                  "description" => "The city and state, e.g. San Francisco, CA"
                },
                "unit" => %{
                  "type" => "string",
                  "enum" => ["celsius", "fahrenheit"]
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

  @doc """
  Streaming chat completion request payload.
  """
  def streaming_chat_request do
    %{
      "model" => "mistral-tiny",
      "messages" => [
        %{
          "role" => "user",
          "content" => "Tell me a short story"
        }
      ],
      "stream" => true,
      "temperature" => 0.7
    }
  end

  @doc """
  Chat completion response with multiple choices.
  """
  def chat_completion_multiple_choices_response do
    %{
      "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
      "model" => "mistral-small-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "Option 1: This is the first response."
          },
          "finish_reason" => "stop"
        },
        %{
          "index" => 1,
          "message" => %{
            "role" => "assistant",
            "content" => "Option 2: This is the second response."
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 20,
        "completion_tokens" => 24,
        "total_tokens" => 44
      }
    }
  end

  @doc """
  Chat completion request with system message.
  """
  def chat_completion_with_system_request do
    %{
      "model" => "mistral-medium-latest",
      "messages" => [
        %{
          "role" => "system",
          "content" => "You are a helpful assistant that speaks like a pirate."
        },
        %{
          "role" => "user",
          "content" => "Hello, how are you?"
        }
      ],
      "temperature" => 0.7,
      "max_tokens" => 150
    }
  end

  @doc """
  Chat completion response with system message.
  """
  def chat_completion_with_system_response do
    %{
      "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
      "model" => "mistral-medium-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" =>
              "Ahoy there, matey! I be doin' fine as a fiddle, ready to help ye with whatever ye need!"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 35,
        "completion_tokens" => 23,
        "total_tokens" => 58
      }
    }
  end
end
