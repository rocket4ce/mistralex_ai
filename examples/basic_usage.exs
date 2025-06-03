#!/usr/bin/env elixir

# Basic usage example for MistralClient SDK
# This file demonstrates how to use the core functionality

# Note: You need to set your API key before running this example:
# export MISTRAL_API_KEY="your-api-key-here"

# Load the application
Mix.install([{:mistralex_ai, path: "."}])

defmodule BasicUsageExample do
  @moduledoc """
  Basic usage examples for the MistralClient SDK.
  """

  def run_examples do
    IO.puts("🚀 MistralClient SDK - Basic Usage Examples")
    IO.puts("=" |> String.duplicate(50))

    # Check configuration
    case check_configuration() do
      :ok ->
        IO.puts("✅ Configuration is valid")
        run_api_examples()

      {:error, reason} ->
        IO.puts("❌ Configuration error: #{reason}")
        IO.puts("\nPlease set your API key:")
        IO.puts("export MISTRAL_API_KEY=\"your-api-key-here\"")
    end
  end

  defp check_configuration do
    config = MistralClient.Config.get()
    MistralClient.Config.validate(config)
  end

  defp run_api_examples do
    IO.puts("\n📋 Available Models Example")
    list_models_example()

    IO.puts("\n💬 Chat Completion Example")
    chat_example()

    IO.puts("\n🔢 Embeddings Example")
    embeddings_example()

    IO.puts("\n📁 Files Example")
    files_example()
  end

  defp list_models_example do
    case MistralClient.models() do
      {:ok, models} ->
        IO.puts("✅ Found #{length(models)} available models:")

        models
        # Show first 5 models
        |> Enum.take(5)
        |> Enum.each(fn model ->
          IO.puts("  - #{model.id} (owned by: #{model.owned_by})")
        end)

        if length(models) > 5 do
          IO.puts("  ... and #{length(models) - 5} more models")
        end

      {:error, error} ->
        IO.puts("❌ Error listing models: #{Exception.message(error)}")
    end
  end

  defp chat_example do
    messages = [
      %{role: "user", content: "Hello! Can you tell me what you are in one sentence?"}
    ]

    case MistralClient.chat(messages, %{max_tokens: 100}) do
      {:ok, response} ->
        IO.puts("✅ Chat completion successful!")

        choice = List.first(response.choices)

        if choice && choice.message do
          IO.puts("🤖 Response: #{choice.message.content}")

          if response.usage do
            IO.puts("📊 Token usage: #{response.usage.total_tokens} total tokens")
          end
        end

      {:error, error} ->
        IO.puts("❌ Error in chat completion: #{Exception.message(error)}")
    end
  end

  defp embeddings_example do
    text = "Hello, this is a test for embeddings generation."

    case MistralClient.embeddings(text) do
      {:ok, response} ->
        IO.puts("✅ Embeddings generated successfully!")

        if response.data && length(response.data) > 0 do
          embedding = List.first(response.data)
          vector_length = length(embedding.embedding)
          IO.puts("📊 Generated embedding with #{vector_length} dimensions")

          # Show first few values
          first_values =
            embedding.embedding
            |> Enum.take(5)
            |> Enum.map(&Float.round(&1, 4))
            |> Enum.join(", ")

          IO.puts("🔢 First 5 values: [#{first_values}, ...]")
        end

      {:error, error} ->
        IO.puts("❌ Error generating embeddings: #{Exception.message(error)}")
    end
  end

  defp files_example do
    case MistralClient.files() do
      {:ok, files} ->
        IO.puts("✅ Files list retrieved successfully!")

        if length(files) > 0 do
          IO.puts("📁 Found #{length(files)} files:")

          files
          |> Enum.take(3)
          |> Enum.each(fn file ->
            size_kb = if file.bytes, do: Float.round(file.bytes / 1024, 1), else: "unknown"
            IO.puts("  - #{file.filename} (#{size_kb} KB, purpose: #{file.purpose})")
          end)
        else
          IO.puts("📁 No files found in your account")
        end

      {:error, error} ->
        IO.puts("❌ Error listing files: #{Exception.message(error)}")
    end
  end
end

# Run the examples
BasicUsageExample.run_examples()
