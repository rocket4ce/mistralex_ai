defmodule MistralClient.API.BetaTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.Config
  alias MistralClient.API.Beta
  alias MistralClient.Models.Beta.{Agent, Conversation, ConversationResponse, ConversationHistory}
  alias MistralClient.Test.Fixtures.BetaFixtures

  setup :verify_on_exit!

  setup do
    config = Config.new(api_key: "test-api-key")
    {:ok, config: config}
  end

  describe "beta_available?/1" do
    test "returns true when beta APIs are available", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!([])}}
      end)

      assert Beta.beta_available?(config) == true
    end

    test "returns false when beta APIs return 404", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 404, body: Jason.encode!(%{"error" => "Not found"})}}
      end)

      assert Beta.beta_available?(config) == false
    end

    test "returns false when beta APIs return 403", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 403, body: Jason.encode!(BetaFixtures.beta_access_denied_error())}}
      end)

      assert Beta.beta_available?(config) == false
    end

    test "returns false on other errors", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert Beta.beta_available?(config) == false
    end
  end

  describe "beta_status/1" do
    test "returns status when beta APIs are available", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!([])}}
      end)

      assert {:ok, status} = Beta.beta_status(config)
      assert status.available == true
      assert status.features == ["agents", "conversations"]
      assert status.version == "beta"
    end

    test "returns unavailable status when APIs return 404", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 404, body: Jason.encode!(%{"error" => "Not found"})}}
      end)

      assert {:ok, status} = Beta.beta_status(config)
      assert status.available == false
      assert status.reason == "Beta APIs not found"
    end

    test "returns access denied status when APIs return 403", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 403, body: Jason.encode!(BetaFixtures.beta_access_denied_error())}}
      end)

      assert {:ok, status} = Beta.beta_status(config)
      assert status.available == false
      assert status.reason == "Access denied to beta features"
    end

    test "returns error on network failure", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Beta.beta_status(config)
    end
  end

  describe "create_agent/2" do
    test "creates an agent successfully", %{config: config} do
      request = BetaFixtures.agent_create_request()
      response = BetaFixtures.agent_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, "https://api.mistral.ai/v1/agents", _headers, body, _opts ->
        assert Jason.decode!(body) == request
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %Agent{} = agent} = Beta.create_agent(config, request)
      assert agent.id == "agent_123"
      assert agent.name == "Customer Support Agent"
      assert agent.model == "mistral-large-latest"
      assert agent.instructions == "You are a helpful customer support agent."
      assert agent.version == 1
    end

    test "returns error for missing required fields", %{config: config} do
      # missing name
      request = %{"model" => "mistral-large-latest"}

      assert {:error, "Missing required fields: name"} = Beta.create_agent(config, request)
    end

    test "returns error for validation failure", %{config: config} do
      request = BetaFixtures.agent_create_request()
      error_response = BetaFixtures.validation_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 422, body: Jason.encode!(error_response)}}
      end)

      assert {:error, _} = Beta.create_agent(config, request)
    end
  end

  describe "list_agents/2" do
    test "lists agents successfully", %{config: config} do
      response = BetaFixtures.agents_list_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, agents} = Beta.list_agents(config)
      assert length(agents) == 2
      assert [%Agent{} = agent1, %Agent{} = agent2] = agents
      assert agent1.id == "agent_123"
      assert agent2.id == "agent_456"
    end

    test "lists agents with pagination", %{config: config} do
      response = BetaFixtures.agents_list_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, opts ->
        assert url == "https://api.mistral.ai/v1/agents"
        assert Keyword.get(opts, :params) == [page: 1, page_size: 10]
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, agents} = Beta.list_agents(config, %{page: 1, page_size: 10})
      assert length(agents) == 2
    end

    test "returns error on API failure", %{config: config} do
      MistralClient.HttpClientMock
      |> expect(:request, fn :get, "https://api.mistral.ai/v1/agents", _headers, _body, _opts ->
        {:ok, %{status: 500, body: Jason.encode!(%{"error" => "Internal server error"})}}
      end)

      assert {:error, _} = Beta.list_agents(config)
    end
  end

  describe "get_agent/2" do
    test "retrieves an agent successfully", %{config: config} do
      agent_id = "agent_123"
      response = BetaFixtures.agent_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, _opts ->
        assert url == "https://api.mistral.ai/v1/agents/#{agent_id}"
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %Agent{} = agent} = Beta.get_agent(config, agent_id)
      assert agent.id == "agent_123"
      assert agent.name == "Customer Support Agent"
    end

    test "returns error for non-existent agent", %{config: config} do
      agent_id = "nonexistent"
      error_response = BetaFixtures.agent_not_found_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, _opts ->
        assert url == "https://api.mistral.ai/v1/agents/#{agent_id}"
        {:ok, %{status: 404, body: Jason.encode!(error_response)}}
      end)

      assert {:error, _} = Beta.get_agent(config, agent_id)
    end
  end

  describe "update_agent/3" do
    test "updates an agent successfully", %{config: config} do
      agent_id = "agent_123"
      updates = BetaFixtures.agent_update_request()
      response = BetaFixtures.agent_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :patch, url, _headers, body, _opts ->
        assert url == "https://api.mistral.ai/v1/agents/#{agent_id}"
        assert Jason.decode!(body) == updates
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %Agent{} = agent} = Beta.update_agent(config, agent_id, updates)
      assert agent.id == "agent_123"
    end

    test "returns error for empty updates", %{config: config} do
      agent_id = "agent_123"
      updates = %{}

      assert {:error, "No valid update fields provided"} =
               Beta.update_agent(config, agent_id, updates)
    end

    test "returns error for invalid updates", %{config: config} do
      agent_id = "agent_123"
      updates = %{"invalid_field" => "value"}

      assert {:error, "No valid update fields provided"} =
               Beta.update_agent(config, agent_id, updates)
    end
  end

  describe "update_agent_version/3" do
    test "updates agent version successfully", %{config: config} do
      agent_id = "agent_123"
      version = 2
      response = BetaFixtures.agent_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :patch, url, _headers, _body, opts ->
        assert url == "https://api.mistral.ai/v1/agents/#{agent_id}/version"
        assert Keyword.get(opts, :params) == [version: version]
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %Agent{} = agent} = Beta.update_agent_version(config, agent_id, version)
      assert agent.id == "agent_123"
    end
  end

  describe "start_conversation/2" do
    test "starts a conversation with an agent", %{config: config} do
      request = BetaFixtures.conversation_start_request()
      response = BetaFixtures.conversation_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post,
                             "https://api.mistral.ai/v1/conversations",
                             _headers,
                             body,
                             _opts ->
        assert Jason.decode!(body) == request
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %ConversationResponse{} = conv_response} =
               Beta.start_conversation(config, request)

      assert conv_response.conversation_id == "conv_123"
      assert length(conv_response.outputs) == 1
    end

    test "starts a conversation with a model", %{config: config} do
      request = %{
        "model" => "mistral-large-latest",
        "inputs" => "Hello, explain quantum computing",
        "instructions" => "You are a physics teacher."
      }

      response = BetaFixtures.conversation_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post,
                             "https://api.mistral.ai/v1/conversations",
                             _headers,
                             body,
                             _opts ->
        assert Jason.decode!(body) == request
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %ConversationResponse{}} = Beta.start_conversation(config, request)
    end

    test "returns error when both agent_id and model are specified", %{config: config} do
      request = %{
        "agent_id" => "agent_123",
        "model" => "mistral-large-latest",
        "inputs" => "Hello"
      }

      assert {:error, "Cannot specify both agent_id and model"} =
               Beta.start_conversation(config, request)
    end

    test "returns error when neither agent_id nor model are specified", %{config: config} do
      request = %{
        "inputs" => "Hello"
      }

      assert {:error, "Must specify either agent_id or model"} =
               Beta.start_conversation(config, request)
    end

    test "returns error for missing inputs", %{config: config} do
      request = %{
        "agent_id" => "agent_123"
      }

      assert {:error, "Missing required fields: inputs"} =
               Beta.start_conversation(config, request)
    end
  end

  describe "list_conversations/2" do
    test "lists conversations successfully", %{config: config} do
      response = BetaFixtures.conversations_list_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get,
                             "https://api.mistral.ai/v1/conversations",
                             _headers,
                             _body,
                             _opts ->
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, conversations} = Beta.list_conversations(config)
      assert length(conversations) == 2
      assert [%Conversation{} = conv1, %Conversation{} = conv2] = conversations
      assert conv1.id == "conv_123"
      assert conv2.id == "conv_456"
    end

    test "lists conversations with pagination", %{config: config} do
      response = BetaFixtures.conversations_list_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, opts ->
        assert url == "https://api.mistral.ai/v1/conversations"
        assert Keyword.get(opts, :params) == [page: 0, page_size: 50]
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, conversations} = Beta.list_conversations(config, %{page: 0, page_size: 50})
      assert length(conversations) == 2
    end
  end

  describe "get_conversation/2" do
    test "retrieves a conversation successfully", %{config: config} do
      conversation_id = "conv_123"
      response = BetaFixtures.conversation_entity()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, _opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}"
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %Conversation{} = conversation} =
               Beta.get_conversation(config, conversation_id)

      assert conversation.id == "conv_123"
      assert conversation.name == "Customer Support Session"
    end

    test "returns error for non-existent conversation", %{config: config} do
      conversation_id = "nonexistent"
      error_response = BetaFixtures.conversation_not_found_error()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, _opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}"
        {:ok, %{status: 404, body: Jason.encode!(error_response)}}
      end)

      assert {:error, _} = Beta.get_conversation(config, conversation_id)
    end
  end

  describe "append_to_conversation/3" do
    test "appends to conversation successfully", %{config: config} do
      conversation_id = "conv_123"
      request = BetaFixtures.conversation_append_request()
      response = BetaFixtures.conversation_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}"
        assert Jason.decode!(body) == request
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %ConversationResponse{} = conv_response} =
               Beta.append_to_conversation(config, conversation_id, request)

      assert conv_response.conversation_id == "conv_123"
    end

    test "returns error for missing inputs", %{config: config} do
      conversation_id = "conv_123"
      request = %{}

      assert {:error, "Missing required fields: inputs"} =
               Beta.append_to_conversation(config, conversation_id, request)
    end
  end

  describe "get_conversation_history/2" do
    test "retrieves conversation history successfully", %{config: config} do
      conversation_id = "conv_123"
      response = BetaFixtures.conversation_history_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, _opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}/history"
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %ConversationHistory{} = history} =
               Beta.get_conversation_history(config, conversation_id)

      assert history.conversation_id == "conv_123"
      assert length(history.entries) == 3
    end
  end

  describe "get_conversation_messages/2" do
    test "retrieves conversation messages successfully", %{config: config} do
      conversation_id = "conv_123"
      response = BetaFixtures.conversation_messages_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, url, _headers, _body, _opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}/messages"
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %ConversationHistory{} = messages} =
               Beta.get_conversation_messages(config, conversation_id)

      assert messages.conversation_id == "conv_123"
      assert length(messages.messages) == 2
    end
  end

  describe "restart_conversation/3" do
    test "restarts conversation successfully", %{config: config} do
      conversation_id = "conv_123"
      request = BetaFixtures.conversation_restart_request()
      response = BetaFixtures.conversation_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, _opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}/restart"
        assert Jason.decode!(body) == request
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end)

      assert {:ok, %ConversationResponse{} = conv_response} =
               Beta.restart_conversation(config, conversation_id, request)

      assert conv_response.conversation_id == "conv_123"
    end

    test "returns error for missing required fields", %{config: config} do
      conversation_id = "conv_123"
      # missing from_entry_id
      request = %{"inputs" => "Hello"}

      assert {:error, "Missing required fields: from_entry_id"} =
               Beta.restart_conversation(config, conversation_id, request)
    end
  end

  describe "streaming functions" do
    test "start_conversation_stream/3 handles streaming", %{config: config} do
      request = %{
        "agent_id" => "agent_123",
        "inputs" => "Tell me a story",
        "stream" => true
      }

      chunks = BetaFixtures.conversation_stream_chunks()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post,
                             "https://api.mistral.ai/v1/conversations",
                             _headers,
                             body,
                             opts ->
        assert Jason.decode!(body) == request
        callback = Keyword.get(opts, :stream_callback)

        # Simulate streaming by calling the callback with each chunk
        Enum.each(chunks, fn chunk ->
          callback.(Jason.encode!(chunk))
        end)

        {:ok, %{status: 200, body: ""}}
      end)

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      assert {:ok, _} =
               Beta.start_conversation_stream(config, Map.delete(request, "stream"), callback)

      # Verify we received the chunks
      assert_received {:chunk, _}
    end

    test "append_to_conversation_stream/4 handles streaming", %{config: config} do
      conversation_id = "conv_123"

      request = %{
        "inputs" => "Continue the story",
        "stream" => true
      }

      chunks = BetaFixtures.conversation_stream_chunks()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}"
        assert Jason.decode!(body) == request
        callback = Keyword.get(opts, :stream_callback)

        # Simulate streaming
        Enum.each(chunks, fn chunk ->
          callback.(Jason.encode!(chunk))
        end)

        {:ok, %{status: 200, body: ""}}
      end)

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      assert {:ok, _} =
               Beta.append_to_conversation_stream(
                 config,
                 conversation_id,
                 Map.delete(request, "stream"),
                 callback
               )

      # Verify we received the chunks
      assert_received {:chunk, _}
    end

    test "restart_conversation_stream/4 handles streaming", %{config: config} do
      conversation_id = "conv_123"

      request = %{
        "inputs" => "Let's start over",
        "from_entry_id" => "entry_123",
        "stream" => true
      }

      chunks = BetaFixtures.conversation_stream_chunks()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, url, _headers, body, opts ->
        assert url == "https://api.mistral.ai/v1/conversations/#{conversation_id}/restart"
        assert Jason.decode!(body) == request
        callback = Keyword.get(opts, :stream_callback)

        # Simulate streaming
        Enum.each(chunks, fn chunk ->
          callback.(Jason.encode!(chunk))
        end)

        {:ok, %{status: 200, body: ""}}
      end)

      callback = fn chunk ->
        send(self(), {:chunk, chunk})
      end

      assert {:ok, _} =
               Beta.restart_conversation_stream(
                 config,
                 conversation_id,
                 Map.delete(request, "stream"),
                 callback
               )

      # Verify we received the chunks
      assert_received {:chunk, _}
    end
  end
end
