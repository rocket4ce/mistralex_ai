defmodule MistralClient.Test.Fixtures.FineTuningFixtures do
  @moduledoc """
  Test fixtures for Fine-tuning API responses.
  """

  def create_job_success_response do
    %{
      "id" => "ftjob-123456789",
      "auto_start" => true,
      "model" => "open-mistral-7b",
      "status" => "QUEUED",
      "created_at" => 1_704_067_200,
      "modified_at" => 1_704_067_200,
      "training_files" => ["file-abc123"],
      "validation_files" => ["file-def456"],
      "object" => "job",
      "fine_tuned_model" => nil,
      "suffix" => "my-model",
      "integrations" => [
        %{
          "type" => "wandb",
          "project" => "my-project",
          "name" => "my-run",
          "api_key" => "wandb-key-123"
        }
      ],
      "trained_tokens" => nil,
      "metadata" => %{
        "expected_duration_seconds" => 3600
      },
      "job_type" => "completion",
      "repositories" => [
        %{
          "type" => "github",
          "name" => "my-repo",
          "owner" => "my-org",
          "ref" => "main",
          "weight" => 1.0,
          "commit_id" => "abc123def456"
        }
      ],
      "events" => [],
      "checkpoints" => [],
      "hyperparameters" => %{
        "training_steps" => 1000,
        "learning_rate" => 0.0001,
        "weight_decay" => 0.01,
        "warmup_fraction" => 0.1,
        "epochs" => 3.0,
        "seq_len" => 2048,
        "fim_ratio" => 0.9
      }
    }
  end

  def get_job_success_response do
    %{
      "id" => "ftjob-123456789",
      "auto_start" => true,
      "model" => "open-mistral-7b",
      "status" => "RUNNING",
      "created_at" => 1_704_067_200,
      "modified_at" => 1_704_067_260,
      "training_files" => ["file-abc123"],
      "validation_files" => ["file-def456"],
      "object" => "job",
      "fine_tuned_model" => nil,
      "suffix" => "my-model",
      "integrations" => [
        %{
          "type" => "wandb",
          "project" => "my-project",
          "name" => "my-run",
          "api_key" => "wandb-key-123"
        }
      ],
      "trained_tokens" => 50_000,
      "metadata" => %{
        "expected_duration_seconds" => 3600
      },
      "job_type" => "completion",
      "repositories" => [
        %{
          "type" => "github",
          "name" => "my-repo",
          "owner" => "my-org",
          "ref" => "main",
          "weight" => 1.0,
          "commit_id" => "abc123def456"
        }
      ],
      "events" => [
        %{
          "name" => "job.queued",
          "created_at" => 1_704_067_200,
          "data" => %{}
        },
        %{
          "name" => "job.started",
          "created_at" => 1_704_067_260,
          "data" => %{}
        }
      ],
      "checkpoints" => [
        %{
          "step" => 100,
          "metrics" => %{
            "train_loss" => 2.5,
            "valid_loss" => 2.7
          },
          "created_at" => 1_704_067_320
        }
      ],
      "hyperparameters" => %{
        "training_steps" => 1000,
        "learning_rate" => 0.0001,
        "weight_decay" => 0.01,
        "warmup_fraction" => 0.1,
        "epochs" => 3.0,
        "seq_len" => 2048,
        "fim_ratio" => 0.9
      }
    }
  end

  def completed_job_response do
    %{
      "id" => "ftjob-123456789",
      "auto_start" => true,
      "model" => "open-mistral-7b",
      "status" => "SUCCESS",
      "created_at" => 1_704_067_200,
      "modified_at" => 1_704_070_800,
      "training_files" => ["file-abc123"],
      "validation_files" => ["file-def456"],
      "object" => "job",
      "fine_tuned_model" => "ft:open-mistral-7b:my-model:abc123",
      "suffix" => "my-model",
      "integrations" => [
        %{
          "type" => "wandb",
          "project" => "my-project",
          "name" => "my-run",
          "api_key" => "wandb-key-123"
        }
      ],
      "trained_tokens" => 100_000,
      "metadata" => %{
        "expected_duration_seconds" => 3600
      },
      "job_type" => "completion",
      "repositories" => [
        %{
          "type" => "github",
          "name" => "my-repo",
          "owner" => "my-org",
          "ref" => "main",
          "weight" => 1.0,
          "commit_id" => "abc123def456"
        }
      ],
      "events" => [
        %{
          "name" => "job.queued",
          "created_at" => 1_704_067_200,
          "data" => %{}
        },
        %{
          "name" => "job.started",
          "created_at" => 1_704_067_260,
          "data" => %{}
        },
        %{
          "name" => "job.succeeded",
          "created_at" => 1_704_070_800,
          "data" => %{
            "fine_tuned_model" => "ft:open-mistral-7b:my-model:abc123"
          }
        }
      ],
      "checkpoints" => [
        %{
          "step" => 100,
          "metrics" => %{
            "train_loss" => 2.5,
            "valid_loss" => 2.7
          },
          "created_at" => 1_704_067_320
        },
        %{
          "step" => 500,
          "metrics" => %{
            "train_loss" => 1.8,
            "valid_loss" => 2.1
          },
          "created_at" => 1_704_069_000
        },
        %{
          "step" => 1000,
          "metrics" => %{
            "train_loss" => 1.2,
            "valid_loss" => 1.8
          },
          "created_at" => 1_704_070_800
        }
      ],
      "hyperparameters" => %{
        "training_steps" => 1000,
        "learning_rate" => 0.0001,
        "weight_decay" => 0.01,
        "warmup_fraction" => 0.1,
        "epochs" => 3.0,
        "seq_len" => 2048,
        "fim_ratio" => 0.9
      }
    }
  end

  def list_jobs_success_response do
    %{
      "total" => 3,
      "data" => [
        get_job_success_response(),
        completed_job_response(),
        %{
          "id" => "ftjob-987654321",
          "auto_start" => false,
          "model" => "open-mistral-7b",
          "status" => "CANCELLED",
          "created_at" => 1_704_060_000,
          "modified_at" => 1_704_061_000,
          "training_files" => ["file-xyz789"],
          "validation_files" => nil,
          "object" => "job",
          "fine_tuned_model" => nil,
          "suffix" => "cancelled-model",
          "integrations" => nil,
          "trained_tokens" => 10_000,
          "metadata" => nil,
          "job_type" => "completion",
          "repositories" => nil,
          "events" => [
            %{
              "name" => "job.queued",
              "created_at" => 1_704_060_000,
              "data" => %{}
            },
            %{
              "name" => "job.cancelled",
              "created_at" => 1_704_061_000,
              "data" => %{}
            }
          ],
          "checkpoints" => [],
          "hyperparameters" => %{
            "training_steps" => 500,
            "learning_rate" => 0.0002
          }
        }
      ],
      "has_more" => false,
      "object" => "list"
    }
  end

  def start_job_success_response do
    Map.put(get_job_success_response(), "status", "STARTED")
  end

  def cancel_job_success_response do
    Map.put(get_job_success_response(), "status", "CANCELLATION_REQUESTED")
  end

  def archive_model_success_response do
    %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "archived" => true
    }
  end

  def unarchive_model_success_response do
    %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "archived" => false
    }
  end

  def update_model_success_response do
    %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "name" => "Updated Model Name",
      "description" => "Updated description"
    }
  end

  # Error responses
  def job_not_found_error do
    %{
      "error" => %{
        "message" => "Job not found",
        "type" => "not_found",
        "code" => "job_not_found"
      }
    }
  end

  def model_not_found_error do
    %{
      "error" => %{
        "message" => "Model not found",
        "type" => "not_found",
        "code" => "model_not_found"
      }
    }
  end

  def invalid_request_error do
    %{
      "error" => %{
        "message" => "Invalid request parameters",
        "type" => "invalid_request_error",
        "code" => "invalid_parameters"
      }
    }
  end

  def unauthorized_error do
    %{
      "error" => %{
        "message" => "Unauthorized",
        "type" => "authentication_error",
        "code" => "unauthorized"
      }
    }
  end

  def rate_limit_error do
    %{
      "error" => %{
        "message" => "Rate limit exceeded",
        "type" => "rate_limit_error",
        "code" => "rate_limit_exceeded"
      }
    }
  end

  def server_error do
    %{
      "error" => %{
        "message" => "Internal server error",
        "type" => "server_error",
        "code" => "internal_error"
      }
    }
  end

  # Request helpers
  def create_job_request do
    %{
      "model" => "open-mistral-7b",
      "hyperparameters" => %{
        "training_steps" => 1000,
        "learning_rate" => 0.0001,
        "weight_decay" => 0.01,
        "warmup_fraction" => 0.1,
        "epochs" => 3.0,
        "seq_len" => 2048,
        "fim_ratio" => 0.9
      },
      "training_files" => [
        %{
          "file_id" => "file-abc123",
          "weight" => 1.0
        }
      ],
      "validation_files" => ["file-def456"],
      "suffix" => "my-model",
      "integrations" => [
        %{
          "type" => "wandb",
          "project" => "my-project",
          "name" => "my-run",
          "api_key" => "wandb-key-123"
        }
      ],
      "auto_start" => true,
      "invalid_sample_skip_percentage" => 0.0,
      "job_type" => "completion",
      "repositories" => [
        %{
          "type" => "github",
          "name" => "my-repo",
          "owner" => "my-org",
          "ref" => "main",
          "weight" => 1.0,
          "commit_id" => "abc123def456"
        }
      ]
    }
  end

  def minimal_create_job_request do
    %{
      "model" => "open-mistral-7b",
      "hyperparameters" => %{
        "learning_rate" => 0.0001
      }
    }
  end
end
