defmodule MistralClient.API.FineTuning do
  @moduledoc """
  Fine-tuning API for creating and managing fine-tuning jobs.

  This module provides functions to:
  - Create fine-tuning jobs
  - List fine-tuning jobs with filtering
  - Get fine-tuning job details
  - Start, cancel fine-tuning jobs
  - Archive/unarchive fine-tuned models
  - Update fine-tuned models

  ## Examples

      # Create a fine-tuning job
      config = MistralClient.Config.new(api_key: "your-api-key")

      hyperparameters = %MistralClient.Models.CompletionTrainingParameters{
        learning_rate: 0.0001,
        training_steps: 1000
      }

      request = %MistralClient.Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: hyperparameters,
        training_files: [%MistralClient.Models.TrainingFile{file_id: "file-123"}]
      }

      {:ok, job} = MistralClient.API.FineTuning.create_job(config, request)

      # List jobs with filtering
      {:ok, jobs} = MistralClient.API.FineTuning.list_jobs(config, %{
        status: "RUNNING",
        model: "open-mistral-7b"
      })

      # Get job details
      {:ok, job} = MistralClient.API.FineTuning.get_job(config, "job-123")

      # Start a job
      {:ok, job} = MistralClient.API.FineTuning.start_job(config, "job-123")

      # Cancel a job
      {:ok, job} = MistralClient.API.FineTuning.cancel_job(config, "job-123")
  """

  alias MistralClient.{Client, Config}

  alias MistralClient.Models.{
    FineTuningJobRequest,
    FineTuningJobResponse,
    FineTuningJobsResponse,
    CompletionTrainingParameters,
    TrainingFile,
    WandbIntegration,
    GithubRepository
  }

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

  @type fine_tuneable_model_type :: :completion | :classifier

  @doc """
  Creates a new fine-tuning job.

  ## Parameters

  - `config` - Client configuration
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

      hyperparameters = %CompletionTrainingParameters{
        learning_rate: 0.0001,
        training_steps: 1000,
        weight_decay: 0.01
      }

      request = %FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: hyperparameters,
        training_files: [%TrainingFile{file_id: "file-123"}],
        suffix: "my-model"
      }

      {:ok, job} = MistralClient.API.FineTuning.create_job(config, request)
  """
  @spec create_job(Config.t(), FineTuningJobRequest.t()) ::
          {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def create_job(%Config{} = config, %FineTuningJobRequest{} = request) do
    with :ok <- validate_create_job_request(request),
         body <- prepare_create_job_body(request) do
      client = Client.new(config)

      Client.request(client, :post, "/fine_tuning/jobs", body)
      |> handle_job_response()
    end
  end

  @doc """
  Lists fine-tuning jobs with optional filtering.

  ## Parameters

  - `config` - Client configuration
  - `options` - Filtering and pagination options

  ## Options

  - `page` - Page number (default: 0)
  - `page_size` - Number of items per page (default: 100)
  - `model` - Filter by model name
  - `created_after` - Filter by creation date (DateTime)
  - `created_before` - Filter by creation date (DateTime)
  - `created_by_me` - Show only jobs created by the caller (default: false)
  - `status` - Filter by job status
  - `wandb_project` - Filter by Weights & Biases project
  - `wandb_name` - Filter by Weights & Biases run name
  - `suffix` - Filter by model suffix

  ## Examples

      # List all jobs
      {:ok, jobs} = MistralClient.API.FineTuning.list_jobs(config)

      # List running jobs for a specific model
      {:ok, jobs} = MistralClient.API.FineTuning.list_jobs(config, %{
        status: :running,
        model: "open-mistral-7b",
        page_size: 50
      })
  """
  @spec list_jobs(Config.t(), map()) :: {:ok, FineTuningJobsResponse.t()} | {:error, term()}
  def list_jobs(%Config{} = config, options \\ %{}) do
    query_params = build_list_query_params(options)

    client = Client.new(config)

    Client.request(client, :get, "/fine_tuning/jobs", nil, query: query_params)
    |> handle_jobs_response()
  end

  @doc """
  Gets details of a specific fine-tuning job.

  ## Parameters

  - `config` - Client configuration
  - `job_id` - The ID of the job to retrieve

  ## Examples

      {:ok, job} = MistralClient.API.FineTuning.get_job(config, "job-123")
  """
  @spec get_job(Config.t(), String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def get_job(%Config{} = config, job_id) when is_binary(job_id) do
    client = Client.new(config)

    Client.request(client, :get, "/fine_tuning/jobs/#{job_id}")
    |> handle_job_response()
  end

  @doc """
  Starts a validated fine-tuning job.

  ## Parameters

  - `config` - Client configuration
  - `job_id` - The ID of the job to start

  ## Examples

      {:ok, job} = MistralClient.API.FineTuning.start_job(config, "job-123")
  """
  @spec start_job(Config.t(), String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def start_job(%Config{} = config, job_id) when is_binary(job_id) do
    client = Client.new(config)

    Client.request(client, :post, "/fine_tuning/jobs/#{job_id}/start", %{})
    |> handle_job_response()
  end

  @doc """
  Cancels a fine-tuning job.

  ## Parameters

  - `config` - Client configuration
  - `job_id` - The ID of the job to cancel

  ## Examples

      {:ok, job} = MistralClient.API.FineTuning.cancel_job(config, "job-123")
  """
  @spec cancel_job(Config.t(), String.t()) :: {:ok, FineTuningJobResponse.t()} | {:error, term()}
  def cancel_job(%Config{} = config, job_id) when is_binary(job_id) do
    client = Client.new(config)

    Client.request(client, :post, "/fine_tuning/jobs/#{job_id}/cancel", %{})
    |> handle_job_response()
  end

  @doc """
  Archives a fine-tuned model.

  ## Parameters

  - `config` - Client configuration
  - `model_id` - The ID of the model to archive

  ## Examples

      {:ok, model} = MistralClient.API.FineTuning.archive_model(config, "ft:open-mistral-7b:my-model:xxx")
  """
  @spec archive_model(Config.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def archive_model(%Config{} = config, model_id) when is_binary(model_id) do
    client = Client.new(config)

    Client.request(client, :post, "/fine_tuning/models/#{model_id}/archive", %{})
    |> handle_model_response()
  end

  @doc """
  Unarchives a fine-tuned model.

  ## Parameters

  - `config` - Client configuration
  - `model_id` - The ID of the model to unarchive

  ## Examples

      {:ok, model} = MistralClient.API.FineTuning.unarchive_model(config, "ft:open-mistral-7b:my-model:xxx")
  """
  @spec unarchive_model(Config.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def unarchive_model(%Config{} = config, model_id) when is_binary(model_id) do
    client = Client.new(config)

    Client.request(client, :post, "/fine_tuning/models/#{model_id}/unarchive", %{})
    |> handle_model_response()
  end

  @doc """
  Updates a fine-tuned model.

  ## Parameters

  - `config` - Client configuration
  - `model_id` - The ID of the model to update
  - `updates` - Map of fields to update

  ## Examples

      {:ok, model} = MistralClient.API.FineTuning.update_model(config, "ft:open-mistral-7b:my-model:xxx", %{
        name: "Updated Model Name"
      })
  """
  @spec update_model(Config.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def update_model(%Config{} = config, model_id, updates)
      when is_binary(model_id) and is_map(updates) do
    client = Client.new(config)

    Client.request(client, :patch, "/fine_tuning/models/#{model_id}", updates)
    |> handle_model_response()
  end

  # Private functions

  defp validate_create_job_request(%FineTuningJobRequest{
         model: model,
         hyperparameters: hyperparameters
       }) do
    cond do
      is_nil(model) or model == "" ->
        {:error, "Model is required"}

      is_nil(hyperparameters) ->
        {:error, "Hyperparameters are required"}

      true ->
        :ok
    end
  end

  defp prepare_create_job_body(%FineTuningJobRequest{} = request) do
    request
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> convert_hyperparameters()
    |> convert_training_files()
    |> convert_integrations()
    |> convert_repositories()
  end

  defp convert_hyperparameters(
         %{hyperparameters: %CompletionTrainingParameters{} = params} = body
       ) do
    hyperparameters =
      params
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{body | hyperparameters: hyperparameters}
  end

  defp convert_hyperparameters(body), do: body

  defp convert_training_files(%{training_files: files} = body) when is_list(files) do
    training_files =
      files
      |> Enum.map(fn
        %TrainingFile{file_id: file_id} -> %{file_id: file_id}
        file when is_map(file) -> file
      end)

    %{body | training_files: training_files}
  end

  defp convert_training_files(body), do: body

  defp convert_integrations(%{integrations: integrations} = body) when is_list(integrations) do
    converted_integrations =
      integrations
      |> Enum.map(fn
        %WandbIntegration{} = integration ->
          integration
          |> Map.from_struct()
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        integration when is_map(integration) ->
          integration
      end)

    %{body | integrations: converted_integrations}
  end

  defp convert_integrations(body), do: body

  defp convert_repositories(%{repositories: repositories} = body) when is_list(repositories) do
    converted_repositories =
      repositories
      |> Enum.map(fn
        %GithubRepository{} = repo ->
          repo |> Map.from_struct() |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

        repo when is_map(repo) ->
          repo
      end)

    %{body | repositories: converted_repositories}
  end

  defp convert_repositories(body), do: body

  defp build_list_query_params(options) do
    options
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case {key, value} do
        {:page, page} when is_integer(page) ->
          Map.put(acc, :page, page)

        {:page_size, size} when is_integer(size) ->
          Map.put(acc, :page_size, size)

        {:model, model} when is_binary(model) ->
          Map.put(acc, :model, model)

        {:created_after, %DateTime{} = dt} ->
          Map.put(acc, :created_after, DateTime.to_iso8601(dt))

        {:created_before, %DateTime{} = dt} ->
          Map.put(acc, :created_before, DateTime.to_iso8601(dt))

        {:created_by_me, bool} when is_boolean(bool) ->
          Map.put(acc, :created_by_me, bool)

        {:status, status} when is_atom(status) ->
          Map.put(acc, :status, status_to_string(status))

        {:wandb_project, project} when is_binary(project) ->
          Map.put(acc, :wandb_project, project)

        {:wandb_name, name} when is_binary(name) ->
          Map.put(acc, :wandb_name, name)

        {:suffix, suffix} when is_binary(suffix) ->
          Map.put(acc, :suffix, suffix)

        _ ->
          acc
      end
    end)
  end

  defp status_to_string(status) do
    case status do
      :queued -> "QUEUED"
      :started -> "STARTED"
      :validating -> "VALIDATING"
      :validated -> "VALIDATED"
      :running -> "RUNNING"
      :failed_validation -> "FAILED_VALIDATION"
      :failed -> "FAILED"
      :success -> "SUCCESS"
      :cancelled -> "CANCELLED"
      :cancellation_requested -> "CANCELLATION_REQUESTED"
      status when is_binary(status) -> status
    end
  end

  defp handle_job_response({:ok, %{status: 200, body: body}}) do
    case parse_job_response(body) do
      {:ok, job} -> {:ok, job}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_job_response({:ok, body}) when is_map(body) do
    case parse_job_response(body) do
      {:ok, job} -> {:ok, job}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_job_response({:ok, %{status: status, body: _body}}) do
    {:error, "API error: #{status}"}
  end

  defp handle_job_response({:error, reason}) do
    {:error, reason}
  end

  defp handle_jobs_response({:ok, %{status: 200, body: body}}) do
    case parse_jobs_response(body) do
      {:ok, jobs} -> {:ok, jobs}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_jobs_response({:ok, body}) when is_map(body) do
    case parse_jobs_response(body) do
      {:ok, jobs} -> {:ok, jobs}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_jobs_response({:ok, %{status: status, body: _body}}) do
    {:error, "API error: #{status}"}
  end

  defp handle_jobs_response({:error, reason}) do
    {:error, reason}
  end

  defp handle_model_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_model_response({:ok, body}) when is_map(body) do
    {:ok, body}
  end

  defp handle_model_response({:ok, %{status: status, body: _body}}) do
    {:error, "API error: #{status}"}
  end

  defp handle_model_response({:error, reason}) do
    {:error, reason}
  end

  defp parse_job_response(body) when is_map(body) do
    try do
      job = %FineTuningJobResponse{
        id: body["id"],
        auto_start: body["auto_start"],
        model: body["model"],
        status: parse_status(body["status"]),
        created_at: body["created_at"],
        modified_at: body["modified_at"],
        training_files: body["training_files"] || [],
        validation_files: body["validation_files"],
        object: body["object"],
        fine_tuned_model: body["fine_tuned_model"],
        suffix: body["suffix"],
        integrations: parse_integrations(body["integrations"]),
        trained_tokens: body["trained_tokens"],
        metadata: body["metadata"],
        job_type: parse_job_type(body["job_type"]),
        repositories: parse_repositories(body["repositories"]),
        events: parse_events(body["events"]),
        checkpoints: parse_checkpoints(body["checkpoints"]),
        hyperparameters: parse_hyperparameters(body["hyperparameters"])
      }

      {:ok, job}
    rescue
      e -> {:error, "Failed to parse job response: #{inspect(e)}"}
    end
  end

  defp parse_job_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_job_response(decoded)
      {:error, reason} -> {:error, "Failed to decode JSON: #{inspect(reason)}"}
    end
  end

  defp parse_jobs_response(body) when is_map(body) do
    try do
      jobs = %FineTuningJobsResponse{
        total: body["total"],
        data: parse_jobs_list(body["data"] || []),
        has_more: body["has_more"],
        object: body["object"]
      }

      {:ok, jobs}
    rescue
      e -> {:error, "Failed to parse jobs response: #{inspect(e)}"}
    end
  end

  defp parse_jobs_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_jobs_response(decoded)
      {:error, reason} -> {:error, "Failed to decode JSON: #{inspect(reason)}"}
    end
  end

  defp parse_jobs_list(jobs) when is_list(jobs) do
    Enum.map(jobs, fn job_data ->
      case parse_job_response(job_data) do
        {:ok, job} -> job
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_status(status) when is_binary(status) do
    case String.upcase(status) do
      "QUEUED" -> :queued
      "STARTED" -> :started
      "VALIDATING" -> :validating
      "VALIDATED" -> :validated
      "RUNNING" -> :running
      "FAILED_VALIDATION" -> :failed_validation
      "FAILED" -> :failed
      "SUCCESS" -> :success
      "CANCELLED" -> :cancelled
      "CANCELLATION_REQUESTED" -> :cancellation_requested
      _ -> status
    end
  end

  defp parse_status(status), do: status

  defp parse_job_type("completion"), do: :completion
  defp parse_job_type("classifier"), do: :classifier
  defp parse_job_type(job_type), do: job_type

  defp parse_integrations(nil), do: nil

  defp parse_integrations(integrations) when is_list(integrations) do
    Enum.map(integrations, fn integration ->
      %WandbIntegration{
        type: integration["type"],
        project: integration["project"],
        name: integration["name"],
        api_key: integration["api_key"]
      }
    end)
  end

  defp parse_repositories(nil), do: nil

  defp parse_repositories(repositories) when is_list(repositories) do
    Enum.map(repositories, fn repo ->
      %GithubRepository{
        type: repo["type"],
        name: repo["name"],
        owner: repo["owner"],
        ref: repo["ref"],
        weight: repo["weight"],
        commit_id: repo["commit_id"]
      }
    end)
  end

  defp parse_events(nil), do: nil
  defp parse_events(events) when is_list(events), do: events

  defp parse_checkpoints(nil), do: nil
  defp parse_checkpoints(checkpoints) when is_list(checkpoints), do: checkpoints

  defp parse_hyperparameters(nil), do: nil

  defp parse_hyperparameters(params) when is_map(params) do
    %CompletionTrainingParameters{
      training_steps: params["training_steps"],
      learning_rate: params["learning_rate"],
      weight_decay: params["weight_decay"],
      warmup_fraction: params["warmup_fraction"],
      epochs: params["epochs"],
      seq_len: params["seq_len"],
      fim_ratio: params["fim_ratio"]
    }
  end
end
