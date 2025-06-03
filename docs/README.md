# Mistral SDK for Elixir

A comprehensive Elixir SDK for the Mistral AI API, providing access to all Mistral AI services including chat completions, embeddings, fine-tuning, agents, and more.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Migration from Python SDK](#migration-from-python-sdk)
- [Contributing](#contributing)

## Installation

Add `mistralex_ai` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mistralex_ai, "~> 1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

```elixir
# Configure your API key
config = MistralClient.Config.new(api_key: "your-api-key")

# Create a simple chat completion
{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [
    %{role: "user", content: "Hello, how are you?"}
  ]
})

IO.puts(response.choices |> List.first() |> Map.get(:message) |> Map.get(:content))
```

## Configuration

### Basic Configuration

```elixir
# Using environment variables
config = MistralClient.Config.new()  # Uses MISTRAL_API_KEY env var

# Explicit configuration
config = MistralClient.Config.new(
  api_key: "your-api-key",
  endpoint: "https://api.mistral.ai",  # Optional, defaults to official endpoint
  timeout: 30_000,                     # Optional, defaults to 30 seconds
  max_retries: 3                       # Optional, defaults to 3
)
```

### Application Configuration

Add to your `config/config.exs`:

```elixir
config :mistralex_ai,
  api_key: System.get_env("MISTRAL_API_KEY"),
  endpoint: "https://api.mistral.ai",
  timeout: 30_000,
  max_retries: 3
```

## API Reference

### Chat Completions

The Chat API allows you to generate conversational responses.

```elixir
# Basic chat completion
{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [
    %{role: "system", content: "You are a helpful assistant."},
    %{role: "user", content: "Explain quantum computing"}
  ],
  max_tokens: 1000,
  temperature: 0.7
})

# Streaming chat completion
MistralClient.chat_stream(config, %{
  model: "mistral-large-latest",
  messages: [%{role: "user", content: "Tell me a story"}]
}, fn chunk ->
  case chunk do
    {:data, data} -> IO.write(data.choices |> List.first() |> Map.get(:delta) |> Map.get(:content, ""))
    {:done} -> IO.puts("\n--- Stream completed ---")
    {:error, error} -> IO.puts("Error: #{inspect(error)}")
  end
end)
```

### Function Calling / Tools

```elixir
tools = [
  %{
    type: "function",
    function: %{
      name: "get_weather",
      description: "Get current weather for a location",
      parameters: %{
        type: "object",
        properties: %{
          location: %{type: "string", description: "City name"}
        },
        required: ["location"]
      }
    }
  }
]

{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [%{role: "user", content: "What's the weather in Paris?"}],
  tools: tools,
  tool_choice: "auto"
})
```

### Embeddings

Generate vector embeddings for text.

```elixir
# Single text embedding
{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: "Hello, world!"
})

# Batch embeddings
{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: ["Text 1", "Text 2", "Text 3"]
})

embeddings = response.data |> Enum.map(& &1.embedding)
```

### Models

List and manage available models.

```elixir
# List all models
{:ok, models} = MistralClient.list_models(config)

# Get specific model
{:ok, model} = MistralClient.get_model(config, "mistral-large-latest")

# List only fine-tuned models
{:ok, fine_tuned} = MistralClient.list_models(config, %{owned_by: "user"})
```

### Files

Manage files for fine-tuning and other operations.

```elixir
# Upload a file
{:ok, file} = MistralClient.upload_file(config, %{
  file: "/path/to/training_data.jsonl",
  purpose: "fine-tune"
})

# List files
{:ok, files} = MistralClient.list_files(config)

# Download a file
{:ok, content} = MistralClient.download_file(config, file.id)

# Delete a file
{:ok, _} = MistralClient.delete_file(config, file.id)
```

### Fine-tuning

Train custom models on your data.

```elixir
# Create a fine-tuning job
{:ok, job} = MistralClient.create_fine_tuning_job(config, %{
  model: "mistral-small-latest",
  training_files: [file.id],
  validation_files: [validation_file.id],
  hyperparameters: %{
    training_steps: 1000,
    learning_rate: 0.0001
  }
})

# Start the job
{:ok, started_job} = MistralClient.start_fine_tuning_job(config, job.id)

# Monitor job progress
{:ok, job_status} = MistralClient.get_fine_tuning_job(config, job.id)

# List all jobs
{:ok, jobs} = MistralClient.list_fine_tuning_jobs(config)
```

### Agents

Use Mistral agents for specialized tasks.

```elixir
# Create an agent
{:ok, agent} = MistralClient.create_agent(config, %{
  name: "Code Assistant",
  description: "Helps with coding tasks",
  instructions: "You are an expert programmer. Help users with coding questions.",
  model: "mistral-large-latest",
  tools: [
    %{
      type: "function",
      function: %{
        name: "execute_code",
        description: "Execute Python code",
        parameters: %{
          type: "object",
          properties: %{
            code: %{type: "string"}
          }
        }
      }
    }
  ]
})

# Use agent for completion
{:ok, response} = MistralClient.agents_complete(config, %{
  agent_id: agent.id,
  messages: [%{role: "user", content: "Write a Python function to calculate fibonacci"}]
})
```

### Fill-in-the-Middle (FIM)

Code completion using FIM models.

```elixir
# FIM completion
{:ok, response} = MistralClient.fim_complete(config, %{
  model: "codestral-latest",
  prompt: "def fibonacci(n):",
  suffix: "    return result",
  max_tokens: 100
})

# Streaming FIM
MistralClient.fim_stream(config, %{
  model: "codestral-latest",
  prompt: "function calculateSum(",
  suffix: ") { return sum; }"
}, fn chunk ->
  case chunk do
    {:data, data} -> IO.write(data.choices |> List.first() |> Map.get(:delta) |> Map.get(:content, ""))
    {:done} -> IO.puts("\n--- Completion done ---")
  end
end)
```

### Batch Processing

Process multiple requests efficiently.

```elixir
# Create batch job
{:ok, batch} = MistralClient.create_batch_job(config, %{
  input_files: [batch_file.id],
  endpoint: "/v1/chat/completions",
  completion_window: "24h"
})

# Monitor batch progress
{:ok, batch_status} = MistralClient.get_batch_job(config, batch.id)

# Cancel batch if needed
{:ok, _} = MistralClient.cancel_batch_job(config, batch.id)
```

### Content Moderation

Classify and moderate content.

```elixir
# Text moderation
{:ok, result} = MistralClient.moderate(config, %{
  model: "mistral-moderation-latest",
  input: "This is some text to moderate"
})

# Chat moderation
{:ok, result} = MistralClient.moderate_chat(config, %{
  model: "mistral-moderation-latest",
  input: [
    %{role: "user", content: "Hello"},
    %{role: "assistant", content: "Hi there!"}
  ]
})

# Custom classification
{:ok, result} = MistralClient.classify(config, %{
  model: "mistral-large-latest",
  input: "I love this product!",
  categories: ["positive", "negative", "neutral"]
})
```

### OCR (Optical Character Recognition)

Extract text from images and documents.

```elixir
# Process document URL
{:ok, result} = MistralClient.ocr_process(config, "pixtral-12b-2409", %{
  type: "document_url",
  document_url: "https://example.com/document.pdf"
})

# Process image with base64
{:ok, result} = MistralClient.ocr_process(config, "pixtral-12b-2409", %{
  type: "image_url",
  image_url: "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ..."
})
```

## Examples

### Complete Chat Application

```elixir
defmodule ChatBot do
  def start do
    config = MistralClient.Config.new()
    conversation_loop(config, [])
  end

  defp conversation_loop(config, history) do
    IO.write("You: ")
    user_input = IO.gets("") |> String.trim()

    if user_input == "quit" do
      IO.puts("Goodbye!")
    else
      messages = history ++ [%{role: "user", content: user_input}]

      case MistralClient.chat_complete(config, %{
        model: "mistral-large-latest",
        messages: messages,
        max_tokens: 1000
      }) do
        {:ok, response} ->
          assistant_message = response.choices |> List.first() |> Map.get(:message)
          IO.puts("Assistant: #{assistant_message.content}")

          new_history = messages ++ [assistant_message]
          conversation_loop(config, new_history)

        {:error, error} ->
          IO.puts("Error: #{inspect(error)}")
          conversation_loop(config, history)
      end
    end
  end
end

# Start the chat
ChatBot.start()
```

### Document Analysis with OCR

```elixir
defmodule DocumentAnalyzer do
  def analyze_document(config, document_url) do
    # First, extract text using OCR
    case MistralClient.ocr_process(config, "pixtral-12b-2409", %{
      type: "document_url",
      document_url: document_url
    }) do
      {:ok, ocr_result} ->
        extracted_text = ocr_result.choices |> List.first() |> Map.get(:message) |> Map.get(:content)

        # Then analyze the extracted text
        analyze_text(config, extracted_text)

      {:error, error} ->
        {:error, "OCR failed: #{inspect(error)}"}
    end
  end

  defp analyze_text(config, text) do
    MistralClient.chat_complete(config, %{
      model: "mistral-large-latest",
      messages: [
        %{role: "system", content: "You are a document analyzer. Summarize the key points and extract important information."},
        %{role: "user", content: "Analyze this document:\n\n#{text}"}
      ]
    })
  end
end
```

### Fine-tuning Workflow

```elixir
defmodule FineTuningWorkflow do
  def create_custom_model(config, training_file_path, model_name) do
    with {:ok, file} <- upload_training_data(config, training_file_path),
         {:ok, job} <- create_job(config, file.id, model_name),
         {:ok, started_job} <- start_job(config, job.id),
         {:ok, completed_job} <- wait_for_completion(config, started_job.id) do
      {:ok, completed_job.fine_tuned_model}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp upload_training_data(config, file_path) do
    MistralClient.upload_file(config, %{
      file: file_path,
      purpose: "fine-tune"
    })
  end

  defp create_job(config, file_id, model_name) do
    MistralClient.create_fine_tuning_job(config, %{
      model: "mistral-small-latest",
      training_files: [file_id],
      suffix: model_name,
      hyperparameters: %{
        training_steps: 1000,
        learning_rate: 0.0001
      }
    })
  end

  defp start_job(config, job_id) do
    MistralClient.start_fine_tuning_job(config, job_id)
  end

  defp wait_for_completion(config, job_id) do
    case MistralClient.get_fine_tuning_job(config, job_id) do
      {:ok, %{status: :succeeded} = job} -> {:ok, job}
      {:ok, %{status: :failed} = job} -> {:error, "Job failed: #{job.error}"}
      {:ok, %{status: status}} when status in [:queued, :running] ->
        :timer.sleep(10_000)  # Wait 10 seconds
        wait_for_completion(config, job_id)
      {:error, reason} -> {:error, reason}
    end
  end
end
```

## Best Practices

### Error Handling

Always handle errors appropriately:

```elixir
case MistralClient.chat_complete(config, request) do
  {:ok, response} ->
    # Handle success
    process_response(response)

  {:error, %MistralClient.Errors.APIError{status: 429}} ->
    # Rate limit exceeded - implement backoff
    :timer.sleep(1000)
    retry_request(config, request)

  {:error, %MistralClient.Errors.APIError{status: 401}} ->
    # Authentication error
    {:error, "Invalid API key"}

  {:error, %MistralClient.Errors.NetworkError{}} ->
    # Network error - retry with exponential backoff
    retry_with_backoff(config, request)

  {:error, reason} ->
    # Other errors
    {:error, reason}
end
```

### Configuration Management

Use application configuration for production:

```elixir
# config/prod.exs
config :mistralex_ai,
  api_key: System.get_env("MISTRAL_API_KEY"),
  timeout: 60_000,
  max_retries: 5

# In your application
defmodule MyApp.MistralService do
  def get_config do
    Application.get_env(:mistralex_ai)
    |> MistralClient.Config.new()
  end
end
```

### Streaming Best Practices

Handle streaming responses robustly:

```elixir
defmodule StreamHandler do
  def handle_stream(config, request) do
    collected_content = []

    MistralClient.chat_stream(config, request, fn chunk ->
      case chunk do
        {:data, data} ->
          content = extract_content(data)
          collected_content = [content | collected_content]

        {:done} ->
          final_content = collected_content |> Enum.reverse() |> Enum.join()
          send(self(), {:stream_complete, final_content})

        {:error, error} ->
          send(self(), {:stream_error, error})
      end
    end)

    receive do
      {:stream_complete, content} -> {:ok, content}
      {:stream_error, error} -> {:error, error}
    after
      30_000 -> {:error, :timeout}
    end
  end

  defp extract_content(data) do
    data.choices
    |> List.first()
    |> Map.get(:delta, %{})
    |> Map.get(:content, "")
  end
end
```

### Resource Management

Clean up resources properly:

```elixir
defmodule ResourceManager do
  def with_temporary_file(config, file_path, fun) do
    case MistralClient.upload_file(config, %{file: file_path, purpose: "fine-tune"}) do
      {:ok, file} ->
        try do
          fun.(file)
        after
          MistralClient.delete_file(config, file.id)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Migration from Python SDK

### Key Differences

| Python SDK | Elixir SDK | Notes |
|------------|------------|-------|
| `client = MistralClient(api_key="...")` | `config = MistralClient.Config.new(api_key: "...")` | Configuration approach |
| `client.chat(...)` | `MistralClient.chat_complete(config, ...)` | Function-based API |
| `client.embeddings(...)` | `MistralClient.embeddings_create(config, ...)` | Explicit operation names |
| Exception handling | `{:ok, result} \| {:error, reason}` | Elixir tuple conventions |
| Async/await | Streaming with callbacks | Different concurrency model |

### Migration Examples

**Python:**
```python
from mistralai.client import MistralClient

client = MistralClient(api_key="your-api-key")

response = client.chat(
    model="mistral-large-latest",
    messages=[{"role": "user", "content": "Hello"}]
)

print(response.choices[0].message.content)
```

**Elixir:**
```elixir
config = MistralClient.Config.new(api_key: "your-api-key")

{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [%{role: "user", content: "Hello"}]
})

response.choices |> List.first() |> Map.get(:message) |> Map.get(:content) |> IO.puts()
```

### Common Patterns

**Error Handling Migration:**

Python:
```python
try:
    response = client.chat(...)
except MistralAPIError as e:
    print(f"API Error: {e}")
except Exception as e:
    print(f"Unexpected error: {e}")
```

Elixir:
```elixir
case MistralClient.chat_complete(config, request) do
  {:ok, response} -> process_response(response)
  {:error, %MistralClient.Errors.APIError{} = error} -> handle_api_error(error)
  {:error, reason} -> handle_other_error(reason)
end
```

**Streaming Migration:**

Python:
```python
for chunk in client.chat_stream(...):
    print(chunk.choices[0].delta.content, end="")
```

Elixir:
```elixir
MistralClient.chat_stream(config, request, fn chunk ->
  case chunk do
    {:data, data} ->
      content = data.choices |> List.first() |> Map.get(:delta) |> Map.get(:content, "")
      IO.write(content)
    {:done} -> IO.puts("\n")
  end
end)
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`mix test`)
5. Format your code (`mix format`)
6. Commit your changes (`git commit -am 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- [GitHub Issues](https://github.com/your-org/mistralex_ai/issues)
- [Documentation](https://hexdocs.pm/mistralex_ai)
- [Mistral AI Documentation](https://docs.mistral.ai/)
