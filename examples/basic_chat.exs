#!/usr/bin/env elixir

# Basic Chat Example
#
# This example demonstrates:
# - Basic configuration setup
# - Simple chat completion
# - Error handling
# - Response processing

Mix.install([
  {:mistralex_ai, path: "."},
  {:jason, "~> 1.4"}
])

defmodule BasicChatExample do
  @moduledoc """
  A simple example showing basic chat completion with the Mistral SDK.
  """

  def run do
    IO.puts("🤖 Basic Chat Example")
    IO.puts("=" |> String.duplicate(50))

    # Setup configuration
    config = setup_config()

    # Simple chat completion
    simple_chat(config)

    # Chat with system message
    chat_with_system_message(config)

    # Chat with parameters
    chat_with_parameters(config)

    IO.puts("\n✅ Example completed!")
  end

  defp setup_config do
    api_key = System.get_env("MISTRAL_API_KEY")

    if is_nil(api_key) do
      IO.puts("❌ Error: MISTRAL_API_KEY environment variable not set")
      IO.puts("Please set it with: export MISTRAL_API_KEY='your-api-key'")
      System.halt(1)
    end

    IO.puts("🔧 Setting up configuration...")
    MistralClient.Config.new(api_key: api_key)
  end

  defp simple_chat(config) do
    IO.puts("\n📝 Simple Chat Completion")
    IO.puts("-" |> String.duplicate(30))

    request = %{
      model: "mistral-large-latest",
      messages: [
        %{role: "user", content: "What is the capital of France?"}
      ]
    }

    case MistralClient.chat_complete(config, request) do
      {:ok, response} ->
        message = response.choices |> List.first() |> Map.get(:message)
        IO.puts("🤖 Assistant: #{message.content}")
        IO.puts("📊 Tokens used: #{response.usage.total_tokens}")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  defp chat_with_system_message(config) do
    IO.puts("\n🎭 Chat with System Message")
    IO.puts("-" |> String.duplicate(30))

    request = %{
      model: "mistral-large-latest",
      messages: [
        %{
          role: "system",
          content: "You are a helpful assistant that responds in a friendly, conversational tone."
        },
        %{role: "user", content: "Tell me about Elixir programming language"}
      ],
      max_tokens: 200
    }

    case MistralClient.chat_complete(config, request) do
      {:ok, response} ->
        message = response.choices |> List.first() |> Map.get(:message)
        IO.puts("🤖 Assistant: #{message.content}")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  defp chat_with_parameters(config) do
    IO.puts("\n⚙️ Chat with Custom Parameters")
    IO.puts("-" |> String.duplicate(30))

    request = %{
      model: "mistral-large-latest",
      messages: [
        %{role: "user", content: "Write a haiku about programming"}
      ],
      # More creative
      temperature: 0.9,
      max_tokens: 100,
      top_p: 0.95
    }

    case MistralClient.chat_complete(config, request) do
      {:ok, response} ->
        message = response.choices |> List.first() |> Map.get(:message)
        IO.puts("🤖 Assistant: #{message.content}")

        # Show finish reason
        choice = response.choices |> List.first()
        IO.puts("🏁 Finish reason: #{choice.finish_reason}")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end
end

# Run the example
BasicChatExample.run()
