defmodule MistralClient.Test.Fixtures.BetaFixtures do
  @moduledoc """
  Test fixtures for Beta API responses.
  """

  def agent_response do
    %{
      "id" => "agent_123",
      "object" => "agent",
      "name" => "Customer Support Agent",
      "model" => "mistral-large-latest",
      "instructions" => "You are a helpful customer support agent.",
      "description" => "An agent for handling customer support inquiries",
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_order_status",
            "description" => "Get the status of a customer order",
            "parameters" => %{
              "type" => "object",
              "properties" => %{
                "order_id" => %{
                  "type" => "string",
                  "description" => "The order ID to check"
                }
              },
              "required" => ["order_id"]
            }
          }
        }
      ],
      "completion_args" => %{
        "temperature" => 0.7,
        "max_tokens" => 1000
      },
      "handoffs" => ["escalation_agent"],
      "version" => 1,
      "created_at" => "2024-03-06T12:00:00Z",
      "updated_at" => "2024-03-06T12:00:00Z"
    }
  end

  def agents_list_response do
    [
      agent_response(),
      %{
        "id" => "agent_456",
        "object" => "agent",
        "name" => "Sales Agent",
        "model" => "mistral-large-latest",
        "instructions" => "You are a sales assistant.",
        "description" => "An agent for handling sales inquiries",
        "tools" => [],
        "completion_args" => %{
          "temperature" => 0.5
        },
        "handoffs" => [],
        "version" => 2,
        "created_at" => "2024-03-05T10:00:00Z",
        "updated_at" => "2024-03-06T11:00:00Z"
      }
    ]
  end

  def conversation_response do
    %{
      "object" => "conversation.response",
      "conversation_id" => "conv_123",
      "outputs" => [
        %{
          "id" => "entry_456",
          "object" => "entry",
          "type" => "message.output",
          "role" => "assistant",
          "content" =>
            "Hello! I'm here to help you with your order. Could you please provide your order ID?",
          "agent_id" => "agent_123",
          "model" => "mistral-large-latest",
          "created_at" => "2024-03-06T12:01:00Z",
          "completed_at" => "2024-03-06T12:01:05Z"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 25,
        "completion_tokens" => 20,
        "total_tokens" => 45
      }
    }
  end

  def conversation_entity do
    %{
      "id" => "conv_123",
      "object" => "conversation",
      "name" => "Customer Support Session",
      "description" => "A conversation with customer support",
      "model" => "mistral-large-latest",
      "instructions" => "You are a helpful customer support agent.",
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_order_status",
            "description" => "Get order status"
          }
        }
      ],
      "completion_args" => %{
        "temperature" => 0.7
      },
      "created_at" => "2024-03-06T12:00:00Z",
      "updated_at" => "2024-03-06T12:01:00Z"
    }
  end

  def conversations_list_response do
    [
      conversation_entity(),
      %{
        "id" => "conv_456",
        "object" => "conversation",
        "name" => "Sales Inquiry",
        "description" => "A sales conversation",
        "model" => "mistral-large-latest",
        "instructions" => "You are a sales assistant.",
        "tools" => [],
        "completion_args" => %{
          "temperature" => 0.5
        },
        "created_at" => "2024-03-05T10:00:00Z",
        "updated_at" => "2024-03-05T10:30:00Z"
      }
    ]
  end

  def conversation_history_response do
    %{
      "object" => "conversation.history",
      "conversation_id" => "conv_123",
      "entries" => [
        %{
          "id" => "entry_001",
          "object" => "entry",
          "type" => "message.input",
          "role" => "user",
          "content" => "Hello, I need help with my order.",
          "created_at" => "2024-03-06T12:00:00Z",
          "completed_at" => "2024-03-06T12:00:00Z"
        },
        %{
          "id" => "entry_002",
          "object" => "entry",
          "type" => "message.output",
          "role" => "assistant",
          "content" =>
            "Hello! I'm here to help you with your order. Could you please provide your order ID?",
          "agent_id" => "agent_123",
          "model" => "mistral-large-latest",
          "created_at" => "2024-03-06T12:01:00Z",
          "completed_at" => "2024-03-06T12:01:05Z"
        },
        %{
          "id" => "entry_003",
          "object" => "entry",
          "type" => "message.input",
          "role" => "user",
          "content" => "My order ID is ORD-12345",
          "created_at" => "2024-03-06T12:02:00Z",
          "completed_at" => "2024-03-06T12:02:00Z"
        }
      ]
    }
  end

  def conversation_messages_response do
    %{
      "object" => "conversation.messages",
      "conversation_id" => "conv_123",
      "messages" => [
        %{
          "id" => "entry_001",
          "object" => "entry",
          "type" => "message.input",
          "role" => "user",
          "content" => "Hello, I need help with my order.",
          "created_at" => "2024-03-06T12:00:00Z",
          "completed_at" => "2024-03-06T12:00:00Z"
        },
        %{
          "id" => "entry_002",
          "object" => "entry",
          "type" => "message.output",
          "role" => "assistant",
          "content" =>
            "Hello! I'm here to help you with your order. Could you please provide your order ID?",
          "agent_id" => "agent_123",
          "model" => "mistral-large-latest",
          "created_at" => "2024-03-06T12:01:00Z",
          "completed_at" => "2024-03-06T12:01:05Z"
        }
      ]
    }
  end

  def beta_status_available do
    %{
      "available" => true,
      "features" => ["agents", "conversations"],
      "version" => "beta"
    }
  end

  def beta_status_unavailable do
    %{
      "available" => false,
      "reason" => "Access denied to beta features"
    }
  end

  # Error responses
  def agent_not_found_error do
    %{
      "error" => %{
        "message" => "Agent not found",
        "type" => "not_found_error",
        "code" => "agent_not_found"
      }
    }
  end

  def conversation_not_found_error do
    %{
      "error" => %{
        "message" => "Conversation not found",
        "type" => "not_found_error",
        "code" => "conversation_not_found"
      }
    }
  end

  def validation_error do
    %{
      "error" => %{
        "message" => "Validation error: Missing required field 'name'",
        "type" => "validation_error",
        "code" => "missing_required_field"
      }
    }
  end

  def beta_access_denied_error do
    %{
      "error" => %{
        "message" => "Access denied to beta features",
        "type" => "permission_error",
        "code" => "beta_access_denied"
      }
    }
  end

  # Streaming responses
  def conversation_stream_chunks do
    [
      %{
        "object" => "conversation.response.chunk",
        "conversation_id" => "conv_123",
        "delta" => %{
          "content" => "Hello! "
        }
      },
      %{
        "object" => "conversation.response.chunk",
        "conversation_id" => "conv_123",
        "delta" => %{
          "content" => "I'm here to help "
        }
      },
      %{
        "object" => "conversation.response.chunk",
        "conversation_id" => "conv_123",
        "delta" => %{
          "content" => "you with your order."
        }
      },
      %{
        "object" => "conversation.response.chunk",
        "conversation_id" => "conv_123",
        "delta" => %{},
        "finish_reason" => "stop"
      }
    ]
  end

  # Request examples
  def agent_create_request do
    %{
      "name" => "Customer Support Agent",
      "model" => "mistral-large-latest",
      "instructions" => "You are a helpful customer support agent.",
      "description" => "An agent for handling customer support inquiries",
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_order_status",
            "description" => "Get the status of a customer order"
          }
        }
      ]
    }
  end

  def agent_update_request do
    %{
      "instructions" => "You are an updated customer support agent with enhanced capabilities.",
      "description" => "Updated description for the agent"
    }
  end

  def conversation_start_request do
    %{
      "agent_id" => "agent_123",
      "inputs" => "Hello, I need help with my order.",
      "name" => "Customer Support Session",
      "store" => true
    }
  end

  def conversation_append_request do
    %{
      "inputs" => "My order ID is ORD-12345",
      "store" => true
    }
  end

  def conversation_restart_request do
    %{
      "inputs" => "Let me try a different approach",
      "from_entry_id" => "entry_002",
      "store" => true
    }
  end
end
