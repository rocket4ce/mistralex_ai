defmodule MistralClient.Models.Beta do
  @moduledoc """
  Data models for Beta API features.

  This module contains all the data structures used by the Beta APIs,
  including agents, conversations, and related entities.
  """

  # Forward declarations for circular dependencies
  alias __MODULE__.{ConversationEntry, ToolFunction}

  defmodule Agent do
    @moduledoc """
    Represents an AI agent with specific instructions and capabilities.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            name: String.t(),
            model: String.t(),
            instructions: String.t() | nil,
            description: String.t() | nil,
            tools: list(map()) | nil,
            completion_args: map() | nil,
            handoffs: list(String.t()) | nil,
            version: integer(),
            created_at: DateTime.t(),
            updated_at: DateTime.t()
          }

    defstruct [
      :id,
      :object,
      :name,
      :model,
      :instructions,
      :description,
      :tools,
      :completion_args,
      :handoffs,
      :version,
      :created_at,
      :updated_at
    ]

    @doc """
    Create an Agent struct from a map response.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object", "agent"),
        name: Map.get(data, "name"),
        model: Map.get(data, "model"),
        instructions: Map.get(data, "instructions"),
        description: Map.get(data, "description"),
        tools: Map.get(data, "tools"),
        completion_args: Map.get(data, "completion_args"),
        handoffs: Map.get(data, "handoffs"),
        version: Map.get(data, "version", 0),
        created_at: parse_datetime(Map.get(data, "created_at")),
        updated_at: parse_datetime(Map.get(data, "updated_at"))
      }
    end

    def parse_datetime(nil), do: nil

    def parse_datetime(datetime_string) when is_binary(datetime_string) do
      case DateTime.from_iso8601(datetime_string) do
        {:ok, datetime, _} -> datetime
        _ -> nil
      end
    end

    def parse_datetime(_), do: nil
  end

  defmodule Conversation do
    @moduledoc """
    Represents a conversation entity with its configuration.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            name: String.t() | nil,
            description: String.t() | nil,
            model: String.t() | nil,
            instructions: String.t() | nil,
            tools: list(map()) | nil,
            completion_args: map() | nil,
            created_at: DateTime.t(),
            updated_at: DateTime.t()
          }

    defstruct [
      :id,
      :object,
      :name,
      :description,
      :model,
      :instructions,
      :tools,
      :completion_args,
      :created_at,
      :updated_at
    ]

    @doc """
    Create a Conversation struct from a map response.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object", "conversation"),
        name: Map.get(data, "name"),
        description: Map.get(data, "description"),
        model: Map.get(data, "model"),
        instructions: Map.get(data, "instructions"),
        tools: Map.get(data, "tools"),
        completion_args: Map.get(data, "completion_args"),
        created_at: Agent.parse_datetime(Map.get(data, "created_at")),
        updated_at: Agent.parse_datetime(Map.get(data, "updated_at"))
      }
    end
  end

  defmodule ConversationResponse do
    @moduledoc """
    Represents the response from conversation operations.
    """

    @type t :: %__MODULE__{
            object: String.t(),
            conversation_id: String.t(),
            outputs: list(ConversationEntry.t()),
            usage: map() | nil
          }

    defstruct [
      :object,
      :conversation_id,
      :outputs,
      :usage
    ]

    @doc """
    Create a ConversationResponse struct from a map response.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        object: Map.get(data, "object", "conversation.response"),
        conversation_id: Map.get(data, "conversation_id"),
        outputs: parse_outputs(Map.get(data, "outputs", [])),
        usage: Map.get(data, "usage")
      }
    end

    defp parse_outputs(outputs) when is_list(outputs) do
      Enum.map(outputs, &ConversationEntry.from_map/1)
    end

    defp parse_outputs(_), do: []
  end

  defmodule ConversationEntry do
    @moduledoc """
    Represents an entry in a conversation (message, function call, etc.).
    """

    @type t :: %__MODULE__{
            id: String.t(),
            object: String.t(),
            type: String.t(),
            role: String.t() | nil,
            content: String.t() | nil,
            agent_id: String.t() | nil,
            model: String.t() | nil,
            created_at: DateTime.t() | nil,
            completed_at: DateTime.t() | nil
          }

    defstruct [
      :id,
      :object,
      :type,
      :role,
      :content,
      :agent_id,
      :model,
      :created_at,
      :completed_at
    ]

    @doc """
    Create a ConversationEntry struct from a map response.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: Map.get(data, "id"),
        object: Map.get(data, "object", "entry"),
        type: Map.get(data, "type"),
        role: Map.get(data, "role"),
        content: Map.get(data, "content"),
        agent_id: Map.get(data, "agent_id"),
        model: Map.get(data, "model"),
        created_at: Agent.parse_datetime(Map.get(data, "created_at")),
        completed_at: Agent.parse_datetime(Map.get(data, "completed_at"))
      }
    end
  end

  defmodule ConversationHistory do
    @moduledoc """
    Represents the history of a conversation with all entries.
    """

    @type t :: %__MODULE__{
            object: String.t(),
            conversation_id: String.t(),
            entries: list(ConversationEntry.t()) | nil,
            messages: list(ConversationEntry.t()) | nil
          }

    defstruct [
      :object,
      :conversation_id,
      :entries,
      :messages
    ]

    @doc """
    Create a ConversationHistory struct from a map response.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        object: Map.get(data, "object"),
        conversation_id: Map.get(data, "conversation_id"),
        entries: parse_entries(Map.get(data, "entries")),
        messages: parse_entries(Map.get(data, "messages"))
      }
    end

    defp parse_entries(nil), do: nil

    defp parse_entries(entries) when is_list(entries) do
      Enum.map(entries, &ConversationEntry.from_map/1)
    end

    defp parse_entries(_), do: nil
  end

  defmodule CompletionArgs do
    @moduledoc """
    Represents completion arguments for agents and conversations.
    """

    @type t :: %__MODULE__{
            temperature: float() | nil,
            top_p: float() | nil,
            max_tokens: integer() | nil,
            stop: String.t() | list(String.t()) | nil,
            random_seed: integer() | nil,
            presence_penalty: float() | nil,
            frequency_penalty: float() | nil,
            response_format: map() | nil,
            tool_choice: String.t() | map() | nil,
            prediction: map() | nil
          }

    defstruct [
      :temperature,
      :top_p,
      :max_tokens,
      :stop,
      :random_seed,
      :presence_penalty,
      :frequency_penalty,
      :response_format,
      :tool_choice,
      :prediction
    ]

    @doc """
    Create a CompletionArgs struct from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        temperature: Map.get(data, "temperature"),
        top_p: Map.get(data, "top_p"),
        max_tokens: Map.get(data, "max_tokens"),
        stop: Map.get(data, "stop"),
        random_seed: Map.get(data, "random_seed"),
        presence_penalty: Map.get(data, "presence_penalty"),
        frequency_penalty: Map.get(data, "frequency_penalty"),
        response_format: Map.get(data, "response_format"),
        tool_choice: Map.get(data, "tool_choice"),
        prediction: Map.get(data, "prediction")
      }
    end

    @doc """
    Convert a CompletionArgs struct to a map for API requests.
    """
    @spec to_map(t()) :: map()
    def to_map(%__MODULE__{} = args) do
      args
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end
  end

  defmodule Tool do
    @moduledoc """
    Represents a tool that can be used by agents.
    """

    @type t :: %__MODULE__{
            type: String.t(),
            function: ToolFunction.t() | nil
          }

    defstruct [
      :type,
      :function
    ]

    @doc """
    Create a Tool struct from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        type: Map.get(data, "type"),
        function: parse_function(Map.get(data, "function"))
      }
    end

    defp parse_function(nil), do: nil

    defp parse_function(function_data) when is_map(function_data) do
      ToolFunction.from_map(function_data)
    end

    defp parse_function(_), do: nil
  end

  defmodule ToolFunction do
    @moduledoc """
    Represents a function tool definition.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            description: String.t() | nil,
            parameters: map() | nil,
            strict: boolean() | nil
          }

    defstruct [
      :name,
      :description,
      :parameters,
      :strict
    ]

    @doc """
    Create a ToolFunction struct from a map.
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        name: Map.get(data, "name"),
        description: Map.get(data, "description"),
        parameters: Map.get(data, "parameters"),
        strict: Map.get(data, "strict")
      }
    end
  end
end
