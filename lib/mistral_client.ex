defmodule MistralClient do
  @moduledoc """
  Elixir client for the Mistral AI API.

  This module provides a comprehensive interface to the Mistral AI API with complete
  feature parity to the Python SDK. It supports all major API endpoints including
  chat completions, embeddings, model management, file operations, and advanced
  features like streaming responses and structured outputs.

  ## Configuration

  Configure your API key and other settings:

      config :mistralex_ai,
        api_key: "your-api-key",
        base_url: "https://api.mistral.ai",
        timeout: 30_000

  Or set environment variables:

      export MISTRAL_API_KEY="your-api-key"

  ## Basic Usage

      # Chat completion
      {:ok, response} = MistralClient.chat([
        %{role: "user", content: "Hello, how are you?"}
      ])

      # Generate embeddings
      {:ok, embeddings} = MistralClient.embeddings("Hello world")

      # List available models
      {:ok, models} = MistralClient.models()

  ## Streaming

      # Stream chat responses
      MistralClient.chat_stream([
        %{role: "user", content: "Tell me a story"}
      ], fn chunk ->
        IO.write(chunk.choices |> hd() |> get_in(["delta", "content"]) || "")
      end)

  ## Error Handling

  All functions return `{:ok, result}` on success or `{:error, reason}` on failure.
  The client handles retries, rate limiting, and network errors automatically.
  """

  alias MistralClient.{Client, Config}

  alias MistralClient.API.{
    Chat,
    Embeddings,
    Models,
    Files,
    FIM,
    FineTuning,
    Jobs,
    Batch,
    OCR,
    Beta,
    Classifiers
  }

  @type message :: %{
          role: String.t(),
          content: String.t(),
          name: String.t() | nil,
          tool_calls: list() | nil,
          tool_call_id: String.t() | nil
        }

  @type chat_options :: %{
          model: String.t(),
          temperature: float() | nil,
          max_tokens: integer() | nil,
          top_p: float() | nil,
          stream: boolean() | nil,
          tools: list() | nil,
          tool_choice: String.t() | map() | nil,
          response_format: map() | nil
        }

  @type embedding_options :: %{
          model: String.t(),
          encoding_format: String.t() | nil,
          dimensions: integer() | nil
        }

  @type fim_options :: %{
          model: String.t(),
          suffix: String.t() | nil,
          temperature: float() | nil,
          top_p: float() | nil,
          max_tokens: integer() | nil,
          min_tokens: integer() | nil,
          stop: String.t() | list(String.t()) | nil,
          random_seed: integer() | nil
        }

  @type fine_tuning_options :: %{
          page: integer() | nil,
          page_size: integer() | nil,
          model: String.t() | nil,
          created_after: DateTime.t() | nil,
          created_before: DateTime.t() | nil,
          created_by_me: boolean() | nil,
          status: atom() | nil,
          wandb_project: String.t() | nil,
          wandb_name: String.t() | nil,
          suffix: String.t() | nil
        }

  @type batch_options :: %{
          page: integer() | nil,
          page_size: integer() | nil,
          model: String.t() | nil,
          metadata: map() | nil,
          created_after: DateTime.t() | nil,
          created_by_me: boolean() | nil,
          status: list(atom()) | nil
        }

  @type ocr_options :: %{
          id: String.t() | nil,
          pages: list(integer()) | nil,
          include_image_base64: boolean() | nil,
          image_limit: integer() | nil,
          image_min_size: integer() | nil,
          bbox_annotation_format: map() | nil,
          document_annotation_format: map() | nil
        }

  # Chat API
  @doc """
  Create a chat completion.

  ## Parameters

    * `messages` - List of message maps with role and content
    * `options` - Optional parameters (model, temperature, etc.)

  ## Examples

      {:ok, response} = MistralClient.chat([
        %{role: "user", content: "Hello!"}
      ])

      {:ok, response} = MistralClient.chat(
        [%{role: "user", content: "Hello!"}],
        %{model: "mistral-large-latest", temperature: 0.7}
      )
  """
  @spec chat(list(message()), chat_options()) :: {:ok, map()} | {:error, term()}
  def chat(messages, options \\ %{}) do
    Chat.complete(messages, options)
  end

  @doc """
  Create a streaming chat completion.

  ## Parameters

    * `messages` - List of message maps with role and content
    * `callback` - Function to handle each chunk
    * `options` - Optional parameters

  ## Examples

      MistralClient.chat_stream([
        %{role: "user", content: "Tell me a story"}
      ], fn chunk ->
        content = get_in(chunk, ["choices", Access.at(0), "delta", "content"])
        if content, do: IO.write(content)
      end)
  """
  @spec chat_stream(list(message()), function(), chat_options()) :: :ok | {:error, term()}
  def chat_stream(messages, callback, options \\ %{}) do
    Chat.stream(messages, callback, options)
  end

  # Embeddings API
  @doc """
  Generate embeddings for the given input.

  ## Parameters

    * `input` - Text string or list of strings to embed
    * `options` - Optional parameters (model, dimensions, etc.)

  ## Examples

      {:ok, embeddings} = MistralClient.embeddings("Hello world")

      {:ok, embeddings} = MistralClient.embeddings(
        ["Hello", "World"],
        %{model: "mistral-embed", dimensions: 1024}
      )
  """
  @spec embeddings(String.t() | list(String.t()), embedding_options()) ::
          {:ok, map()} | {:error, term()}
  def embeddings(input, options \\ %{}) do
    Embeddings.create(input, options)
  end

  # Models API
  @doc """
  List available models.

  ## Examples

      {:ok, models} = MistralClient.models()
  """
  @spec models() :: {:ok, list(map())} | {:error, term()}
  def models do
    Models.list()
  end

  @doc """
  Retrieve a specific model.

  ## Parameters

    * `model_id` - The ID of the model to retrieve

  ## Examples

      {:ok, model} = MistralClient.model("mistral-large-latest")
  """
  @spec model(String.t()) :: {:ok, map()} | {:error, term()}
  def model(model_id) do
    Models.retrieve(model_id)
  end

  # Files API
  @doc """
  Upload a file.

  ## Parameters

    * `file_path` - Path to the file to upload
    * `purpose` - Purpose of the file (e.g., "fine-tune")

  ## Examples

      {:ok, file} = MistralClient.upload_file("./data.jsonl", "fine-tune")
  """
  @spec upload_file(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def upload_file(file_path, purpose) do
    Files.upload(file_path, purpose)
  end

  @doc """
  List uploaded files.

  ## Examples

      {:ok, files} = MistralClient.files()
  """
  @spec files() :: {:ok, list(map())} | {:error, term()}
  def files do
    Files.list()
  end

  @doc """
  Delete a file.

  ## Parameters

    * `file_id` - The ID of the file to delete

  ## Examples

      {:ok, _} = MistralClient.delete_file("file-123")
  """
  @spec delete_file(String.t()) :: {:ok, map()} | {:error, term()}
  def delete_file(file_id) do
    Files.delete(file_id)
  end

  # FIM API
  @doc """
  Perform FIM (Fill-in-the-Middle) completion for code.

  ## Parameters

    * `model` - Codestral model ID ("codestral-2405" or "codestral-latest")
    * `prompt` - The code prefix to complete
    * `options` - Optional parameters (suffix, temperature, etc.)

  ## Examples

      {:ok, completion} = MistralClient.fim_complete(
        "codestral-2405",
        "def fibonacci(n):",
        %{suffix: "return result"}
      )
  """
  @spec fim_complete(String.t(), String.t(), fim_options()) :: {:ok, map()} | {:error, term()}
  def fim_complete(model, prompt, options \\ %{}) do
    client = Client.new()
    FIM.complete(client, model, prompt, Map.to_list(options))
  end

  @doc """
  Stream FIM completion with real-time results.

  ## Parameters

    * `model` - Codestral model ID
    * `prompt` - The code prefix to complete
    * `callback` - Function to handle each chunk
    * `options` - Optional parameters

  ## Examples

      MistralClient.fim_stream(
        "codestral-2405",
        "def fibonacci(n):",
        fn chunk ->
          if chunk.content, do: IO.write(chunk.content)
        end,
        %{suffix: "return result"}
      )
  """
  @spec fim_stream(String.t(), String.t(), function(), fim_options()) ::
          {:ok, term()} | {:error, term()}
  def fim_stream(model, prompt, callback, options \\ %{}) do
    client = Client.new()
    opts = options |> Map.to_list() |> Keyword.put(:callback, callback)
    FIM.stream(client, model, prompt, opts)
  end

  # Fine-tuning API
  @doc """
  Create a fine-tuning job.
  """
  @spec create_fine_tuning_job(MistralClient.Models.FineTuningJobRequest.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def create_fine_tuning_job(request) do
    config = Config.new()
    FineTuning.create_job(config, request)
  end

  # Jobs API (Fine-tuning Jobs)
  @doc """
  List fine-tuning jobs with optional filtering.

  ## Examples

      # List all jobs
      {:ok, jobs} = MistralClient.list_jobs()

      # List with filtering
      {:ok, jobs} = MistralClient.list_jobs(%{
        status: :running,
        model: "open-mistral-7b"
      })
  """
  @spec list_jobs(map()) ::
          {:ok, MistralClient.Models.FineTuningJobsResponse.t()} | {:error, term()}
  def list_jobs(options \\ %{}) do
    Jobs.list(options)
  end

  @doc """
  Create a fine-tuning job.

  ## Examples

      request = %MistralClient.Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: %MistralClient.Models.CompletionTrainingParameters{
          learning_rate: 0.0001
        }
      }
      {:ok, job} = MistralClient.create_job(request)
  """
  @spec create_job(MistralClient.Models.FineTuningJobRequest.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def create_job(request) do
    Jobs.create(request)
  end

  @doc """
  Get details of a specific fine-tuning job.

  ## Examples

      {:ok, job} = MistralClient.get_job("job-123")
  """
  @spec get_job(String.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def get_job(job_id) do
    Jobs.get(job_id)
  end

  @doc """
  Start a validated fine-tuning job.

  ## Examples

      {:ok, job} = MistralClient.start_job("job-123")
  """
  @spec start_job(String.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def start_job(job_id) do
    Jobs.start(job_id)
  end

  @doc """
  Cancel a fine-tuning job.

  ## Examples

      {:ok, job} = MistralClient.cancel_job("job-123")
  """
  @spec cancel_job(String.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def cancel_job(job_id) do
    Jobs.cancel(job_id)
  end

  @doc """
  List fine-tuning jobs with optional filtering.
  """
  @spec list_fine_tuning_jobs(fine_tuning_options()) ::
          {:ok, MistralClient.Models.FineTuningJobsResponse.t()} | {:error, term()}
  def list_fine_tuning_jobs(options \\ %{}) do
    config = Config.new()
    FineTuning.list_jobs(config, options)
  end

  @doc """
  Get details of a specific fine-tuning job.
  """
  @spec get_fine_tuning_job(String.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def get_fine_tuning_job(job_id) do
    config = Config.new()
    FineTuning.get_job(config, job_id)
  end

  @doc """
  Start a validated fine-tuning job.
  """
  @spec start_fine_tuning_job(String.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def start_fine_tuning_job(job_id) do
    config = Config.new()
    FineTuning.start_job(config, job_id)
  end

  @doc """
  Cancel a fine-tuning job.
  """
  @spec cancel_fine_tuning_job(String.t()) ::
          {:ok, MistralClient.Models.FineTuningJobResponse.t()} | {:error, term()}
  def cancel_fine_tuning_job(job_id) do
    config = Config.new()
    FineTuning.cancel_job(config, job_id)
  end

  @doc """
  Archive a fine-tuned model.
  """
  @spec archive_fine_tuned_model(String.t()) :: {:ok, map()} | {:error, term()}
  def archive_fine_tuned_model(model_id) do
    config = Config.new()
    FineTuning.archive_model(config, model_id)
  end

  @doc """
  Unarchive a fine-tuned model.
  """
  @spec unarchive_fine_tuned_model(String.t()) :: {:ok, map()} | {:error, term()}
  def unarchive_fine_tuned_model(model_id) do
    config = Config.new()
    FineTuning.unarchive_model(config, model_id)
  end

  @doc """
  Update a fine-tuned model.
  """
  @spec update_fine_tuned_model(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def update_fine_tuned_model(model_id, updates) do
    config = Config.new()
    FineTuning.update_model(config, model_id, updates)
  end

  # Batch API
  @doc """
  List batch jobs with optional filtering and pagination.

  ## Parameters

    * `options` - Optional filtering parameters:
      - `:page` - Page number (default: 0)
      - `:page_size` - Number of jobs per page (default: 100)
      - `:model` - Filter by model name
      - `:metadata` - Filter by metadata
      - `:created_after` - Filter by creation date (DateTime)
      - `:created_by_me` - Filter by ownership (boolean, default: false)
      - `:status` - Filter by status list (e.g., [:running, :queued])

  ## Examples

      # List all batch jobs
      {:ok, jobs} = MistralClient.list_batch_jobs()

      # List with filtering
      {:ok, jobs} = MistralClient.list_batch_jobs(%{
        page: 0,
        page_size: 50,
        status: [:running, :queued],
        model: "mistral-large-latest"
      })
  """
  @spec list_batch_jobs(batch_options()) ::
          {:ok, MistralClient.Models.BatchJobsOut.t()} | {:error, term()}
  def list_batch_jobs(options \\ %{}) do
    client = Client.new()
    Batch.list(client, options)
  end

  @doc """
  Create a new batch job for processing multiple requests.

  ## Parameters

    * `request` - Batch job request with:
      - `:input_files` - List of file IDs to process (required)
      - `:endpoint` - API endpoint to use (required)
      - `:model` - Model to use for processing (required)
      - `:metadata` - Optional metadata map
      - `:timeout_hours` - Timeout in hours (default: 24)

  ## Examples

      {:ok, job} = MistralClient.create_batch_job(%{
        input_files: ["file-abc123", "file-def456"],
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest",
        metadata: %{"project" => "customer-support"},
        timeout_hours: 48
      })
  """
  @spec create_batch_job(map() | MistralClient.Models.BatchJobIn.t()) ::
          {:ok, MistralClient.Models.BatchJobOut.t()} | {:error, term()}
  def create_batch_job(request) do
    client = Client.new()
    Batch.create(client, request)
  end

  @doc """
  Get details of a specific batch job by ID.

  ## Parameters

    * `job_id` - The batch job ID

  ## Examples

      {:ok, job} = MistralClient.get_batch_job("batch_abc123")
      IO.puts("Status: \#{job.status}")
      IO.puts("Progress: \#{job.completed_requests}/\#{job.total_requests}")
  """
  @spec get_batch_job(String.t()) ::
          {:ok, MistralClient.Models.BatchJobOut.t()} | {:error, term()}
  def get_batch_job(job_id) do
    client = Client.new()
    Batch.get(client, job_id)
  end

  @doc """
  Cancel a running batch job.

  ## Parameters

    * `job_id` - The batch job ID to cancel

  ## Examples

      {:ok, job} = MistralClient.cancel_batch_job("batch_abc123")
      # job.status will be :cancellation_requested or :cancelled
  """
  @spec cancel_batch_job(String.t()) ::
          {:ok, MistralClient.Models.BatchJobOut.t()} | {:error, term()}
  def cancel_batch_job(job_id) do
    client = Client.new()
    Batch.cancel(client, job_id)
  end

  # OCR API
  @doc """
  Process a document or image using OCR (Optical Character Recognition).

  ## Parameters

    * `model` - Model to use for OCR processing (e.g., "pixtral-12b-2024-12-19")
    * `document` - Document or image to process (DocumentURLChunk or ImageURLChunk)
    * `options` - Optional parameters:
      - `:id` - Request identifier
      - `:pages` - List of specific page numbers to process (0-indexed)
      - `:include_image_base64` - Include base64-encoded images in response
      - `:image_limit` - Maximum number of images to extract
      - `:image_min_size` - Minimum size (height and width) for image extraction
      - `:bbox_annotation_format` - Structured output format for bounding boxes
      - `:document_annotation_format` - Structured output format for the document

  ## Examples

      # Process a document URL
      document = MistralClient.Models.DocumentURLChunk.new("https://example.com/doc.pdf")
      {:ok, response} = MistralClient.ocr_process("pixtral-12b-2024-12-19", document)

      # Process an image with options
      image_url = MistralClient.Models.ImageURLChunkImageURL.new("data:image/png;base64,...")
      image_chunk = MistralClient.Models.ImageURLChunk.new(image_url)
      {:ok, response} = MistralClient.ocr_process(
        "pixtral-12b-2024-12-19",
        image_chunk,
        %{include_image_base64: true, image_limit: 5}
      )

      # Process specific pages
      {:ok, response} = MistralClient.ocr_process(
        "pixtral-12b-2024-12-19",
        document,
        %{pages: [0, 1, 2]}
      )
  """
  @spec ocr_process(String.t(), MistralClient.Models.OCRRequest.document_type(), ocr_options()) ::
          {:ok, MistralClient.Models.OCRResponse.t()} | {:error, term()}
  def ocr_process(model, document, options \\ %{}) do
    config = Config.new()
    OCR.process(config, model, document, Map.to_list(options))
  end

  @doc """
  Process a document or image using OCR with a structured request.

  ## Parameters

    * `request` - OCR request struct with all parameters

  ## Examples

      document = MistralClient.Models.DocumentURLChunk.new("https://example.com/doc.pdf")
      request = MistralClient.Models.OCRRequest.new("pixtral-12b-2024-12-19", document,
        pages: [0, 1],
        include_image_base64: true
      )
      {:ok, response} = MistralClient.ocr_process_request(request)
  """
  @spec ocr_process_request(MistralClient.Models.OCRRequest.t()) ::
          {:ok, MistralClient.Models.OCRResponse.t()} | {:error, term()}
  def ocr_process_request(request) do
    config = Config.new()
    OCR.process(config, request)
  end

  # Beta APIs
  @doc """
  Check if Beta APIs are available for the current API key.

  ## Examples

      if MistralClient.beta_available?() do
        IO.puts("Beta features are available!")
      end
  """
  @spec beta_available?() :: boolean()
  def beta_available? do
    config = Config.new()
    Beta.beta_available?(config)
  end

  @doc """
  Get Beta API status and available features.

  ## Examples

      {:ok, status} = MistralClient.beta_status()
      IO.inspect(status.features)
  """
  @spec beta_status() :: {:ok, map()} | {:error, term()}
  def beta_status do
    config = Config.new()
    Beta.beta_status(config)
  end

  # Beta Agents API
  @doc """
  Create a new AI agent with specific instructions and tools.

  ## Parameters

    * `request` - Agent creation request with:
      - `:name` - Agent name (required)
      - `:model` - Model to use (required)
      - `:instructions` - Instructions for the agent (optional)
      - `:tools` - List of tools available to the agent (optional)
      - `:description` - Agent description (optional)

  ## Examples

      {:ok, agent} = MistralClient.create_agent(%{
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
      })
  """
  @spec create_agent(map()) :: {:ok, MistralClient.Models.Beta.Agent.t()} | {:error, term()}
  def create_agent(request) do
    config = Config.new()
    Beta.create_agent(config, request)
  end

  @doc """
  List all agents with optional pagination.

  ## Examples

      {:ok, agents} = MistralClient.list_agents()
      {:ok, agents} = MistralClient.list_agents(%{page: 1, page_size: 10})
  """
  @spec list_agents(map()) :: {:ok, list(MistralClient.Models.Beta.Agent.t())} | {:error, term()}
  def list_agents(options \\ %{}) do
    config = Config.new()
    Beta.list_agents(config, options)
  end

  @doc """
  Retrieve a specific agent by ID.

  ## Examples

      {:ok, agent} = MistralClient.get_agent("agent_123")
  """
  @spec get_agent(String.t()) :: {:ok, MistralClient.Models.Beta.Agent.t()} | {:error, term()}
  def get_agent(agent_id) do
    config = Config.new()
    Beta.get_agent(config, agent_id)
  end

  @doc """
  Update an agent's configuration.

  ## Examples

      {:ok, updated_agent} = MistralClient.update_agent("agent_123", %{
        instructions: "Updated instructions for the agent"
      })
  """
  @spec update_agent(String.t(), map()) ::
          {:ok, MistralClient.Models.Beta.Agent.t()} | {:error, term()}
  def update_agent(agent_id, updates) do
    config = Config.new()
    Beta.update_agent(config, agent_id, updates)
  end

  # Beta Conversations API
  @doc """
  Start a new conversation with an agent or model.

  ## Parameters

    * `request` - Conversation start request with:
      - `:inputs` - Initial message(s) (required)
      - `:agent_id` - Agent ID to use (optional, mutually exclusive with model)
      - `:model` - Model to use (optional, mutually exclusive with agent_id)
      - `:instructions` - Custom instructions (optional)

  ## Examples

      # Start with an agent
      {:ok, conversation} = MistralClient.start_conversation(%{
        agent_id: "agent_123",
        inputs: "Hello, I need help with my order."
      })

      # Start with a model
      {:ok, conversation} = MistralClient.start_conversation(%{
        model: "mistral-large-latest",
        inputs: "Explain quantum computing",
        instructions: "You are a physics teacher."
      })
  """
  @spec start_conversation(map()) ::
          {:ok, MistralClient.Models.Beta.ConversationResponse.t()} | {:error, term()}
  def start_conversation(request) do
    config = Config.new()
    Beta.start_conversation(config, request)
  end

  @doc """
  Start a new conversation with streaming responses.

  ## Examples

      MistralClient.start_conversation_stream(%{
        agent_id: "agent_123",
        inputs: "Tell me a story"
      }, fn chunk ->
        IO.write(chunk.content || "")
      end)
  """
  @spec start_conversation_stream(map(), function()) :: {:ok, term()} | {:error, term()}
  def start_conversation_stream(request, callback) do
    config = Config.new()
    Beta.start_conversation_stream(config, request, callback)
  end

  @doc """
  List conversations with optional pagination.

  ## Examples

      {:ok, conversations} = MistralClient.list_conversations()
  """
  @spec list_conversations(map()) ::
          {:ok, list(MistralClient.Models.Beta.Conversation.t())} | {:error, term()}
  def list_conversations(options \\ %{}) do
    config = Config.new()
    Beta.list_conversations(config, options)
  end

  @doc """
  Append new messages to an existing conversation.

  ## Examples

      {:ok, response} = MistralClient.append_to_conversation(conversation_id, %{
        inputs: "What's the weather like today?"
      })
  """
  @spec append_to_conversation(String.t(), map()) ::
          {:ok, MistralClient.Models.Beta.ConversationResponse.t()} | {:error, term()}
  def append_to_conversation(conversation_id, request) do
    config = Config.new()
    Beta.append_to_conversation(config, conversation_id, request)
  end

  @doc """
  Get the history of a conversation.

  ## Examples

      {:ok, history} = MistralClient.get_conversation_history(conversation_id)
  """
  @spec get_conversation_history(String.t()) ::
          {:ok, MistralClient.Models.Beta.ConversationHistory.t()} | {:error, term()}
  def get_conversation_history(conversation_id) do
    config = Config.new()
    Beta.get_conversation_history(config, conversation_id)
  end

  # Classifiers API
  @doc """
  Moderate text content for safety and policy violations.

  ## Parameters

    * `model` - Model to use for moderation (e.g., "mistral-moderation-latest")
    * `inputs` - Text to moderate (string or list of strings)

  ## Examples

      # Moderate a single text
      {:ok, response} = MistralClient.moderate(
        "mistral-moderation-latest",
        "This is some text to moderate"
      )

      # Moderate multiple texts
      {:ok, response} = MistralClient.moderate(
        "mistral-moderation-latest",
        ["Text 1", "Text 2", "Text 3"]
      )
  """
  @spec moderate(String.t(), String.t() | list(String.t())) ::
          {:ok, MistralClient.Models.ModerationResponse.t()} | {:error, term()}
  def moderate(model, inputs) do
    client = Client.new()
    Classifiers.moderate(client, model, inputs)
  end

  @doc """
  Moderate chat conversations for safety and policy violations.

  ## Parameters

    * `model` - Model to use for moderation
    * `inputs` - Chat conversations to moderate (list of message lists)

  ## Examples

      {:ok, response} = MistralClient.moderate_chat(
        "mistral-moderation-latest",
        [
          [
            %{role: "user", content: "Hello"},
            %{role: "assistant", content: "Hi there!"}
          ]
        ]
      )
  """
  @spec moderate_chat(String.t(), list(list(map()))) ::
          {:ok, MistralClient.Models.ModerationResponse.t()} | {:error, term()}
  def moderate_chat(model, inputs) do
    client = Client.new()
    Classifiers.moderate_chat(client, model, inputs)
  end

  @doc """
  Classify text into categories.

  ## Parameters

    * `model` - Model to use for classification
    * `inputs` - Text to classify (string or list of strings)

  ## Examples

      # Classify a single text
      {:ok, response} = MistralClient.classify(
        "mistral-classifier-latest",
        "This is some text to classify"
      )

      # Classify multiple texts
      {:ok, response} = MistralClient.classify(
        "mistral-classifier-latest",
        ["Text 1", "Text 2", "Text 3"]
      )
  """
  @spec classify(String.t(), String.t() | list(String.t())) ::
          {:ok, MistralClient.Models.ClassificationResponse.t()} | {:error, term()}
  def classify(model, inputs) do
    client = Client.new()
    Classifiers.classify(client, model, inputs)
  end

  @doc """
  Classify chat conversations into categories.

  ## Parameters

    * `model` - Model to use for classification
    * `inputs` - Chat conversations to classify

  ## Examples

      {:ok, response} = MistralClient.classify_chat(
        "mistral-classifier-latest",
        [%{messages: [%{role: "user", content: "Hello"}]}]
      )
  """
  @spec classify_chat(String.t(), list(map())) ::
          {:ok, MistralClient.Models.ClassificationResponse.t()} | {:error, term()}
  def classify_chat(model, inputs) do
    client = Client.new()
    Classifiers.classify_chat(client, model, inputs)
  end

  # Configuration helpers
  @doc """
  Get the current configuration.

  ## Examples

      config = MistralClient.config()
  """
  @spec config() :: map()
  def config do
    Config.get()
  end

  @doc """
  Create a new client with custom configuration.

  ## Parameters

    * `options` - Configuration options

  ## Examples

      client = MistralClient.new(api_key: "custom-key", timeout: 60_000)
  """
  @spec new(keyword()) :: Client.t()
  def new(options \\ []) do
    Client.new(options)
  end
end
