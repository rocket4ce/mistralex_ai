# MistralClient SDK for Elixir

A comprehensive Elixir client for the Mistral AI API with complete feature parity to the Python SDK.

[![Hex.pm](https://img.shields.io/hexpm/v/mistral_client.svg)](https://hex.pm/packages/mistral_client)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/mistral_client)

## Features

- ✅ **Complete API Coverage**: Chat, Embeddings, Models, Files, and more
- ✅ **Streaming Support**: Real-time chat completions with Server-Sent Events
- ✅ **Type Safety**: Comprehensive Elixir structs and typespecs
- ✅ **Error Handling**: Robust error handling with automatic retries
- ✅ **Configuration**: Flexible configuration via application config or environment variables
- ✅ **Authentication**: Secure API key management
- ✅ **Rate Limiting**: Built-in rate limit handling with exponential backoff
- ✅ **File Operations**: Upload/download with multipart support
- ✅ **Tool Calling**: Function calling and structured outputs
- ✅ **Similarity Functions**: Built-in cosine similarity and distance calculations

## Installation

Add `mistral_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mistral_client, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Configuration

Set your API key using one of these methods:

**Environment Variable (Recommended):**
```bash
export MISTRAL_API_KEY="your-api-key-here"
```

**Application Configuration:**
```elixir
# config/config.exs
config :mistral_client,
  api_key: "your-api-key-here",
  base_url: "https://api.mistral.ai",
  timeout: 30_000
```

### 2. Basic Usage

```elixir
# Chat completion
{:ok, response} = MistralClient.chat([
  %{role: "user", content: "Hello, how are you?"}
])

# Generate embeddings
{:ok, embeddings} = MistralClient.embeddings("Hello world")

# List available models
{:ok, models} = MistralClient.models()
```

## API Reference

### Chat Completions

```elixir
# Basic chat
{:ok, response} = MistralClient.chat([
  %{role: "user", content: "What is the capital of France?"}
])

# With options
{:ok, response} = MistralClient.chat(
  [%{role: "user", content: "Hello!"}],
  %{model: "mistral-large-latest", temperature: 0.7, max_tokens: 100}
)

# Streaming chat
MistralClient.chat_stream([
  %{role: "user", content: "Tell me a story"}
], fn chunk ->
  content = get_in(chunk, ["choices", Access.at(0), "delta", "content"])
  if content, do: IO.write(content)
end)

# Tool calling
tools = [
  %{
    type: "function",
    function: %{
      name: "get_weather",
      description: "Get current weather",
      parameters: %{
        type: "object",
        properties: %{location: %{type: "string"}},
        required: ["location"]
      }
    }
  }
]

{:ok, response} = MistralClient.API.Chat.with_tools(messages, tools)
```

### Embeddings

```elixir
# Single text
{:ok, response} = MistralClient.embeddings("Hello world")

# Multiple texts
{:ok, response} = MistralClient.embeddings([
  "First document",
  "Second document"
])

# With options
{:ok, response} = MistralClient.embeddings(
  "Hello world",
  %{model: "mistral-embed", dimensions: 1024}
)

# Extract embeddings
embeddings = MistralClient.API.Embeddings.extract_embeddings(response)

# Calculate similarity
similarity = MistralClient.API.Embeddings.cosine_similarity(
  embedding1,
  embedding2
)
```

### Models

```elixir
# List all models
{:ok, models} = MistralClient.models()

# Get specific model
{:ok, model} = MistralClient.model("mistral-large-latest")

# Filter models
{:ok, all_models} = MistralClient.API.Models.list()
base_models = MistralClient.API.Models.filter_models(all_models, :base)
fine_tuned = MistralClient.API.Models.filter_models(all_models, :fine_tuned)
```

### Files

```elixir
# Upload file
{:ok, file} = MistralClient.upload_file("./data.jsonl", "fine-tune")

# List files
{:ok, files} = MistralClient.files()

# Download file
{:ok, content} = MistralClient.API.Files.download("file-abc123")

# Delete file
{:ok, _} = MistralClient.delete_file("file-abc123")
```

## Advanced Usage

### Custom Client Configuration

```elixir
# Create client with custom settings
client = MistralClient.new(
  api_key: "custom-key",
  timeout: 60_000,
  max_retries: 5
)

# Use custom client
{:ok, response} = MistralClient.API.Chat.complete(messages, %{}, client)
```

### Error Handling

```elixir
case MistralClient.chat(messages) do
  {:ok, response} ->
    # Handle success
    IO.puts("Response: #{response.choices |> hd() |> get_in(["message", "content"])}")

  {:error, %MistralClient.Errors.RateLimitError{retry_after: seconds}} ->
    # Handle rate limiting
    IO.puts("Rate limited. Retry after #{seconds} seconds")

  {:error, %MistralClient.Errors.AuthenticationError{}} ->
    # Handle auth error
    IO.puts("Invalid API key")

  {:error, error} ->
    # Handle other errors
    IO.puts("Error: #{Exception.message(error)}")
end
```

### Streaming with Custom Processing

```elixir
alias MistralClient.Stream

MistralClient.chat_stream(messages, fn chunk ->
  case Stream.extract_content(chunk) do
    nil -> :ok
    content ->
      IO.write(content)

      # Check if stream is complete
      if Stream.stream_complete?(chunk) do
        reason = Stream.extract_finish_reason(chunk)
        IO.puts("\nStream finished: #{reason}")
      end
  end
end)
```

## Configuration Options

| Option | Environment Variable | Default | Description |
|--------|---------------------|---------|-------------|
| `:api_key` | `MISTRAL_API_KEY` | `nil` | Your Mistral API key (required) |
| `:base_url` | `MISTRAL_BASE_URL` | `"https://api.mistral.ai"` | API base URL |
| `:timeout` | `MISTRAL_TIMEOUT` | `30_000` | Request timeout (ms) |
| `:max_retries` | `MISTRAL_MAX_RETRIES` | `3` | Maximum retry attempts |
| `:retry_delay` | `MISTRAL_RETRY_DELAY` | `1_000` | Base retry delay (ms) |
| `:user_agent` | `MISTRAL_USER_AGENT` | `"mistral-client-elixir/0.1.0"` | User agent string |

## Examples

Run the included examples:

```bash
cd mistralex_sdk

# Set your API key
export MISTRAL_API_KEY="your-api-key-here"

# Run basic usage example
elixir examples/basic_usage.exs
```

## Development

```bash
# Clone the repository
git clone https://github.com/rocket4ce/mistralex_ai.git
cd mistral_client

# Install dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs

# Check code quality
mix credo
mix dialyzer
```

## API Coverage

### ✅ Implemented

- **Chat API**: Complete, streaming, tool calling, structured outputs
- **Embeddings API**: Single/batch generation, similarity functions
- **Models API**: List, retrieve, manage fine-tuned models
- **Files API**: Upload, download, list, delete with multipart support

### 🚧 In Progress

- **Agents API**: AI agents management
- **Fine-tuning API**: Model training and management
- **Batch API**: Batch processing operations

### ⏳ Planned

- **Conversations API**: Beta conversation management
- **Jobs API**: Job management and monitoring
- **Classifiers API**: Text classification
- **OCR API**: Optical character recognition
- **FIM API**: Fill-in-the-middle completion

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Mistral AI](https://mistral.ai/) for providing the API
- [mistral-client-python](https://github.com/mistralai/client-python) for API reference
- The Elixir community for excellent libraries and tools

## Support

- 📖 [Documentation](https://hexdocs.pm/mistral_client)
- 🐛 [Issue Tracker](https://github.com/rocket4ce/mistralex_ai/issues)
- 💬 [Discussions](https://github.com/rocket4ce/mistralex_ai/discussions)
