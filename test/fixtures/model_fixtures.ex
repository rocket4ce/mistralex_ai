defmodule MistralClient.Test.ModelFixtures do
  @moduledoc """
  Test fixtures for Models API responses.
  """

  def model_list_response do
    %{
      "object" => "list",
      "data" => [
        base_model_response(),
        fine_tuned_model_response()
      ]
    }
  end

  def base_model_response do
    %{
      "id" => "mistral-large-latest",
      "object" => "model",
      "created" => 1_640_995_200,
      "owned_by" => "mistralai",
      "name" => "Mistral Large",
      "description" =>
        "Our flagship model, ideal for complex tasks that require large reasoning capabilities or are highly specialized",
      "max_context_length" => 128_000,
      "aliases" => ["mistral-large-2407"],
      "deprecation" => nil,
      "default_model_temperature" => 0.7,
      "type" => "base",
      "capabilities" => %{
        "completion_chat" => true,
        "completion_fim" => false,
        "function_calling" => true,
        "fine_tuning" => false,
        "vision" => true
      }
    }
  end

  def fine_tuned_model_response do
    %{
      "id" => "ft:open-mistral-7b:587a6b29:20240514:7e773925",
      "object" => "model",
      "created" => 1_715_676_800,
      "owned_by" => "user-123",
      "name" => "My Custom Model",
      "description" => "A fine-tuned model for specific use case",
      "max_context_length" => 32_768,
      "aliases" => [],
      "deprecation" => nil,
      "default_model_temperature" => 0.7,
      "type" => "fine-tuned",
      "job" => "ftjob-abc123",
      "root" => "open-mistral-7b",
      "archived" => false,
      "capabilities" => %{
        "completion_chat" => true,
        "completion_fim" => false,
        "function_calling" => false,
        "fine_tuning" => false,
        "vision" => false
      }
    }
  end

  def delete_model_response do
    %{
      "id" => "ft:open-mistral-7b:587a6b29:20240514:7e773925",
      "object" => "model",
      "deleted" => true
    }
  end

  def archive_model_response do
    %{
      "id" => "ft:open-mistral-7b:587a6b29:20240514:7e773925",
      "object" => "model",
      "archived" => true
    }
  end

  def unarchive_model_response do
    %{
      "id" => "ft:open-mistral-7b:587a6b29:20240514:7e773925",
      "object" => "model",
      "archived" => false
    }
  end

  def update_model_request do
    %{
      "name" => "Updated Model Name",
      "description" => "Updated description for the model"
    }
  end

  def updated_model_response do
    fine_tuned_model_response()
    |> Map.put("name", "Updated Model Name")
    |> Map.put("description", "Updated description for the model")
  end

  # Error responses
  def model_not_found_error do
    %{
      "error" => %{
        "message" => "Model not found",
        "type" => "not_found_error",
        "code" => "model_not_found"
      }
    }
  end

  def validation_error_response do
    %{
      "error" => %{
        "message" => "Invalid model ID",
        "type" => "validation_error",
        "code" => "invalid_request"
      }
    }
  end

  def unauthorized_error_response do
    %{
      "error" => %{
        "message" => "Invalid API key",
        "type" => "authentication_error",
        "code" => "invalid_api_key"
      }
    }
  end

  def permission_denied_error do
    %{
      "error" => %{
        "message" => "You don't have permission to delete this model",
        "type" => "permission_error",
        "code" => "insufficient_permissions"
      }
    }
  end

  def rate_limit_error_response do
    %{
      "error" => %{
        "message" => "Rate limit exceeded",
        "type" => "rate_limit_error",
        "code" => "rate_limit_exceeded"
      }
    }
  end

  def server_error_response do
    %{
      "error" => %{
        "message" => "Internal server error",
        "type" => "server_error",
        "code" => "internal_error"
      }
    }
  end

  # Mock HTTP responses
  def mock_list_success do
    {:ok, %{status: 200, body: Jason.encode!(model_list_response())}}
  end

  def mock_retrieve_base_model_success do
    {:ok, %{status: 200, body: Jason.encode!(base_model_response())}}
  end

  def mock_retrieve_ft_model_success do
    {:ok, %{status: 200, body: Jason.encode!(fine_tuned_model_response())}}
  end

  def mock_delete_success do
    {:ok, %{status: 200, body: Jason.encode!(delete_model_response())}}
  end

  def mock_update_success do
    {:ok, %{status: 200, body: Jason.encode!(updated_model_response())}}
  end

  def mock_archive_success do
    {:ok, %{status: 200, body: Jason.encode!(archive_model_response())}}
  end

  def mock_unarchive_success do
    {:ok, %{status: 200, body: Jason.encode!(unarchive_model_response())}}
  end

  def mock_not_found_error do
    {:ok, %{status: 404, body: Jason.encode!(model_not_found_error())}}
  end

  def mock_validation_error do
    {:ok, %{status: 422, body: Jason.encode!(validation_error_response())}}
  end

  def mock_unauthorized_error do
    {:ok, %{status: 401, body: Jason.encode!(unauthorized_error_response())}}
  end

  def mock_permission_denied_error do
    {:ok, %{status: 403, body: Jason.encode!(permission_denied_error())}}
  end

  def mock_rate_limit_error do
    {:ok, %{status: 429, body: Jason.encode!(rate_limit_error_response())}}
  end

  def mock_server_error do
    {:ok, %{status: 500, body: Jason.encode!(server_error_response())}}
  end

  # Helper functions for creating test data
  def create_base_model_card do
    MistralClient.Models.BaseModelCard.from_map(base_model_response())
  end

  def create_ft_model_card do
    MistralClient.Models.FTModelCard.from_map(fine_tuned_model_response())
  end

  def create_model_list do
    MistralClient.Models.ModelList.from_map(model_list_response())
  end

  def create_delete_result do
    MistralClient.Models.DeleteModelOut.from_map(delete_model_response())
  end

  def create_archive_result do
    MistralClient.Models.ArchiveFTModelOut.from_map(archive_model_response())
  end

  def create_unarchive_result do
    MistralClient.Models.UnarchiveFTModelOut.from_map(unarchive_model_response())
  end
end
