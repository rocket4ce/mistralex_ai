defmodule MistralClient.API.Batch do
  @moduledoc """
  Batch API for processing multiple requests asynchronously.

  The Batch API allows you to submit multiple requests for processing in the background.
  This is useful for processing large volumes of data without blocking your application.

  ## Supported Endpoints

  - `/v1/chat/completions` - Chat completions
  - `/v1/embeddings` - Text embeddings
  - `/v1/fim/completions` - Fill-in-the-middle completions
  - `/v1/moderations` - Content moderation
  - `/v1/chat/moderations` - Chat moderation

  ## Example

      # Create a batch job
      {:ok, job} = MistralClient.API.Batch.create(client, %{
        input_files: ["file-abc123"],
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest",
        metadata: %{"description" => "Customer support batch"}
      })

      # Monitor progress
      {:ok, updated_job} = MistralClient.API.Batch.get(client, job.id)
      IO.puts("Status: \#{updated_job.status}, Progress: \#{updated_job.completed_requests}/\#{updated_job.total_requests}")

      # List all batch jobs
      {:ok, jobs} = MistralClient.API.Batch.list(client, %{status: ["RUNNING", "QUEUED"]})
  """

  alias MistralClient.Client
  alias MistralClient.Models.{BatchJobIn, BatchJobOut, BatchJobsOut}

  @doc """
  List batch jobs with optional filtering and pagination.

  ## Parameters

  - `client` - The MistralClient.Client instance
  - `params` - Optional parameters map:
    - `:page` - Page number (default: 0)
    - `:page_size` - Number of jobs per page (default: 100)
    - `:model` - Filter by model name
    - `:metadata` - Filter by metadata
    - `:created_after` - Filter by creation date (DateTime)
    - `:created_by_me` - Filter by ownership (boolean, default: false)
    - `:status` - Filter by status list (e.g., ["RUNNING", "QUEUED"])

  ## Returns

  - `{:ok, %BatchJobsOut{}}` - List of batch jobs
  - `{:error, reason}` - Error details

  ## Example

      {:ok, jobs} = MistralClient.API.Batch.list(client, %{
        page: 0,
        page_size: 50,
        status: ["RUNNING", "QUEUED"],
        model: "mistral-large-latest"
      })
  """
  @spec list(Client.t(), map()) :: {:ok, BatchJobsOut.t()} | {:error, any()}
  def list(client, params \\ %{}) do
    query_params = build_list_params(params)

    client
    |> Client.request(:get, "/batch/jobs", nil, query: query_params)
    |> handle_response(&BatchJobsOut.from_map/1)
  end

  @doc """
  Create a new batch job for processing multiple requests.

  ## Parameters

  - `client` - The MistralClient.Client instance
  - `request` - BatchJobIn struct or map with:
    - `:input_files` - List of file IDs to process (required)
    - `:endpoint` - API endpoint to use (required)
    - `:model` - Model to use for processing (required)
    - `:metadata` - Optional metadata map
    - `:timeout_hours` - Timeout in hours (default: 24)

  ## Returns

  - `{:ok, %BatchJobOut{}}` - Created batch job
  - `{:error, reason}` - Error details

  ## Example

      {:ok, job} = MistralClient.API.Batch.create(client, %{
        input_files: ["file-abc123", "file-def456"],
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest",
        metadata: %{"project" => "customer-support"},
        timeout_hours: 48
      })
  """
  @spec create(Client.t(), map() | BatchJobIn.t()) :: {:ok, BatchJobOut.t()} | {:error, any()}
  def create(client, %BatchJobIn{} = request) do
    body = BatchJobIn.to_map(request)

    client
    |> Client.request(:post, "/batch/jobs", body)
    |> handle_response(&BatchJobOut.from_map/1)
  end

  def create(client, request) when is_map(request) do
    with {:ok, validated_request} <- validate_create_request(request),
         body <- BatchJobIn.to_map(validated_request) do
      client
      |> Client.request(:post, "/batch/jobs", body)
      |> handle_response(&BatchJobOut.from_map/1)
    end
  end

  @doc """
  Get details of a specific batch job by ID.

  ## Parameters

  - `client` - The MistralClient.Client instance
  - `job_id` - The batch job ID

  ## Returns

  - `{:ok, %BatchJobOut{}}` - Batch job details
  - `{:error, reason}` - Error details

  ## Example

      {:ok, job} = MistralClient.API.Batch.get(client, "batch_abc123")
      IO.puts("Status: \#{job.status}")
      IO.puts("Progress: \#{job.completed_requests}/\#{job.total_requests}")
  """
  @spec get(Client.t(), String.t()) :: {:ok, BatchJobOut.t()} | {:error, any()}
  def get(client, job_id) when is_binary(job_id) do
    client
    |> Client.request(:get, "/batch/jobs/#{job_id}")
    |> handle_response(&BatchJobOut.from_map/1)
  end

  @doc """
  Cancel a running batch job.

  ## Parameters

  - `client` - The MistralClient.Client instance
  - `job_id` - The batch job ID to cancel

  ## Returns

  - `{:ok, %BatchJobOut{}}` - Updated batch job with cancellation status
  - `{:error, reason}` - Error details

  ## Example

      {:ok, job} = MistralClient.API.Batch.cancel(client, "batch_abc123")
      # job.status will be "CANCELLATION_REQUESTED" or "CANCELLED"
  """
  @spec cancel(Client.t(), String.t()) :: {:ok, BatchJobOut.t()} | {:error, any()}
  def cancel(client, job_id) when is_binary(job_id) do
    client
    |> Client.request(:post, "/batch/jobs/#{job_id}/cancel", %{})
    |> handle_response(&BatchJobOut.from_map/1)
  end

  # Private helper functions

  defp build_list_params(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case {key, value} do
        {:page, page} when is_integer(page) ->
          Map.put(acc, "page", page)

        {:page_size, size} when is_integer(size) ->
          Map.put(acc, "page_size", size)

        {:model, model} when is_binary(model) ->
          Map.put(acc, "model", model)

        {:metadata, metadata} when is_map(metadata) ->
          Map.put(acc, "metadata", metadata)

        {:created_after, %DateTime{} = dt} ->
          Map.put(acc, "created_after", DateTime.to_iso8601(dt))

        {:created_by_me, flag} when is_boolean(flag) ->
          Map.put(acc, "created_by_me", flag)

        {:status, statuses} when is_list(statuses) ->
          # Convert list to comma-separated string for query parameter
          status_string = Enum.join(statuses, ",")
          Map.put(acc, "status", status_string)

        _ ->
          acc
      end
    end)
  end

  defp validate_create_request(request) do
    required_fields = [:input_files, :endpoint, :model]

    case check_required_fields(request, required_fields) do
      :ok ->
        validated = %BatchJobIn{
          input_files: get_field(request, :input_files),
          endpoint: get_field(request, :endpoint),
          model: get_field(request, :model),
          metadata: get_field(request, :metadata),
          timeout_hours: get_field(request, :timeout_hours) || 24
        }

        {:ok, validated}

      {:error, missing} ->
        {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  defp check_required_fields(request, required_fields) do
    missing =
      required_fields
      |> Enum.filter(fn field ->
        value = get_field(request, field)
        is_nil(value)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, missing}
    end
  end

  # Helper function to get field value from map with either atom or string keys
  defp get_field(map, field) when is_atom(field) do
    Map.get(map, field) || Map.get(map, Atom.to_string(field))
  end

  defp handle_response({:ok, body}, parser_fn) do
    case parser_fn.(body) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} = error -> error
    end
  end

  defp handle_response({:error, reason}, _parser_fn) do
    {:error, reason}
  end
end
