defmodule ErrorFixtures do
  @moduledoc """
  Test fixtures for error responses from the Mistral API.

  These fixtures cover various error scenarios including authentication,
  rate limiting, validation errors, and server errors.
  """

  @doc """
  401 Unauthorized error response.
  """
  def unauthorized_error do
    %{
      "error" => %{
        "message" => "Unauthorized",
        "type" => "invalid_request_error",
        "param" => nil,
        "code" => "invalid_api_key"
      }
    }
  end

  @doc """
  422 Validation error response.
  """
  def validation_error do
    %{
      "error" => %{
        "message" => "Invalid request: missing required parameter 'model'",
        "type" => "invalid_request_error",
        "param" => "model",
        "code" => "missing_required_parameter"
      }
    }
  end

  @doc """
  422 Validation error for invalid model.
  """
  def invalid_model_error do
    %{
      "error" => %{
        "message" => "Invalid model: 'invalid-model' does not exist",
        "type" => "invalid_request_error",
        "param" => "model",
        "code" => "model_not_found"
      }
    }
  end

  @doc """
  429 Rate limit exceeded error response.
  """
  def rate_limit_error do
    %{
      "error" => %{
        "message" => "Rate limit exceeded. Please try again later.",
        "type" => "rate_limit_error",
        "param" => nil,
        "code" => "rate_limit_exceeded"
      }
    }
  end

  @doc """
  500 Internal server error response.
  """
  def internal_server_error do
    %{
      "error" => %{
        "message" => "Internal server error. Please try again later.",
        "type" => "server_error",
        "param" => nil,
        "code" => "internal_error"
      }
    }
  end

  @doc """
  503 Service unavailable error response.
  """
  def service_unavailable_error do
    %{
      "error" => %{
        "message" => "Service temporarily unavailable. Please try again later.",
        "type" => "server_error",
        "param" => nil,
        "code" => "service_unavailable"
      }
    }
  end

  @doc """
  400 Bad request error for malformed JSON.
  """
  def bad_request_error do
    %{
      "error" => %{
        "message" => "Invalid JSON in request body",
        "type" => "invalid_request_error",
        "param" => nil,
        "code" => "invalid_json"
      }
    }
  end

  @doc """
  422 Validation error for invalid temperature.
  """
  def invalid_temperature_error do
    %{
      "error" => %{
        "message" => "Invalid value for 'temperature': must be between 0 and 2",
        "type" => "invalid_request_error",
        "param" => "temperature",
        "code" => "invalid_parameter_value"
      }
    }
  end

  @doc """
  422 Validation error for invalid max_tokens.
  """
  def invalid_max_tokens_error do
    %{
      "error" => %{
        "message" => "Invalid value for 'max_tokens': must be a positive integer",
        "type" => "invalid_request_error",
        "param" => "max_tokens",
        "code" => "invalid_parameter_value"
      }
    }
  end

  @doc """
  422 Validation error for empty messages array.
  """
  def empty_messages_error do
    %{
      "error" => %{
        "message" => "Invalid request: 'messages' cannot be empty",
        "type" => "invalid_request_error",
        "param" => "messages",
        "code" => "invalid_parameter_value"
      }
    }
  end

  @doc """
  422 Validation error for invalid message role.
  """
  def invalid_message_role_error do
    %{
      "error" => %{
        "message" => "Invalid message role: must be 'system', 'user', or 'assistant'",
        "type" => "invalid_request_error",
        "param" => "messages[0].role",
        "code" => "invalid_parameter_value"
      }
    }
  end

  @doc """
  422 Validation error for missing message content.
  """
  def missing_message_content_error do
    %{
      "error" => %{
        "message" => "Invalid request: message content cannot be empty",
        "type" => "invalid_request_error",
        "param" => "messages[0].content",
        "code" => "missing_required_parameter"
      }
    }
  end

  @doc """
  422 Validation error for invalid tool definition.
  """
  def invalid_tool_error do
    %{
      "error" => %{
        "message" => "Invalid tool definition: missing required field 'function.name'",
        "type" => "invalid_request_error",
        "param" => "tools[0].function.name",
        "code" => "missing_required_parameter"
      }
    }
  end

  @doc """
  422 Validation error for invalid tool choice.
  """
  def invalid_tool_choice_error do
    %{
      "error" => %{
        "message" => "Invalid tool_choice: must be 'auto', 'none', or a specific tool",
        "type" => "invalid_request_error",
        "param" => "tool_choice",
        "code" => "invalid_parameter_value"
      }
    }
  end

  @doc """
  Network timeout error (not from API, but from client).
  """
  def timeout_error do
    %{
      "error" => %{
        "message" => "Request timeout",
        "type" => "timeout_error",
        "code" => "timeout"
      }
    }
  end

  @doc """
  Connection error (not from API, but from client).
  """
  def connection_error do
    %{
      "error" => %{
        "message" => "Connection failed",
        "type" => "connection_error",
        "code" => "connection_failed"
      }
    }
  end

  @doc """
  Generic error response structure.
  """
  def generic_error(message, type \\ "api_error", code \\ "unknown_error", param \\ nil) do
    %{
      "error" => %{
        "message" => message,
        "type" => type,
        "param" => param,
        "code" => code
      }
    }
  end

  @doc """
  Returns a list of all common HTTP error codes and their corresponding fixtures.
  """
  def all_error_scenarios do
    [
      {400, bad_request_error()},
      {401, unauthorized_error()},
      {422, validation_error()},
      {422, invalid_model_error()},
      {422, invalid_temperature_error()},
      {422, invalid_max_tokens_error()},
      {422, empty_messages_error()},
      {422, invalid_message_role_error()},
      {422, missing_message_content_error()},
      {422, invalid_tool_error()},
      {422, invalid_tool_choice_error()},
      {429, rate_limit_error()},
      {500, internal_server_error()},
      {503, service_unavailable_error()}
    ]
  end
end
