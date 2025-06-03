defmodule MistralClient.API.Beta do
  @moduledoc """
  Beta API endpoints for experimental Mistral AI features.

  This module provides access to experimental features that are in beta testing.
  These APIs may change without notice and should be used with caution in production.

  ## Available Beta APIs

  - **Agents API**: Create and manage AI agents with specific instructions and tools
  - **Conversations API**: Manage persistent conversations with agents

  ## Usage

      # Create an agent
      {:ok, agent} = MistralClient.API.Beta.create_agent(%{
        name: "Customer Support Agent",
        model: "mistral-large-latest",
        instructions: "You are a helpful customer support agent."
      })

      # Start a conversation
      {:ok, conversation} = MistralClient.API.Beta.start_conversation(%{
        agent_id: agent.id,
        inputs: "Hello, I need help with my order."
      })
  """

  alias MistralClient.{Client, Config}
  alias MistralClient.API.Beta.{Agents, Conversations}

  # Agents API delegation
  defdelegate create_agent(config, request), to: Agents, as: :create
  defdelegate list_agents(config, options \\ %{}), to: Agents, as: :list
  defdelegate get_agent(config, agent_id), to: Agents, as: :get
  defdelegate update_agent(config, agent_id, updates), to: Agents, as: :update
  defdelegate update_agent_version(config, agent_id, version), to: Agents, as: :update_version

  # Conversations API delegation
  defdelegate start_conversation(config, request), to: Conversations, as: :start
  defdelegate list_conversations(config, options \\ %{}), to: Conversations, as: :list
  defdelegate get_conversation(config, conversation_id), to: Conversations, as: :get

  defdelegate append_to_conversation(config, conversation_id, request),
    to: Conversations,
    as: :append

  defdelegate get_conversation_history(config, conversation_id), to: Conversations, as: :history
  defdelegate get_conversation_messages(config, conversation_id), to: Conversations, as: :messages

  defdelegate restart_conversation(config, conversation_id, request),
    to: Conversations,
    as: :restart

  # Streaming versions
  defdelegate start_conversation_stream(config, request, callback),
    to: Conversations,
    as: :start_stream

  defdelegate append_to_conversation_stream(config, conversation_id, request, callback),
    to: Conversations,
    as: :append_stream

  defdelegate restart_conversation_stream(config, conversation_id, request, callback),
    to: Conversations,
    as: :restart_stream

  @doc """
  Check if Beta APIs are available.

  Returns true if the current API key has access to beta features.
  """
  @spec beta_available?(Config.t()) :: boolean()
  def beta_available?(config) do
    client = get_or_create_client(config)

    case Client.request(client, :get, "/v1/agents", %{}, []) do
      {:ok, _} -> true
      {:error, %{status: 404}} -> false
      {:error, %{status: 403}} -> false
      _ -> false
    end
  end

  @doc """
  Get beta API status and available features.
  """
  @spec beta_status(Config.t()) :: {:ok, map()} | {:error, term()}
  def beta_status(config) do
    client = get_or_create_client(config)

    case Client.request(client, :get, "/v1/agents", %{}, params: [page_size: 1]) do
      {:ok, _} ->
        {:ok,
         %{
           available: true,
           features: ["agents", "conversations"],
           version: "beta"
         }}

      {:error, %MistralClient.Errors.NotFoundError{}} ->
        {:ok, %{available: false, reason: "Beta APIs not found"}}

      {:error, %MistralClient.Errors.PermissionError{}} ->
        {:ok, %{available: false, reason: "Access denied to beta features"}}

      {:error, %MistralClient.Errors.NetworkError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private functions

  defp get_or_create_client(config) when is_list(config) do
    Client.new(config)
  end

  defp get_or_create_client(%Client{} = client), do: client

  defp get_or_create_client(%Config{} = config) do
    Client.new(config)
  end
end
