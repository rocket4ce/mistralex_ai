# Fine-tuning API Documentation

The Fine-tuning API allows you to create custom models by training on your specific data. This enables you to adapt Mistral models to your particular use case, domain, or style.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Data Preparation](#data-preparation)
- [Job Management](#job-management)
- [Model Management](#model-management)
- [Monitoring and Status](#monitoring-and-status)
- [Best Practices](#best-practices)
- [Advanced Examples](#advanced-examples)

## Overview

Fine-tuning involves several steps:

1. **Prepare training data** in JSONL format
2. **Upload files** using the Files API
3. **Create a fine-tuning job** with hyperparameters
4. **Start the job** and monitor progress
5. **Deploy the fine-tuned model** for inference

### Supported Base Models

```elixir
# Available base models for fine-tuning
base_models = [
  "mistral-small-latest",
  "mistral-medium-latest",
  "codestral-latest"  # For code-specific fine-tuning
]
```

## Quick Start

### Complete Fine-tuning Workflow

```elixir
config = MistralClient.Config.new(api_key: "your-api-key")

# 1. Upload training data
{:ok, training_file} = MistralClient.upload_file(config, %{
  file: "/path/to/training_data.jsonl",
  purpose: "fine-tune"
})

# 2. Create fine-tuning job
{:ok, job} = MistralClient.create_fine_tuning_job(config, %{
  model: "mistral-small-latest",
  training_files: [training_file.id],
  hyperparameters: %{
    training_steps: 1000,
    learning_rate: 0.0001
  }
})

# 3. Start the job
{:ok, started_job} = MistralClient.start_fine_tuning_job(config, job.id)

# 4. Monitor progress
{:ok, job_status} = MistralClient.get_fine_tuning_job(config, job.id)
IO.puts("Job status: #{job_status.status}")

# 5. Use the fine-tuned model (once completed)
if job_status.status == :succeeded do
  {:ok, response} = MistralClient.chat_complete(config, %{
    model: job_status.fine_tuned_model,
    messages: [%{role: "user", content: "Hello!"}]
  })
end
```

## Data Preparation

### Training Data Format

Training data must be in JSONL format with conversation examples:

```jsonl
{"messages": [{"role": "user", "content": "What is machine learning?"}, {"role": "assistant", "content": "Machine learning is a subset of artificial intelligence..."}]}
{"messages": [{"role": "user", "content": "Explain neural networks"}, {"role": "assistant", "content": "Neural networks are computing systems inspired by biological neural networks..."}]}
{"messages": [{"role": "system", "content": "You are a helpful assistant."}, {"role": "user", "content": "Hello"}, {"role": "assistant", "content": "Hello! How can I help you today?"}]}
```

### Data Validation

```elixir
defmodule FineTuningDataValidator do
  def validate_jsonl_file(file_path) do
    file_path
    |> File.stream!()
    |> Stream.with_index()
    |> Enum.reduce_while({:ok, []}, fn {line, index}, {:ok, errors} ->
      case validate_line(line, index + 1) do
        :ok -> {:cont, {:ok, errors}}
        {:error, error} -> {:cont, {:ok, [error | errors]}}
      end
    end)
    |> case do
      {:ok, []} -> {:ok, "File is valid"}
      {:ok, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_line(line, line_number) do
    case Jason.decode(String.trim(line)) do
      {:ok, %{"messages" => messages}} when is_list(messages) ->
        validate_messages(messages, line_number)

      {:ok, _} ->
        {:error, "Line #{line_number}: Missing 'messages' field"}

      {:error, _} ->
        {:error, "Line #{line_number}: Invalid JSON"}
    end
  end

  defp validate_messages(messages, line_number) do
    cond do
      length(messages) < 2 ->
        {:error, "Line #{line_number}: Need at least 2 messages"}

      not valid_conversation_flow?(messages) ->
        {:error, "Line #{line_number}: Invalid conversation flow"}

      true ->
        :ok
    end
  end

  defp valid_conversation_flow?(messages) do
    messages
    |> Enum.all?(fn msg ->
      Map.has_key?(msg, "role") and Map.has_key?(msg, "content") and
      msg["role"] in ["system", "user", "assistant"]
    end)
  end

  def prepare_training_data(conversations) do
    conversations
    |> Enum.map(fn conversation ->
      %{messages: conversation}
      |> Jason.encode!()
    end)
    |> Enum.join("\n")
  end

  def save_training_data(data, file_path) do
    File.write(file_path, data)
  end
end

# Usage example
conversations = [
  [
    %{role: "user", content: "What is Elixir?"},
    %{role: "assistant", content: "Elixir is a functional programming language..."}
  ],
  [
    %{role: "system", content: "You are an Elixir expert."},
    %{role: "user", content: "How do I start a GenServer?"},
    %{role: "assistant", content: "To start a GenServer, you can use GenServer.start_link/3..."}
  ]
]

training_data = FineTuningDataValidator.prepare_training_data(conversations)
FineTuningDataValidator.save_training_data(training_data, "training_data.jsonl")
{:ok, result} = FineTuningDataValidator.validate_jsonl_file("training_data.jsonl")
```

### Data Quality Guidelines

```elixir
defmodule DataQualityChecker do
  def analyze_dataset(file_path) do
    stats = %{
      total_examples: 0,
      avg_messages_per_example: 0,
      avg_tokens_per_message: 0,
      role_distribution: %{},
      message_lengths: []
    }

    file_path
    |> File.stream!()
    |> Enum.reduce(stats, &analyze_example/2)
    |> finalize_stats()
  end

  defp analyze_example(line, stats) do
    case Jason.decode(String.trim(line)) do
      {:ok, %{"messages" => messages}} ->
        stats
        |> Map.update!(:total_examples, &(&1 + 1))
        |> analyze_messages(messages)

      _ ->
        stats
    end
  end

  defp analyze_messages(stats, messages) do
    message_count = length(messages)

    role_counts = Enum.reduce(messages, %{}, fn msg, acc ->
      role = msg["role"]
      Map.update(acc, role, 1, &(&1 + 1))
    end)

    message_lengths = Enum.map(messages, fn msg ->
      String.length(msg["content"] || "")
    end)

    stats
    |> Map.update!(:avg_messages_per_example, &(&1 + message_count))
    |> Map.update!(:role_distribution, fn dist ->
      Map.merge(dist, role_counts, fn _k, v1, v2 -> v1 + v2 end)
    end)
    |> Map.update!(:message_lengths, &(&1 ++ message_lengths))
  end

  defp finalize_stats(stats) do
    total = stats.total_examples

    avg_messages = if total > 0 do
      stats.avg_messages_per_example / total
    else
      0
    end

    avg_tokens = if length(stats.message_lengths) > 0 do
      Enum.sum(stats.message_lengths) / length(stats.message_lengths)
    else
      0
    end

    %{
      total_examples: total,
      avg_messages_per_example: Float.round(avg_messages, 2),
      avg_tokens_per_message: Float.round(avg_tokens, 2),
      role_distribution: stats.role_distribution,
      recommendations: generate_recommendations(stats, total)
    }
  end

  defp generate_recommendations(stats, total) do
    recommendations = []

    recommendations = if total < 100 do
      ["Consider adding more training examples (current: #{total}, recommended: 100+)" | recommendations]
    else
      recommendations
    end

    recommendations = if stats.avg_messages_per_example < 2 do
      ["Conversations should have at least 2 messages" | recommendations]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Dataset looks good for fine-tuning!"]
    else
      recommendations
    end
  end
end
```

## Job Management

### Creating Fine-tuning Jobs

```elixir
defmodule FineTuningJobManager do
  def create_job(config, opts) do
    # Validate required parameters
    with {:ok, model} <- validate_model(opts[:model]),
         {:ok, training_files} <- validate_training_files(opts[:training_files]),
         {:ok, hyperparameters} <- validate_hyperparameters(opts[:hyperparameters]) do

      job_params = %{
        model: model,
        training_files: training_files,
        hyperparameters: hyperparameters
      }
      |> maybe_add_validation_files(opts[:validation_files])
      |> maybe_add_suffix(opts[:suffix])
      |> maybe_add_integrations(opts[:integrations])

      MistralClient.create_fine_tuning_job(config, job_params)
    end
  end

  defp validate_model(nil), do: {:error, "Model is required"}
  defp validate_model(model) when model in ["mistral-small-latest", "mistral-medium-latest", "codestral-latest"] do
    {:ok, model}
  end
  defp validate_model(_), do: {:error, "Invalid model"}

  defp validate_training_files(nil), do: {:error, "Training files are required"}
  defp validate_training_files(files) when is_list(files) and length(files) > 0 do
    {:ok, files}
  end
  defp validate_training_files(_), do: {:error, "Training files must be a non-empty list"}

  defp validate_hyperparameters(nil), do: {:ok, %{}}
  defp validate_hyperparameters(params) when is_map(params) do
    # Validate hyperparameter ranges
    validated = params
    |> validate_training_steps()
    |> validate_learning_rate()
    |> validate_batch_size()

    {:ok, validated}
  end

  defp validate_training_steps(params) do
    case Map.get(params, :training_steps) do
      nil -> params
      steps when is_integer(steps) and steps > 0 and steps <= 10000 ->
        params
      _ ->
        Map.put(params, :training_steps, 1000)  # Default
    end
  end

  defp validate_learning_rate(params) do
    case Map.get(params, :learning_rate) do
      nil -> params
      rate when is_float(rate) and rate > 0 and rate < 1 ->
        params
      _ ->
        Map.put(params, :learning_rate, 0.0001)  # Default
    end
  end

  defp validate_batch_size(params) do
    case Map.get(params, :batch_size) do
      nil -> params
      size when is_integer(size) and size > 0 and size <= 64 ->
        params
      _ ->
        Map.put(params, :batch_size, 8)  # Default
    end
  end

  defp maybe_add_validation_files(params, nil), do: params
  defp maybe_add_validation_files(params, files), do: Map.put(params, :validation_files, files)

  defp maybe_add_suffix(params, nil), do: params
  defp maybe_add_suffix(params, suffix), do: Map.put(params, :suffix, suffix)

  defp maybe_add_integrations(params, nil), do: params
  defp maybe_add_integrations(params, integrations), do: Map.put(params, :integrations, integrations)
end
```

### Job Lifecycle Management

```elixir
defmodule JobLifecycleManager do
  def manage_job_lifecycle(config, job_params) do
    with {:ok, job} <- FineTuningJobManager.create_job(config, job_params),
         {:ok, started_job} <- MistralClient.start_fine_tuning_job(config, job.id),
         {:ok, completed_job} <- wait_for_completion(config, started_job.id) do
      {:ok, completed_job}
    end
  end

  def wait_for_completion(config, job_id, check_interval \\ 30_000) do
    wait_loop(config, job_id, check_interval)
  end

  defp wait_loop(config, job_id, check_interval) do
    case MistralClient.get_fine_tuning_job(config, job_id) do
      {:ok, %{status: :succeeded} = job} ->
        IO.puts("✅ Fine-tuning completed successfully!")
        IO.puts("Fine-tuned model: #{job.fine_tuned_model}")
        {:ok, job}

      {:ok, %{status: :failed, error: error}} ->
        IO.puts("❌ Fine-tuning failed: #{error}")
        {:error, "Fine-tuning failed: #{error}"}

      {:ok, %{status: :cancelled}} ->
        IO.puts("⏹️ Fine-tuning was cancelled")
        {:error, "Fine-tuning was cancelled"}

      {:ok, %{status: status} = job} when status in [:queued, :running] ->
        progress_info = format_progress(job)
        IO.puts("🔄 #{progress_info}")

        :timer.sleep(check_interval)
        wait_loop(config, job_id, check_interval)

      {:error, reason} ->
        {:error, "Failed to check job status: #{inspect(reason)}"}
    end
  end

  defp format_progress(job) do
    base_info = "Job #{job.id} - Status: #{job.status}"

    case job do
      %{trained_tokens: tokens, training_files: files} when not is_nil(tokens) ->
        "#{base_info} - Trained tokens: #{tokens}"
      %{training_files: files} ->
        "#{base_info} - Training files: #{length(files)}"
      _ ->
        base_info
    end
  end

  def cancel_job_if_needed(config, job_id, reason \\ "User requested cancellation") do
    case MistralClient.get_fine_tuning_job(config, job_id) do
      {:ok, %{status: status}} when status in [:queued, :running] ->
        IO.puts("Cancelling job #{job_id}: #{reason}")
        MistralClient.cancel_fine_tuning_job(config, job_id)

      {:ok, %{status: status}} ->
        {:error, "Cannot cancel job in status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Model Management

### Model Deployment and Management

```elixir
defmodule FineTunedModelManager do
  def deploy_model(config, job_id) do
    case MistralClient.get_fine_tuning_job(config, job_id) do
      {:ok, %{status: :succeeded, fine_tuned_model: model_id}} ->
        # Test the model
        case test_model(config, model_id) do
          {:ok, _response} ->
            IO.puts("✅ Model #{model_id} is ready for use")
            {:ok, model_id}

          {:error, reason} ->
            IO.puts("⚠️ Model test failed: #{reason}")
            {:error, "Model test failed: #{reason}"}
        end

      {:ok, %{status: status}} ->
        {:error, "Job not completed yet. Status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp test_model(config, model_id) do
    MistralClient.chat_complete(config, %{
      model: model_id,
      messages: [%{role: "user", content: "Hello, this is a test."}],
      max_tokens: 50
    })
  end

  def archive_model(config, model_id) do
    case MistralClient.archive_model(config, model_id) do
      {:ok, archived_model} ->
        IO.puts("📦 Model #{model_id} archived successfully")
        {:ok, archived_model}

      {:error, reason} ->
        IO.puts("❌ Failed to archive model: #{reason}")
        {:error, reason}
    end
  end

  def unarchive_model(config, model_id) do
    case MistralClient.unarchive_model(config, model_id) do
      {:ok, unarchived_model} ->
        IO.puts("📤 Model #{model_id} unarchived successfully")
        {:ok, unarchived_model}

      {:error, reason} ->
        IO.puts("❌ Failed to unarchive model: #{reason}")
        {:error, reason}
    end
  end

  def update_model_metadata(config, model_id, updates) do
    case MistralClient.update_model(config, model_id, updates) do
      {:ok, updated_model} ->
        IO.puts("✏️ Model #{model_id} updated successfully")
        {:ok, updated_model}

      {:error, reason} ->
        IO.puts("❌ Failed to update model: #{reason}")
        {:error, reason}
    end
  end

  def list_fine_tuned_models(config) do
    case MistralClient.list_models(config, %{owned_by: "user"}) do
      {:ok, models} ->
        fine_tuned = Enum.filter(models.data, fn model ->
          String.contains?(model.id, "ft:")
        end)

        IO.puts("📋 Fine-tuned models (#{length(fine_tuned)}):")
        Enum.each(fine_tuned, fn model ->
          status = if model.archived, do: "📦 Archived", else: "✅ Active"
          IO.puts("  - #{model.id} (#{status})")
        end)

        {:ok, fine_tuned}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Monitoring and Status

### Job Monitoring Dashboard

```elixir
defmodule FineTuningDashboard do
  def show_dashboard(config) do
    case MistralClient.list_fine_tuning_jobs(config) do
      {:ok, jobs} ->
        display_jobs_summary(jobs.data)
        display_jobs_details(jobs.data)

      {:error, reason} ->
        IO.puts("❌ Failed to fetch jobs: #{reason}")
    end
  end

  defp display_jobs_summary(jobs) do
    summary = Enum.reduce(jobs, %{}, fn job, acc ->
      Map.update(acc, job.status, 1, &(&1 + 1))
    end)

    IO.puts("\n📊 Fine-tuning Jobs Summary")
    IO.puts("=" |> String.duplicate(40))

    Enum.each(summary, fn {status, count} ->
      emoji = status_emoji(status)
      IO.puts("#{emoji} #{String.capitalize(to_string(status))}: #{count}")
    end)
  end

  defp display_jobs_details(jobs) do
    IO.puts("\n📋 Job Details")
    IO.puts("=" |> String.duplicate(80))

    jobs
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(10)  # Show last 10 jobs
    |> Enum.each(&display_job_detail/1)
  end

  defp display_job_detail(job) do
    emoji = status_emoji(job.status)
    created = format_timestamp(job.created_at)

    IO.puts("#{emoji} #{job.id}")
    IO.puts("   Model: #{job.model}")
    IO.puts("   Status: #{job.status}")
    IO.puts("   Created: #{created}")

    if job.fine_tuned_model do
      IO.puts("   Fine-tuned Model: #{job.fine_tuned_model}")
    end

    if job.error do
      IO.puts("   Error: #{job.error}")
    end

    IO.puts("")
  end

  defp status_emoji(:succeeded), do: "✅"
  defp status_emoji(:failed), do: "❌"
  defp status_emoji(:cancelled), do: "⏹️"
  defp status_emoji(:running), do: "🔄"
  defp status_emoji(:queued), do: "⏳"
  defp status_emoji(_), do: "❓"

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
      _ -> timestamp
    end
  end
  defp format_timestamp(timestamp), do: inspect(timestamp)

  def monitor_job(config, job_id, update_interval \\ 30_000) do
    spawn(fn -> monitor_loop(config, job_id, update_interval) end)
  end

  defp monitor_loop(config, job_id, update_interval) do
    case MistralClient.get_fine_tuning_job(config, job_id) do
      {:ok, job} ->
        display_job_status(job)

        if job.status in [:queued, :running] do
          :timer.sleep(update_interval)
          monitor_loop(config, job_id, update_interval)
        else
          IO.puts("🏁 Monitoring completed. Final status: #{job.status}")
        end

      {:error, reason} ->
        IO.puts("❌ Monitoring error: #{reason}")
    end
  end

  defp display_job_status(job) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
    emoji = status_emoji(job.status)

    status_line = "#{timestamp} #{emoji} Job #{job.id} - #{job.status}"

    status_line = if job.trained_tokens do
      "#{status_line} - Tokens: #{job.trained_tokens}"
    else
      status_line
    end

    IO.puts(status_line)
  end
end
```

## Best Practices

### Complete Fine-tuning Workflow

```elixir
defmodule FineTuningWorkflow do
  def complete_workflow(config, opts) do
    with {:ok, _} <- validate_data(opts[:training_data_path]),
         {:ok, training_file} <- upload_training_data(config, opts),
         {:ok, validation_file} <- maybe_upload_validation_data(config, opts),
         {:ok, job} <- create_and_start_job(config, training_file, validation_file, opts),
         {:ok, completed_job} <- monitor_job_completion(config, job.id),
         {:ok, model_id} <- deploy_and_test_model(config, completed_job) do

      {:ok, %{
        job: completed_job,
        model_id: model_id,
        training_file: training_file,
        validation_file: validation_file
      }}
    end
  end

  defp validate_data(file_path) do
    case FineTuningDataValidator.validate_jsonl_file(file_path) do
      {:ok, _} ->
        stats = DataQualityChecker.analyze_dataset(file_path)
        IO.puts("📊 Dataset Analysis:")
        IO.inspect(stats, pretty: true)
        {:ok, stats}

      {:error, errors} ->
        IO.puts("❌ Data validation failed:")
        Enum.each(errors, &IO.puts("  - #{&1}"))
        {:error, "Data validation failed"}
    end
  end

  defp upload_training_data(config, opts) do
    IO.puts("📤 Uploading training data...")

    case MistralClient.upload_file(config, %{
      file: opts[:training_data_path],
      purpose: "fine-tune"
    }) do
      {:ok, file} ->
        IO.puts("✅ Training data uploaded: #{file.id}")
        {:ok, file}

      {:error, reason} ->
        IO.puts("❌ Failed to upload training data: #{reason}")
        {:error, reason}
    end
  end

  defp maybe_upload_validation_data(config, opts) do
    case opts[:validation_data_path] do
      nil -> {:ok, nil}
      path ->
        IO.puts("📤 Uploading validation data...")

        case MistralClient.upload_file(config, %{file: path, purpose: "fine-tune"}) do
          {:ok, file} ->
            IO.puts("✅ Validation data uploaded: #{file.id}")
            {:ok, file}

          {:error, reason} ->
            IO.puts("❌ Failed to upload validation data: #{reason}")
            {:error, reason}
        end
    end
  end

  defp create_and_start_job(config, training_file, validation_file, opts) do
    IO.puts("🚀 Creating fine-tuning job...")

    job_params = %{
      model: opts[:model] || "mistral-small-latest",
      training_files: [training_file.id],
      hyperparameters: opts[:hyperparameters] || %{
        training_steps: 1000,
        learning_rate: 0.0001
      }
    }

    job_params = if validation_file do
      Map.put(job_params, :validation_files, [validation_file.id])
    else
      job_params
    end

    job_params = if opts[:suffix] do
      Map.put(job_params, :suffix, opts[:suffix])
    else
      job_params
    end

    with {:ok, job} <- MistralClient.create_fine_tuning_job(config, job_params),
         {:ok, started_job} <- MistralClient.start_fine_tuning_job(config, job.id) do

      IO.puts("✅ Job created and started: #{started_job.id}")
      {:ok, started_job}
    end
  end

  defp monitor_job_completion(config, job_id) do
    IO.puts("👀 Monitoring job progress...")
    JobLifecycleManager.wait_for_completion(config, job_id)
  end

  defp deploy_and_test_model(config, completed_job) do
    IO.puts("🚀 Deploying model...")
    FineTunedModelManager.deploy_model(config, completed_job.id)
  end

  # Convenience function for common use cases
  def quick_fine_tune(config, training_data_path, opts \\ []) do
    default_opts = [
      model: "mistral-small-latest",
      hyperparameters: %{
        training_steps: 1000,
        learning_rate: 0.0001,
        batch_size: 8
      }
    ]

    final_opts = Keyword.merge(default_opts, opts)
    |> Keyword.put(:training_data_path, training_data_path)

    complete_workflow(config, final_opts)
  end
end

# Usage examples
config = MistralClient.Config.new(api_key: "your-api-key")

# Quick fine-tuning
{:ok, result} = FineTuningWorkflow.quick_fine_tune(config, "training_data.jsonl",
  suffix: "my-custom-model"
)

# Advanced fine-tuning with validation data
{:ok, result} = FineTuningWorkflow.complete_workflow(config, [
  training_data_path: "training_data.jsonl",
  validation_data_path: "validation_data.jsonl",
  model: "mistral-medium-latest",
  suffix: "advanced-model",
  hyperparameters: %{
    training_steps: 2000,
    learning_rate: 0.00005,
    batch_size: 16
  }
])
```

## Advanced Examples

### Hyperparameter Optimization

```elixir
defmodule HyperparameterOptimizer do
  def optimize_hyperparameters(config, training_file_id, validation_file_id) do
    # Define hyperparameter search space
    search_space = [
      %{learning_rate: 0.0001, training_steps: 500, batch_size: 8},
      %{learning_rate: 0.00005, training_steps: 1000, batch_size: 8},
      %{learning_rate: 0.0001, training_steps: 1000, batch_size: 16},
      %{learning_rate: 0.00005, training_steps: 2000, batch_size: 16}
    ]

    results = Enum.map(search_space, fn params ->
      run_experiment(config, training_file_id, validation_file_id, params)
    end)

    best_result = Enum.min_by(results, fn result ->
      case result do
        {:ok, %{validation_loss: loss}} -> loss
        _ -> :infinity
      end
    end)

    IO.puts("🏆 Best hyperparameters found:")
    IO.inspect(best_result, pretty: true)

    best_result
  end

  defp run_experiment(config, training_file_id, validation_file_id, hyperparams) do
    IO.puts("🧪 Testing hyperparameters: #{inspect(hyperparams)}")

    job_params = %{
      model: "mistral-small-latest",
      training_files: [training_file_id],
      validation_files: [validation_file_id],
      hyperparameters: hyperparams,
      suffix: "exp-#{:rand.uniform(1000)}"
    }

    with {:ok, job} <- MistralClient.create_fine_tuning_job(config, job_params),
         {:ok, started_job} <- MistralClient.start_fine_tuning_job(config, job.id),
         {:ok, completed_job} <- JobLifecycleManager.wait_for_completion(config, started_job.id) do

      # Extract metrics from completed job
      metrics = extract_metrics(completed_job)

      {:ok, Map.merge(hyperparams, metrics)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_metrics(job) do
    # Extract relevant metrics from the completed job
    %{
      validation_loss: job.validation_loss || 0.0,
      training_loss: job.training_loss || 0.0,
      trained_tokens: job.trained_tokens || 0,
      training_time: job.training_time || 0
    }
  end
end
```

### A/B Testing Fine-tuned Models

```elixir
defmodule ModelABTesting do
  def compare_models(config, model_a, model_b, test_prompts) do
    results = Enum.map(test_prompts, fn prompt ->
      compare_single_prompt(config, model_a, model_b, prompt)
    end)

    analyze_results(results, model_a, model_b)
  end

  defp compare_single_prompt(config, model_a, model_b, prompt) do
    messages = [%{role: "user", content: prompt}]

    # Get responses from both models
    response_a = MistralClient.chat_complete(config, %{
      model: model_a,
      messages: messages,
      max_tokens: 200
    })

    response_b = MistralClient.chat_complete(config, %{
      model: model_b,
      messages: messages,
      max_tokens: 200
    })

    %{
      prompt: prompt,
      model_a_response: extract_response_content(response_a),
      model_b_response: extract_response_content(response_b)
    }
  end

  defp extract_response_content({:ok, response}) do
    response.choices |> List.first() |> Map.get(:message) |> Map.get(:content)
  end
  defp extract_response_content({:error, reason}), do: "Error: #{inspect(reason)}"

  defp analyze_results(results, model_a, model_b) do
    IO.puts("\n🔬 A/B Testing Results")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("Model A: #{model_a}")
    IO.puts("Model B: #{model_b}")
    IO.puts("")

    Enum.with_index(results, 1)
    |> Enum.each(fn {result, index} ->
      IO.puts("Test #{index}: #{result.prompt}")
      IO.puts("Model A: #{result.model_a_response}")
      IO.puts("Model B: #{result.model_b_response}")
      IO.puts("")
    end)

    results
  end
end
```

### Continuous Fine-tuning Pipeline

```elixir
defmodule ContinuousFineTuning do
  use GenServer

  defstruct [:config, :base_model, :data_queue, :current_job, :models_history]

  def start_link(config, base_model) do
    GenServer.start_link(__MODULE__, {config, base_model}, name: __MODULE__)
  end

  def add_training_data(data_batch) do
    GenServer.cast(__MODULE__, {:add_data, data_batch})
  end

  def trigger_training do
    GenServer.call(__MODULE__, :trigger_training)
  end

  def get_latest_model do
    GenServer.call(__MODULE__, :get_latest_model)
  end

  @impl true
  def init({config, base_model}) do
    state = %__MODULE__{
      config: config,
      base_model: base_model,
      data_queue: [],
      current_job: nil,
      models_history: []
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:add_data, data_batch}, state) do
    new_queue = state.data_queue ++ data_batch

    # Auto-trigger training if we have enough data
    if length(new_queue) >= 100 and is_nil(state.current_job) do
      send(self(), :auto_trigger_training)
    end

    {:noreply, %{state | data_queue: new_queue}}
  end

  @impl true
  def handle_call(:trigger_training, _from, state) do
    if length(state.data_queue) < 10 do
      {:reply, {:error, "Not enough training data"}, state}
    else
      case start_training_job(state) do
        {:ok, job_id} ->
          new_state = %{state | current_job: job_id, data_queue: []}
          {:reply, {:ok, job_id}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_latest_model, _from, state) do
    latest_model = case state.models_history do
      [latest | _] -> latest.model_id
      [] -> state.base_model
    end

    {:reply, latest_model, state}
  end

  @impl true
  def handle_info(:auto_trigger_training, state) do
    case start_training_job(state) do
      {:ok, job_id} ->
        new_state = %{state | current_job: job_id, data_queue: []}
        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:job_completed, job_id, model_id}, state) do
    if state.current_job == job_id do
      model_entry = %{
        model_id: model_id,
        created_at: DateTime.utc_now(),
        job_id: job_id
      }

      new_state = %{
        state |
        current_job: nil,
        models_history: [model_entry | state.models_history]
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  defp start_training_job(state) do
    # Prepare training data
    training_data = FineTuningDataValidator.prepare_training_data(state.data_queue)
    file_path = "/tmp/training_#{:rand.uniform(10000)}.jsonl"

    case File.write(file_path, training_data) do
      :ok ->
        # Upload and start job
        with {:ok, file} <- MistralClient.upload_file(state.config, %{
               file: file_path,
               purpose: "fine-tune"
             }),
             {:ok, job} <- MistralClient.create_fine_tuning_job(state.config, %{
               model: get_base_model_for_training(state),
               training_files: [file.id],
               hyperparameters: %{training_steps: 500, learning_rate: 0.0001}
             }),
             {:ok, started_job} <- MistralClient.start_fine_tuning_job(state.config, job.id) do

          # Monitor job in background
          spawn(fn -> monitor_job(state.config, started_job.id) end)

          {:ok, started_job.id}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_base_model_for_training(state) do
    case state.models_history do
      [latest | _] -> latest.model_id  # Use latest fine-tuned model
      [] -> state.base_model           # Use original base model
    end
  end

  defp monitor_job(config, job_id) do
    case JobLifecycleManager.wait_for_completion(config, job_id) do
      {:ok, completed_job} ->
        send(__MODULE__, {:job_completed, job_id, completed_job.fine_tuned_model})

      {:error, _reason} ->
        send(__MODULE__, {:job_failed, job_id})
    end
  end
end
```

## Best Practices Summary

1. **Data Quality**: Always validate and analyze your training data before fine-tuning
2. **Start Small**: Begin with smaller datasets and shorter training runs to validate your approach
3. **Use Validation Data**: Include validation data to monitor overfitting
4. **Monitor Progress**: Actively monitor training jobs and be prepared to cancel if needed
5. **Test Thoroughly**: Always test fine-tuned models before deploying to production
6. **Version Control**: Keep track of different model versions and their performance
7. **Hyperparameter Tuning**: Experiment with different hyperparameters to optimize performance
8. **Cost Management**: Monitor training costs and optimize for your budget
9. **Backup Models**: Archive important models to prevent accidental loss
10. **Documentation**: Document your fine-tuning experiments and results

## Common Issues and Solutions

### Training Data Issues

- **Insufficient Data**: Need at least 50-100 high-quality examples
- **Poor Data Quality**: Ensure conversations are natural and well-formatted
- **Inconsistent Format**: Validate JSONL format and message structure
- **Imbalanced Data**: Ensure good distribution of different conversation types

### Job Failures

- **Resource Limits**: Check if you've exceeded API limits or quotas
- **Invalid Parameters**: Validate hyperparameters are within acceptable ranges
- **File Issues**: Ensure uploaded files are accessible and properly formatted
- **Network Issues**: Implement retry logic for transient failures

### Model Performance

- **Overfitting**: Use validation data and early stopping
- **Underfitting**: Increase training steps or learning rate
- **Poor Generalization**: Add more diverse training examples
- **Inconsistent Outputs**: Review training data for consistency

For more detailed information about fine-tuning, refer to the [Mistral AI Fine-tuning Guide](https://docs.mistral.ai/guides/finetuning/).
