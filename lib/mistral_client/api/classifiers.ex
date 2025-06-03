defmodule MistralClient.API.Classifiers do
  @moduledoc """
  Classifiers API for text classification and content moderation.

  This module provides functions for:
  - Text moderation and safety classification
  - Chat conversation moderation
  - General text classification
  - Chat conversation classification

  ## Examples

      # Text moderation
      {:ok, response} = MistralClient.API.Classifiers.moderate(
        client,
        "mistral-moderation-latest",
        ["This is some text to moderate"]
      )

      # Chat moderation
      {:ok, response} = MistralClient.API.Classifiers.moderate_chat(
        client,
        "mistral-moderation-latest",
        [[%{role: "user", content: "Hello, how are you?"}]]
      )

      # Text classification
      {:ok, response} = MistralClient.API.Classifiers.classify(
        client,
        "mistral-classifier-latest",
        ["Text to classify"]
      )

      # Chat classification
      {:ok, response} = MistralClient.API.Classifiers.classify_chat(
        client,
        "mistral-classifier-latest",
        [%{messages: [%{role: "user", content: "Hello"}]}]
      )
  """

  alias MistralClient.{Client, Config}

  alias MistralClient.Models.{
    ClassificationRequest,
    ClassificationResponse,
    ChatModerationRequest,
    ChatClassificationRequest,
    ModerationResponse
  }

  @doc """
  Moderations - Analyze text for safety and content policy violations.

  ## Parameters

  - `client` - The client configuration
  - `model` - ID of the model to use (e.g., "mistral-moderation-latest")
  - `inputs` - Text to classify (string or list of strings)

  ## Returns

  - `{:ok, ModerationResponse.t()}` on success
  - `{:error, term()}` on failure

  ## Examples

      {:ok, response} = MistralClient.API.Classifiers.moderate(
        client,
        "mistral-moderation-latest",
        "This is some text to moderate"
      )

      {:ok, response} = MistralClient.API.Classifiers.moderate(
        client,
        "mistral-moderation-latest",
        ["Text 1", "Text 2", "Text 3"]
      )
  """
  @spec moderate(Client.t() | Config.t(), String.t(), String.t() | [String.t()]) ::
          {:ok, ModerationResponse.t()} | {:error, term()}
  def moderate(client, model, inputs)
      when is_binary(model) and (is_binary(inputs) or is_list(inputs)) do
    request = %ClassificationRequest{
      model: model,
      inputs: inputs
    }

    request_map = ClassificationRequest.to_map(request)

    with {:ok, body} <- Jason.encode(request_map),
         {:ok, response} <- Client.request(client, :post, "/v1/moderations", body) do
      {:ok, struct(ModerationResponse, atomize_keys(response))}
    else
      {:error, %{__struct__: _} = error} ->
        {:error, Exception.message(error)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Chat Moderations - Analyze chat conversations for safety and content policy violations.

  ## Parameters

  - `client` - The client configuration
  - `model` - ID of the model to use
  - `inputs` - Chat conversations to classify (list of message lists)

  ## Returns

  - `{:ok, ModerationResponse.t()}` on success
  - `{:error, term()}` on failure

  ## Examples

      {:ok, response} = MistralClient.API.Classifiers.moderate_chat(
        client,
        "mistral-moderation-latest",
        [
          [
            %{role: "user", content: "Hello"},
            %{role: "assistant", content: "Hi there!"}
          ]
        ]
      )
  """
  @spec moderate_chat(Client.t() | Config.t(), String.t(), [[map()]]) ::
          {:ok, ModerationResponse.t()} | {:error, term()}
  def moderate_chat(client, model, inputs) when is_binary(model) and is_list(inputs) do
    request = %ChatModerationRequest{
      model: model,
      inputs: inputs
    }

    request_map = ChatModerationRequest.to_map(request)

    with {:ok, body} <- Jason.encode(request_map),
         {:ok, response} <- Client.request(client, :post, "/v1/chat/moderations", body) do
      {:ok, struct(ModerationResponse, atomize_keys(response))}
    else
      {:error, %{__struct__: _} = error} ->
        {:error, Exception.message(error)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Classifications - Classify text into categories.

  ## Parameters

  - `client` - The client configuration
  - `model` - ID of the model to use
  - `inputs` - Text to classify (string or list of strings)

  ## Returns

  - `{:ok, ClassificationResponse.t()}` on success
  - `{:error, term()}` on failure

  ## Examples

      {:ok, response} = MistralClient.API.Classifiers.classify(
        client,
        "mistral-classifier-latest",
        "This is some text to classify"
      )

      {:ok, response} = MistralClient.API.Classifiers.classify(
        client,
        "mistral-classifier-latest",
        ["Text 1", "Text 2", "Text 3"]
      )
  """
  @spec classify(Client.t() | Config.t(), String.t(), String.t() | [String.t()]) ::
          {:ok, ClassificationResponse.t()} | {:error, term()}
  def classify(client, model, inputs)
      when is_binary(model) and (is_binary(inputs) or is_list(inputs)) do
    request = %ClassificationRequest{
      model: model,
      inputs: inputs
    }

    request_map = ClassificationRequest.to_map(request)

    with {:ok, body} <- Jason.encode(request_map),
         {:ok, response} <- Client.request(client, :post, "/v1/classifications", body) do
      {:ok, struct(ClassificationResponse, atomize_keys(response))}
    else
      {:error, %{__struct__: _} = error} ->
        {:error, Exception.message(error)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Chat Classifications - Classify chat conversations into categories.

  ## Parameters

  - `client` - The client configuration
  - `model` - ID of the model to use
  - `inputs` - Chat conversations to classify

  ## Returns

  - `{:ok, ClassificationResponse.t()}` on success
  - `{:error, term()}` on failure

  ## Examples

      {:ok, response} = MistralClient.API.Classifiers.classify_chat(
        client,
        "mistral-classifier-latest",
        [%{messages: [%{role: "user", content: "Hello"}]}]
      )
  """
  @spec classify_chat(Client.t() | Config.t(), String.t(), [map()]) ::
          {:ok, ClassificationResponse.t()} | {:error, term()}
  def classify_chat(client, model, inputs) when is_binary(model) and is_list(inputs) do
    request = %ChatClassificationRequest{
      model: model,
      inputs: inputs
    }

    request_map = ChatClassificationRequest.to_map(request)

    with {:ok, body} <- Jason.encode(request_map),
         {:ok, response} <- Client.request(client, :post, "/v1/chat/classifications", body) do
      {:ok, struct(ClassificationResponse, atomize_keys(response))}
    else
      {:error, %{__struct__: _} = error} ->
        {:error, Exception.message(error)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper function to convert string keys to atoms for top-level response fields
  # but preserve string keys in nested results
  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {atomize_key(k), atomize_nested_value(v)} end)
    |> Enum.into(%{})
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  # Convert top-level keys to atoms
  defp atomize_key(key) when is_binary(key), do: String.to_atom(key)
  defp atomize_key(key), do: key

  # Handle nested values - preserve string keys in results
  defp atomize_nested_value(list) when is_list(list) do
    Enum.map(list, &atomize_nested_value/1)
  end

  defp atomize_nested_value(map) when is_map(map) do
    # Check if this looks like a results map (has string keys that should be preserved)
    if has_classification_structure?(map) do
      # Preserve string keys for classification results
      map
      |> Enum.map(fn {k, v} -> {k, atomize_nested_value(v)} end)
      |> Enum.into(%{})
    else
      # Convert keys to atoms for other nested maps
      map
      |> Enum.map(fn {k, v} -> {atomize_key(k), atomize_nested_value(v)} end)
      |> Enum.into(%{})
    end
  end

  defp atomize_nested_value(value), do: value

  # Check if a map has classification structure (category names as keys)
  defp has_classification_structure?(map) when is_map(map) do
    # If the map has keys that look like classification categories, preserve string keys
    map
    |> Map.keys()
    |> Enum.any?(fn key ->
      is_binary(key) and key not in ["categories", "category_scores", "scores"]
    end)
  end
end
