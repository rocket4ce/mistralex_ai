defmodule MistralClient.Test.BatchFixtures do
  @moduledoc """
  Test fixtures for Batch API responses.
  """

  def batch_job_create_request do
    %{
      "input_files" => ["file-abc123", "file-def456"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "metadata" => %{"project" => "customer-support"},
      "timeout_hours" => 24
    }
  end

  def batch_job_response do
    %{
      "id" => "batch_abc123",
      "input_files" => ["file-abc123", "file-def456"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "QUEUED",
      "created_at" => 1_640_995_200,
      "total_requests" => 100,
      "completed_requests" => 0,
      "succeeded_requests" => 0,
      "failed_requests" => 0,
      "object" => "batch",
      "metadata" => %{"project" => "customer-support"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => nil,
      "completed_at" => nil
    }
  end

  def batch_job_running_response do
    %{
      "id" => "batch_abc123",
      "input_files" => ["file-abc123", "file-def456"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "RUNNING",
      "created_at" => 1_640_995_200,
      "total_requests" => 100,
      "completed_requests" => 45,
      "succeeded_requests" => 42,
      "failed_requests" => 3,
      "object" => "batch",
      "metadata" => %{"project" => "customer-support"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => 1_640_995_260,
      "completed_at" => nil
    }
  end

  def batch_job_completed_response do
    %{
      "id" => "batch_abc123",
      "input_files" => ["file-abc123", "file-def456"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "SUCCESS",
      "created_at" => 1_640_995_200,
      "total_requests" => 100,
      "completed_requests" => 100,
      "succeeded_requests" => 97,
      "failed_requests" => 3,
      "object" => "batch",
      "metadata" => %{"project" => "customer-support"},
      "output_file" => "file-output123",
      "error_file" => "file-errors123",
      "started_at" => 1_640_995_260,
      "completed_at" => 1_640_998_800
    }
  end

  def batch_job_failed_response do
    %{
      "id" => "batch_abc123",
      "input_files" => ["file-abc123", "file-def456"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [
        %{"message" => "Invalid input format in file file-abc123"}
      ],
      "status" => "FAILED",
      "created_at" => 1_640_995_200,
      "total_requests" => 100,
      "completed_requests" => 25,
      "succeeded_requests" => 0,
      "failed_requests" => 25,
      "object" => "batch",
      "metadata" => %{"project" => "customer-support"},
      "output_file" => nil,
      "error_file" => "file-errors123",
      "started_at" => 1_640_995_260,
      "completed_at" => 1_640_996_200
    }
  end

  def batch_job_cancelled_response do
    %{
      "id" => "batch_abc123",
      "input_files" => ["file-abc123", "file-def456"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "CANCELLED",
      "created_at" => 1_640_995_200,
      "total_requests" => 100,
      "completed_requests" => 30,
      "succeeded_requests" => 28,
      "failed_requests" => 2,
      "object" => "batch",
      "metadata" => %{"project" => "customer-support"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => 1_640_995_260,
      "completed_at" => 1_640_996_800
    }
  end

  def batch_jobs_list_response do
    %{
      "total" => 3,
      "data" => [
        batch_job_response(),
        batch_job_running_response(),
        batch_job_completed_response()
      ],
      "object" => "list"
    }
  end

  def batch_jobs_empty_list_response do
    %{
      "total" => 0,
      "data" => [],
      "object" => "list"
    }
  end

  def batch_jobs_filtered_list_response do
    %{
      "total" => 1,
      "data" => [
        batch_job_running_response()
      ],
      "object" => "list"
    }
  end

  # Error responses
  def batch_job_not_found_error do
    %{
      "error" => %{
        "message" => "Batch job not found",
        "type" => "not_found_error",
        "code" => "batch_job_not_found"
      }
    }
  end

  def batch_job_validation_error do
    %{
      "error" => %{
        "message" => "Missing required field: input_files",
        "type" => "validation_error",
        "code" => "invalid_request"
      }
    }
  end

  def batch_job_invalid_endpoint_error do
    %{
      "error" => %{
        "message" => "Invalid endpoint: /v1/invalid/endpoint",
        "type" => "validation_error",
        "code" => "invalid_endpoint"
      }
    }
  end

  def batch_job_file_not_found_error do
    %{
      "error" => %{
        "message" => "Input file not found: file-nonexistent",
        "type" => "not_found_error",
        "code" => "file_not_found"
      }
    }
  end

  def batch_job_unauthorized_error do
    %{
      "error" => %{
        "message" => "Invalid API key",
        "type" => "authentication_error",
        "code" => "invalid_api_key"
      }
    }
  end

  def batch_job_rate_limit_error do
    %{
      "error" => %{
        "message" => "Rate limit exceeded",
        "type" => "rate_limit_error",
        "code" => "rate_limit_exceeded"
      }
    }
  end

  def batch_job_server_error do
    %{
      "error" => %{
        "message" => "Internal server error",
        "type" => "server_error",
        "code" => "internal_error"
      }
    }
  end

  # Different endpoint examples
  def batch_job_embeddings_request do
    %{
      "input_files" => ["file-embeddings123"],
      "endpoint" => "/v1/embeddings",
      "model" => "mistral-embed",
      "metadata" => %{"type" => "embeddings"},
      "timeout_hours" => 12
    }
  end

  def batch_job_embeddings_response do
    %{
      "id" => "batch_embed123",
      "input_files" => ["file-embeddings123"],
      "endpoint" => "/v1/embeddings",
      "model" => "mistral-embed",
      "errors" => [],
      "status" => "SUCCESS",
      "created_at" => 1_640_995_200,
      "total_requests" => 50,
      "completed_requests" => 50,
      "succeeded_requests" => 50,
      "failed_requests" => 0,
      "object" => "batch",
      "metadata" => %{"type" => "embeddings"},
      "output_file" => "file-embed-output123",
      "error_file" => nil,
      "started_at" => 1_640_995_260,
      "completed_at" => 1_640_996_200
    }
  end

  def batch_job_fim_request do
    %{
      "input_files" => ["file-code123"],
      "endpoint" => "/v1/fim/completions",
      "model" => "codestral-latest",
      "metadata" => %{"type" => "code-completion"},
      "timeout_hours" => 6
    }
  end

  def batch_job_fim_response do
    %{
      "id" => "batch_fim123",
      "input_files" => ["file-code123"],
      "endpoint" => "/v1/fim/completions",
      "model" => "codestral-latest",
      "errors" => [],
      "status" => "SUCCESS",
      "created_at" => 1_640_995_200,
      "total_requests" => 25,
      "completed_requests" => 25,
      "succeeded_requests" => 24,
      "failed_requests" => 1,
      "object" => "batch",
      "metadata" => %{"type" => "code-completion"},
      "output_file" => "file-fim-output123",
      "error_file" => "file-fim-errors123",
      "started_at" => 1_640_995_260,
      "completed_at" => 1_640_995_800
    }
  end

  # Progress tracking examples
  def batch_job_progress_0_percent do
    %{
      "id" => "batch_progress123",
      "input_files" => ["file-large123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "QUEUED",
      "created_at" => 1_640_995_200,
      "total_requests" => 1000,
      "completed_requests" => 0,
      "succeeded_requests" => 0,
      "failed_requests" => 0,
      "object" => "batch",
      "metadata" => %{"size" => "large"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => nil,
      "completed_at" => nil
    }
  end

  def batch_job_progress_25_percent do
    %{
      "id" => "batch_progress123",
      "input_files" => ["file-large123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "RUNNING",
      "created_at" => 1_640_995_200,
      "total_requests" => 1000,
      "completed_requests" => 250,
      "succeeded_requests" => 245,
      "failed_requests" => 5,
      "object" => "batch",
      "metadata" => %{"size" => "large"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => 1_640_995_260,
      "completed_at" => nil
    }
  end

  def batch_job_progress_75_percent do
    %{
      "id" => "batch_progress123",
      "input_files" => ["file-large123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "RUNNING",
      "created_at" => 1_640_995_200,
      "total_requests" => 1000,
      "completed_requests" => 750,
      "succeeded_requests" => 735,
      "failed_requests" => 15,
      "object" => "batch",
      "metadata" => %{"size" => "large"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => 1_640_995_260,
      "completed_at" => nil
    }
  end

  def batch_job_progress_100_percent do
    %{
      "id" => "batch_progress123",
      "input_files" => ["file-large123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "SUCCESS",
      "created_at" => 1_640_995_200,
      "total_requests" => 1000,
      "completed_requests" => 1000,
      "succeeded_requests" => 980,
      "failed_requests" => 20,
      "object" => "batch",
      "metadata" => %{"size" => "large"},
      "output_file" => "file-large-output123",
      "error_file" => "file-large-errors123",
      "started_at" => 1_640_995_260,
      "completed_at" => 1_641_001_200
    }
  end

  # Timeout scenarios
  def batch_job_timeout_exceeded_response do
    %{
      "id" => "batch_timeout123",
      "input_files" => ["file-slow123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [
        %{"message" => "Batch job exceeded timeout limit of 24 hours"}
      ],
      "status" => "TIMEOUT_EXCEEDED",
      "created_at" => 1_640_995_200,
      "total_requests" => 500,
      "completed_requests" => 300,
      "succeeded_requests" => 295,
      "failed_requests" => 5,
      "object" => "batch",
      "metadata" => %{"timeout_hours" => 24},
      "output_file" => "file-partial-output123",
      "error_file" => "file-timeout-errors123",
      "started_at" => 1_640_995_260,
      "completed_at" => 1_641_081_660
    }
  end

  # Cancellation scenarios
  def batch_job_cancellation_requested_response do
    %{
      "id" => "batch_cancel123",
      "input_files" => ["file-cancel123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-large-latest",
      "errors" => [],
      "status" => "CANCELLATION_REQUESTED",
      "created_at" => 1_640_995_200,
      "total_requests" => 200,
      "completed_requests" => 80,
      "succeeded_requests" => 78,
      "failed_requests" => 2,
      "object" => "batch",
      "metadata" => %{"cancel_reason" => "user_requested"},
      "output_file" => nil,
      "error_file" => nil,
      "started_at" => 1_640_995_260,
      "completed_at" => nil
    }
  end
end
