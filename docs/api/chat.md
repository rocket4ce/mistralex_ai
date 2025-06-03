# Chat API Documentation

The Chat API is the core interface for conversational AI interactions with Mistral models. It supports both single-turn and multi-turn conversations, function calling, structured outputs, and streaming responses.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Configuration](#configuration)
- [Message Formats](#message-formats)
- [Function Calling](#function-calling)
- [Structured Outputs](#structured-outputs)
- [Streaming](#streaming)
- [Error Handling](#error-handling)
- [Advanced Examples](#advanced-examples)

## Basic Usage

### Simple Chat Completion

```elixir
config = MistralClient.Config.new(api_key: "your-api-key")

{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [
    %{role: "user", content: "What is the capital of France?"}
  ]
})

# Extract the response
message = response.choices |> List.first() |> Map.get(:message)
IO.puts(message.content)  # "The capital of France is Paris."
```

### Multi-turn Conversation

```elixir
messages = [
  %{role: "system", content: "You are a helpful assistant."},
  %{role: "user", content: "Hello!"},
  %{role: "assistant", content: "Hello! How can I help you today?"},
  %{role: "user", content: "What's the weather like?"}
]

{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: messages,
  max_tokens: 150,
  temperature: 0.7
})
```

## Configuration

### Available Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | String | Required | Model to use (e.g., "mistral-large-latest") |
| `messages` | List | Required | List of message objects |
| `max_tokens` | Integer | nil | Maximum tokens to generate |
| `temperature` | Float | 0.7 | Sampling temperature (0.0 to 2.0) |
| `top_p` | Float | 1.0 | Nucleus sampling parameter |
| `stream` | Boolean | false | Enable streaming responses |
| `stop` | String/List | nil | Stop sequences |
| `random_seed` | Integer | nil | Seed for deterministic outputs |
| `tools` | List | nil | Available functions for calling |
| `tool_choice` | String/Object | "auto" | Tool selection strategy |
| `response_format` | Object | nil | Structured output format |

### Model Selection

```elixir
# Available models
models = [
  "mistral-large-latest",      # Most capable model
  "mistral-medium-latest",     # Balanced performance
  "mistral-small-latest",      # Fast and efficient
  "codestral-latest",          # Code-specialized
  "mistral-embed"              # Embeddings only
]

# Choose based on your needs
config = %{
  model: "mistral-large-latest",  # For complex reasoning
  # model: "mistral-small-latest",  # For simple tasks
  # model: "codestral-latest",      # For code generation
  messages: messages
}
```

## Message Formats

### Basic Message Structure

```elixir
%{
  role: "user" | "assistant" | "system" | "tool",
  content: "Message content",
  name: "optional_name",        # For tool messages
  tool_calls: [],               # For assistant messages with tool calls
  tool_call_id: "id"           # For tool response messages
}
```

### System Messages

```elixir
system_message = %{
  role: "system",
  content: """
  You are an expert software engineer with deep knowledge of Elixir.
  Always provide code examples and explain your reasoning.
  Be concise but thorough in your explanations.
  """
}
```

### User Messages with Context

```elixir
user_message = %{
  role: "user",
  content: """
  I'm building a GenServer that needs to handle rate limiting.
  Can you show me how to implement a token bucket algorithm?
  """
}
```

### Assistant Messages

```elixir
assistant_message = %{
  role: "assistant",
  content: "I'll help you implement a token bucket rate limiter...",
  tool_calls: [
    %{
      id: "call_123",
      type: "function",
      function: %{
        name: "generate_code",
        arguments: "{\"language\": \"elixir\"}"
      }
    }
  ]
}
```

## Function Calling

### Defining Tools

```elixir
tools = [
  %{
    type: "function",
    function: %{
      name: "get_weather",
      description: "Get current weather information for a location",
      parameters: %{
        type: "object",
        properties: %{
          location: %{
            type: "string",
            description: "City name or coordinates"
          },
          units: %{
            type: "string",
            enum: ["celsius", "fahrenheit"],
            description: "Temperature units"
          }
        },
        required: ["location"]
      }
    }
  },
  %{
    type: "function",
    function: %{
      name: "search_web",
      description: "Search the web for information",
      parameters: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Search query"},
          max_results: %{type: "integer", description: "Maximum results"}
        },
        required: ["query"]
      }
    }
  }
]
```

### Using Tools

```elixir
{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [
    %{role: "user", content: "What's the weather in Paris and search for recent news about AI?"}
  ],
  tools: tools,
  tool_choice: "auto"  # Let the model decide which tools to use
})

# Handle tool calls
case response.choices |> List.first() |> Map.get(:message) do
  %{tool_calls: tool_calls} when is_list(tool_calls) ->
    # Process each tool call
    results = Enum.map(tool_calls, &execute_tool_call/1)

    # Continue conversation with tool results
    continue_with_tool_results(config, messages, tool_calls, results)

  %{content: content} ->
    # Regular response without tool calls
    IO.puts(content)
end
```

### Tool Execution Example

```elixir
defmodule ToolExecutor do
  def execute_tool_call(%{function: %{name: "get_weather", arguments: args}}) do
    %{location: location} = Jason.decode!(args)

    # Simulate weather API call
    %{
      temperature: 22,
      condition: "sunny",
      location: location
    }
  end

  def execute_tool_call(%{function: %{name: "search_web", arguments: args}}) do
    %{query: query} = Jason.decode!(args)

    # Simulate web search
    [
      %{title: "AI News", url: "https://example.com", snippet: "Latest AI developments..."}
    ]
  end

  def continue_with_tool_results(config, original_messages, tool_calls, results) do
    # Add assistant message with tool calls
    assistant_msg = %{
      role: "assistant",
      tool_calls: tool_calls
    }

    # Add tool result messages
    tool_messages = Enum.zip(tool_calls, results)
    |> Enum.map(fn {call, result} ->
      %{
        role: "tool",
        tool_call_id: call.id,
        content: Jason.encode!(result)
      }
    end)

    # Continue conversation
    new_messages = original_messages ++ [assistant_msg] ++ tool_messages

    MistralClient.chat_complete(config, %{
      model: "mistral-large-latest",
      messages: new_messages
    })
  end
end
```

## Structured Outputs

### JSON Schema Response Format

```elixir
# Define the expected response structure
response_format = %{
  type: "json_object",
  schema: %{
    type: "object",
    properties: %{
      analysis: %{
        type: "object",
        properties: %{
          sentiment: %{type: "string", enum: ["positive", "negative", "neutral"]},
          confidence: %{type: "number", minimum: 0, maximum: 1},
          key_topics: %{type: "array", items: %{type: "string"}},
          summary: %{type: "string"}
        },
        required: ["sentiment", "confidence", "summary"]
      }
    },
    required: ["analysis"]
  }
}

{:ok, response} = MistralClient.chat_complete(config, %{
  model: "mistral-large-latest",
  messages: [
    %{role: "system", content: "Analyze the sentiment and extract key information from the given text."},
    %{role: "user", content: "I absolutely love this new product! It's innovative and well-designed."}
  ],
  response_format: response_format
})

# Parse structured response
analysis = response.choices
|> List.first()
|> Map.get(:message)
|> Map.get(:content)
|> Jason.decode!()
|> Map.get("analysis")

IO.inspect(analysis)
# %{
#   "sentiment" => "positive",
#   "confidence" => 0.95,
#   "key_topics" => ["product", "innovation", "design"],
#   "summary" => "Highly positive review praising innovation and design"
# }
```

### Data Extraction Example

```elixir
defmodule DataExtractor do
  def extract_contact_info(config, text) do
    schema = %{
      type: "object",
      properties: %{
        contacts: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              name: %{type: "string"},
              email: %{type: "string", format: "email"},
              phone: %{type: "string"},
              company: %{type: "string"}
            },
            required: ["name"]
          }
        }
      },
      required: ["contacts"]
    }

    MistralClient.chat_complete(config, %{
      model: "mistral-large-latest",
      messages: [
        %{role: "system", content: "Extract contact information from the provided text."},
        %{role: "user", content: text}
      ],
      response_format: %{type: "json_object", schema: schema}
    })
  end
end
```

## Streaming

### Basic Streaming

```elixir
MistralClient.chat_stream(config, %{
  model: "mistral-large-latest",
  messages: [%{role: "user", content: "Tell me a story about a brave knight"}]
}, fn chunk ->
  case chunk do
    {:data, data} ->
      # Extract content from the chunk
      content = data.choices
      |> List.first()
      |> Map.get(:delta, %{})
      |> Map.get(:content, "")

      IO.write(content)

    {:done} ->
      IO.puts("\n--- Story completed ---")

    {:error, error} ->
      IO.puts("Stream error: #{inspect(error)}")
  end
end)
```

### Advanced Streaming with State

```elixir
defmodule StreamCollector do
  def collect_stream(config, request) do
    collector_pid = spawn(fn -> collect_loop([]) end)

    MistralClient.chat_stream(config, request, fn chunk ->
      case chunk do
        {:data, data} ->
          content = extract_content(data)
          send(collector_pid, {:chunk, content})

        {:done} ->
          send(collector_pid, :done)

        {:error, error} ->
          send(collector_pid, {:error, error})
      end
    end)

    # Wait for completion
    receive do
      {:complete, full_text} -> {:ok, full_text}
      {:error, reason} -> {:error, reason}
    after
      30_000 -> {:error, :timeout}
    end
  end

  defp collect_loop(chunks) do
    receive do
      {:chunk, content} ->
        collect_loop([content | chunks])

      :done ->
        full_text = chunks |> Enum.reverse() |> Enum.join()
        send(self(), {:complete, full_text})

      {:error, reason} ->
        send(self(), {:error, reason})
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

### Streaming with Function Calls

```elixir
defmodule StreamingToolHandler do
  def handle_streaming_with_tools(config, messages, tools) do
    tool_calls = []
    current_call = nil

    MistralClient.chat_stream(config, %{
      model: "mistral-large-latest",
      messages: messages,
      tools: tools,
      tool_choice: "auto"
    }, fn chunk ->
      case chunk do
        {:data, data} ->
          delta = data.choices |> List.first() |> Map.get(:delta, %{})

          cond do
            Map.has_key?(delta, :tool_calls) ->
              # Handle tool call deltas
              handle_tool_call_delta(delta.tool_calls)

            Map.has_key?(delta, :content) ->
              # Handle regular content
              IO.write(delta.content)

            true ->
              # Other delta types
              :ok
          end

        {:done} ->
          IO.puts("\n--- Stream completed ---")

        {:error, error} ->
          IO.puts("Error: #{inspect(error)}")
      end
    end)
  end

  defp handle_tool_call_delta(tool_call_deltas) do
    # Process incremental tool call information
    Enum.each(tool_call_deltas, fn delta ->
      IO.puts("Tool call delta: #{inspect(delta)}")
    end)
  end
end
```

## Error Handling

### Common Error Types

```elixir
case MistralClient.chat_complete(config, request) do
  {:ok, response} ->
    # Success case
    process_response(response)

  {:error, %MistralClient.Errors.APIError{status: 400, message: message}} ->
    # Bad request - invalid parameters
    {:error, "Invalid request: #{message}"}

  {:error, %MistralClient.Errors.APIError{status: 401}} ->
    # Authentication error
    {:error, "Invalid API key"}

  {:error, %MistralClient.Errors.APIError{status: 429}} ->
    # Rate limit exceeded
    handle_rate_limit()

  {:error, %MistralClient.Errors.APIError{status: 500}} ->
    # Server error
    {:error, "Server error, please try again"}

  {:error, %MistralClient.Errors.NetworkError{reason: reason}} ->
    # Network connectivity issues
    {:error, "Network error: #{reason}"}

  {:error, %MistralClient.Errors.ValidationError{message: message}} ->
    # Client-side validation error
    {:error, "Validation error: #{message}"}

  {:error, reason} ->
    # Other errors
    {:error, "Unexpected error: #{inspect(reason)}"}
end
```

### Retry Logic with Exponential Backoff

```elixir
defmodule ChatRetryHandler do
  def chat_with_retry(config, request, max_retries \\ 3) do
    do_chat_with_retry(config, request, max_retries, 1)
  end

  defp do_chat_with_retry(config, request, 0, _attempt) do
    {:error, "Max retries exceeded"}
  end

  defp do_chat_with_retry(config, request, retries_left, attempt) do
    case MistralClient.chat_complete(config, request) do
      {:ok, response} ->
        {:ok, response}

      {:error, %MistralClient.Errors.APIError{status: status}} when status in [429, 500, 502, 503] ->
        # Retryable errors
        delay = :math.pow(2, attempt) * 1000 |> round()
        :timer.sleep(delay)
        do_chat_with_retry(config, request, retries_left - 1, attempt + 1)

      {:error, reason} ->
        # Non-retryable errors
        {:error, reason}
    end
  end
end
```

## Advanced Examples

### Conversation Manager

```elixir
defmodule ConversationManager do
  use GenServer

  defstruct [:config, :messages, :tools, :max_history]

  def start_link(config, opts \\ []) do
    GenServer.start_link(__MODULE__, {config, opts}, name: __MODULE__)
  end

  def send_message(message) do
    GenServer.call(__MODULE__, {:send_message, message})
  end

  def get_history do
    GenServer.call(__MODULE__, :get_history)
  end

  def clear_history do
    GenServer.call(__MODULE__, :clear_history)
  end

  @impl true
  def init({config, opts}) do
    state = %__MODULE__{
      config: config,
      messages: [],
      tools: Keyword.get(opts, :tools, []),
      max_history: Keyword.get(opts, :max_history, 50)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_message, user_message}, _from, state) do
    new_messages = state.messages ++ [%{role: "user", content: user_message}]

    case MistralClient.chat_complete(state.config, %{
      model: "mistral-large-latest",
      messages: new_messages,
      tools: state.tools
    }) do
      {:ok, response} ->
        assistant_message = response.choices |> List.first() |> Map.get(:message)
        updated_messages = new_messages ++ [assistant_message]

        # Trim history if needed
        trimmed_messages = trim_history(updated_messages, state.max_history)

        new_state = %{state | messages: trimmed_messages}
        {:reply, {:ok, assistant_message.content}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call(:clear_history, _from, state) do
    new_state = %{state | messages: []}
    {:reply, :ok, new_state}
  end

  defp trim_history(messages, max_history) do
    if length(messages) > max_history do
      Enum.take(messages, -max_history)
    else
      messages
    end
  end
end
```

### Multi-Model Comparison

```elixir
defmodule ModelComparison do
  def compare_models(config, prompt, models \\ ["mistral-large-latest", "mistral-medium-latest", "mistral-small-latest"]) do
    tasks = Enum.map(models, fn model ->
      Task.async(fn ->
        case MistralClient.chat_complete(config, %{
          model: model,
          messages: [%{role: "user", content: prompt}],
          max_tokens: 200
        }) do
          {:ok, response} ->
            content = response.choices |> List.first() |> Map.get(:message) |> Map.get(:content)
            {model, {:ok, content}}

          {:error, reason} ->
            {model, {:error, reason}}
        end
      end)
    end)

    results = Task.await_many(tasks, 30_000)

    Enum.each(results, fn {model, result} ->
      IO.puts("\n=== #{model} ===")
      case result do
        {:ok, content} -> IO.puts(content)
        {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
      end
    end)

    results
  end
end
```

### Context-Aware Assistant

```elixir
defmodule ContextAwareAssistant do
  def create_assistant(config, context_info) do
    system_prompt = build_system_prompt(context_info)

    %{
      config: config,
      system_message: %{role: "system", content: system_prompt},
      context: context_info
    }
  end

  def ask(assistant, question) do
    messages = [
      assistant.system_message,
      %{role: "user", content: question}
    ]

    MistralClient.chat_complete(assistant.config, %{
      model: "mistral-large-latest",
      messages: messages,
      temperature: 0.7
    })
  end

  defp build_system_prompt(context) do
    """
    You are an AI assistant with the following context:

    User Profile:
    - Name: #{context.user_name}
    - Role: #{context.user_role}
    - Experience Level: #{context.experience_level}

    Current Project:
    - Type: #{context.project_type}
    - Technology Stack: #{Enum.join(context.tech_stack, ", ")}
    - Goals: #{Enum.join(context.goals, ", ")}

    Please provide responses that are:
    1. Tailored to the user's experience level
    2. Relevant to their current project
    3. Practical and actionable
    4. Include code examples when appropriate
    """
  end
end

# Usage
context = %{
  user_name: "Alice",
  user_role: "Backend Developer",
  experience_level: "Intermediate",
  project_type: "Web API",
  tech_stack: ["Elixir", "Phoenix", "PostgreSQL"],
  goals: ["Performance optimization", "Error handling", "Testing"]
}

assistant = ContextAwareAssistant.create_assistant(config, context)
{:ok, response} = ContextAwareAssistant.ask(assistant, "How should I handle database connection pooling?")
```

## Best Practices

1. **Always handle errors gracefully** - Network issues and API errors can occur
2. **Use appropriate models** - Choose the right model for your use case
3. **Implement retry logic** - For production applications, implement exponential backoff
4. **Manage conversation history** - Trim old messages to stay within token limits
5. **Validate inputs** - Check message formats and parameters before API calls
6. **Use streaming for long responses** - Better user experience for lengthy generations
7. **Implement proper logging** - Log API calls and responses for debugging
8. **Cache responses when appropriate** - Avoid redundant API calls
9. **Set reasonable timeouts** - Don't let requests hang indefinitely
10. **Monitor usage and costs** - Track API usage and implement usage limits

## Rate Limiting and Costs

- **Rate Limits**: Mistral APIs have rate limits based on your subscription tier
- **Token Counting**: Both input and output tokens count toward your usage
- **Model Costs**: Different models have different pricing per token
- **Optimization**: Use smaller models for simple tasks, larger models for complex reasoning

For the most up-to-date information on rate limits and pricing, refer to the [Mistral AI documentation](https://docs.mistral.ai/).
