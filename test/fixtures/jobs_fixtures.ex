defmodule MistralClient.Test.Fixtures.JobsFixtures do
  @moduledoc """
  Test fixtures for Jobs API responses.
  """

  def jobs_list_response do
    %{
      "total" => 2,
      "data" => [
        job_response(),
        %{
          "id" => "ft-job-456",
          "auto_start" => false,
          "model" => "open-mistral-7b",
          "status" => "QUEUED",
          "created_at" => 1_704_067_200,
          "modified_at" => 1_704_067_200,
          "training_files" => [%{"file_id" => "file-456"}],
          "validation_files" => [],
          "object" => "job",
          "fine_tuned_model" => nil,
          "suffix" => "test-model-2",
          "integrations" => [],
          "trained_tokens" => nil,
          "metadata" => %{},
          "job_type" => "completion",
          "repositories" => [],
          "events" => [],
          "checkpoints" => [],
          "hyperparameters" => %{
            "learning_rate" => 0.0001,
            "training_steps" => 500
          }
        }
      ],
      "has_more" => false,
      "object" => "list"
    }
  end

  def job_response do
    %{
      "id" => "ft-job-123",
      "auto_start" => true,
      "model" => "open-mistral-7b",
      "status" => "RUNNING",
      "created_at" => 1_704_067_200,
      "modified_at" => 1_704_070_800,
      "training_files" => [%{"file_id" => "file-123"}],
      "validation_files" => ["file-456"],
      "object" => "job",
      "fine_tuned_model" => "ft:open-mistral-7b:test-model:xxx",
      "suffix" => "test-model",
      "integrations" => [
        %{
          "type" => "wandb",
          "project" => "my-project",
          "name" => "my-run",
          "api_key" => "wandb-key"
        }
      ],
      "trained_tokens" => 1000,
      "metadata" => %{"custom_field" => "value"},
      "job_type" => "completion",
      "repositories" => [
        %{
          "type" => "github",
          "name" => "my-repo",
          "owner" => "my-org",
          "ref" => "main",
          "weight" => 1.0,
          "commit_id" => "abc123"
        }
      ],
      "events" => [
        %{
          "name" => "job.started",
          "created_at" => 1_704_067_200,
          "data" => %{}
        }
      ],
      "checkpoints" => [
        %{
          "step" => 100,
          "metrics" => %{"loss" => 0.5}
        }
      ],
      "hyperparameters" => %{
        "learning_rate" => 0.0001,
        "training_steps" => 1000,
        "weight_decay" => 0.01,
        "warmup_fraction" => 0.1,
        "epochs" => 3,
        "seq_len" => 2048,
        "fim_ratio" => 0.9
      }
    }
  end

  def job_created_response do
    %{
      "id" => "ft-job-789",
      "auto_start" => false,
      "model" => "open-mistral-7b",
      "status" => "QUEUED",
      "created_at" => 1_704_067_200,
      "modified_at" => 1_704_067_200,
      "training_files" => [%{"file_id" => "file-789"}],
      "validation_files" => [],
      "object" => "job",
      "fine_tuned_model" => nil,
      "suffix" => "new-model",
      "integrations" => [],
      "trained_tokens" => nil,
      "metadata" => %{},
      "job_type" => "completion",
      "repositories" => [],
      "events" => [],
      "checkpoints" => [],
      "hyperparameters" => %{
        "learning_rate" => 0.0001,
        "training_steps" => 1000
      }
    }
  end

  def job_started_response do
    job_response()
    |> Map.put("status", "STARTED")
    |> Map.put("modified_at", 1_704_070_900)
  end

  def job_cancelled_response do
    job_response()
    |> Map.put("status", "CANCELLED")
    |> Map.put("modified_at", 1_704_070_900)
  end

  def job_request do
    %{
      "model" => "open-mistral-7b",
      "hyperparameters" => %{
        "learning_rate" => 0.0001,
        "training_steps" => 1000
      },
      "training_files" => [%{"file_id" => "file-123"}],
      "suffix" => "test-model",
      "auto_start" => true
    }
  end

  def error_response(status \\ 400, message \\ "Bad Request") do
    %{
      "error" => %{
        "message" => message,
        "type" => "invalid_request_error",
        "code" => status
      }
    }
  end

  def unauthorized_error do
    error_response(401, "Invalid API key")
  end

  def not_found_error do
    error_response(404, "Job not found")
  end

  def validation_error do
    error_response(422, "Validation failed: model is required")
  end

  def rate_limit_error do
    error_response(429, "Rate limit exceeded")
  end

  def server_error do
    error_response(500, "Internal server error")
  end
end
