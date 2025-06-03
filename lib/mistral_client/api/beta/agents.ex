defmodule MistralClient.API.Beta.Agents do
  @moduledoc """
  Beta Agents API for creating and managing AI agents.

  This module provides functionality to create, manage, and interact with AI agents
  that have specific instructions, tools, and capabilities.

  ## Features

  - Create agents with custom instructions and tools
  - List and retrieve agent information
  - Update agent configurations and versions
  - Version management for agents

  ## Usage

      config = MistralClient.Config.new()

      # Create an agent
      request = %{
        name: "Customer Support Agent",
        model: "mistral-large-latest",
        instructions: "You are a helpful customer support agent.",
        tools: [
          %{
            type: "function",
            function: %{
              name: "get_order_status",
              description: "Get the status of a customer order"
            }
          }
        ]
      }
      {:ok, agent} = MistralClient.API.Beta.Agents.create(config, request)

      # List agents
      {:ok, agents} = MistralClient.API.Beta.Agents.list(config)

      # Get specific agent
      {:ok, agent} = MistralClient.API.Beta.Agents.get(config, agent_id)
  """

  alias MistralClient.{Client, Config}
  alias MistralClient.Models.Beta.Agent

  @doc """
  Create a new agent.

  ## Parameters

    * `config` - Client configuration
    * `request` - Agent creation request with:
      - `:name` - Agent name (required)
      - `:model` - Model to use (required)
      - `:instructions` - Instructions for the agent (optional)
      - `:tools` - List of tools available to the agent (optional)
      - `:description` - Agent description (optional)
      - `:completion_args` - Default completion arguments (optional)
      - `:handoffs` - List of agent handoff targets (optional)

  ## Examples

      request = %{
        name: "Support Agent",
        model: "mistral-large-latest",
        instructions: "You are a helpful support agent.",
        tools: [
          %{
            type: "function",
            function: %{
              name: "search_kb",
              description: "Search knowledge base"
            }
          }
        ]
      }
      {:ok, agent} = create(config, request)
  """
  @spec create(Config.t(), map()) :: {:ok, Agent.t()} | {:error, term()}
  def create(config, request) do
    client = get_or_create_client(config)

    with {:ok, validated_request} <- validate_create_request(request),
         {:ok, response} <- Client.request(client, :post, "/v1/agents", validated_request, []) do
      {:ok, Agent.from_map(response)}
    end
  end

  @doc """
  List agents with optional pagination.

  ## Parameters

    * `config` - Client configuration
    * `options` - Optional parameters:
      - `:page` - Page number (default: 0)
      - `:page_size` - Number of agents per page (default: 20)

  ## Examples

      # List all agents
      {:ok, agents} = list(config)

      # List with pagination
      {:ok, agents} = list(config, %{page: 1, page_size: 10})
  """
  @spec list(Config.t(), map()) :: {:ok, list(Agent.t())} | {:error, term()}
  def list(config, options \\ %{}) do
    client = get_or_create_client(config)
    query_params = build_list_params(options)

    request_options = if query_params == [], do: [], else: [params: query_params]

    with {:ok, response} <- Client.request(client, :get, "/v1/agents", %{}, request_options) do
      agents = Enum.map(response, &Agent.from_map/1)
      {:ok, agents}
    end
  end

  @doc """
  Retrieve a specific agent by ID.

  ## Parameters

    * `config` - Client configuration
    * `agent_id` - The agent ID to retrieve

  ## Examples

      {:ok, agent} = get(config, "agent_123")
  """
  @spec get(Config.t(), String.t()) :: {:ok, Agent.t()} | {:error, term()}
  def get(config, agent_id) when is_binary(agent_id) do
    client = get_or_create_client(config)

    with {:ok, response} <- Client.request(client, :get, "/v1/agents/#{agent_id}", %{}, []) do
      {:ok, Agent.from_map(response)}
    end
  end

  @doc """
  Update an agent's configuration.

  This creates a new version of the agent with the updated configuration.

  ## Parameters

    * `config` - Client configuration
    * `agent_id` - The agent ID to update
    * `updates` - Map of fields to update:
      - `:name` - New agent name (optional)
      - `:instructions` - New instructions (optional)
      - `:tools` - New tools list (optional)
      - `:description` - New description (optional)
      - `:completion_args` - New completion arguments (optional)
      - `:handoffs` - New handoff targets (optional)

  ## Examples

      updates = %{
        instructions: "Updated instructions for the agent",
        tools: [new_tool]
      }
      {:ok, updated_agent} = update(config, agent_id, updates)
  """
  @spec update(Config.t(), String.t(), map()) :: {:ok, Agent.t()} | {:error, term()}
  def update(config, agent_id, updates) when is_binary(agent_id) and is_map(updates) do
    client = get_or_create_client(config)

    with {:ok, validated_updates} <- validate_update_request(updates),
         {:ok, response} <-
           Client.request(client, :patch, "/v1/agents/#{agent_id}", validated_updates, []) do
      {:ok, Agent.from_map(response)}
    end
  end

  @doc """
  Update an agent's active version.

  ## Parameters

    * `config` - Client configuration
    * `agent_id` - The agent ID
    * `version` - Version number to activate

  ## Examples

      {:ok, agent} = update_version(config, agent_id, 2)
  """
  @spec update_version(Config.t(), String.t(), integer()) :: {:ok, Agent.t()} | {:error, term()}
  def update_version(config, agent_id, version)
      when is_binary(agent_id) and is_integer(version) do
    client = get_or_create_client(config)
    options = [params: [version: version]]

    with {:ok, response} <-
           Client.request(client, :patch, "/v1/agents/#{agent_id}/version", %{}, options) do
      {:ok, Agent.from_map(response)}
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

  defp validate_create_request(request) do
    # Convert string keys to atom keys for validation
    request_with_atoms = convert_string_keys_to_atoms(request)

    required_fields = [:name, :model]
    optional_fields = [:instructions, :tools, :description, :completion_args, :handoffs]

    case validate_required_fields(request_with_atoms, required_fields) do
      :ok ->
        validated = Map.take(request_with_atoms, required_fields ++ optional_fields)
        {:ok, validated}

      error ->
        error
    end
  end

  defp validate_update_request(updates) do
    # Convert string keys to atom keys for validation
    updates_with_atoms = convert_string_keys_to_atoms(updates)

    allowed_fields = [
      :name,
      :instructions,
      :tools,
      :description,
      :completion_args,
      :handoffs,
      :model
    ]

    validated = Map.take(updates_with_atoms, allowed_fields)

    if map_size(validated) > 0 do
      {:ok, validated}
    else
      {:error, "No valid update fields provided"}
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
      "name" => :name,
      "model" => :model,
      "instructions" => :instructions,
      "tools" => :tools,
      "description" => :description,
      "completion_args" => :completion_args,
      "handoffs" => :handoffs
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
