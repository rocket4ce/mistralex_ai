defmodule MistralClient.API.FilesTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.{API.Files, Models, Errors}
  alias MistralClient.Test.{FileFixtures, TestHelpers}

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  @test_file_path "/tmp/test_file.jsonl"
  @large_test_file_path "/tmp/large_test_file.jsonl"

  setup do
    # Create a mock client
    client = TestHelpers.mock_client()

    # Clean up any existing test files
    FileFixtures.cleanup_test_file(@test_file_path)
    FileFixtures.cleanup_test_file(@large_test_file_path)

    # Create test files
    FileFixtures.create_test_file(@test_file_path)

    on_exit(fn ->
      FileFixtures.cleanup_test_file(@test_file_path)
      FileFixtures.cleanup_test_file(@large_test_file_path)
    end)

    {:ok, client: client}
  end

  describe "upload/4" do
    test "uploads a file successfully", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :post, url, headers, _body, options ->
          assert String.ends_with?(url, "/files")

          assert [{"content-type", "multipart/form-data"}] in [
                   headers,
                   Keyword.get(options, :headers)
                 ]

          form_data = Keyword.get(options, :form)
          assert {"purpose", "fine-tune"} in form_data

          assert {"file", _content, [{"filename", "test_file.jsonl"}]} =
                   List.keyfind(form_data, "file", 0)

          {:ok, %{status: 200, body: FileFixtures.file_upload_response(), headers: %{}}}
      end)

      assert {:ok, file_upload} = Files.upload(@test_file_path, "fine-tune", [], client)
      assert %Models.FileUpload{} = file_upload
      assert file_upload.id == "file-abc123"
      assert file_upload.filename == "training_data.jsonl"
      assert file_upload.purpose == "fine-tune"
    end

    test "uploads a file with custom filename", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :post, url, _headers, _body, options ->
          assert String.ends_with?(url, "/files")
          form_data = Keyword.get(options, :form)

          assert {"file", _content, [{"filename", "custom_name.jsonl"}]} =
                   List.keyfind(form_data, "file", 0)

          {:ok, %{status: 200, body: FileFixtures.file_upload_response(), headers: %{}}}
      end)

      assert {:ok, _file_upload} =
               Files.upload(@test_file_path, "fine-tune", [filename: "custom_name.jsonl"], client)
    end

    test "uploads a file with progress callback", %{client: client} do
      progress_calls = Agent.start_link(fn -> [] end)
      {:ok, agent} = progress_calls

      progress_fn = fn progress ->
        Agent.update(agent, fn calls -> [progress | calls] end)
      end

      expect(MistralClient.HttpClientMock, :request, fn
        :post, url, _headers, _body, _options ->
          assert String.ends_with?(url, "/files")
          {:ok, %{status: 200, body: FileFixtures.file_upload_response(), headers: %{}}}
      end)

      assert {:ok, _file_upload} =
               Files.upload(
                 @test_file_path,
                 "fine-tune",
                 [progress_callback: progress_fn],
                 client
               )

      calls = Agent.get(agent, & &1)
      assert 1.0 in calls
    end

    test "validates file existence", %{client: client} do
      assert {:error, %Errors.ValidationError{field: "file_path"}} =
               Files.upload("/nonexistent/file.jsonl", "fine-tune", [], client)
    end

    test "validates file size", %{client: client} do
      # Create a large file (over 512MB)
      large_content = String.duplicate("x", 513 * 1024 * 1024)
      File.write!(@large_test_file_path, large_content)

      assert {:error, %Errors.ValidationError{field: "file_size"}} =
               Files.upload(@large_test_file_path, "fine-tune", [], client)
    end

    test "validates file extension for fine-tuning", %{client: client} do
      txt_file = "/tmp/test.txt"
      File.write!(txt_file, "test content")

      on_exit(fn -> File.rm!(txt_file) end)

      assert {:error, %Errors.ValidationError{field: "file_extension"}} =
               Files.upload(txt_file, "fine-tune", [], client)
    end

    test "validates purpose", %{client: client} do
      assert {:error, %Errors.ValidationError{field: "purpose"}} =
               Files.upload(@test_file_path, "invalid-purpose", [], client)
    end

    test "handles upload errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :post, url, _headers, _body, _options ->
          assert String.ends_with?(url, "/files")
          {:error, %Errors.APIError{message: "Upload failed"}}
      end)

      assert {:error, %Errors.APIError{}} = Files.upload(@test_file_path, "fine-tune", [], client)
    end
  end

  describe "list/2" do
    test "lists all files", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.ends_with?(url, "/files")
          {:ok, %{status: 200, body: FileFixtures.file_list_response(), headers: %{}}}
      end)

      assert {:ok, file_list} = Files.list([], client)
      assert %Models.FileList{} = file_list
      assert length(file_list.data) == 2
      assert file_list.total == 2
    end

    test "lists files with pagination", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "page=1")
          assert String.contains?(url, "page_size=50")
          {:ok, %{status: 200, body: FileFixtures.file_list_response(), headers: %{}}}
      end)

      assert {:ok, _file_list} = Files.list([page: 1, page_size: 50], client)
    end

    test "lists files with filters", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "purpose=fine-tune")
          assert String.contains?(url, "search=training")
          {:ok, %{status: 200, body: FileFixtures.file_list_response(), headers: %{}}}
      end)

      assert {:ok, _file_list} = Files.list([purpose: "fine-tune", search: "training"], client)
    end

    test "handles list errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.ends_with?(url, "/files")
          {:error, %Errors.APIError{message: "List failed"}}
      end)

      assert {:error, %Errors.APIError{}} = Files.list([], client)
    end
  end

  describe "retrieve/2" do
    test "retrieves a specific file", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/file-abc123")
          {:ok, %{status: 200, body: FileFixtures.file_response(), headers: %{}}}
      end)

      assert {:ok, file} = Files.retrieve("file-abc123", client)
      assert %Models.File{} = file
      assert file.id == "file-abc123"
      assert file.filename == "training_data.jsonl"
    end

    test "validates file_id", %{client: client} do
      assert {:error, %Errors.ValidationError{field: "file_id"}} =
               Files.retrieve("", client)
    end

    test "handles retrieve errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/nonexistent")
          {:error, %Errors.NotFoundError{message: "File not found"}}
      end)

      assert {:error, %Errors.NotFoundError{}} = Files.retrieve("nonexistent", client)
    end
  end

  describe "delete/2" do
    test "deletes a file", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :delete, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/file-abc123")
          {:ok, %{status: 200, body: FileFixtures.delete_file_response(), headers: %{}}}
      end)

      assert {:ok, delete_result} = Files.delete("file-abc123", client)
      assert %Models.DeleteFileOut{} = delete_result
      assert delete_result.id == "file-abc123"
      assert delete_result.deleted == true
    end

    test "validates file_id", %{client: client} do
      assert {:error, %Errors.ValidationError{field: "file_id"}} =
               Files.delete("", client)
    end

    test "handles delete errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :delete, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/nonexistent")
          {:error, %Errors.NotFoundError{message: "File not found"}}
      end)

      assert {:error, %Errors.NotFoundError{}} = Files.delete("nonexistent", client)
    end
  end

  describe "download/2" do
    test "downloads file content", %{client: client} do
      file_content = "test file content"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/file-abc123/content")
          {:ok, %{status: 200, body: file_content, headers: %{}}}
      end)

      assert {:ok, ^file_content} = Files.download("file-abc123", client)
    end

    test "validates file_id", %{client: client} do
      assert {:error, %Errors.ValidationError{field: "file_id"}} =
               Files.download("", client)
    end

    test "handles download errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/nonexistent/content")
          {:error, %Errors.NotFoundError{message: "File not found"}}
      end)

      assert {:error, %Errors.NotFoundError{}} = Files.download("nonexistent", client)
    end
  end

  describe "get_signed_url/3" do
    test "gets signed URL with default expiry", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/file-abc123/url")
          assert String.contains?(url, "expiry=24")
          {:ok, %{status: 200, body: FileFixtures.signed_url_response(), headers: %{}}}
      end)

      assert {:ok, signed_url} = Files.get_signed_url("file-abc123", [], client)
      assert %Models.FileSignedURL{} = signed_url
      assert signed_url.signed_url =~ "storage.googleapis.com"
    end

    test "gets signed URL with custom expiry", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/file-abc123/url")
          assert String.contains?(url, "expiry=48")
          {:ok, %{status: 200, body: FileFixtures.signed_url_response(), headers: %{}}}
      end)

      assert {:ok, _signed_url} = Files.get_signed_url("file-abc123", [expiry: 48], client)
    end

    test "validates file_id", %{client: client} do
      assert {:error, %Errors.ValidationError{field: "file_id"}} =
               Files.get_signed_url("", [], client)
    end

    test "handles signed URL errors", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/nonexistent/url")
          {:error, %Errors.NotFoundError{message: "File not found"}}
      end)

      assert {:error, %Errors.NotFoundError{}} = Files.get_signed_url("nonexistent", [], client)
    end
  end

  describe "exists?/2" do
    test "returns true when file exists", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/file-abc123")
          {:ok, %{status: 200, body: FileFixtures.file_response(), headers: %{}}}
      end)

      assert Files.exists?("file-abc123", client) == true
    end

    test "returns false when file does not exist", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "/files/nonexistent")
          {:error, %Errors.NotFoundError{message: "File not found"}}
      end)

      assert Files.exists?("nonexistent", client) == false
    end
  end

  describe "filter_by_purpose/2" do
    test "filters files by purpose" do
      files = [
        %Models.File{id: "file-1", purpose: "fine-tune"},
        %Models.File{id: "file-2", purpose: "assistants"},
        %Models.File{id: "file-3", purpose: "fine-tune"}
      ]

      filtered = Files.filter_by_purpose(files, "fine-tune")
      assert length(filtered) == 2
      assert Enum.all?(filtered, &(&1.purpose == "fine-tune"))
    end
  end

  describe "total_size/1" do
    test "calculates total size of files" do
      files = [
        %Models.File{bytes: 1024},
        %Models.File{bytes: 2048},
        %Models.File{bytes: nil}
      ]

      assert Files.total_size(files) == 3072
    end
  end

  describe "validation functions" do
    test "validate_file_path with valid path", %{client: client} do
      # This is tested implicitly in upload tests
      expect(MistralClient.HttpClientMock, :request, fn
        :post, url, _headers, _body, _options ->
          assert String.ends_with?(url, "/files")
          {:ok, %{status: 200, body: FileFixtures.file_upload_response(), headers: %{}}}
      end)

      assert {:ok, _} = Files.upload(@test_file_path, "fine-tune", [], client)
    end

    test "validate_purpose with valid purposes", %{client: client} do
      valid_purposes = ["fine-tune", "assistants", "batch"]

      for purpose <- valid_purposes do
        expect(MistralClient.HttpClientMock, :request, fn
          :post, url, _headers, _body, _options ->
            assert String.ends_with?(url, "/files")
            {:ok, %{status: 200, body: FileFixtures.file_upload_response(), headers: %{}}}
        end)

        assert {:ok, _} = Files.upload(@test_file_path, purpose, [], client)
      end
    end

    test "validate_file_extension allows non-jsonl for non-fine-tune purposes", %{client: client} do
      txt_file = "/tmp/test.txt"
      File.write!(txt_file, "test content")

      on_exit(fn -> File.rm!(txt_file) end)

      expect(MistralClient.HttpClientMock, :request, fn
        :post, url, _headers, _body, _options ->
          assert String.ends_with?(url, "/files")
          {:ok, %{status: 200, body: FileFixtures.file_upload_response(), headers: %{}}}
      end)

      assert {:ok, _} = Files.upload(txt_file, "assistants", [], client)
    end
  end

  describe "query parameter encoding" do
    test "encodes single values correctly", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "purpose=fine-tune")
          assert String.contains?(url, "page=1")
          {:ok, %{status: 200, body: FileFixtures.file_list_response(), headers: %{}}}
      end)

      assert {:ok, _} = Files.list([purpose: "fine-tune", page: 1], client)
    end

    test "encodes list values correctly", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "sample_type=fine-tuning")
          assert String.contains?(url, "sample_type=embedding")
          {:ok, %{status: 200, body: FileFixtures.file_list_response(), headers: %{}}}
      end)

      assert {:ok, _} = Files.list([sample_type: ["fine-tuning", "embedding"]], client)
    end

    test "filters nil values", %{client: client} do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, url, _headers, _body, _options ->
          assert String.contains?(url, "purpose=fine-tune")
          refute String.contains?(url, "search=")
          {:ok, %{status: 200, body: FileFixtures.file_list_response(), headers: %{}}}
      end)

      assert {:ok, _} = Files.list([purpose: "fine-tune", search: nil], client)
    end
  end
end
