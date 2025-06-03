defmodule MistralClient.API.Beta.Conversations do
  @moduledoc """
  Beta Conversations API for managing persistent conversations with agents.

  This module provides functionality to create, manage, and interact with conversations
  that can persist across multiple interactions and maintain context.

  ## Features

  - Start conversations with agents or models
  - Append messages to existing conversations
  - Retrieve conversation history and messages
  - Restart conversations from specific points
  - Stream conversation responses in real-time

  ## Usage

      config = MistralClient.Config.new()

      # Start a conversation with an agent
      {:ok, conversation} = start(config, %{
        agent_id: "agent_123",
        inputs: "Hello, I need help with my order."
      })

      # Append to the conversation
      {:ok, response} = append(config, conversation.conversation_id, %{
        inputs: "Can you check order #12345?"
      })

      # Get conversation history
      {:ok, history} = history(config, conversation.conversation_id)
  """

  alias MistralClient.{Client, Config, Stream}
  alias MistralClient.Models.Beta.{Conversation, ConversationResponse, ConversationHistory}

  @doc """
  Start a new conversation.

  ## Parameters

    * `config` - Client configuration
    * `request` - Conversation start request with:
      - `:inputs` - Initial message(s) (required)
      - `:agent_id` - Agent ID to use (optional, mutually exclusive with model)
      - `:model` - Model to use (optional, mutually exclusive with agent_id)
      - `:instructions` - Custom instructions (optional)
      - `:tools` - Tools available in conversation (optional)
      - `:completion_args` - Completion arguments (optional)
      - `:name` - Conversation name (optional)
      - `:description` - Conversation description (optional)
      - `:store` - Whether to store the conversation (optional, default: true)
      - `:handoff_execution` - Handoff execution mode (optional)

  ## Examples

      # Start with an agent
      {:ok, conversation} = start(config, %{
        agent_id: "agent_123",
        inputs: "Hello, how can you help me?"
      })

      # Start with a model
      {:ok, conversation} = start(config, %{
        model: "mistral-large-latest",
        inputs: "Explain quantum computing",
        instructions: "You are a physics teacher."
      })
  """
  @spec start(Config.t(), map()) :: {:ok, ConversationResponse.t()} | {:error, term()}
  def start(config, request) do
    client = get_or_create_client(config)

    with {:ok, validated_request} <- validate_start_request(request),
         {:ok, response} <-
           Client.request(client, :post, "/v1/conversations", validated_request, []) do
      {:ok, ConversationResponse.from_map(response)}
    end
  end

  @doc """
  Start a new conversation with streaming responses.

  ## Parameters

    * `config` - Client configuration
    * `request` - Conversation start request (same as start/2)
    * `callback` - Function to handle streaming chunks

  ## Examples

      start_stream(config, %{
        agent_id: "agent_123",
        inputs: "Tell me a story"
      }, fn chunk ->
        IO.write(chunk.content || "")
      end)
  """
  @spec start_stream(Config.t(), map(), function()) :: {:ok, term()} | {:error, term()}
  def start_stream(config, request, callback) when is_function(callback, 1) do
    validated_request = request |> Map.put(:stream, true)

    with {:ok, validated_request} <- validate_start_request(validated_request) do
      Stream.request_stream(config, :post, "/v1/conversations", validated_request, [], callback)
    end
  end

  @doc """
  List conversations with optional pagination.

  ## Parameters

    * `config` - Client configuration
    * `options` - Optional parameters:
      - `:page` - Page number (default: 0)
      - `:page_size` - Number of conversations per page (default: 100)

  ## Examples

      {:ok, conversations} = list(config)
      {:ok, conversations} = list(config, %{page: 1, page_size: 50})
  """
  @spec list(Config.t(), map()) :: {:ok, list(Conversation.t())} | {:error, term()}
  def list(config, options \\ %{}) do
    client = get_or_create_client(config)
    query_params = build_list_params(options)

    request_options = if query_params == [], do: [], else: [params: query_params]

    with {:ok, response} <-
           Client.request(client, :get, "/v1/conversations", %{}, request_options) do
      conversations = Enum.map(response, &Conversation.from_map/1)
      {:ok, conversations}
    end
  end

  @doc """
  Retrieve a specific conversation by ID.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID to retrieve

  ## Examples

      {:ok, conversation} = get(config, "conv_123")
  """
  @spec get(Config.t(), String.t()) :: {:ok, Conversation.t()} | {:error, term()}
  def get(config, conversation_id) when is_binary(conversation_id) do
    client = get_or_create_client(config)

    with {:ok, response} <-
           Client.request(client, :get, "/v1/conversations/#{conversation_id}", %{}, []) do
      {:ok, Conversation.from_map(response)}
    end
  end

  @doc """
  Append new entries to an existing conversation.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID
    * `request` - Append request with:
      - `:inputs` - New message(s) to append (required)
      - `:stream` - Whether to stream responses (optional, default: false)
      - `:store` - Whether to store results (optional, default: true)
      - `:handoff_execution` - Handoff execution mode (optional)
      - `:completion_args` - Completion arguments (optional)

  ## Examples

      {:ok, response} = append(config, conversation_id, %{
        inputs: "What's the weather like today?"
      })
  """
  @spec append(Config.t(), String.t(), map()) ::
          {:ok, ConversationResponse.t()} | {:error, term()}
  def append(config, conversation_id, request) when is_binary(conversation_id) do
    client = get_or_create_client(config)

    with {:ok, validated_request} <- validate_append_request(request),
         {:ok, response} <-
           Client.request(
             client,
             :post,
             "/v1/conversations/#{conversation_id}",
             validated_request,
             []
           ) do
      {:ok, ConversationResponse.from_map(response)}
    end
  end

  @doc """
  Append new entries to an existing conversation with streaming.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID
    * `request` - Append request (same as append/3)
    * `callback` - Function to handle streaming chunks

  ## Examples

      append_stream(config, conversation_id, %{
        inputs: "Continue the story"
      }, fn chunk ->
        IO.write(chunk.content || "")
      end)
  """
  @spec append_stream(Config.t(), String.t(), map(), function()) ::
          {:ok, term()} | {:error, term()}
  def append_stream(config, conversation_id, request, callback)
      when is_binary(conversation_id) and is_function(callback, 1) do
    validated_request = request |> Map.put(:stream, true)

    with {:ok, validated_request} <- validate_append_request(validated_request) do
      Stream.request_stream(
        config,
        :post,
        "/v1/conversations/#{conversation_id}",
        validated_request,
        [],
        callback
      )
    end
  end

  @doc """
  Retrieve all entries in a conversation.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID

  ## Examples

      {:ok, history} = history(config, conversation_id)
  """
  @spec history(Config.t(), String.t()) :: {:ok, ConversationHistory.t()} | {:error, term()}
  def history(config, conversation_id) when is_binary(conversation_id) do
    client = get_or_create_client(config)

    with {:ok, response} <-
           Client.request(client, :get, "/v1/conversations/#{conversation_id}/history", %{}, []) do
      {:ok, ConversationHistory.from_map(response)}
    end
  end

  @doc """
  Retrieve all messages in a conversation.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID

  ## Examples

      {:ok, messages} = messages(config, conversation_id)
  """
  @spec messages(Config.t(), String.t()) :: {:ok, ConversationHistory.t()} | {:error, term()}
  def messages(config, conversation_id) when is_binary(conversation_id) do
    client = get_or_create_client(config)

    with {:ok, response} <-
           Client.request(client, :get, "/v1/conversations/#{conversation_id}/messages", %{}, []) do
      {:ok, ConversationHistory.from_map(response)}
    end
  end

  @doc """
  Restart a conversation from a specific entry.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID
    * `request` - Restart request with:
      - `:inputs` - New message(s) (required)
      - `:from_entry_id` - Entry ID to restart from (required)
      - `:stream` - Whether to stream responses (optional, default: false)
      - `:store` - Whether to store results (optional, default: true)
      - `:handoff_execution` - Handoff execution mode (optional)
      - `:completion_args` - Completion arguments (optional)

  ## Examples

      {:ok, response} = restart(config, conversation_id, %{
        inputs: "Let's try a different approach",
        from_entry_id: "entry_456"
      })
  """
  @spec restart(Config.t(), String.t(), map()) ::
          {:ok, ConversationResponse.t()} | {:error, term()}
  def restart(config, conversation_id, request) when is_binary(conversation_id) do
    client = get_or_create_client(config)

    with {:ok, validated_request} <- validate_restart_request(request),
         {:ok, response} <-
           Client.request(
             client,
             :post,
             "/v1/conversations/#{conversation_id}/restart",
             validated_request,
             []
           ) do
      {:ok, ConversationResponse.from_map(response)}
    end
  end

  @doc """
  Restart a conversation from a specific entry with streaming.

  ## Parameters

    * `config` - Client configuration
    * `conversation_id` - The conversation ID
    * `request` - Restart request (same as restart/3)
    * `callback` - Function to handle streaming chunks

  ## Examples

      restart_stream(config, conversation_id, %{
        inputs: "Let's start over",
        from_entry_id: "entry_123"
      }, fn chunk ->
        IO.write(chunk.content || "")
      end)
  """
  @spec restart_stream(Config.t(), String.t(), map(), function()) ::
          {:ok, term()} | {:error, term()}
  def restart_stream(config, conversation_id, request, callback)
      when is_binary(conversation_id) and is_function(callback, 1) do
    validated_request = request |> Map.put(:stream, true)

    with {:ok, validated_request} <- validate_restart_request(validated_request) do
      Stream.request_stream(
        config,
        :post,
        "/v1/conversations/#{conversation_id}/restart",
        validated_request,
        [],
        callback
      )
    end
  end

  # Private helper functions

  defp get_or_create_client(config) when is_list(config) do
    Client.new(config)
  end

  defp get_or_create_client(%Client{} = client), do: client

  defp get_or_create_client(%Config{} = config) do
    Client.new(config)
  end

  defp validate_start_request(request) do
    # Convert string keys to atom keys for validation
    request_with_atoms = convert_string_keys_to_atoms(request)

    required_fields = [:inputs]

    optional_fields = [
      :agent_id,
      :model,
      :instructions,
      :tools,
      :completion_args,
      :name,
      :description,
      :store,
      :handoff_execution,
      :stream
    ]

    with :ok <- validate_required_fields(request_with_atoms, required_fields),
         :ok <- validate_agent_or_model(request_with_atoms) do
      validated = Map.take(request_with_atoms, required_fields ++ optional_fields)
      {:ok, validated}
    end
  end

  defp validate_append_request(request) do
    # Convert string keys to atom keys for validation
    request_with_atoms = convert_string_keys_to_atoms(request)

    required_fields = [:inputs]
    optional_fields = [:stream, :store, :handoff_execution, :completion_args]

    case validate_required_fields(request_with_atoms, required_fields) do
      :ok ->
        validated = Map.take(request_with_atoms, required_fields ++ optional_fields)
        {:ok, validated}

      error ->
        error
    end
  end

  defp validate_restart_request(request) do
    # Convert string keys to atom keys for validation
    request_with_atoms = convert_string_keys_to_atoms(request)

    required_fields = [:inputs, :from_entry_id]
    optional_fields = [:stream, :store, :handoff_execution, :completion_args]

    case validate_required_fields(request_with_atoms, required_fields) do
      :ok ->
        validated = Map.take(request_with_atoms, required_fields ++ optional_fields)
        {:ok, validated}

      error ->
        error
    end
  end

  defp validate_agent_or_model(request) do
    has_agent = Map.has_key?(request, :agent_id) and not is_nil(Map.get(request, :agent_id))
    has_model = Map.has_key?(request, :model) and not is_nil(Map.get(request, :model))

    cond do
      has_agent and has_model ->
        {:error, "Cannot specify both agent_id and model"}

      has_agent or has_model ->
        :ok

      true ->
        {:error, "Must specify either agent_id or model"}
    end
  end

  defp validate_required_fields(request, required_fields) do
    missing_fields =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(request, field) or is_nil(Map.get(request, field))
      end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  defp convert_string_keys_to_atoms(map) when is_map(map) do
    # Known string keys that should be converted to atoms
    known_keys = %{
      "inputs" => :inputs,
      "agent_id" => :agent_id,
      "model" => :model,
      "instructions" => :instructions,
      "tools" => :tools,
      "completion_args" => :completion_args,
      "name" => :name,
      "description" => :description,
      "store" => :store,
      "handoff_execution" => :handoff_execution,
      "stream" => :stream,
      "from_entry_id" => :from_entry_id
    }

    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_binary(key) ->
        case Map.get(known_keys, key) do
          # Keep unknown string keys as-is
          nil -> Map.put(acc, key, value)
          atom_key -> Map.put(acc, atom_key, value)
        end

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp build_list_params(options) do
    # Preserve order: page first, then page_size
    params = []

    params =
      if Map.has_key?(options, :page) and not is_nil(options[:page]) do
        [{:page, options[:page]} | params]
      else
        params
      end

    params =
      if Map.has_key?(options, :page_size) and not is_nil(options[:page_size]) do
        [{:page_size, options[:page_size]} | params]
      else
        params
      end

    Enum.reverse(params)
  end
end
