defmodule MistralClient.API.JobsTest do
  use ExUnit.Case, async: true

  import Mox
  import MistralClient.Test.Fixtures.JobsFixtures

  alias MistralClient.API.Jobs
  alias MistralClient.Models.{FineTuningJobRequest, CompletionTrainingParameters, TrainingFile}
  alias MistralClient.Test.TestHelpers

  setup :verify_on_exit!

  describe "list/0" do
    test "lists all jobs successfully" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: jobs_list_response()}}
      end)

      assert {:ok, response} = Jobs.list(config, %{})
      assert response.total == 2
      assert length(response.data) == 2
      assert response.has_more == false
      assert response.object == "list"

      first_job = hd(response.data)
      assert first_job.id == "ft-job-123"
      assert first_job.status == :running
      assert first_job.model == "open-mistral-7b"
    end

    test "handles empty job list" do
      config = TestHelpers.test_config()

      empty_response = %{
        "total" => 0,
        "data" => [],
        "has_more" => false,
        "object" => "list"
      }

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: empty_response}}
      end)

      assert {:ok, response} = Jobs.list(config, %{})
      assert response.total == 0
      assert response.data == []
      assert response.has_more == false
    end

    test "handles API errors" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 401, body: unauthorized_error()}}
      end)

      assert {:error, _reason} = Jobs.list(config, %{})
    end
  end

  describe "list/1 with options" do
    test "lists jobs with filtering options" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, options ->
        query = options[:query]
        assert query[:status] == "RUNNING"
        assert query[:model] == "open-mistral-7b"
        assert query[:page_size] == 10
        assert query[:created_by_me] == true

        {:ok, %{status: 200, body: jobs_list_response()}}
      end)

      options = %{
        status: :running,
        model: "open-mistral-7b",
        page_size: 10,
        created_by_me: true
      }

      assert {:ok, response} = Jobs.list(config, options)
      assert response.total == 2
    end

    test "lists jobs with pagination" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, options ->
        query = options[:query]
        assert query[:page] == 1
        assert query[:page_size] == 50

        {:ok, %{status: 200, body: jobs_list_response()}}
      end)

      options = %{page: 1, page_size: 50}

      assert {:ok, response} = Jobs.list(config, options)
      assert response.total == 2
    end
  end

  describe "list/2 with custom config" do
    test "lists jobs with custom configuration" do
      config = TestHelpers.test_config(api_key: "custom-key")

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: jobs_list_response()}}
      end)

      assert {:ok, response} = Jobs.list(config, %{})
      assert response.total == 2
    end
  end

  describe "create/1" do
    test "creates a job successfully" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: job_created_response()}}
      end)

      request = %FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: %CompletionTrainingParameters{
          learning_rate: 0.0001,
          training_steps: 1000
        },
        training_files: [%TrainingFile{file_id: "file-123"}],
        auto_start: true,
        suffix: "test-model"
      }

      assert {:ok, job} = Jobs.create(config, request)
      assert job.id == "ft-job-789"
      assert job.status == :queued
      assert job.model == "open-mistral-7b"
      assert job.suffix == "new-model"
    end

    test "handles validation errors" do
      config = TestHelpers.test_config()
      # This test validates client-side validation, so no HTTP request is made
      request = %FineTuningJobRequest{
        model: "",
        hyperparameters: %CompletionTrainingParameters{learning_rate: 0.0001}
      }

      assert {:error, "Model is required"} = Jobs.create(config, request)
    end

    test "handles API validation errors" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 422, body: validation_error()}}
      end)

      request = %FineTuningJobRequest{
        model: "open-mistral-7b",
        hyperparameters: %CompletionTrainingParameters{learning_rate: 0.0001}
      }

      assert {:error, _reason} = Jobs.create(config, request)
    end
  end

  describe "get/1" do
    test "gets job details successfully" do
      config = TestHelpers.test_config()
      job_id = "ft-job-123"

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: job_response()}}
      end)

      assert {:ok, job} = Jobs.get(config, job_id)
      assert job.id == "ft-job-123"
      assert job.status == :running
      assert job.model == "open-mistral-7b"
      assert job.fine_tuned_model == "ft:open-mistral-7b:test-model:xxx"
      assert job.trained_tokens == 1000
    end

    test "handles job not found" do
      config = TestHelpers.test_config()
      job_id = "nonexistent-job"

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: not_found_error()}}
      end)

      assert {:error, _reason} = Jobs.get(config, job_id)
    end
  end

  describe "start/1" do
    test "starts a job successfully" do
      config = TestHelpers.test_config()
      job_id = "ft-job-123"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: job_started_response()}}
      end)

      assert {:ok, job} = Jobs.start(config, job_id)
      assert job.id == "ft-job-123"
      assert job.status == :started
    end

    test "handles job not found when starting" do
      config = TestHelpers.test_config()
      job_id = "nonexistent-job"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: not_found_error()}}
      end)

      assert {:error, _reason} = Jobs.start(config, job_id)
    end
  end

  describe "cancel/1" do
    test "cancels a job successfully" do
      config = TestHelpers.test_config()
      job_id = "ft-job-123"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: job_cancelled_response()}}
      end)

      assert {:ok, job} = Jobs.cancel(config, job_id)
      assert job.id == "ft-job-123"
      assert job.status == :cancelled
    end

    test "handles job not found when cancelling" do
      config = TestHelpers.test_config()
      job_id = "nonexistent-job"

      MistralClient.HttpClientMock
      |> expect(:request, fn :post, _url, _headers, _body, _options ->
        {:ok, %{status: 404, body: not_found_error()}}
      end)

      assert {:error, _reason} = Jobs.cancel(config, job_id)
    end
  end

  describe "error handling" do
    test "handles rate limiting" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 429, body: rate_limit_error()}}
      end)

      assert {:error, _reason} = Jobs.list(config, %{})
    end

    test "handles server errors" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 500, body: server_error()}}
      end)

      assert {:error, _reason} = Jobs.list(config, %{})
    end

    test "handles network errors" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:error, :timeout}
      end)

      assert {:error, %MistralClient.Errors.NetworkError{reason: :timeout}} =
               Jobs.list(config, %{})
    end
  end

  describe "response parsing" do
    test "handles malformed JSON responses" do
      config = TestHelpers.test_config()

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: "invalid json"}}
      end)

      assert {:error, _reason} = Jobs.list(config, %{})
    end

    test "handles missing required fields" do
      config = TestHelpers.test_config()

      incomplete_response = %{
        "total" => 1,
        # Missing required fields
        "data" => [%{"id" => "job-123"}],
        "has_more" => false,
        "object" => "list"
      }

      MistralClient.HttpClientMock
      |> expect(:request, fn :get, _url, _headers, _body, _options ->
        {:ok, %{status: 200, body: incomplete_response}}
      end)

      assert {:ok, response} = Jobs.list(config, %{})
      assert response.total == 1
      assert length(response.data) == 1
    end
  end

  describe "status conversion" do
    test "converts string statuses to atoms correctly" do
      config = TestHelpers.test_config()

      job_with_status = fn status ->
        job_response() |> Map.put("status", status)
      end

      status_mappings = [
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

      for {string_status, atom_status} <- status_mappings do
        MistralClient.HttpClientMock
        |> expect(:request, fn :get, _url, _headers, _body, _options ->
          {:ok, %{status: 200, body: job_with_status.(string_status)}}
        end)

        assert {:ok, job} = Jobs.get(config, "test-job")
        assert job.status == atom_status
      end
    end
  end
end
