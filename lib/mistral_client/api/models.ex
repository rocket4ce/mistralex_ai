defmodule MistralClient.API.Models do
  @moduledoc """
  Models API for the Mistral AI client.

  This module provides functions for managing and retrieving information about
  available models, including listing models, retrieving model details, and
  managing fine-tuned models.

  ## Features

    * List available models
    * Retrieve model details
    * Delete fine-tuned models
    * Update model metadata
    * Archive and unarchive models
    * Model permission management

  ## Usage

      # List all available models
      {:ok, models} = MistralClient.API.Models.list()

      # Get details for a specific model
      {:ok, model} = MistralClient.API.Models.retrieve("mistral-large-latest")

      # Delete a fine-tuned model
      {:ok, _} = MistralClient.API.Models.delete("ft:mistral-small:my-org:custom-suffix")
  """

  alias MistralClient.{Client, Models, Errors}
  require Logger

  @endpoint "/models"

  @type model_id :: String.t()
  @type update_options :: %{
          name: String.t() | nil,
          description: String.t() | nil,
          metadata: map() | nil
        }

  @doc """
  List all available models.

  Returns a list of models that are available for use, including both
  base models and fine-tuned models.

  ## Parameters

    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, models} = MistralClient.API.Models.list()

      # Filter for specific model types
      {:ok, models} = MistralClient.API.Models.list()
      base_models = Enum.filter(models, &(&1.owned_by == "mistralai"))
  """
  @spec list(Client.t() | nil) :: {:ok, Models.ModelList.t()} | {:error, Exception.t()}
  def list(client \\ nil) do
    client = client || Client.new()

    case Client.request(client, :get, @endpoint) do
      {:ok, response} ->
        model_list = Models.ModelList.from_map(response)
        {:ok, model_list}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Retrieve details for a specific model.

  ## Parameters

    * `model_id` - The ID of the model to retrieve
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, model} = MistralClient.API.Models.retrieve("mistral-large-latest")
      {:ok, model} = MistralClient.API.Models.retrieve("ft:mistral-small:my-org:custom-suffix")
  """
  @spec retrieve(model_id(), Client.t() | nil) ::
          {:ok, Models.BaseModelCard.t() | Models.FTModelCard.t()} | {:error, Exception.t()}
  def retrieve(model_id, client \\ nil) do
    client = client || Client.new()

    case validate_model_id(model_id) do
      :ok ->
        path = "#{@endpoint}/#{model_id}"

        case Client.request(client, :get, path) do
          {:ok, response} ->
            model = parse_model_response(response)
            {:ok, model}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Delete a fine-tuned model.

  You can only delete fine-tuned models that you own. Base models cannot be deleted.

  ## Parameters

    * `model_id` - The ID of the fine-tuned model to delete
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, result} = MistralClient.API.Models.delete("ft:mistral-small:my-org:custom-suffix")
  """
  @spec delete(model_id(), Client.t() | nil) ::
          {:ok, Models.DeleteModelOut.t()} | {:error, Exception.t()}
  def delete(model_id, client \\ nil) when is_binary(model_id) do
    client = client || Client.new()

    case validate_model_id(model_id) do
      :ok ->
        path = "#{@endpoint}/#{model_id}"

        case Client.request(client, :delete, path) do
          {:ok, response} ->
            delete_result = Models.DeleteModelOut.from_map(response)
            {:ok, delete_result}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Update metadata for a fine-tuned model.

  ## Parameters

    * `model_id` - The ID of the model to update
    * `updates` - Map of fields to update
    * `client` - HTTP client (optional, uses default if not provided)

  ## Update Options

    * `:name` - New name for the model
    * `:description` - New description for the model
    * `:metadata` - Additional metadata

  ## Examples

      {:ok, model} = MistralClient.API.Models.update("ft:mistral-small:my-org:custom-suffix", %{
        name: "My Custom Model",
        description: "A model fine-tuned for my specific use case"
      })
  """
  @spec update(model_id(), update_options(), Client.t() | nil) ::
          {:ok, Models.BaseModelCard.t() | Models.FTModelCard.t()} | {:error, Exception.t()}
  def update(model_id, updates, client \\ nil) when is_binary(model_id) and is_map(updates) do
    client = client || Client.new()

    with :ok <- validate_model_id(model_id),
         {:ok, request_body} <- build_update_body(updates) do
      path = "#{@endpoint}/#{model_id}"

      case Client.request(client, :patch, path, request_body) do
        {:ok, response} ->
          model = parse_model_response(response)
          {:ok, model}

        {:error, _} = error ->
          error
      end
    end
  end

  @doc """
  Archive a model.

  Archived models are not available for inference but are still accessible
  for management operations.

  ## Parameters

    * `model_id` - The ID of the model to archive
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, model} = MistralClient.API.Models.archive("ft:mistral-small:my-org:custom-suffix")
  """
  @spec archive(model_id(), Client.t() | nil) ::
          {:ok, Models.ArchiveFTModelOut.t()} | {:error, Exception.t()}
  def archive(model_id, client \\ nil) when is_binary(model_id) do
    client = client || Client.new()

    case validate_model_id(model_id) do
      :ok ->
        path = "#{@endpoint}/#{model_id}/archive"

        case Client.request(client, :post, path) do
          {:ok, response} ->
            archive_result = Models.ArchiveFTModelOut.from_map(response)
            {:ok, archive_result}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Unarchive a model.

  Makes an archived model available for inference again.

  ## Parameters

    * `model_id` - The ID of the model to unarchive
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, model} = MistralClient.API.Models.unarchive("ft:mistral-small:my-org:custom-suffix")
  """
  @spec unarchive(model_id(), Client.t() | nil) ::
          {:ok, Models.UnarchiveFTModelOut.t()} | {:error, Exception.t()}
  def unarchive(model_id, client \\ nil) when is_binary(model_id) do
    client = client || Client.new()

    case validate_model_id(model_id) do
      :ok ->
        path = "#{@endpoint}/#{model_id}/unarchive"

        case Client.request(client, :post, path) do
          {:ok, response} ->
            unarchive_result = Models.UnarchiveFTModelOut.from_map(response)
            {:ok, unarchive_result}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Check if a model exists and is available.

  ## Parameters

    * `model_id` - The ID of the model to check
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      true = MistralClient.API.Models.exists?("mistral-large-latest")
      false = MistralClient.API.Models.exists?("non-existent-model")
  """
  @spec exists?(model_id(), Client.t() | nil) :: boolean()
  def exists?(model_id, client \\ nil) when is_binary(model_id) do
    case retrieve(model_id, client) do
      {:ok, _model} -> true
      {:error, %Errors.NotFoundError{}} -> false
      {:error, _} -> false
    end
  end

  @doc """
  Filter models by type.

  ## Parameters

    * `models` - List of models to filter
    * `filter_type` - Type of filter to apply

  ## Filter Types

    * `:base` - Base models owned by Mistral AI
    * `:fine_tuned` - Fine-tuned models
    * `:owned` - Models owned by the current user/organization

  ## Examples

      {:ok, all_models} = MistralClient.API.Models.list()
      base_models = MistralClient.API.Models.filter_models(all_models, :base)
      fine_tuned = MistralClient.API.Models.filter_models(all_models, :fine_tuned)
  """
  @spec filter_models(list(Models.BaseModelCard.t() | Models.FTModelCard.t()), atom()) ::
          list(Models.BaseModelCard.t() | Models.FTModelCard.t())
  def filter_models(models, :base) when is_list(models) do
    Enum.filter(models, fn
      %Models.BaseModelCard{} -> true
      %Models.FTModelCard{} -> false
    end)
  end

  def filter_models(models, :fine_tuned) when is_list(models) do
    Enum.filter(models, fn
      %Models.FTModelCard{} -> true
      %Models.BaseModelCard{} -> false
    end)
  end

  def filter_models(models, :owned) when is_list(models) do
    Enum.filter(models, fn
      %Models.BaseModelCard{owned_by: owned_by} -> owned_by != "mistralai"
      %Models.FTModelCard{owned_by: owned_by} -> owned_by != "mistralai"
    end)
  end

  def filter_models(models, _filter_type) when is_list(models) do
    models
  end

  # Private functions

  defp parse_model_response(%{"job" => _} = response) do
    Models.FTModelCard.from_map(response)
  end

  defp parse_model_response(response) do
    Models.BaseModelCard.from_map(response)
  end

  defp validate_model_id(model_id) when is_binary(model_id) and byte_size(model_id) > 0 do
    :ok
  end

  defp validate_model_id(_model_id) do
    {:error,
     Errors.ValidationError.exception(
       message: "Model ID must be a non-empty string",
       field: "model_id"
     )}
  end

  defp build_update_body(updates) when is_map(updates) do
    allowed_fields = [:name, :description, :metadata]

    filtered_updates =
      updates
      |> Enum.filter(fn {key, _value} -> key in allowed_fields end)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    if map_size(filtered_updates) == 0 do
      {:error,
       Errors.ValidationError.exception(
         message: "At least one valid field must be provided for update",
         field: "updates"
       )}
    else
      case validate_update_fields(filtered_updates) do
        :ok -> {:ok, filtered_updates}
        {:error, _} = error -> error
      end
    end
  end

  defp validate_update_fields(updates) do
    cond do
      Map.has_key?(updates, :name) &&
          (not is_binary(updates.name) || String.trim(updates.name) == "") ->
        {:error,
         Errors.ValidationError.exception(
           message: "Name must be a non-empty string",
           field: "name"
         )}

      Map.has_key?(updates, :description) && not is_binary(updates.description) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Description must be a string",
           field: "description"
         )}

      Map.has_key?(updates, :metadata) && not is_map(updates.metadata) ->
        {:error,
         Errors.ValidationError.exception(
           message: "Metadata must be a map",
           field: "metadata"
         )}

      true ->
        :ok
    end
  end
end
