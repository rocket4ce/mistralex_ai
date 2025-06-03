defmodule MistralClient.Test.ClassifierFixtures do
  @moduledoc """
  Test fixtures for the Classifiers API.
  """

  def moderation_request_fixture do
    %{
      "model" => "mistral-moderation-latest",
      "input" => "This is some text to moderate"
    }
  end

  def moderation_request_list_fixture do
    %{
      "model" => "mistral-moderation-latest",
      "input" => ["Text 1", "Text 2", "Text 3"]
    }
  end

  def moderation_response_fixture do
    %{
      "id" => "mod-123456789",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{
            "hate" => false,
            "hate/threatening" => false,
            "harassment" => false,
            "harassment/threatening" => false,
            "self-harm" => false,
            "self-harm/intent" => false,
            "self-harm/instructions" => false,
            "sexual" => false,
            "sexual/minors" => false,
            "violence" => false,
            "violence/graphic" => false
          },
          "category_scores" => %{
            "hate" => 0.0001,
            "hate/threatening" => 0.0001,
            "harassment" => 0.0002,
            "harassment/threatening" => 0.0001,
            "self-harm" => 0.0001,
            "self-harm/intent" => 0.0001,
            "self-harm/instructions" => 0.0001,
            "sexual" => 0.0001,
            "sexual/minors" => 0.0001,
            "violence" => 0.0001,
            "violence/graphic" => 0.0001
          }
        }
      ]
    }
  end

  def moderation_response_multiple_fixture do
    %{
      "id" => "mod-123456789",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{
            "hate" => false,
            "harassment" => false,
            "violence" => false
          },
          "category_scores" => %{
            "hate" => 0.0001,
            "harassment" => 0.0002,
            "violence" => 0.0001
          }
        },
        %{
          "categories" => %{
            "hate" => false,
            "harassment" => false,
            "violence" => false
          },
          "category_scores" => %{
            "hate" => 0.0003,
            "harassment" => 0.0001,
            "violence" => 0.0002
          }
        },
        %{
          "categories" => %{
            "hate" => false,
            "harassment" => false,
            "violence" => false
          },
          "category_scores" => %{
            "hate" => 0.0002,
            "harassment" => 0.0003,
            "violence" => 0.0001
          }
        }
      ]
    }
  end

  def chat_moderation_request_fixture do
    %{
      "model" => "mistral-moderation-latest",
      "input" => [
        [
          %{"role" => "user", "content" => "Hello"},
          %{"role" => "assistant", "content" => "Hi there!"}
        ]
      ]
    }
  end

  def chat_moderation_response_fixture do
    %{
      "id" => "mod-chat-123456789",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{
            "hate" => false,
            "harassment" => false,
            "violence" => false,
            "sexual" => false
          },
          "category_scores" => %{
            "hate" => 0.0001,
            "harassment" => 0.0001,
            "violence" => 0.0001,
            "sexual" => 0.0001
          }
        }
      ]
    }
  end

  def classification_request_fixture do
    %{
      "model" => "mistral-classifier-latest",
      "input" => "This is some text to classify"
    }
  end

  def classification_request_list_fixture do
    %{
      "model" => "mistral-classifier-latest",
      "input" => ["Text 1", "Text 2", "Text 3"]
    }
  end

  def classification_response_fixture do
    %{
      "id" => "cls-123456789",
      "model" => "mistral-classifier-latest",
      "results" => [
        %{
          "category_1" => %{
            "scores" => %{
              "positive" => 0.8,
              "negative" => 0.2
            }
          }
        }
      ]
    }
  end

  def classification_response_multiple_fixture do
    %{
      "id" => "cls-123456789",
      "model" => "mistral-classifier-latest",
      "results" => [
        %{
          "sentiment" => %{
            "scores" => %{
              "positive" => 0.8,
              "negative" => 0.2
            }
          }
        },
        %{
          "sentiment" => %{
            "scores" => %{
              "positive" => 0.3,
              "negative" => 0.7
            }
          }
        },
        %{
          "sentiment" => %{
            "scores" => %{
              "positive" => 0.6,
              "negative" => 0.4
            }
          }
        }
      ]
    }
  end

  def chat_classification_request_fixture do
    %{
      "model" => "mistral-classifier-latest",
      "input" => [
        %{
          "messages" => [
            %{"role" => "user", "content" => "Hello"}
          ]
        }
      ]
    }
  end

  def chat_classification_response_fixture do
    %{
      "id" => "cls-chat-123456789",
      "model" => "mistral-classifier-latest",
      "results" => [
        %{
          "intent" => %{
            "scores" => %{
              "greeting" => 0.9,
              "question" => 0.1
            }
          }
        }
      ]
    }
  end

  # Error fixtures
  def validation_error_fixture do
    %{
      "detail" => [
        %{
          "loc" => ["body", "model"],
          "msg" => "field required",
          "type" => "value_error.missing"
        }
      ]
    }
  end

  def unauthorized_error_fixture do
    %{
      "message" => "Unauthorized",
      "request_id" => "req_123456789"
    }
  end

  def rate_limit_error_fixture do
    %{
      "message" => "Rate limit exceeded",
      "type" => "rate_limit_exceeded",
      "request_id" => "req_123456789"
    }
  end

  def server_error_fixture do
    %{
      "message" => "Internal server error",
      "type" => "server_error",
      "request_id" => "req_123456789"
    }
  end

  # Moderation with violations
  def moderation_violation_response_fixture do
    %{
      "id" => "mod-violation-123",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{
            "hate" => true,
            "hate/threatening" => false,
            "harassment" => false,
            "harassment/threatening" => false,
            "self-harm" => false,
            "self-harm/intent" => false,
            "self-harm/instructions" => false,
            "sexual" => false,
            "sexual/minors" => false,
            "violence" => false,
            "violence/graphic" => false
          },
          "category_scores" => %{
            "hate" => 0.8,
            "hate/threatening" => 0.1,
            "harassment" => 0.2,
            "harassment/threatening" => 0.1,
            "self-harm" => 0.1,
            "self-harm/intent" => 0.1,
            "self-harm/instructions" => 0.1,
            "sexual" => 0.1,
            "sexual/minors" => 0.1,
            "violence" => 0.2,
            "violence/graphic" => 0.1
          }
        }
      ]
    }
  end

  # Complex classification with multiple categories
  def complex_classification_response_fixture do
    %{
      "id" => "cls-complex-123",
      "model" => "mistral-classifier-latest",
      "results" => [
        %{
          "sentiment" => %{
            "scores" => %{
              "positive" => 0.7,
              "negative" => 0.2,
              "neutral" => 0.1
            }
          },
          "topic" => %{
            "scores" => %{
              "technology" => 0.8,
              "business" => 0.15,
              "science" => 0.05
            }
          },
          "urgency" => %{
            "scores" => %{
              "high" => 0.1,
              "medium" => 0.3,
              "low" => 0.6
            }
          }
        }
      ]
    }
  end
end
