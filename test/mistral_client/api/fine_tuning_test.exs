defmodule MistralClient.API.FineTuningTest do
  use ExUnit.Case, async: true

  alias MistralClient.{Config, Models}
  alias MistralClient.API.FineTuning
  alias MistralClient.Test.Fixtures.FineTuningFixtures
  alias MistralClient.Test.TestHelpers

  import Mox

  setup :verify_on_exit!

  describe "create_job/2" do
    test "creates a fine-tuning job successfully" do
      config = TestHelpers.test_config()

      hyperparameters = %Models.CompletionTrainingParameters{
        learning_rate: 0.0001,
        training_steps: 1000,
        weight_decay: 0.01,
        warmup_fraction: 0.1,
        epochs: 3.0,
        seq_len: 2048,
        fim_ratio: 0.9
      }

      training_files = [%Models.TrainingFile{file_id: "file-abc123", weight: 1.0}]

      integrations = [
        %Models.WandbIntegration{
          type: "wandb",
          project: "my-project",
          name: "my-run",
          api_key: "wandb-key-123"
        }
      ]

      repositories = [
        %Models.GithubRepository{
          type: "github",
          name: "my-repo",
          owner: "my-org",
          ref: "main",
          weight: 1.0,
          commit_id: "abc123def456"
        }
      ]

      request = %Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: hyperparameters,
        training_files: training_files,
        validation_files: ["file-def456"],
        suffix: "my-model",
        integrations: integrations,
        auto_start: true,
        invalid_sample_skip_percentage: 0.0,
        job_type: :completion,
        repositories: repositories
      }

      expected_body = FineTuningFixtures.create_job_request()
      response_body = FineTuningFixtures.create_job_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.create_job(config, request)
      assert job.id == "ftjob-123456789"
      assert job.model == "open-mistral-7b"
      assert job.status == :queued
      assert job.suffix == "my-model"
      assert job.auto_start == true
      assert length(job.training_files) == 1
      assert length(job.validation_files) == 1
      assert length(job.integrations) == 1
      assert length(job.repositories) == 1
      assert job.hyperparameters.learning_rate == 0.0001
      assert job.hyperparameters.training_steps == 1000
    end

    test "creates a minimal fine-tuning job" do
      config = TestHelpers.test_config()

      hyperparameters = %Models.CompletionTrainingParameters{
        learning_rate: 0.0001
      }

      request = %Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: hyperparameters
      }

      expected_body = FineTuningFixtures.minimal_create_job_request()
      response_body = FineTuningFixtures.create_job_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.create_job(config, request)
      assert job.id == "ftjob-123456789"
      assert job.model == "open-mistral-7b"
    end

    test "validates required parameters" do
      config = TestHelpers.test_config()

      # Missing model
      request = %Models.FineTuningJobRequest{
        model: nil,
        hyperparameters: %Models.CompletionTrainingParameters{learning_rate: 0.0001}
      }

      assert {:error, "Model is required"} = FineTuning.create_job(config, request)

      # Missing hyperparameters
      request = %Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: nil
      }

      assert {:error, "Hyperparameters are required"} = FineTuning.create_job(config, request)
    end

    test "handles API errors" do
      config = TestHelpers.test_config()

      request = %Models.FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: %Models.CompletionTrainingParameters{learning_rate: 0.0001}
      }

      # Test 401 Unauthorized
      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 401, body: FineTuningFixtures.unauthorized_error()}}
      end)

      assert {:error, error} = FineTuning.create_job(config, request)
      assert error.message =~ "Unauthorized"

      # Test 422 Invalid Request
      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 422, body: FineTuningFixtures.invalid_request_error()}}
      end)

      assert {:error, error} = FineTuning.create_job(config, request)
      assert error.message =~ "Invalid request parameters"

      # Test 429 Rate Limit
      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 429, body: FineTuningFixtures.rate_limit_error()}}
      end)

      assert {:error, error} = FineTuning.create_job(config, request)
      assert error.message =~ "Rate limit exceeded"

      # Test 500 Server Error
      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 500, body: FineTuningFixtures.server_error()}}
      end)

      assert {:error, error} = FineTuning.create_job(config, request)
      assert error.message =~ "Internal server error"
    end
  end

  describe "list_jobs/2" do
    test "lists all fine-tuning jobs" do
      config = TestHelpers.test_config()
      response_body = FineTuningFixtures.list_jobs_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, jobs_response} = FineTuning.list_jobs(config)
      assert jobs_response.total == 3
      assert length(jobs_response.data) == 3
      assert jobs_response.has_more == false

      # Check first job
      first_job = hd(jobs_response.data)
      assert first_job.id == "ftjob-123456789"
      assert first_job.status == :running
    end

    test "lists jobs with filtering options" do
      config = TestHelpers.test_config()

      options = %{
        status: :running,
        model: "open-mistral-7b",
        page: 1,
        page_size: 10,
        created_by_me: true,
        wandb_project: "my-project",
        suffix: "my-model"
      }

      expected_params = %{
        status: "RUNNING",
        model: "open-mistral-7b",
        page: 1,
        page_size: 10,
        created_by_me: true,
        wandb_project: "my-project",
        suffix: "my-model"
      }

      response_body = FineTuningFixtures.list_jobs_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, _jobs_response} = FineTuning.list_jobs(config, options)
    end

    test "lists jobs with DateTime filtering" do
      config = TestHelpers.test_config()

      created_after = ~U[2024-01-01 00:00:00Z]
      created_before = ~U[2024-12-31 23:59:59Z]

      options = %{
        created_after: created_after,
        created_before: created_before
      }

      expected_params = %{
        created_after: "2024-01-01T00:00:00Z",
        created_before: "2024-12-31T23:59:59Z"
      }

      response_body = FineTuningFixtures.list_jobs_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, _jobs_response} = FineTuning.list_jobs(config, options)
    end

    test "handles API errors for list jobs" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 401, body: FineTuningFixtures.unauthorized_error()}}
      end)

      assert {:error, error} = FineTuning.list_jobs(config)
      assert error.message =~ "Unauthorized"
    end
  end

  describe "get_job/2" do
    test "gets a specific fine-tuning job" do
      config = TestHelpers.test_config()
      job_id = "ftjob-123456789"
      response_body = FineTuningFixtures.get_job_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.get_job(config, job_id)
      assert job.id == "ftjob-123456789"
      assert job.status == :running
      assert job.trained_tokens == 50_000
      assert length(job.events) == 2
      assert length(job.checkpoints) == 1
    end

    test "handles job not found error" do
      config = TestHelpers.test_config()
      job_id = "nonexistent-job"

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: FineTuningFixtures.job_not_found_error()}}
      end)

      assert {:error, error} = FineTuning.get_job(config, job_id)
      assert error.message =~ "Job not found"
    end
  end

  describe "start_job/2" do
    test "starts a fine-tuning job" do
      config = TestHelpers.test_config()
      job_id = "ftjob-123456789"
      response_body = FineTuningFixtures.start_job_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.start_job(config, job_id)
      assert job.id == "ftjob-123456789"
      assert job.status == :started
    end

    test "handles start job errors" do
      config = TestHelpers.test_config()
      job_id = "ftjob-123456789"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: FineTuningFixtures.job_not_found_error()}}
      end)

      assert {:error, error} = FineTuning.start_job(config, job_id)
      assert error.message =~ "Job not found"
    end
  end

  describe "cancel_job/2" do
    test "cancels a fine-tuning job" do
      config = TestHelpers.test_config()
      job_id = "ftjob-123456789"
      response_body = FineTuningFixtures.cancel_job_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.cancel_job(config, job_id)
      assert job.id == "ftjob-123456789"
      assert job.status == :cancellation_requested
    end

    test "handles cancel job errors" do
      config = TestHelpers.test_config()
      job_id = "ftjob-123456789"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: FineTuningFixtures.job_not_found_error()}}
      end)

      assert {:error, error} = FineTuning.cancel_job(config, job_id)
      assert error.message =~ "Job not found"
    end
  end

  describe "archive_model/2" do
    test "archives a fine-tuned model" do
      config = TestHelpers.test_config()
      model_id = "ft:open-mistral-7b:my-model:abc123"
      response_body = FineTuningFixtures.archive_model_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, model} = FineTuning.archive_model(config, model_id)
      assert model["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert model["archived"] == true
    end

    test "handles archive model errors" do
      config = TestHelpers.test_config()
      model_id = "ft:open-mistral-7b:my-model:abc123"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: FineTuningFixtures.model_not_found_error()}}
      end)

      assert {:error, error} = FineTuning.archive_model(config, model_id)
      assert error.message =~ "Model not found"
    end
  end

  describe "unarchive_model/2" do
    test "unarchives a fine-tuned model" do
      config = TestHelpers.test_config()
      model_id = "ft:open-mistral-7b:my-model:abc123"
      response_body = FineTuningFixtures.unarchive_model_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, model} = FineTuning.unarchive_model(config, model_id)
      assert model["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert model["archived"] == false
    end

    test "handles unarchive model errors" do
      config = TestHelpers.test_config()
      model_id = "ft:open-mistral-7b:my-model:abc123"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: FineTuningFixtures.model_not_found_error()}}
      end)

      assert {:error, error} = FineTuning.unarchive_model(config, model_id)
      assert error.message =~ "Model not found"
    end
  end

  describe "update_model/3" do
    test "updates a fine-tuned model" do
      config = TestHelpers.test_config()
      model_id = "ft:open-mistral-7b:my-model:abc123"
      updates = %{"name" => "Updated Model Name", "description" => "Updated description"}
      response_body = FineTuningFixtures.update_model_success_response()

      MistralClient.HttpClientMock
      |> expect(:request, fn :patch, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, model} = FineTuning.update_model(config, model_id, updates)
      assert model["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert model["name"] == "Updated Model Name"
      assert model["description"] == "Updated description"
    end

    test "handles update model errors" do
      config = TestHelpers.test_config()
      model_id = "ft:open-mistral-7b:my-model:abc123"
      updates = %{"name" => "Updated Model Name"}

      MistralClient.HttpClientMock
      |> expect(:request, fn :patch, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: FineTuningFixtures.model_not_found_error()}}
      end)

      assert {:error, error} = FineTuning.update_model(config, model_id, updates)
      assert error.message =~ "Model not found"
    end
  end

  describe "response parsing" do
    test "parses job status correctly" do
      config = TestHelpers.test_config()

      # Test all status values
      statuses = [
        {"QUEUED", :queued},
        {"STARTED", :started},
        {"VALIDATING", :validating},
        {"VALIDATED", :validated},
        {"RUNNING", :running},
        {"FAILED_VALIDATION", :failed_validation},
        {"FAILED", :failed},
        {"SUCCESS", :success},
        {"CANCELLED", :cancelled},
        {"CANCELLATION_REQUESTED", :cancellation_requested}
      ]

      for {api_status, expected_atom} <- statuses do
        response_body = %{FineTuningFixtures.get_job_success_response() | "status" => api_status}

        MistralClient.HttpClientMock
        |> expect(:request, fn :get, _url, _headers, _body, _options ->
          {:ok, %{status: 200, body: response_body}}
        end)

        assert {:ok, job} = FineTuning.get_job(config, "test-job")
        assert job.status == expected_atom
      end
    end

    test "parses job type correctly" do
      config = TestHelpers.test_config()

      # Test completion job type
      response_body = %{
        FineTuningFixtures.get_job_success_response()
        | "job_type" => "completion"
      }

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.get_job(config, "test-job")
      assert job.job_type == :completion

      # Test classifier job type
      response_body = %{
        FineTuningFixtures.get_job_success_response()
        | "job_type" => "classifier"
      }

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: response_body}}
      end)

      assert {:ok, job} = FineTuning.get_job(config, "test-job")
      assert job.job_type == :classifier
    end

    test "handles network errors" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:error, :timeout}
      end)

      assert {:error, %MistralClient.Errors.NetworkError{reason: :timeout}} =
               FineTuning.get_job(config, "test-job")
    end
  end
end
