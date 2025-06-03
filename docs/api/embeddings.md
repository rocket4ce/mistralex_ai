# Embeddings API Documentation

The Embeddings API converts text into high-dimensional vector representations that capture semantic meaning. These embeddings are useful for similarity search, clustering, classification, and other machine learning tasks.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Configuration](#configuration)
- [Input Formats](#input-formats)
- [Response Format](#response-format)
- [Batch Processing](#batch-processing)
- [Use Cases](#use-cases)
- [Error Handling](#error-handling)
- [Advanced Examples](#advanced-examples)

## Basic Usage

### Single Text Embedding

```elixir
config = MistralClient.Config.new(api_key: "your-api-key")

{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: "Hello, world!"
})

# Extract the embedding vector
embedding = response.data |> List.first() |> Map.get(:embedding)
IO.inspect(embedding)  # [0.1234, -0.5678, 0.9012, ...]
```

### Multiple Text Embeddings

```elixir
texts = [
  "The quick brown fox jumps over the lazy dog",
  "Machine learning is a subset of artificial intelligence",
  "Elixir is a functional programming language"
]

{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: texts
})

# Extract all embeddings
embeddings = Enum.map(response.data, & &1.embedding)
IO.puts("Generated #{length(embeddings)} embeddings")
```

## Configuration

### Available Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | String | Required | Embedding model to use |
| `input` | String/List | Required | Text(s) to embed |
| `encoding_format` | String | "float" | Format of the embeddings ("float" or "base64") |

### Model Selection

```elixir
# Available embedding models
models = [
  "mistral-embed",           # General-purpose embeddings
  "mistral-embed-large"      # Higher-dimensional embeddings (if available)
]

# Use the appropriate model for your use case
{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: "Your text here"
})
```

## Input Formats

### String Input

```elixir
# Single string
{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: "This is a single text to embed"
})
```

### List Input

```elixir
# Multiple strings
{:ok, response} = MistralClient.embeddings_create(config, %{
  model: "mistral-embed",
  input: [
    "First text to embed",
    "Second text to embed",
    "Third text to embed"
  ]
})
```

### Input Validation

```elixir
defmodule EmbeddingValidator do
  def validate_input(input) when is_binary(input) do
    cond do
      String.length(input) == 0 ->
        {:error, "Input cannot be empty"}

      String.length(input) > 8192 ->
        {:error, "Input too long (max 8192 characters)"}

      true ->
        {:ok, input}
    end
  end

  def validate_input(input) when is_list(input) do
    cond do
      length(input) == 0 ->
        {:error, "Input list cannot be empty"}

      length(input) > 100 ->
        {:error, "Too many inputs (max 100 per request)"}

      true ->
        # Validate each string in the list
        case Enum.find(input, &(not is_binary(&1) or String.length(&1) == 0)) do
          nil -> {:ok, input}
          _invalid -> {:error, "All inputs must be non-empty strings"}
        end
    end
  end

  def validate_input(_), do: {:error, "Input must be a string or list of strings"}
end
```

## Response Format

### Response Structure

```elixir
%{
  object: "list",
  data: [
    %{
      object: "embedding",
      index: 0,
      embedding: [0.1234, -0.5678, 0.9012, ...]  # Vector of floats
    },
    %{
      object: "embedding",
      index: 1,
      embedding: [0.2345, -0.6789, 0.0123, ...]
    }
  ],
  model: "mistral-embed",
  usage: %{
    prompt_tokens: 15,
    total_tokens: 15
  }
}
```

### Extracting Embeddings

```elixir
defmodule EmbeddingExtractor do
  def extract_embeddings({:ok, response}) do
    embeddings = Enum.map(response.data, fn item ->
      %{
        index: item.index,
        embedding: item.embedding,
        dimension: length(item.embedding)
      }
    end)

    {:ok, embeddings}
  end

  def extract_embeddings({:error, reason}), do: {:error, reason}

  def extract_single_embedding({:ok, response}) do
    case response.data do
      [first | _] -> {:ok, first.embedding}
      [] -> {:error, "No embeddings returned"}
    end
  end

  def extract_single_embedding({:error, reason}), do: {:error, reason}
end
```

## Batch Processing

### Efficient Batch Processing

```elixir
defmodule BatchEmbedder do
  @batch_size 50  # Process in batches to avoid rate limits

  def embed_large_dataset(config, texts) do
    texts
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
    |> Enum.map(fn {batch, index} ->
      IO.puts("Processing batch #{index + 1}/#{div(length(texts), @batch_size) + 1}")

      case MistralClient.embeddings_create(config, %{
        model: "mistral-embed",
        input: batch
      }) do
        {:ok, response} ->
          Enum.map(response.data, & &1.embedding)

        {:error, reason} ->
          IO.puts("Batch #{index + 1} failed: #{inspect(reason)}")
          []
      end
    end)
    |> List.flatten()
  end

  def embed_with_retry(config, texts, max_retries \\ 3) do
    do_embed_with_retry(config, texts, max_retries)
  end

  defp do_embed_with_retry(_config, _texts, 0) do
    {:error, "Max retries exceeded"}
  end

  defp do_embed_with_retry(config, texts, retries_left) do
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: texts
    }) do
      {:ok, response} ->
        {:ok, response}

      {:error, %MistralClient.Errors.APIError{status: 429}} ->
        # Rate limit - wait and retry
        :timer.sleep(2000)
        do_embed_with_retry(config, texts, retries_left - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Parallel Processing

```elixir
defmodule ParallelEmbedder do
  def embed_parallel(config, texts, concurrency \\ 5) do
    texts
    |> Enum.chunk_every(10)  # Smaller chunks for parallel processing
    |> Task.async_stream(
      fn batch ->
        MistralClient.embeddings_create(config, %{
          model: "mistral-embed",
          input: batch
        })
      end,
      max_concurrency: concurrency,
      timeout: 30_000
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {:ok, response}}, {embeddings, errors} ->
        batch_embeddings = Enum.map(response.data, & &1.embedding)
        {embeddings ++ batch_embeddings, errors}

      {:ok, {:error, reason}}, {embeddings, errors} ->
        {embeddings, [reason | errors]}

      {:exit, reason}, {embeddings, errors} ->
        {embeddings, [reason | errors]}
    end)
  end
end
```

## Use Cases

### Semantic Search

```elixir
defmodule SemanticSearch do
  def build_search_index(config, documents) do
    # Create embeddings for all documents
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: documents
    }) do
      {:ok, response} ->
        index = response.data
        |> Enum.with_index()
        |> Enum.map(fn {embedding_data, doc_index} ->
          %{
            document: Enum.at(documents, doc_index),
            embedding: embedding_data.embedding,
            index: doc_index
          }
        end)

        {:ok, index}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search(config, index, query, top_k \\ 5) do
    # Get query embedding
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: query
    }) do
      {:ok, response} ->
        query_embedding = response.data |> List.first() |> Map.get(:embedding)

        # Calculate similarities and return top results
        results = index
        |> Enum.map(fn item ->
          similarity = cosine_similarity(query_embedding, item.embedding)
          Map.put(item, :similarity, similarity)
        end)
        |> Enum.sort_by(& &1.similarity, :desc)
        |> Enum.take(top_k)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cosine_similarity(vec1, vec2) do
    dot_product = Enum.zip(vec1, vec2)
    |> Enum.map(fn {a, b} -> a * b end)
    |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.map(vec1, &(&1 * &1)) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(vec2, &(&1 * &1)) |> Enum.sum())

    dot_product / (magnitude1 * magnitude2)
  end
end

# Usage example
documents = [
  "Elixir is a functional programming language",
  "Phoenix is a web framework for Elixir",
  "GenServer is used for building stateful processes",
  "Supervisor trees provide fault tolerance"
]

{:ok, index} = SemanticSearch.build_search_index(config, documents)
{:ok, results} = SemanticSearch.search(config, index, "web development framework", 2)

Enum.each(results, fn result ->
  IO.puts("#{result.similarity |> Float.round(3)}: #{result.document}")
end)
```

### Text Clustering

```elixir
defmodule TextClusterer do
  def cluster_texts(config, texts, num_clusters \\ 3) do
    # Get embeddings for all texts
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: texts
    }) do
      {:ok, response} ->
        embeddings = Enum.map(response.data, & &1.embedding)

        # Simple k-means clustering (simplified implementation)
        clusters = k_means_cluster(embeddings, num_clusters)

        # Map back to original texts
        clustered_texts = Enum.zip(texts, clusters)
        |> Enum.group_by(fn {_text, cluster} -> cluster end)
        |> Enum.map(fn {cluster_id, items} ->
          {cluster_id, Enum.map(items, fn {text, _} -> text end)}
        end)
        |> Map.new()

        {:ok, clustered_texts}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Simplified k-means implementation
  defp k_means_cluster(embeddings, k) do
    # Initialize random centroids
    centroids = Enum.take_random(embeddings, k)

    # Assign each point to nearest centroid
    Enum.map(embeddings, fn embedding ->
      centroids
      |> Enum.with_index()
      |> Enum.min_by(fn {centroid, _index} ->
        euclidean_distance(embedding, centroid)
      end)
      |> elem(1)
    end)
  end

  defp euclidean_distance(vec1, vec2) do
    Enum.zip(vec1, vec2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
end
```

### Document Classification

```elixir
defmodule DocumentClassifier do
  def train_classifier(config, labeled_documents) do
    # Extract texts and labels
    {texts, labels} = Enum.unzip(labeled_documents)

    # Get embeddings
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: texts
    }) do
      {:ok, response} ->
        embeddings = Enum.map(response.data, & &1.embedding)

        # Create training data
        training_data = Enum.zip(embeddings, labels)

        # Calculate class centroids
        class_centroids = training_data
        |> Enum.group_by(fn {_embedding, label} -> label end)
        |> Enum.map(fn {label, items} ->
          embeddings_for_class = Enum.map(items, fn {embedding, _} -> embedding end)
          centroid = calculate_centroid(embeddings_for_class)
          {label, centroid}
        end)
        |> Map.new()

        {:ok, %{centroids: class_centroids, training_data: training_data}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def classify(config, classifier, text) do
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: text
    }) do
      {:ok, response} ->
        text_embedding = response.data |> List.first() |> Map.get(:embedding)

        # Find nearest class centroid
        {predicted_class, _distance} = classifier.centroids
        |> Enum.min_by(fn {_label, centroid} ->
          euclidean_distance(text_embedding, centroid)
        end)

        {:ok, predicted_class}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_centroid(embeddings) do
    dimension = length(List.first(embeddings))
    count = length(embeddings)

    0..(dimension - 1)
    |> Enum.map(fn i ->
      sum = Enum.map(embeddings, &Enum.at(&1, i)) |> Enum.sum()
      sum / count
    end)
  end

  defp euclidean_distance(vec1, vec2) do
    Enum.zip(vec1, vec2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
end

# Usage example
labeled_docs = [
  {"This is about technology and programming", "tech"},
  {"Machine learning and AI are fascinating", "tech"},
  {"I love cooking and trying new recipes", "food"},
  {"The restaurant has amazing pasta dishes", "food"},
  {"Sports and fitness are important for health", "sports"},
  {"The basketball game was very exciting", "sports"}
]

{:ok, classifier} = DocumentClassifier.train_classifier(config, labeled_docs)
{:ok, prediction} = DocumentClassifier.classify(config, classifier, "I enjoy playing tennis")
IO.puts("Predicted class: #{prediction}")  # Should predict "sports"
```

## Error Handling

### Common Error Scenarios

```elixir
defmodule EmbeddingErrorHandler do
  def safe_embed(config, input) do
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: input
    }) do
      {:ok, response} ->
        {:ok, response}

      {:error, %MistralClient.Errors.APIError{status: 400, message: message}} ->
        # Bad request - usually input validation issues
        {:error, "Invalid input: #{message}"}

      {:error, %MistralClient.Errors.APIError{status: 401}} ->
        # Authentication error
        {:error, "Invalid API key"}

      {:error, %MistralClient.Errors.APIError{status: 429}} ->
        # Rate limit exceeded
        {:error, "Rate limit exceeded - please try again later"}

      {:error, %MistralClient.Errors.APIError{status: 500}} ->
        # Server error
        {:error, "Server error - please try again"}

      {:error, %MistralClient.Errors.NetworkError{reason: reason}} ->
        # Network connectivity issues
        {:error, "Network error: #{reason}"}

      {:error, reason} ->
        # Other errors
        {:error, "Unexpected error: #{inspect(reason)}"}
    end
  end

  def embed_with_fallback(config, input, fallback_fn \\ nil) do
    case safe_embed(config, input) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} when is_function(fallback_fn) ->
        IO.puts("Embedding failed: #{reason}")
        IO.puts("Using fallback strategy...")
        fallback_fn.(input)

      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Usage with fallback
fallback = fn input ->
  # Simple fallback: return random embeddings
  dimension = 1024
  random_embedding = Enum.map(1..dimension, fn _ -> :rand.normal() end)

  {:ok, %{
    data: [%{embedding: random_embedding, index: 0}],
    model: "fallback",
    usage: %{prompt_tokens: 0, total_tokens: 0}
  }}
end

{:ok, response} = EmbeddingErrorHandler.embed_with_fallback(
  config,
  "Some text to embed",
  fallback
)
```

## Advanced Examples

### Embedding Cache

```elixir
defmodule EmbeddingCache do
  use GenServer

  defstruct [:config, :cache, :max_size]

  def start_link(config, opts \\ []) do
    GenServer.start_link(__MODULE__, {config, opts}, name: __MODULE__)
  end

  def get_embedding(text) do
    GenServer.call(__MODULE__, {:get_embedding, text})
  end

  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @impl true
  def init({config, opts}) do
    state = %__MODULE__{
      config: config,
      cache: %{},
      max_size: Keyword.get(opts, :max_size, 1000)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_embedding, text}, _from, state) do
    case Map.get(state.cache, text) do
      nil ->
        # Not in cache, fetch from API
        case MistralClient.embeddings_create(state.config, %{
          model: "mistral-embed",
          input: text
        }) do
          {:ok, response} ->
            embedding = response.data |> List.first() |> Map.get(:embedding)

            # Add to cache (with size limit)
            new_cache = if map_size(state.cache) >= state.max_size do
              # Remove oldest entry (simplified LRU)
              {_key, cache_without_oldest} = Map.pop(state.cache,
                state.cache |> Map.keys() |> List.first())
              Map.put(cache_without_oldest, text, embedding)
            else
              Map.put(state.cache, text, embedding)
            end

            new_state = %{state | cache: new_cache}
            {:reply, {:ok, embedding}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      cached_embedding ->
        # Return cached result
        {:reply, {:ok, cached_embedding}, state}
    end
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    new_state = %{state | cache: %{}}
    {:reply, :ok, new_state}
  end
end
```

### Embedding Similarity Service

```elixir
defmodule SimilarityService do
  def find_similar_texts(config, target_text, candidate_texts, threshold \\ 0.7) do
    all_texts = [target_text | candidate_texts]

    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: all_texts
    }) do
      {:ok, response} ->
        [target_embedding | candidate_embeddings] =
          Enum.map(response.data, & &1.embedding)

        similarities = candidate_embeddings
        |> Enum.with_index()
        |> Enum.map(fn {embedding, index} ->
          similarity = cosine_similarity(target_embedding, embedding)
          %{
            text: Enum.at(candidate_texts, index),
            similarity: similarity,
            index: index
          }
        end)
        |> Enum.filter(& &1.similarity >= threshold)
        |> Enum.sort_by(& &1.similarity, :desc)

        {:ok, similarities}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def batch_similarity_matrix(config, texts) do
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: texts
    }) do
      {:ok, response} ->
        embeddings = Enum.map(response.data, & &1.embedding)

        # Calculate similarity matrix
        matrix = for {emb1, i} <- Enum.with_index(embeddings) do
          for {emb2, j} <- Enum.with_index(embeddings) do
            if i == j do
              1.0  # Self-similarity is 1.0
            else
              cosine_similarity(emb1, emb2)
            end
          end
        end

        {:ok, matrix}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cosine_similarity(vec1, vec2) do
    dot_product = Enum.zip(vec1, vec2)
    |> Enum.map(fn {a, b} -> a * b end)
    |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.map(vec1, &(&1 * &1)) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(vec2, &(&1 * &1)) |> Enum.sum())

    dot_product / (magnitude1 * magnitude2)
  end
end
```

## Best Practices

1. **Batch Processing**: Process multiple texts in a single request when possible
2. **Caching**: Cache embeddings for frequently used texts to reduce API calls
3. **Input Validation**: Validate text length and format before API calls
4. **Error Handling**: Implement proper retry logic for transient failures
5. **Rate Limiting**: Respect API rate limits and implement backoff strategies
6. **Normalization**: Consider normalizing embeddings for certain use cases
7. **Dimension Awareness**: Be aware of the embedding dimensions for your chosen model
8. **Cost Optimization**: Use embeddings efficiently to minimize token usage
9. **Storage**: Consider efficient storage formats for large embedding datasets
10. **Monitoring**: Track embedding quality and API usage metrics

## Performance Considerations

- **Batch Size**: Optimal batch size is typically 10-50 texts per request
- **Concurrency**: Use parallel processing for large datasets, but respect rate limits
- **Memory Usage**: Large embedding datasets can consume significant memory
- **Storage Format**: Consider using binary formats for storing embeddings at scale
- **Indexing**: Use specialized vector databases for large-scale similarity search

## Integration with Vector Databases

```elixir
# Example integration with a vector database (pseudo-code)
defmodule VectorDBIntegration do
  def store_embeddings(config, documents) do
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: documents
    }) do
      {:ok, response} ->
        # Store in vector database
        response.data
        |> Enum.with_index()
        |> Enum.each(fn {embedding_data, index} ->
          VectorDB.insert(%{
            id: index,
            text: Enum.at(documents, index),
            embedding: embedding_data.embedding,
            metadata: %{created_at: DateTime.utc_now()}
          })
        end)

        {:ok, "Stored #{length(documents)} embeddings"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def semantic_search(config, query, limit \\ 10) do
    case MistralClient.embeddings_create(config, %{
      model: "mistral-embed",
      input: query
    }) do
      {:ok, response} ->
        query_embedding = response.data |> List.first() |> Map.get(:embedding)

        # Search in vector database
        results = VectorDB.similarity_search(query_embedding, limit)
        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

For more information about embeddings and vector operations, refer to the [Mistral AI documentation](https://docs.mistral.ai/).
