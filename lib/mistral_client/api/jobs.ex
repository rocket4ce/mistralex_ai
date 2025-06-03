defmodule MistralClient.API.Jobs do
  @moduledoc """
  Jobs API for managing fine-tuning jobs.

  This module provides a dedicated interface for fine-tuning job operations,
  maintaining API parity with the Python SDK's `mistral.fine_tuning.jobs` interface.

  ## Examples

      # List fine-tuning jobs
      {:ok, jobs} = MistralClient.API.Jobs.list()

      # Create a fine-tuning job
      request = %MistralClient.Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: %MistralClient.Models.CompletionTrainingParameters{
          learning_rate: 0.0001
        }
      }
      {:ok, job} = MistralClient.API.Jobs.create(request)

      # Get job details
      {:ok, job} = MistralClient.API.Jobs.get("job-123")

      # Start a job
      {:ok, job} = MistralClient.API.Jobs.start("job-123")

      # Cancel a job
      {:ok, job} = MistralClient.API.Jobs.cancel("job-123")
  """

  alias MistralClient.{Config}
  alias MistralClient.API.FineTuning
  alias MistralClient.Models.{FineTuningJobRequest, FineTuningJobResponse, FineTuningJobsResponse}

  @type job_status ::
          :queued
          | :started
          | :validating
          | :validated
          | :running
          | :failed_validation
          | :failed
          | :success
          | :cancelled
          | :cancellation_requested

  @type list_options :: %{
          page: integer() | nil,
          page_size: integer() | nil,
          model: String.t() | nil,
          created_after: Date.t() | nil,
          created_before: Date.t() | nil,
          created_by_me: boolean() | nil,
          status: job_status() | nil,
          wandb_project: String.t() | nil,
          wandb_name: String.t() | nil,
          suffix: String.t() | nil
        }

  @doc """
  Get a list of fine-tuning jobs for your organization and user.

  ## Parameters

  - `config` - Client configuration (optional, uses default if not provided)
  - `options` - Filtering and pagination options

  ## Options

  - `page` - The page number of the results to be returned
  - `page_size` - The number of items to return per page
  - `model` - The model name used for fine-tuning to filter on
  - `created_after` - Filter jobs created after this date
  - `created_before` - Filter jobs created before this date
  - `created_by_me` - When true, only return results for jobs created by the API caller
  - `status` - The current job state to filter on
  - `wandb_project` - The Weights and Biases project to filter on
  - `wandb_name` - The Weight and Biases run name to filter on
  - `suffix` - The model suffix to filter on

  ## Examples

      # List all jobs
      {:ok, jobs} = MistralClient.API.Jobs.list()

      # List with filtering
      {:ok, jobs} = MistralClient.API.Jobs.list(%{
        status: :running,
        model: "open-mistral-7b",
        page_size: 10
      })

      # With custom config
      config = MistralClient.Config.new(api_key: "custom-key")
      {:ok, jobs} = MistralClient.API.Jobs.list(config, %{created_by_me: true})
  """
  @spec list() :: {:ok, FineTuningJobsResponse.t()} | {:error, term()}
  @spec list(Config.t() | map()) :: {:ok, FineTuningJobsResponse.t()} | {:error, term()}
  @spec list(Config.t(), map()) :: {:ok, FineTuningJobsResponse.t()} | {:error, term()}
  def list(config_or_options \\ %{}, options \\ %{})

  def list(%Config{} = config, options) when is_map(options) do
    FineTuning.list_jobs(config, options)
  end

  def list(options, _) when is_map(options) do
    config = Config.new()
    FineTuning.list_jobs(config, options)
  end

  @doc """
  Create a new fine-tuning job, it will be queued for processing.

  ## Parameters

  - `config` - Client configuration (optional, uses default if not provided)
  - `request` - Fine-tuning job request parameters

  ## Request Parameters

  - `model` (required) - The name of the model to fine-tune
  - `hyperparameters` (required) - Training hyperparameters
  - `training_files` - List of training file IDs
  - `validation_files` - List of validation file IDs
  - `suffix` - String to add to fine-tuned model name
  - `integrations` - List of integrations (e.g., Weights & Biases)
  - `auto_start` - Whether to automatically start the job
  - `invalid_sample_skip_percentage` - Percentage of invalid samples to skip
  - `job_type` - Type of fine-tuning job
  - `repositories` - List of GitHub repositories
  - `classifier_targets` - Classifier targets (for classifier jobs)

  ## Examples

      request = %MistralClient.Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: %MistralClient.Models.CompletionTrainingParameters{
          learning_rate: 0.0001,
          training_steps: 1000
        }
      }

      {:ok, job} = MistralClient.API.Jobs.create(request)

      # With custom config
      config = MistralClient.Config.new(api_key: "custom-key")
      {:ok, job} = MistralClient.API.Jobs.create(config, request)
  """
  @spec create(FineTuningJobRequest.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  @spec create(Config.t(), FineTuningJobRequest.t()) ::
          {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def create(%FineTuningJobRequest{} = request) do
    config = Config.new()
    FineTuning.create_job(config, request)
  end

  def create(%Config{} = config, %FineTuningJobRequest{} = request) do
    FineTuning.create_job(config, request)
  end

  @doc """
  Get a fine-tuned job details by its UUID.

  ## Parameters

  - `config` - Client configuration (optional, uses default if not provided)
  - `job_id` - The ID of the job to retrieve

  ## Examples

      {:ok, job} = MistralClient.API.Jobs.get("job-123")

      # With custom config
      config = MistralClient.Config.new(api_key: "custom-key")
      {:ok, job} = MistralClient.API.Jobs.get(config, "job-123")
  """
  @spec get(String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  @spec get(Config.t(), String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def get(job_id) when is_binary(job_id) do
    config = Config.new()
    FineTuning.get_job(config, job_id)
  end

  def get(%Config{} = config, job_id) when is_binary(job_id) do
    FineTuning.get_job(config, job_id)
  end

  @doc """
  Request the cancellation of a fine tuning job.

  ## Parameters

  - `config` - Client configuration (optional, uses default if not provided)
  - `job_id` - The ID of the job to cancel

  ## Examples

      {:ok, job} = MistralClient.API.Jobs.cancel("job-123")

      # With custom config
      config = MistralClient.Config.new(api_key: "custom-key")
      {:ok, job} = MistralClient.API.Jobs.cancel(config, "job-123")
  """
  @spec cancel(String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  @spec cancel(Config.t(), String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def cancel(job_id) when is_binary(job_id) do
    config = Config.new()
    FineTuning.cancel_job(config, job_id)
  end

  def cancel(%Config{} = config, job_id) when is_binary(job_id) do
    FineTuning.cancel_job(config, job_id)
  end

  @doc """
  Request the start of a validated fine tuning job.

  ## Parameters

  - `config` - Client configuration (optional, uses default if not provided)
  - `job_id` - The ID of the job to start

  ## Examples

      {:ok, job} = MistralClient.API.Jobs.start("job-123")

      # With custom config
      config = MistralClient.Config.new(api_key: "custom-key")
      {:ok, job} = MistralClient.API.Jobs.start(config, "job-123")
  """
  @spec start(String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  @spec start(Config.t(), String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def start(job_id) when is_binary(job_id) do
    config = Config.new()
    FineTuning.start_job(config, job_id)
  end

  def start(%Config{} = config, job_id) when is_binary(job_id) do
    FineTuning.start_job(config, job_id)
  end
end
