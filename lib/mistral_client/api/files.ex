defmodule MistralClient.API.Files do
  @moduledoc """
  Files API for the Mistral AI client.

  This module provides functions for managing files used with the Mistral API,
  including uploading files for fine-tuning, retrieving file information,
  and downloading files.

  ## Features

    * File upload with multipart support
    * File listing and retrieval
    * File deletion
    * File download
    * Signed URL generation
    * File metadata management

  ## Usage

      # Upload a file
      {:ok, file} = MistralClient.API.Files.upload("./training_data.jsonl", "fine-tune")

      # List all files
      {:ok, files} = MistralClient.API.Files.list()

      # Download a file
      {:ok, content} = MistralClient.API.Files.download("file-abc123")

      # Delete a file
      {:ok, _} = MistralClient.API.Files.delete("file-abc123")
  """

  alias MistralClient.{Client, Models, Errors}
  require Logger

  @endpoint "/files"

  @type file_id :: String.t()
  @type file_path :: String.t()
  @type purpose :: String.t()

  @doc """
  Upload a file with support for progress tracking and validation.

  ## Parameters

    * `file_path` - Path to the file to upload
    * `purpose` - Purpose of the file (e.g., "fine-tune", "assistants", "batch")
    * `options` - Keyword list of options:
      * `:progress_callback` - Function to call with upload progress (0.0 to 1.0)
      * `:filename` - Custom filename to use (defaults to basename of file_path)
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      # Simple upload
      {:ok, file} = MistralClient.API.Files.upload("./training_data.jsonl", "fine-tune")

      # Upload with custom filename
      {:ok, file} = MistralClient.API.Files.upload(
        "./data.jsonl",
        "fine-tune",
        filename: "custom_training_data.jsonl"
      )

      # Upload with progress tracking
      progress_fn = fn progress -> IO.puts("Upload progress: \#{trunc(progress * 100)}%") end
      {:ok, file} = MistralClient.API.Files.upload(
        "./large_file.jsonl",
        "fine-tune",
        progress_callback: progress_fn
      )
  """
  @spec upload(file_path(), purpose(), keyword(), Client.t() | nil) ::
          {:ok, Models.FileUpload.t()} | {:error, Exception.t()}
  def upload(file_path, purpose, options \\ [], client \\ nil)
      when is_binary(file_path) and is_binary(purpose) and is_list(options) do
    client = client || Client.new()

    with :ok <- validate_file_path(file_path),
         :ok <- validate_file_size(file_path),
         :ok <- validate_purpose(purpose),
         :ok <- validate_file_extension(file_path, purpose),
         {:ok, file_content} <- read_file(file_path),
         {:ok, request_body} <- build_multipart_body(file_path, file_content, purpose, options) do
      # Report progress if callback provided
      if progress_callback = Keyword.get(options, :progress_callback) do
        progress_callback.(1.0)
      end

      # Use multipart form data for file upload
      upload_options = [
        headers: [{"content-type", "multipart/form-data"}],
        form: request_body
      ]

      case Client.request(client, :post, @endpoint, nil, upload_options) do
        {:ok, response} ->
          {:ok, Models.FileUpload.from_map(response)}

        {:error, _} = error ->
          error
      end
    end
  end

  @doc """
  List all uploaded files with pagination and filtering support.

  ## Parameters

    * `options` - Keyword list of options:
      * `:page` - Page number (default: 0)
      * `:page_size` - Number of items per page (default: 100)
      * `:purpose` - Filter by purpose (e.g., "fine-tune", "assistants")
      * `:sample_type` - Filter by sample type
      * `:source` - Filter by source
      * `:search` - Search term to filter files
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      # List all files
      {:ok, files} = MistralClient.API.Files.list()

      # List with pagination
      {:ok, files} = MistralClient.API.Files.list(page: 1, page_size: 50)

      # Filter by purpose
      {:ok, files} = MistralClient.API.Files.list(purpose: "fine-tune")

      # Search files
      {:ok, files} = MistralClient.API.Files.list(search: "training")
  """
  @spec list(keyword(), Client.t() | nil) :: {:ok, Models.FileList.t()} | {:error, Exception.t()}
  def list(options \\ [], client \\ nil)

  def list(options, client) when is_list(options) do
    client = client || Client.new()
    query_params = build_list_query_params(options)

    endpoint_with_params =
      case query_params do
        "" -> @endpoint
        params -> "#{@endpoint}?#{params}"
      end

    case Client.request(client, :get, endpoint_with_params, nil, []) do
      {:ok, response} ->
        {:ok, Models.FileList.from_map(response)}

      {:error, _} = error ->
        error
    end
  end

  def list(client, nil) when not is_list(client) do
    list([], client)
  end

  @doc """
  Retrieve information about a specific file.

  ## Parameters

    * `file_id` - The ID of the file to retrieve
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, file} = MistralClient.API.Files.retrieve("file-abc123")
  """
  @spec retrieve(file_id(), Client.t() | nil) :: {:ok, Models.File.t()} | {:error, Exception.t()}
  def retrieve(file_id, client \\ nil) when is_binary(file_id) do
    client = client || Client.new()

    case validate_file_id(file_id) do
      :ok ->
        path = "#{@endpoint}/#{file_id}"

        case Client.request(client, :get, path, nil, []) do
          {:ok, response} ->
            {:ok, Models.File.from_map(response)}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Delete a file.

  ## Parameters

    * `file_id` - The ID of the file to delete
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, result} = MistralClient.API.Files.delete("file-abc123")
  """
  @spec delete(file_id(), Client.t() | nil) ::
          {:ok, Models.DeleteFileOut.t()} | {:error, Exception.t()}
  def delete(file_id, client \\ nil) when is_binary(file_id) do
    client = client || Client.new()

    case validate_file_id(file_id) do
      :ok ->
        path = "#{@endpoint}/#{file_id}"

        case Client.request(client, :delete, path, nil, []) do
          {:ok, response} ->
            {:ok, Models.DeleteFileOut.from_map(response)}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Download the content of a file.

  ## Parameters

    * `file_id` - The ID of the file to download
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      {:ok, content} = MistralClient.API.Files.download("file-abc123")
  """
  @spec download(file_id(), Client.t() | nil) :: {:ok, binary()} | {:error, Exception.t()}
  def download(file_id, client \\ nil) when is_binary(file_id) do
    client = client || Client.new()

    case validate_file_id(file_id) do
      :ok ->
        path = "#{@endpoint}/#{file_id}/content"

        case Client.request(client, :get, path, nil, raw_response: true) do
          {:ok, content} when is_binary(content) ->
            {:ok, content}

          {:ok, response} ->
            # If response is not binary, try to extract content
            case extract_content_from_response(response) do
              {:ok, content} -> {:ok, content}
              {:error, _} = error -> error
            end

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get a signed URL for downloading a file.

  ## Parameters

    * `file_id` - The ID of the file
    * `options` - Keyword list of options:
      * `:expiry` - Number of hours before the URL expires (default: 24)
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      # Get signed URL with default expiry (24 hours)
      {:ok, signed_url_response} = MistralClient.API.Files.get_signed_url("file-abc123")

      # Get signed URL with custom expiry (48 hours)
      {:ok, signed_url_response} = MistralClient.API.Files.get_signed_url(
        "file-abc123",
        expiry: 48
      )
  """
  @spec get_signed_url(file_id(), keyword(), Client.t() | nil) ::
          {:ok, Models.FileSignedURL.t()} | {:error, Exception.t()}
  def get_signed_url(file_id, options \\ [], client \\ nil)
      when is_binary(file_id) and is_list(options) do
    client = client || Client.new()

    case validate_file_id(file_id) do
      :ok ->
        expiry = Keyword.get(options, :expiry, 24)
        query_params = if expiry, do: "?expiry=#{expiry}", else: ""
        path = "#{@endpoint}/#{file_id}/url#{query_params}"

        case Client.request(client, :get, path, nil, []) do
          {:ok, response} ->
            {:ok, Models.FileSignedURL.from_map(response)}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Check if a file exists.

  ## Parameters

    * `file_id` - The ID of the file to check
    * `client` - HTTP client (optional, uses default if not provided)

  ## Examples

      true = MistralClient.API.Files.exists?("file-abc123")
      false = MistralClient.API.Files.exists?("non-existent-file")
  """
  @spec exists?(file_id(), Client.t() | nil) :: boolean()
  def exists?(file_id, client \\ nil) when is_binary(file_id) do
    case retrieve(file_id, client) do
      {:ok, _file} -> true
      {:error, %Errors.NotFoundError{}} -> false
      {:error, _} -> false
    end
  end

  @doc """
  Filter files by purpose.

  ## Parameters

    * `files` - List of files to filter
    * `purpose` - Purpose to filter by

  ## Examples

      {:ok, all_files} = MistralClient.API.Files.list()
      fine_tune_files = MistralClient.API.Files.filter_by_purpose(all_files, "fine-tune")
  """
  @spec filter_by_purpose(list(Models.File.t()), purpose()) :: list(Models.File.t())
  def filter_by_purpose(files, purpose) when is_list(files) and is_binary(purpose) do
    Enum.filter(files, &(&1.purpose == purpose))
  end

  @doc """
  Get the total size of all files.

  ## Parameters

    * `files` - List of files

  ## Examples

      {:ok, files} = MistralClient.API.Files.list()
      total_bytes = MistralClient.API.Files.total_size(files)
  """
  @spec total_size(list(Models.File.t())) :: integer()
  def total_size(files) when is_list(files) do
    Enum.reduce(files, 0, fn file, acc -> acc + (file.bytes || 0) end)
  end

  # Private functions

  defp validate_file_path(file_path) when is_binary(file_path) do
    if File.exists?(file_path) do
      :ok
    else
      {:error,
       Errors.ValidationError.exception(
         message: "File does not exist: #{file_path}",
         field: "file_path"
       )}
    end
  end

  defp validate_file_path(_file_path) do
    {:error,
     Errors.ValidationError.exception(
       message: "File path must be a string",
       field: "file_path"
     )}
  end

  defp validate_purpose(purpose) when is_binary(purpose) and byte_size(purpose) > 0 do
    valid_purposes = ["fine-tune", "assistants", "batch"]

    if purpose in valid_purposes do
      :ok
    else
      {:error,
       Errors.ValidationError.exception(
         message: "Purpose must be one of: #{Enum.join(valid_purposes, ", ")}",
         field: "purpose"
       )}
    end
  end

  defp validate_purpose(_purpose) do
    {:error,
     Errors.ValidationError.exception(
       message: "Purpose must be a non-empty string",
       field: "purpose"
     )}
  end

  defp validate_file_id(file_id) when is_binary(file_id) and byte_size(file_id) > 0 do
    :ok
  end

  defp validate_file_id(_file_id) do
    {:error,
     Errors.ValidationError.exception(
       message: "File ID must be a non-empty string",
       field: "file_id"
     )}
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error,
         Errors.ValidationError.exception(
           message: "Failed to read file: #{inspect(reason)}",
           field: "file_path"
         )}
    end
  end

  defp build_multipart_body(file_path, file_content, purpose, options) do
    filename = Keyword.get(options, :filename, Path.basename(file_path))

    form_data = [
      {"purpose", purpose},
      {"file", file_content, [{"filename", filename}]}
    ]

    {:ok, form_data}
  end

  # File size validation (max 512MB)
  @max_file_size 512 * 1024 * 1024

  defp validate_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %File.Stat{size: size}} when size <= @max_file_size ->
        :ok

      {:ok, %File.Stat{size: size}} ->
        size_mb = Float.round(size / (1024 * 1024), 2)

        {:error,
         Errors.ValidationError.exception(
           message: "File size #{size_mb}MB exceeds maximum allowed size of 512MB",
           field: "file_size"
         )}

      {:error, reason} ->
        {:error,
         Errors.ValidationError.exception(
           message: "Failed to get file stats: #{inspect(reason)}",
           field: "file_path"
         )}
    end
  end

  defp validate_file_extension(file_path, purpose) do
    extension = Path.extname(file_path) |> String.downcase()

    case purpose do
      "fine-tune" ->
        if extension == ".jsonl" do
          :ok
        else
          {:error,
           Errors.ValidationError.exception(
             message: "Fine-tuning requires .jsonl files, got: #{extension}",
             field: "file_extension"
           )}
        end

      _ ->
        # Other purposes allow various file types
        :ok
    end
  end

  defp build_list_query_params(options) do
    options
    |> Enum.filter(fn {_key, value} -> value != nil end)
    |> Enum.map(&encode_query_param/1)
    |> Enum.join("&")
  end

  defp encode_query_param({key, value}) when is_list(value) do
    value
    |> Enum.map(fn item -> "#{key}=#{URI.encode_www_form(to_string(item))}" end)
    |> Enum.join("&")
  end

  defp encode_query_param({key, value}) do
    "#{key}=#{URI.encode_www_form(to_string(value))}"
  end

  defp extract_content_from_response(response) when is_map(response) do
    case Map.get(response, "content") do
      content when is_binary(content) ->
        {:ok, content}

      _ ->
        {:error,
         Errors.ValidationError.exception(message: "Response does not contain file content")}
    end
  end

  defp extract_content_from_response(_response) do
    {:error,
     Errors.ValidationError.exception(message: "Invalid response format for file download")}
  end
end
