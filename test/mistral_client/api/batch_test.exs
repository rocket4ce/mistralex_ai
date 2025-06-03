defmodule MistralClient.API.BatchTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.API.Batch
  alias MistralClient.Models.{BatchJobIn, BatchJobOut, BatchJobsOut}
  alias MistralClient.Test.{BatchFixtures, TestHelpers}

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Create a test client with mock HTTP client
    client = TestHelpers.mock_client()
    {:ok, client: client}
  end

  describe "list/2" do
    test "lists batch jobs successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_jobs_list_response())
         }}
      end)

      assert {:ok, %BatchJobsOut{} = response} = Batch.list(client)
      assert response.total == 3
      assert length(response.data) == 3
      assert response.object == "list"

      # Verify first job details
      first_job = hd(response.data)
      assert first_job.id == "batch_abc123"
      assert first_job.status == :queued
      assert first_job.model == "mistral-large-latest"
      assert first_job.endpoint == "/v1/chat/completions"
    end

    test "lists batch jobs with filtering parameters", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, url, _headers, _body, _opts ->
        # Verify query parameters are included
        assert String.contains?(url, "page=1")
        assert String.contains?(url, "page_size=50")
        assert String.contains?(url, "model=mistral-large-latest")
        assert String.contains?(url, "created_by_me=true")

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_jobs_filtered_list_response())
         }}
      end)

      params = %{
        page: 1,
        page_size: 50,
        model: "mistral-large-latest",
        created_by_me: true,
        status: ["RUNNING"]
      }

      assert {:ok, %BatchJobsOut{} = response} = Batch.list(client, params)
      assert response.total == 1
      assert length(response.data) == 1
    end

    test "lists batch jobs with DateTime filtering", %{client: client} do
      created_after = ~U[2022-01-01 00:00:00Z]

      expect(MistralClient.HttpClientMock, :request, fn :get, url, _headers, _body, _opts ->
        # Verify DateTime is converted to ISO8601
        assert String.contains?(url, "created_after=2022-01-01T00%3A00%3A00Z")

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_jobs_empty_list_response())
         }}
      end)

      params = %{created_after: created_after}

      assert {:ok, %BatchJobsOut{} = response} = Batch.list(client, params)
      assert response.total == 0
      assert response.data == []
    end

    test "handles empty list response", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_jobs_empty_list_response())
         }}
      end)

      assert {:ok, %BatchJobsOut{} = response} = Batch.list(client)
      assert response.total == 0
      assert response.data == []
    end

    test "handles 401 unauthorized error", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 401,
           body: Jason.encode!(BatchFixtures.batch_job_unauthorized_error())
         }}
      end)

      assert {:error, %MistralClient.Errors.AuthenticationError{message: "Invalid API key"}} =
               Batch.list(client)
    end

    test "handles 429 rate limit error", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 429,
           body: Jason.encode!(BatchFixtures.batch_job_rate_limit_error())
         }}
      end)

      assert {:error, %MistralClient.Errors.RateLimitError{message: "Rate limit exceeded"}} =
               Batch.list(client)
    end

    test "handles 500 server error", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 500,
           body: Jason.encode!(BatchFixtures.batch_job_server_error())
         }}
      end)

      assert {:error, %MistralClient.Errors.ServerError{message: "Internal server error"}} =
               Batch.list(client)
    end

    test "handles network error", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, %MistralClient.Errors.NetworkError{reason: :timeout}} = Batch.list(client)
    end
  end

  describe "create/2" do
    test "creates batch job successfully with map request", %{client: client} do
      request_data = %{
        input_files: ["file-abc123", "file-def456"],
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest",
        metadata: %{"project" => "customer-support"},
        timeout_hours: 24
      }

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["input_files"] == ["file-abc123", "file-def456"]
        assert decoded_body["endpoint"] == "/v1/chat/completions"
        assert decoded_body["model"] == "mistral-large-latest"
        assert decoded_body["metadata"]["project"] == "customer-support"
        assert decoded_body["timeout_hours"] == 24

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.create(client, request_data)
      assert response.id == "batch_abc123"
      assert response.status == :queued
      assert response.model == "mistral-large-latest"
      assert response.endpoint == "/v1/chat/completions"
      assert response.input_files == ["file-abc123", "file-def456"]
      assert response.total_requests == 100
      assert response.completed_requests == 0
    end

    test "creates batch job successfully with BatchJobIn struct", %{client: client} do
      request = %BatchJobIn{
        input_files: ["file-abc123"],
        endpoint: "/v1/embeddings",
        model: "mistral-embed",
        metadata: %{"type" => "embeddings"},
        timeout_hours: 12
      }

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["input_files"] == ["file-abc123"]
        assert decoded_body["endpoint"] == "/v1/embeddings"
        assert decoded_body["model"] == "mistral-embed"

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_embeddings_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.create(client, request)
      assert response.id == "batch_embed123"
      assert response.endpoint == "/v1/embeddings"
      assert response.model == "mistral-embed"
    end

    test "validates required fields", %{client: client} do
      # Missing input_files
      request_data = %{
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest"
      }

      assert {:error, "Missing required fields: input_files"} = Batch.create(client, request_data)

      # Missing endpoint
      request_data = %{
        input_files: ["file-abc123"],
        model: "mistral-large-latest"
      }

      assert {:error, "Missing required fields: endpoint"} = Batch.create(client, request_data)

      # Missing model
      request_data = %{
        input_files: ["file-abc123"],
        endpoint: "/v1/chat/completions"
      }

      assert {:error, "Missing required fields: model"} = Batch.create(client, request_data)
    end

    test "handles validation error from API", %{client: client} do
      request_data = %{
        input_files: ["file-abc123"],
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest"
      }

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 422,
           body: Jason.encode!(BatchFixtures.batch_job_validation_error())
         }}
      end)

      assert {:error,
              %MistralClient.Errors.ValidationError{
                message: "Missing required field: input_files"
              }} =
               Batch.create(client, request_data)
    end

    test "handles invalid endpoint error", %{client: client} do
      request_data = %{
        input_files: ["file-abc123"],
        endpoint: "/v1/invalid/endpoint",
        model: "mistral-large-latest"
      }

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 422,
           body: Jason.encode!(BatchFixtures.batch_job_invalid_endpoint_error())
         }}
      end)

      assert {:error,
              %MistralClient.Errors.ValidationError{
                message: "Invalid endpoint: /v1/invalid/endpoint"
              }} =
               Batch.create(client, request_data)
    end

    test "handles file not found error", %{client: client} do
      request_data = %{
        input_files: ["file-nonexistent"],
        endpoint: "/v1/chat/completions",
        model: "mistral-large-latest"
      }

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 404,
           body: Jason.encode!(BatchFixtures.batch_job_file_not_found_error())
         }}
      end)

      assert {:error,
              %MistralClient.Errors.NotFoundError{
                message: "Input file not found: file-nonexistent"
              }} =
               Batch.create(client, request_data)
    end
  end

  describe "get/2" do
    test "gets batch job successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, url, _headers, _body, _opts ->
        assert String.ends_with?(url, "/v1/batch/jobs/batch_abc123")

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_running_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_abc123")
      assert response.id == "batch_abc123"
      assert response.status == :running
      assert response.completed_requests == 45
      assert response.total_requests == 100
      assert response.succeeded_requests == 42
      assert response.failed_requests == 3
    end

    test "gets completed batch job with output files", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_completed_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_abc123")
      assert response.status == :success
      assert response.completed_requests == 100
      assert response.output_file == "file-output123"
      assert response.error_file == "file-errors123"
      assert response.started_at == 1_640_995_260
      assert response.completed_at == 1_640_998_800
    end

    test "gets failed batch job with errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_failed_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_abc123")
      assert response.status == :failed
      assert length(response.errors) == 1
      assert hd(response.errors).message == "Invalid input format in file file-abc123"
      assert response.error_file == "file-errors123"
    end

    test "handles batch job not found", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 404,
           body: Jason.encode!(BatchFixtures.batch_job_not_found_error())
         }}
      end)

      assert {:error, %MistralClient.Errors.NotFoundError{message: "Batch job not found"}} =
               Batch.get(client, "batch_nonexistent")
    end
  end

  describe "cancel/2" do
    test "cancels batch job successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, url, _headers, body, _opts ->
        assert String.ends_with?(url, "/v1/batch/jobs/batch_abc123/cancel")
        assert Jason.decode!(body) == %{}

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_cancellation_requested_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.cancel(client, "batch_abc123")
      assert response.id == "batch_cancel123"
      assert response.status == :cancellation_requested
      assert response.completed_requests == 80
    end

    test "cancels batch job that gets cancelled immediately", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_cancelled_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.cancel(client, "batch_abc123")
      assert response.status == :cancelled
      assert response.completed_at == 1_640_996_800
    end

    test "handles cancel request for non-existent job", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 404,
           body: Jason.encode!(BatchFixtures.batch_job_not_found_error())
         }}
      end)

      assert {:error, %MistralClient.Errors.NotFoundError{message: "Batch job not found"}} =
               Batch.cancel(client, "batch_nonexistent")
    end
  end

  describe "progress tracking scenarios" do
    test "tracks progress from 0% to 100%", %{client: client} do
      # Test 0% progress
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_progress_0_percent())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_progress123")
      assert response.status == :queued
      assert response.completed_requests == 0
      assert response.total_requests == 1000

      # Test 25% progress
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_progress_25_percent())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_progress123")
      assert response.status == :running
      assert response.completed_requests == 250
      assert response.succeeded_requests == 245
      assert response.failed_requests == 5

      # Test 75% progress
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_progress_75_percent())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_progress123")
      assert response.status == :running
      assert response.completed_requests == 750
      assert response.succeeded_requests == 735
      assert response.failed_requests == 15

      # Test 100% progress
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_progress_100_percent())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_progress123")
      assert response.status == :success
      assert response.completed_requests == 1000
      assert response.succeeded_requests == 980
      assert response.failed_requests == 20
      assert response.output_file == "file-large-output123"
      assert response.error_file == "file-large-errors123"
    end

    test "handles timeout exceeded scenario", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_timeout_exceeded_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.get(client, "batch_timeout123")
      assert response.status == :timeout_exceeded
      assert response.completed_requests == 300
      assert response.total_requests == 500
      assert length(response.errors) == 1
      assert hd(response.errors).message == "Batch job exceeded timeout limit of 24 hours"
      assert response.output_file == "file-partial-output123"
      assert response.error_file == "file-timeout-errors123"
    end
  end

  describe "different endpoint scenarios" do
    test "creates and tracks embeddings batch job", %{client: client} do
      request_data = BatchFixtures.batch_job_embeddings_request()

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["endpoint"] == "/v1/embeddings"
        assert decoded_body["model"] == "mistral-embed"

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_embeddings_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.create(client, request_data)
      assert response.endpoint == "/v1/embeddings"
      assert response.model == "mistral-embed"
      assert response.status == :success
      assert response.failed_requests == 0
    end

    test "creates and tracks FIM batch job", %{client: client} do
      request_data = BatchFixtures.batch_job_fim_request()

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["endpoint"] == "/v1/fim/completions"
        assert decoded_body["model"] == "codestral-latest"

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_job_fim_response())
         }}
      end)

      assert {:ok, %BatchJobOut{} = response} = Batch.create(client, request_data)
      assert response.endpoint == "/v1/fim/completions"
      assert response.model == "codestral-latest"
      assert response.status == :success
      assert response.total_requests == 25
      assert response.succeeded_requests == 24
      assert response.failed_requests == 1
    end
  end

  describe "parameter validation" do
    test "validates job_id parameter for get", %{client: client} do
      # This would be caught by the function guard, but let's test the behavior
      assert_raise FunctionClauseError, fn ->
        Batch.get(client, nil)
      end

      assert_raise FunctionClauseError, fn ->
        Batch.get(client, 123)
      end
    end

    test "validates job_id parameter for cancel", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Batch.cancel(client, nil)
      end

      assert_raise FunctionClauseError, fn ->
        Batch.cancel(client, 123)
      end
    end

    test "filters invalid parameters in list", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn :get, url, _headers, _body, _opts ->
        # Should not contain invalid parameters
        refute String.contains?(url, "invalid_param")
        refute String.contains?(url, "another_invalid")

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(BatchFixtures.batch_jobs_empty_list_response())
         }}
      end)

      params = %{
        page: 0,
        invalid_param: "should_be_ignored",
        another_invalid: 123,
        model: "mistral-large-latest"
      }

      assert {:ok, %BatchJobsOut{}} = Batch.list(client, params)
    end
  end
end
