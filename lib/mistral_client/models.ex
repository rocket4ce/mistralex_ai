defmodule MistralClient.Models do
  @moduledoc """
  Core data structures for the Mistral AI client.

  This module defines structs and types that represent the various data
  structures used throughout the Mistral API, providing type safety and
  clear documentation of expected data formats.

  ## Message Types

    * `Message` - Chat message with role and content
    * `ToolCall` - Function/tool call within a message
    * `ToolCallFunction` - Function details for a tool call

  ## Response Types

    * `ChatCompletion` - Complete chat response
    * `ChatCompletionChoice` - Individual choice in chat response
    * `ChatCompletionMessage` - Message in chat completion
    * `Usage` - Token usage information
    * `EmbeddingResponse` - Embedding generation response
    * `Embedding` - Individual embedding data

  ## Model Types

    * `Model` - Model information
    * `ModelPermission` - Model access permissions

  ## File Types

    * `File` - File metadata
    * `FileUpload` - File upload response

  ## Usage

      # Create a message
      message = %MistralClient.Models.Message{
        role: "user",
        content: "Hello, world!"
      }

      # Parse a chat completion response
      {:ok, completion} = MistralClient.Models.ChatCompletion.from_map(response_data)
  """

  defmodule Message do
    @moduledoc """
    Represents a chat message.
    """
    @type t :: %__MODULE__{
            role: String.t(),
            content: String.t() | nil,
            name: String.t() | nil,
            tool_calls: list(ToolCall.t()) | nil,
            tool_call_id: String.t() | nil
          }

    defstruct [:role, :content, :name, :tool_calls, :tool_call_id]

    @doc """
    Create a new message.

    ## Examples

        message = MistralClient.Models.Message.new("user", "Hello!")
        %MistralClient.Models.Message{role: "user", content: "Hello!"}
    """
    @spec new(String.t(), String.t(), keyword()) :: t()
    def new(role, content, opts \\ []) do
      %__MODULE__{
        role: role,
        content: content,
        name: Keyword.get(opts, :name),
        tool_calls: Keyword.get(opts, :tool_calls),
        tool_call_id: Keyword.get(opts, :tool_call_id)
      }
    end

    @doc """
    Convert a message to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = message) do
      message
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end

    @doc """
    Create a message from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        role: Map.get(data, "role"),
        content: Map.get(data, "content"),
        name: Map.get(data, "name"),
        tool_calls: parse_tool_calls(Map.get(data, "tool_calls")),
        tool_call_id: Map.get(data, "tool_call_id")
      }
    end

    defp parse_tool_calls(nil), do: nil

    defp parse_tool_calls(calls) when is_list(calls) do
      Enum.map(calls, &MistralClient.Models.ToolCall.from_map/1)
    end
  end

  defmodule ToolCall do
    @moduledoc """
    Represents a tool/function call.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            type: String.t(),
            function: ToolCallFunction.t()
          }

    defstruct [:id, :type, :function]

    @doc """
    Create a tool call from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        type: Map.get(data, "type"),
        function: MistralClient.Models.ToolCallFunction.from_map(Map.get(data, "function", %{}))
      }
    end

    @doc """
    Convert a tool call to a map.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = tool_call) do
      %{
        "id" => tool_call.id,
        "type" => tool_call.type,
        "function" => MistralClient.Models.ToolCallFunction.to_map(tool_call.function)
      }
    end
  end

  defmodule ToolCallFunction do
    @moduledoc """
    Represents function details in a tool call.
    """
    @type t :: %__MODULE__{
            name: String.t(),
            arguments: String.t()
          }

    defstruct [:name, :arguments]

    @doc """
    Create a tool call function from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        name: Map.get(data, "name"),
        arguments: Map.get(data, "arguments")
      }
    end

    @doc """
    Convert a tool call function to a map.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = function) do
      %{
        "name" => function.name,
        "arguments" => function.arguments
      }
    end
  end

  defmodule ChatCompletion do
    @moduledoc """
    Represents a chat completion response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            created: integer(),
            model: String.t(),
            choices: list(ChatCompletionChoice.t()),
            usage: Usage.t() | nil
          }

    defstruct [:id, :object, :created, :model, :choices, :usage]

    @doc """
    Create a chat completion from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        created: Map.get(data, "created"),
        model: Map.get(data, "model"),
        choices: parse_choices(Map.get(data, "choices", [])),
        usage: parse_usage(Map.get(data, "usage"))
      }
    end

    defp parse_choices(choices) when is_list(choices) do
      Enum.map(choices, &MistralClient.Models.ChatCompletionChoice.from_map/1)
    end

    defp parse_usage(nil), do: nil
    defp parse_usage(usage), do: MistralClient.Models.Usage.from_map(usage)
  end

  defmodule ChatCompletionChoice do
    @moduledoc """
    Represents a choice in a chat completion response.
    """
    @type t :: %__MODULE__{
            index: integer(),
            message: Message.t(),
            delta: map() | nil,
            finish_reason: String.t() | nil
          }

    defstruct [:index, :message, :delta, :finish_reason]

    @doc """
    Create a chat completion choice from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        index: Map.get(data, "index"),
        message: parse_message(Map.get(data, "message")),
        delta: Map.get(data, "delta"),
        finish_reason: Map.get(data, "finish_reason")
      }
    end

    defp parse_message(nil), do: nil
    defp parse_message(message), do: MistralClient.Models.Message.from_map(message)
  end

  defmodule Usage do
    @moduledoc """
    Represents token usage information.
    """
    @type t :: %__MODULE__{
            prompt_tokens: integer(),
            completion_tokens: integer(),
            total_tokens: integer()
          }

    defstruct [:prompt_tokens, :completion_tokens, :total_tokens]

    @doc """
    Create usage information from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        prompt_tokens: Map.get(data, "prompt_tokens"),
        completion_tokens: Map.get(data, "completion_tokens"),
        total_tokens: Map.get(data, "total_tokens")
      }
    end
  end

  defmodule EmbeddingResponse do
    @moduledoc """
    Represents an embedding response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            data: list(Embedding.t()),
            model: String.t(),
            usage: Usage.t() | nil
          }

    defstruct [:id, :object, :data, :model, :usage]

    @doc """
    Create an embedding response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        data: parse_embeddings(Map.get(data, "data", [])),
        model: Map.get(data, "model"),
        usage: parse_usage(Map.get(data, "usage"))
      }
    end

    defp parse_embeddings(embeddings) when is_list(embeddings) do
      Enum.map(embeddings, &MistralClient.Models.Embedding.from_map/1)
    end

    defp parse_usage(nil), do: nil
    defp parse_usage(usage), do: MistralClient.Models.Usage.from_map(usage)
  end

  defmodule Embedding do
    @moduledoc """
    Represents an individual embedding.
    """
    @type t :: %__MODULE__{
            object: String.t(),
            embedding: list(float()),
            index: integer()
          }

    defstruct [:object, :embedding, :index]

    @doc """
    Create an embedding from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        object: Map.get(data, "object"),
        embedding: Map.get(data, "embedding"),
        index: Map.get(data, "index")
      }
    end
  end

  defmodule Model do
    @moduledoc """
    Represents model information.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            created: integer(),
            owned_by: String.t(),
            root: String.t() | nil,
            parent: String.t() | nil,
            permission: list(ModelPermission.t()) | nil
          }

    defstruct [:id, :object, :created, :owned_by, :root, :parent, :permission]

    @doc """
    Create a model from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        created: Map.get(data, "created"),
        owned_by: Map.get(data, "owned_by"),
        root: Map.get(data, "root"),
        parent: Map.get(data, "parent"),
        permission: parse_permissions(Map.get(data, "permission"))
      }
    end

    defp parse_permissions(nil), do: nil

    defp parse_permissions(permissions) when is_list(permissions) do
      Enum.map(permissions, &MistralClient.Models.ModelPermission.from_map/1)
    end
  end

  defmodule ModelPermission do
    @moduledoc """
    Represents model access permissions.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            created: integer(),
            allow_create_engine: boolean(),
            allow_sampling: boolean(),
            allow_logprobs: boolean(),
            allow_search_indices: boolean(),
            allow_view: boolean(),
            allow_fine_tuning: boolean(),
            organization: String.t(),
            group: String.t() | nil,
            is_blocking: boolean()
          }

    defstruct [
      :id,
      :object,
      :created,
      :allow_create_engine,
      :allow_sampling,
      :allow_logprobs,
      :allow_search_indices,
      :allow_view,
      :allow_fine_tuning,
      :organization,
      :group,
      :is_blocking
    ]

    @doc """
    Create a model permission from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        created: Map.get(data, "created"),
        allow_create_engine: Map.get(data, "allow_create_engine"),
        allow_sampling: Map.get(data, "allow_sampling"),
        allow_logprobs: Map.get(data, "allow_logprobs"),
        allow_search_indices: Map.get(data, "allow_search_indices"),
        allow_view: Map.get(data, "allow_view"),
        allow_fine_tuning: Map.get(data, "allow_fine_tuning"),
        organization: Map.get(data, "organization"),
        group: Map.get(data, "group"),
        is_blocking: Map.get(data, "is_blocking")
      }
    end
  end

  defmodule File do
    @moduledoc """
    Represents file metadata.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            bytes: integer(),
            created_at: integer(),
            filename: String.t(),
            purpose: String.t(),
            sample_type: String.t() | nil,
            num_lines: integer() | nil,
            source: String.t() | nil
          }

    defstruct [
      :id,
      :object,
      :bytes,
      :created_at,
      :filename,
      :purpose,
      :sample_type,
      :num_lines,
      :source
    ]

    @doc """
    Create a file from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        bytes: Map.get(data, "bytes"),
        created_at: Map.get(data, "created_at"),
        filename: Map.get(data, "filename"),
        purpose: Map.get(data, "purpose"),
        sample_type: Map.get(data, "sample_type"),
        num_lines: Map.get(data, "num_lines"),
        source: Map.get(data, "source")
      }
    end
  end

  defmodule FileUpload do
    @moduledoc """
    Represents a file upload response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            bytes: integer(),
            created_at: integer(),
            filename: String.t(),
            purpose: String.t()
          }

    defstruct [:id, :object, :bytes, :created_at, :filename, :purpose]

    @doc """
    Create a file upload response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        bytes: Map.get(data, "bytes"),
        created_at: Map.get(data, "created_at"),
        filename: Map.get(data, "filename"),
        purpose: Map.get(data, "purpose")
      }
    end
  end

  defmodule FileList do
    @moduledoc """
    Represents a list of files response with pagination.
    """
    @type t :: %__MODULE__{
            object: String.t() | nil,
            data: list(File.t()),
            has_more: boolean() | nil,
            total: integer() | nil
          }

    defstruct [:object, :data, :has_more, :total]

    @doc """
    Create a file list from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        object: Map.get(data, "object"),
        data: parse_files(Map.get(data, "data", [])),
        has_more: Map.get(data, "has_more"),
        total: Map.get(data, "total")
      }
    end

    defp parse_files(files) when is_list(files) do
      Enum.map(files, &File.from_map/1)
    end

    defp parse_files(_), do: []
  end

  defmodule DeleteFileOut do
    @moduledoc """
    Represents a delete file response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t() | nil,
            deleted: boolean() | nil
          }

    defstruct [:id, :object, :deleted]

    @doc """
    Create a delete file response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        deleted: Map.get(data, "deleted")
      }
    end
  end

  defmodule FileSignedURL do
    @moduledoc """
    Represents a file signed URL response.
    """
    @type t :: %__MODULE__{
            signed_url: String.t(),
            expires_at: integer() | nil
          }

    defstruct [:signed_url, :expires_at]

    @doc """
    Create a file signed URL from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        signed_url: Map.get(data, "signed_url"),
        expires_at: Map.get(data, "expires_at")
      }
    end
  end

  defmodule ModelCapabilities do
    @moduledoc """
    Represents model capabilities.
    """
    @type t :: %__MODULE__{
            completion_chat: boolean() | nil,
            completion_fim: boolean() | nil,
            function_calling: boolean() | nil,
            fine_tuning: boolean() | nil,
            vision: boolean() | nil
          }

    defstruct [:completion_chat, :completion_fim, :function_calling, :fine_tuning, :vision]

    @doc """
    Create model capabilities from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        completion_chat: Map.get(data, "completion_chat"),
        completion_fim: Map.get(data, "completion_fim"),
        function_calling: Map.get(data, "function_calling"),
        fine_tuning: Map.get(data, "fine_tuning"),
        vision: Map.get(data, "vision")
      }
    end
  end

  defmodule BaseModelCard do
    @moduledoc """
    Represents a base model card.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            capabilities: ModelCapabilities.t(),
            object: String.t() | nil,
            created: integer() | nil,
            owned_by: String.t() | nil,
            name: String.t() | nil,
            description: String.t() | nil,
            max_context_length: integer() | nil,
            aliases: list(String.t()) | nil,
            deprecation: String.t() | nil,
            default_model_temperature: float() | nil,
            type: String.t() | nil
          }

    defstruct [
      :id,
      :capabilities,
      :object,
      :created,
      :owned_by,
      :name,
      :description,
      :max_context_length,
      :aliases,
      :deprecation,
      :default_model_temperature,
      :type
    ]

    @doc """
    Create a base model card from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        capabilities: parse_capabilities(Map.get(data, "capabilities")),
        object: Map.get(data, "object"),
        created: Map.get(data, "created"),
        owned_by: Map.get(data, "owned_by"),
        name: Map.get(data, "name"),
        description: Map.get(data, "description"),
        max_context_length: Map.get(data, "max_context_length"),
        aliases: Map.get(data, "aliases"),
        deprecation: Map.get(data, "deprecation"),
        default_model_temperature: Map.get(data, "default_model_temperature"),
        type: Map.get(data, "type")
      }
    end

    defp parse_capabilities(nil), do: nil
    defp parse_capabilities(capabilities), do: ModelCapabilities.from_map(capabilities)
  end

  defmodule FTModelCard do
    @moduledoc """
    Represents a fine-tuned model card.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            capabilities: ModelCapabilities.t(),
            job: String.t(),
            root: String.t(),
            object: String.t() | nil,
            created: integer() | nil,
            owned_by: String.t() | nil,
            name: String.t() | nil,
            description: String.t() | nil,
            max_context_length: integer() | nil,
            aliases: list(String.t()) | nil,
            deprecation: String.t() | nil,
            default_model_temperature: float() | nil,
            type: String.t() | nil,
            archived: boolean() | nil
          }

    defstruct [
      :id,
      :capabilities,
      :job,
      :root,
      :object,
      :created,
      :owned_by,
      :name,
      :description,
      :max_context_length,
      :aliases,
      :deprecation,
      :default_model_temperature,
      :type,
      :archived
    ]

    @doc """
    Create a fine-tuned model card from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        capabilities: parse_capabilities(Map.get(data, "capabilities")),
        job: Map.get(data, "job"),
        root: Map.get(data, "root"),
        object: Map.get(data, "object"),
        created: Map.get(data, "created"),
        owned_by: Map.get(data, "owned_by"),
        name: Map.get(data, "name"),
        description: Map.get(data, "description"),
        max_context_length: Map.get(data, "max_context_length"),
        aliases: Map.get(data, "aliases"),
        deprecation: Map.get(data, "deprecation"),
        default_model_temperature: Map.get(data, "default_model_temperature"),
        type: Map.get(data, "type"),
        archived: Map.get(data, "archived")
      }
    end

    defp parse_capabilities(nil), do: nil
    defp parse_capabilities(capabilities), do: ModelCapabilities.from_map(capabilities)
  end

  defmodule ModelList do
    @moduledoc """
    Represents a list of models response.
    """
    @type t :: %__MODULE__{
            object: String.t() | nil,
            data: list(BaseModelCard.t() | FTModelCard.t())
          }

    defstruct [:object, :data]

    @doc """
    Create a model list from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        object: Map.get(data, "object"),
        data: parse_models(Map.get(data, "data", []))
      }
    end

    defp parse_models(models) when is_list(models) do
      Enum.map(models, &parse_model/1)
    end

    defp parse_model(%{"job" => _} = model_data) do
      FTModelCard.from_map(model_data)
    end

    defp parse_model(model_data) do
      BaseModelCard.from_map(model_data)
    end
  end

  defmodule DeleteModelOut do
    @moduledoc """
    Represents a delete model response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t() | nil,
            deleted: boolean() | nil
          }

    defstruct [:id, :object, :deleted]

    @doc """
    Create a delete model response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        deleted: Map.get(data, "deleted")
      }
    end
  end

  defmodule ArchiveFTModelOut do
    @moduledoc """
    Represents an archive fine-tuned model response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t() | nil,
            archived: boolean() | nil
          }

    defstruct [:id, :object, :archived]

    @doc """
    Create an archive model response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        archived: Map.get(data, "archived")
      }
    end
  end

  defmodule UnarchiveFTModelOut do
    @moduledoc """
    Represents an unarchive fine-tuned model response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t() | nil,
            archived: boolean() | nil
          }

    defstruct [:id, :object, :archived]

    @doc """
    Create an unarchive model response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        archived: Map.get(data, "archived")
      }
    end
  end

  defmodule FIMCompletionRequest do
    @moduledoc """
    Represents a FIM (Fill-in-the-Middle) completion request.
    """
    @type t :: %__MODULE__{
            model: String.t(),
            prompt: String.t(),
            suffix: String.t() | nil,
            temperature: float() | nil,
            top_p: float() | nil,
            max_tokens: integer() | nil,
            min_tokens: integer() | nil,
            stream: boolean() | nil,
            stop: String.t() | list(String.t()) | nil,
            random_seed: integer() | nil
          }

    defstruct [
      :model,
      :prompt,
      :suffix,
      :temperature,
      :top_p,
      :max_tokens,
      :min_tokens,
      :stream,
      :stop,
      :random_seed
    ]

    @doc """
    Create a new FIM completion request.
    """
    @spec new(String.t(), String.t(), keyword()) :: t()
    def new(model, prompt, opts \\ []) do
      %__MODULE__{
        model: model,
        prompt: prompt,
        suffix: Keyword.get(opts, :suffix),
        temperature: Keyword.get(opts, :temperature),
        top_p: Keyword.get(opts, :top_p),
        max_tokens: Keyword.get(opts, :max_tokens),
        min_tokens: Keyword.get(opts, :min_tokens),
        stream: Keyword.get(opts, :stream),
        stop: Keyword.get(opts, :stop),
        random_seed: Keyword.get(opts, :random_seed)
      }
    end

    @doc """
    Convert a FIM completion request to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = request) do
      request
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end
  end

  defmodule FIMCompletionResponse do
    @moduledoc """
    Represents a FIM completion response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            created: integer(),
            model: String.t(),
            choices: list(FIMCompletionChoice.t()),
            usage: Usage.t() | nil
          }

    defstruct [:id, :object, :created, :model, :choices, :usage]

    @doc """
    Create a FIM completion response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object"),
        created: Map.get(data, "created"),
        model: Map.get(data, "model"),
        choices: parse_fim_choices(Map.get(data, "choices", [])),
        usage: parse_usage(Map.get(data, "usage"))
      }
    end

    defp parse_fim_choices(choices) when is_list(choices) do
      Enum.map(choices, &MistralClient.Models.FIMCompletionChoice.from_map/1)
    end

    defp parse_usage(nil), do: nil
    defp parse_usage(usage), do: Usage.from_map(usage)
  end

  defmodule FIMCompletionChoice do
    @moduledoc """
    Represents a choice in a FIM completion response.
    """
    @type t :: %__MODULE__{
            index: integer(),
            message: FIMCompletionMessage.t(),
            delta: map() | nil,
            finish_reason: String.t() | nil
          }

    defstruct [:index, :message, :delta, :finish_reason]

    @doc """
    Create a FIM completion choice from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        index: Map.get(data, "index"),
        message: parse_fim_message(Map.get(data, "message")),
        delta: Map.get(data, "delta"),
        finish_reason: Map.get(data, "finish_reason")
      }
    end

    defp parse_fim_message(nil), do: nil

    defp parse_fim_message(message),
      do: MistralClient.Models.FIMCompletionMessage.from_map(message)
  end

  defmodule FIMCompletionMessage do
    @moduledoc """
    Represents a message in a FIM completion response.
    """
    @type t :: %__MODULE__{
            role: String.t(),
            content: String.t() | nil
          }

    defstruct [:role, :content]

    @doc """
    Create a FIM completion message from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        role: Map.get(data, "role"),
        content: Map.get(data, "content")
      }
    end
  end

  # Fine-tuning Models

  defmodule CompletionTrainingParameters do
    @moduledoc """
    Represents completion training hyperparameters for fine-tuning.
    """
    @type t :: %__MODULE__{
            training_steps: integer() | nil,
            learning_rate: float() | nil,
            weight_decay: float() | nil,
            warmup_fraction: float() | nil,
            epochs: float() | nil,
            seq_len: integer() | nil,
            fim_ratio: float() | nil
          }

    defstruct [
      :training_steps,
      :learning_rate,
      :weight_decay,
      :warmup_fraction,
      :epochs,
      :seq_len,
      :fim_ratio
    ]

    @doc """
    Create new completion training parameters.
    """
    @spec new(keyword()) :: t()
    def new(opts \\ []) do
      %__MODULE__{
        training_steps: Keyword.get(opts, :training_steps),
        learning_rate: Keyword.get(opts, :learning_rate, 0.0001),
        weight_decay: Keyword.get(opts, :weight_decay),
        warmup_fraction: Keyword.get(opts, :warmup_fraction),
        epochs: Keyword.get(opts, :epochs),
        seq_len: Keyword.get(opts, :seq_len),
        fim_ratio: Keyword.get(opts, :fim_ratio)
      }
    end

    @doc """
    Create completion training parameters from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        training_steps: Map.get(data, "training_steps"),
        learning_rate: Map.get(data, "learning_rate"),
        weight_decay: Map.get(data, "weight_decay"),
        warmup_fraction: Map.get(data, "warmup_fraction"),
        epochs: Map.get(data, "epochs"),
        seq_len: Map.get(data, "seq_len"),
        fim_ratio: Map.get(data, "fim_ratio")
      }
    end
  end

  defmodule TrainingFile do
    @moduledoc """
    Represents a training file for fine-tuning.
    """
    @type t :: %__MODULE__{
            file_id: String.t(),
            weight: float() | nil
          }

    defstruct [:file_id, :weight]

    @doc """
    Create a new training file.
    """
    @spec new(String.t(), keyword()) :: t()
    def new(file_id, opts \\ []) do
      %__MODULE__{
        file_id: file_id,
        weight: Keyword.get(opts, :weight)
      }
    end

    @doc """
    Create a training file from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        file_id: Map.get(data, "file_id"),
        weight: Map.get(data, "weight")
      }
    end
  end

  defmodule WandbIntegration do
    @moduledoc """
    Represents a Weights & Biases integration for fine-tuning.
    """
    @type t :: %__MODULE__{
            type: String.t(),
            project: String.t(),
            name: String.t() | nil,
            api_key: String.t() | nil
          }

    defstruct [:type, :project, :name, :api_key]

    @doc """
    Create a new Weights & Biases integration.
    """
    @spec new(String.t(), keyword()) :: t()
    def new(project, opts \\ []) do
      %__MODULE__{
        type: "wandb",
        project: project,
        name: Keyword.get(opts, :name),
        api_key: Keyword.get(opts, :api_key)
      }
    end

    @doc """
    Create a Weights & Biases integration from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        type: Map.get(data, "type"),
        project: Map.get(data, "project"),
        name: Map.get(data, "name"),
        api_key: Map.get(data, "api_key")
      }
    end
  end

  defmodule GithubRepository do
    @moduledoc """
    Represents a GitHub repository for fine-tuning.
    """
    @type t :: %__MODULE__{
            type: String.t(),
            name: String.t(),
            owner: String.t(),
            ref: String.t() | nil,
            weight: float() | nil,
            commit_id: String.t() | nil
          }

    defstruct [:type, :name, :owner, :ref, :weight, :commit_id]

    @doc """
    Create a new GitHub repository.
    """
    @spec new(String.t(), String.t(), keyword()) :: t()
    def new(owner, name, opts \\ []) do
      %__MODULE__{
        type: "github",
        name: name,
        owner: owner,
        ref: Keyword.get(opts, :ref),
        weight: Keyword.get(opts, :weight),
        commit_id: Keyword.get(opts, :commit_id)
      }
    end

    @doc """
    Create a GitHub repository from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        type: Map.get(data, "type"),
        name: Map.get(data, "name"),
        owner: Map.get(data, "owner"),
        ref: Map.get(data, "ref"),
        weight: Map.get(data, "weight"),
        commit_id: Map.get(data, "commit_id")
      }
    end
  end

  defmodule FineTuningJobRequest do
    @moduledoc """
    Represents a fine-tuning job creation request.
    """
    @type t :: %__MODULE__{
            model: String.t(),
            hyperparameters: CompletionTrainingParameters.t(),
            training_files: list(TrainingFile.t()) | nil,
            validation_files: list(String.t()) | nil,
            suffix: String.t() | nil,
            integrations: list(WandbIntegration.t()) | nil,
            auto_start: boolean() | nil,
            invalid_sample_skip_percentage: float() | nil,
            job_type: atom() | nil,
            repositories: list(GithubRepository.t()) | nil,
            classifier_targets: list(map()) | nil
          }

    defstruct [
      :model,
      :hyperparameters,
      :training_files,
      :validation_files,
      :suffix,
      :integrations,
      :auto_start,
      :invalid_sample_skip_percentage,
      :job_type,
      :repositories,
      :classifier_targets
    ]

    @doc """
    Create a new fine-tuning job request.
    """
    @spec new(String.t(), CompletionTrainingParameters.t(), keyword()) :: t()
    def new(model, hyperparameters, opts \\ []) do
      %__MODULE__{
        model: model,
        hyperparameters: hyperparameters,
        training_files: Keyword.get(opts, :training_files),
        validation_files: Keyword.get(opts, :validation_files),
        suffix: Keyword.get(opts, :suffix),
        integrations: Keyword.get(opts, :integrations),
        auto_start: Keyword.get(opts, :auto_start),
        invalid_sample_skip_percentage: Keyword.get(opts, :invalid_sample_skip_percentage, 0.0),
        job_type: Keyword.get(opts, :job_type),
        repositories: Keyword.get(opts, :repositories),
        classifier_targets: Keyword.get(opts, :classifier_targets)
      }
    end
  end

  defmodule FineTuningJobResponse do
    @moduledoc """
    Represents a fine-tuning job response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            auto_start: boolean(),
            model: String.t(),
            status: atom(),
            created_at: integer(),
            modified_at: integer(),
            training_files: list(String.t()),
            validation_files: list(String.t()) | nil,
            object: String.t() | nil,
            fine_tuned_model: String.t() | nil,
            suffix: String.t() | nil,
            integrations: list(WandbIntegration.t()) | nil,
            trained_tokens: integer() | nil,
            metadata: map() | nil,
            job_type: atom() | nil,
            repositories: list(GithubRepository.t()) | nil,
            events: list(map()) | nil,
            checkpoints: list(map()) | nil,
            hyperparameters: CompletionTrainingParameters.t() | nil
          }

    defstruct [
      :id,
      :auto_start,
      :model,
      :status,
      :created_at,
      :modified_at,
      :training_files,
      :validation_files,
      :object,
      :fine_tuned_model,
      :suffix,
      :integrations,
      :trained_tokens,
      :metadata,
      :job_type,
      :repositories,
      :events,
      :checkpoints,
      :hyperparameters
    ]

    @doc """
    Create a fine-tuning job response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        auto_start: Map.get(data, "auto_start"),
        model: Map.get(data, "model"),
        status: parse_status(Map.get(data, "status")),
        created_at: Map.get(data, "created_at"),
        modified_at: Map.get(data, "modified_at"),
        training_files: Map.get(data, "training_files", []),
        validation_files: Map.get(data, "validation_files"),
        object: Map.get(data, "object"),
        fine_tuned_model: Map.get(data, "fine_tuned_model"),
        suffix: Map.get(data, "suffix"),
        integrations: parse_integrations(Map.get(data, "integrations")),
        trained_tokens: Map.get(data, "trained_tokens"),
        metadata: Map.get(data, "metadata"),
        job_type: parse_job_type(Map.get(data, "job_type")),
        repositories: parse_repositories(Map.get(data, "repositories")),
        events: Map.get(data, "events"),
        checkpoints: Map.get(data, "checkpoints"),
        hyperparameters: parse_hyperparameters(Map.get(data, "hyperparameters"))
      }
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
      Enum.map(integrations, &WandbIntegration.from_map/1)
    end

    defp parse_repositories(nil), do: nil

    defp parse_repositories(repositories) when is_list(repositories) do
      Enum.map(repositories, &GithubRepository.from_map/1)
    end

    defp parse_hyperparameters(nil), do: nil
    defp parse_hyperparameters(params), do: CompletionTrainingParameters.from_map(params)
  end

  defmodule FineTuningJobsResponse do
    @moduledoc """
    Represents a list of fine-tuning jobs response.
    """
    @type t :: %__MODULE__{
            total: integer(),
            data: list(FineTuningJobResponse.t()),
            has_more: boolean() | nil,
            object: String.t() | nil
          }

    defstruct [:total, :data, :has_more, :object]

    @doc """
    Create a fine-tuning jobs response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        total: Map.get(data, "total"),
        data: parse_jobs(Map.get(data, "data", [])),
        has_more: Map.get(data, "has_more"),
        object: Map.get(data, "object")
      }
    end

    defp parse_jobs(jobs) when is_list(jobs) do
      Enum.map(jobs, &FineTuningJobResponse.from_map/1)
    end
  end

  # Batch API Models

  defmodule BatchError do
    @moduledoc """
    Represents an error in a batch job.
    """
    @type t :: %__MODULE__{
            message: String.t()
          }

    defstruct [:message]

    @doc """
    Create a batch error from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        message: Map.get(data, "message")
      }
    end

    @doc """
    Convert a batch error to a map.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = error) do
      %{
        "message" => error.message
      }
    end
  end

  defmodule BatchJobIn do
    @moduledoc """
    Represents a batch job creation request.
    """
    @type t :: %__MODULE__{
            input_files: list(String.t()),
            endpoint: String.t(),
            model: String.t(),
            metadata: map() | nil,
            timeout_hours: integer() | nil
          }

    defstruct [:input_files, :endpoint, :model, :metadata, :timeout_hours]

    @doc """
    Create a new batch job request.
    """
    @spec new(list(String.t()), String.t(), String.t(), keyword()) :: t()
    def new(input_files, endpoint, model, opts \\ []) do
      %__MODULE__{
        input_files: input_files,
        endpoint: endpoint,
        model: model,
        metadata: Keyword.get(opts, :metadata),
        timeout_hours: Keyword.get(opts, :timeout_hours, 24)
      }
    end

    @doc """
    Create a batch job request from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        input_files: Map.get(data, "input_files", []),
        endpoint: Map.get(data, "endpoint"),
        model: Map.get(data, "model"),
        metadata: Map.get(data, "metadata"),
        timeout_hours: Map.get(data, "timeout_hours", 24)
      }
    end

    @doc """
    Convert a batch job request to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = request) do
      request
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end
  end

  defmodule BatchJobOut do
    @moduledoc """
    Represents a batch job response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            input_files: list(String.t()),
            endpoint: String.t(),
            model: String.t(),
            errors: list(BatchError.t()),
            status: atom(),
            created_at: integer(),
            total_requests: integer(),
            completed_requests: integer(),
            succeeded_requests: integer(),
            failed_requests: integer(),
            object: String.t() | nil,
            metadata: map() | nil,
            output_file: String.t() | nil,
            error_file: String.t() | nil,
            started_at: integer() | nil,
            completed_at: integer() | nil
          }

    defstruct [
      :id,
      :input_files,
      :endpoint,
      :model,
      :errors,
      :status,
      :created_at,
      :total_requests,
      :completed_requests,
      :succeeded_requests,
      :failed_requests,
      :object,
      :metadata,
      :output_file,
      :error_file,
      :started_at,
      :completed_at
    ]

    @doc """
    Create a batch job response from a map.
    """
    @spec from_map(map()) :: {:ok, t()} | {:error, any()}
    def from_map(data) when is_map(data) do
      batch_job = %__MODULE__{
        id: Map.get(data, "id"),
        input_files: Map.get(data, "input_files", []),
        endpoint: Map.get(data, "endpoint"),
        model: Map.get(data, "model"),
        errors: parse_batch_errors(Map.get(data, "errors", [])),
        status: parse_batch_status(Map.get(data, "status")),
        created_at: Map.get(data, "created_at"),
        total_requests: Map.get(data, "total_requests"),
        completed_requests: Map.get(data, "completed_requests"),
        succeeded_requests: Map.get(data, "succeeded_requests"),
        failed_requests: Map.get(data, "failed_requests"),
        object: Map.get(data, "object"),
        metadata: Map.get(data, "metadata"),
        output_file: Map.get(data, "output_file"),
        error_file: Map.get(data, "error_file"),
        started_at: Map.get(data, "started_at"),
        completed_at: Map.get(data, "completed_at")
      }

      {:ok, batch_job}
    end

    defp parse_batch_errors(errors) when is_list(errors) do
      Enum.map(errors, &BatchError.from_map/1)
    end

    defp parse_batch_errors(_), do: []

    defp parse_batch_status(status) when is_binary(status) do
      case String.upcase(status) do
        "QUEUED" -> :queued
        "RUNNING" -> :running
        "SUCCESS" -> :success
        "FAILED" -> :failed
        "TIMEOUT_EXCEEDED" -> :timeout_exceeded
        "CANCELLATION_REQUESTED" -> :cancellation_requested
        "CANCELLED" -> :cancelled
        _ -> status
      end
    end

    defp parse_batch_status(status), do: status
  end

  defmodule BatchJobsOut do
    @moduledoc """
    Represents a list of batch jobs response.
    """
    @type t :: %__MODULE__{
            total: integer(),
            data: list(BatchJobOut.t()) | nil,
            object: String.t() | nil
          }

    defstruct [:total, :data, :object]

    @doc """
    Create a batch jobs response from a map.
    """
    @spec from_map(map()) :: {:ok, t()} | {:error, any()}
    def from_map(data) when is_map(data) do
      batch_jobs = %__MODULE__{
        total: Map.get(data, "total"),
        data: parse_batch_jobs(Map.get(data, "data", [])),
        object: Map.get(data, "object")
      }

      {:ok, batch_jobs}
    end

    defp parse_batch_jobs(jobs) when is_list(jobs) do
      Enum.map(jobs, fn job_data ->
        case BatchJobOut.from_map(job_data) do
          {:ok, job} -> job
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    end

    defp parse_batch_jobs(_), do: []
  end

  # OCR API Models

  defmodule DocumentURLChunk do
    @moduledoc """
    Represents a document URL chunk for OCR processing.
    """
    @type t :: %__MODULE__{
            document_url: String.t(),
            document_name: String.t() | nil,
            type: String.t() | nil
          }

    defstruct [:document_url, :document_name, :type]

    @doc """
    Create a new document URL chunk.
    """
    @spec new(String.t(), keyword()) :: t()
    def new(document_url, opts \\ []) do
      %__MODULE__{
        document_url: document_url,
        document_name: Keyword.get(opts, :document_name),
        type: Keyword.get(opts, :type, "document_url")
      }
    end

    @doc """
    Create a document URL chunk from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        document_url: Map.get(data, "document_url"),
        document_name: Map.get(data, "document_name"),
        type: Map.get(data, "type")
      }
    end

    @doc """
    Convert a document URL chunk to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = chunk) do
      chunk
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end
  end

  defmodule ImageURLChunkImageURL do
    @moduledoc """
    Represents an image URL within an image URL chunk.
    """
    @type t :: %__MODULE__{
            url: String.t()
          }

    defstruct [:url]

    @doc """
    Create a new image URL.
    """
    @spec new(String.t()) :: t()
    def new(url) do
      %__MODULE__{
        url: url
      }
    end

    @doc """
    Create an image URL from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        url: Map.get(data, "url")
      }
    end

    @doc """
    Convert an image URL to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = image_url) do
      %{
        "url" => image_url.url
      }
    end
  end

  defmodule ImageURLChunk do
    @moduledoc """
    Represents an image URL chunk for OCR processing.
    """
    @type t :: %__MODULE__{
            image_url: ImageURLChunkImageURL.t(),
            type: String.t() | nil
          }

    defstruct [:image_url, :type]

    @doc """
    Create a new image URL chunk.
    """
    @spec new(ImageURLChunkImageURL.t(), keyword()) :: t()
    def new(image_url, opts \\ []) do
      %__MODULE__{
        image_url: image_url,
        type: Keyword.get(opts, :type, "image_url")
      }
    end

    @doc """
    Create an image URL chunk from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        image_url: parse_image_url(Map.get(data, "image_url")),
        type: Map.get(data, "type")
      }
    end

    @doc """
    Convert an image URL chunk to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = chunk) do
      chunk_map = %{
        "image_url" => ImageURLChunkImageURL.to_map(chunk.image_url)
      }

      if chunk.type do
        Map.put(chunk_map, "type", chunk.type)
      else
        chunk_map
      end
    end

    defp parse_image_url(nil), do: nil
    defp parse_image_url(image_url), do: ImageURLChunkImageURL.from_map(image_url)
  end

  defmodule OCRPageDimensions do
    @moduledoc """
    Represents the dimensions of an OCR page.
    """
    @type t :: %__MODULE__{
            dpi: integer(),
            height: integer(),
            width: integer()
          }

    defstruct [:dpi, :height, :width]

    @doc """
    Create OCR page dimensions from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        dpi: Map.get(data, "dpi"),
        height: Map.get(data, "height"),
        width: Map.get(data, "width")
      }
    end
  end

  defmodule OCRImageObject do
    @moduledoc """
    Represents an extracted image object from OCR processing.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            top_left_x: integer() | nil,
            top_left_y: integer() | nil,
            bottom_right_x: integer() | nil,
            bottom_right_y: integer() | nil,
            image_base64: String.t() | nil,
            image_annotation: String.t() | nil
          }

    defstruct [
      :id,
      :top_left_x,
      :top_left_y,
      :bottom_right_x,
      :bottom_right_y,
      :image_base64,
      :image_annotation
    ]

    @doc """
    Create an OCR image object from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        top_left_x: Map.get(data, "top_left_x"),
        top_left_y: Map.get(data, "top_left_y"),
        bottom_right_x: Map.get(data, "bottom_right_x"),
        bottom_right_y: Map.get(data, "bottom_right_y"),
        image_base64: Map.get(data, "image_base64"),
        image_annotation: Map.get(data, "image_annotation")
      }
    end
  end

  defmodule OCRPageObject do
    @moduledoc """
    Represents a page object from OCR processing.
    """
    @type t :: %__MODULE__{
            index: integer(),
            markdown: String.t(),
            images: list(OCRImageObject.t()),
            dimensions: OCRPageDimensions.t() | nil
          }

    defstruct [:index, :markdown, :images, :dimensions]

    @doc """
    Create an OCR page object from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        index: Map.get(data, "index"),
        markdown: Map.get(data, "markdown"),
        images: parse_ocr_images(Map.get(data, "images", [])),
        dimensions: parse_ocr_dimensions(Map.get(data, "dimensions"))
      }
    end

    defp parse_ocr_images(images) when is_list(images) do
      Enum.map(images, &OCRImageObject.from_map/1)
    end

    defp parse_ocr_images(_), do: []

    defp parse_ocr_dimensions(nil), do: nil
    defp parse_ocr_dimensions(dimensions), do: OCRPageDimensions.from_map(dimensions)
  end

  defmodule OCRUsageInfo do
    @moduledoc """
    Represents usage information for OCR processing.
    """
    @type t :: %__MODULE__{
            pages_processed: integer(),
            doc_size_bytes: integer() | nil
          }

    defstruct [:pages_processed, :doc_size_bytes]

    @doc """
    Create OCR usage info from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        pages_processed: Map.get(data, "pages_processed"),
        doc_size_bytes: Map.get(data, "doc_size_bytes")
      }
    end
  end

  defmodule OCRResponse do
    @moduledoc """
    Represents an OCR processing response.
    """
    @type t :: %__MODULE__{
            pages: list(OCRPageObject.t()),
            model: String.t(),
            usage_info: OCRUsageInfo.t(),
            document_annotation: String.t() | nil
          }

    defstruct [:pages, :model, :usage_info, :document_annotation]

    @doc """
    Create an OCR response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        pages: parse_ocr_pages(Map.get(data, "pages", [])),
        model: Map.get(data, "model"),
        usage_info: parse_ocr_usage_info(Map.get(data, "usage_info")),
        document_annotation: Map.get(data, "document_annotation")
      }
    end

    defp parse_ocr_pages(pages) when is_list(pages) do
      Enum.map(pages, &OCRPageObject.from_map/1)
    end

    defp parse_ocr_pages(_), do: []

    defp parse_ocr_usage_info(nil), do: nil
    defp parse_ocr_usage_info(usage_info), do: OCRUsageInfo.from_map(usage_info)
  end

  defmodule OCRRequest do
    @moduledoc """
    Represents an OCR processing request.
    """
    @type document_type :: DocumentURLChunk.t() | ImageURLChunk.t()
    @type response_format :: map()

    @type t :: %__MODULE__{
            model: String.t(),
            document: document_type(),
            id: String.t() | nil,
            pages: list(integer()) | nil,
            include_image_base64: boolean() | nil,
            image_limit: integer() | nil,
            image_min_size: integer() | nil,
            bbox_annotation_format: response_format() | nil,
            document_annotation_format: response_format() | nil
          }

    defstruct [
      :model,
      :document,
      :id,
      :pages,
      :include_image_base64,
      :image_limit,
      :image_min_size,
      :bbox_annotation_format,
      :document_annotation_format
    ]

    @doc """
    Create a new OCR request.
    """
    @spec new(String.t(), document_type(), keyword()) :: t()
    def new(model, document, opts \\ []) do
      %__MODULE__{
        model: model,
        document: document,
        id: Keyword.get(opts, :id),
        pages: Keyword.get(opts, :pages),
        include_image_base64: Keyword.get(opts, :include_image_base64),
        image_limit: Keyword.get(opts, :image_limit),
        image_min_size: Keyword.get(opts, :image_min_size),
        bbox_annotation_format: Keyword.get(opts, :bbox_annotation_format),
        document_annotation_format: Keyword.get(opts, :document_annotation_format)
      }
    end

    @doc """
    Convert an OCR request to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = request) do
      base_map = %{
        "model" => request.model,
        "document" => document_to_map(request.document)
      }

      base_map
      |> add_if_present("id", request.id)
      |> add_if_present("pages", request.pages)
      |> add_if_present("include_image_base64", request.include_image_base64)
      |> add_if_present("image_limit", request.image_limit)
      |> add_if_present("image_min_size", request.image_min_size)
      |> add_if_present("bbox_annotation_format", request.bbox_annotation_format)
      |> add_if_present("document_annotation_format", request.document_annotation_format)
    end

    defp document_to_map(%DocumentURLChunk{} = doc), do: DocumentURLChunk.to_map(doc)
    defp document_to_map(%ImageURLChunk{} = doc), do: ImageURLChunk.to_map(doc)

    defp add_if_present(map, _key, nil), do: map
    defp add_if_present(map, key, value), do: Map.put(map, key, value)
  end

  # Classifiers API Models

  defmodule ClassificationRequest do
    @moduledoc """
    Represents a classification request.
    """
    @type t :: %__MODULE__{
            model: String.t(),
            inputs: String.t() | list(String.t())
          }

    defstruct [:model, :inputs]

    @doc """
    Create a new classification request.
    """
    @spec new(String.t(), String.t() | list(String.t())) :: t()
    def new(model, inputs) do
      %__MODULE__{
        model: model,
        inputs: inputs
      }
    end

    @doc """
    Convert a classification request to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = request) do
      %{
        "model" => request.model,
        "input" => request.inputs
      }
    end
  end

  defmodule ClassificationTargetResult do
    @moduledoc """
    Represents classification target results with scores.
    """
    @type t :: %__MODULE__{
            scores: map()
          }

    defstruct [:scores]

    @doc """
    Create classification target result from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        scores: Map.get(data, "scores", %{})
      }
    end
  end

  defmodule ClassificationResponse do
    @moduledoc """
    Represents a classification response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            model: String.t(),
            results: list(map())
          }

    defstruct [:id, :model, :results]

    @doc """
    Create a classification response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        model: Map.get(data, "model"),
        results: parse_classification_results(Map.get(data, "results", []))
      }
    end

    defp parse_classification_results(results) when is_list(results) do
      Enum.map(results, fn result ->
        if is_map(result) do
          result
          |> Enum.map(fn {k, v} ->
            {k, ClassificationTargetResult.from_map(v)}
          end)
          |> Map.new()
        else
          result
        end
      end)
    end

    defp parse_classification_results(_), do: []
  end

  defmodule ModerationObject do
    @moduledoc """
    Represents a moderation object with categories and scores.
    """
    @type t :: %__MODULE__{
            categories: map() | nil,
            category_scores: map() | nil
          }

    defstruct [:categories, :category_scores]

    @doc """
    Create a moderation object from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        categories: Map.get(data, "categories"),
        category_scores: Map.get(data, "category_scores")
      }
    end
  end

  defmodule ModerationResponse do
    @moduledoc """
    Represents a moderation response.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            model: String.t(),
            results: list(ModerationObject.t())
          }

    defstruct [:id, :model, :results]

    @doc """
    Create a moderation response from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        model: Map.get(data, "model"),
        results: parse_moderation_results(Map.get(data, "results", []))
      }
    end

    defp parse_moderation_results(results) when is_list(results) do
      Enum.map(results, &ModerationObject.from_map/1)
    end

    defp parse_moderation_results(_), do: []
  end

  defmodule ChatModerationRequest do
    @moduledoc """
    Represents a chat moderation request.
    """
    @type t :: %__MODULE__{
            model: String.t(),
            inputs: list(list(map()))
          }

    defstruct [:model, :inputs]

    @doc """
    Create a new chat moderation request.
    """
    @spec new(String.t(), list(list(map()))) :: t()
    def new(model, inputs) do
      %__MODULE__{
        model: model,
        inputs: inputs
      }
    end

    @doc """
    Convert a chat moderation request to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = request) do
      %{
        "model" => request.model,
        "input" => request.inputs
      }
    end
  end

  defmodule ChatClassificationRequest do
    @moduledoc """
    Represents a chat classification request.
    """
    @type t :: %__MODULE__{
            model: String.t(),
            inputs: list(map())
          }

    defstruct [:model, :inputs]

    @doc """
    Create a new chat classification request.
    """
    @spec new(String.t(), list(map())) :: t()
    def new(model, inputs) do
      %__MODULE__{
        model: model,
        inputs: inputs
      }
    end

    @doc """
    Convert a chat classification request to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = request) do
      %{
        "model" => request.model,
        "input" => request.inputs
      }
    end
  end
end
