defmodule MistralClient.Test.FileFixtures do
  @moduledoc """
  Test fixtures for Files API responses.
  """

  def file_upload_response do
    %{
      "id" => "file-abc123",
      "object" => "file",
      "bytes" => 1024,
      "created_at" => 1_640_995_200,
      "filename" => "training_data.jsonl",
      "purpose" => "fine-tune"
    }
  end

  def file_response do
    %{
      "id" => "file-abc123",
      "object" => "file",
      "bytes" => 1024,
      "created_at" => 1_640_995_200,
      "filename" => "training_data.jsonl",
      "purpose" => "fine-tune",
      "sample_type" => "fine-tuning",
      "num_lines" => 100,
      "source" => "upload"
    }
  end

  def file_list_response do
    %{
      "object" => "list",
      "data" => [
        file_response(),
        %{
          "id" => "file-def456",
          "object" => "file",
          "bytes" => 2048,
          "created_at" => 1_640_995_300,
          "filename" => "document.pdf",
          "purpose" => "assistants",
          "sample_type" => nil,
          "num_lines" => nil,
          "source" => "upload"
        }
      ],
      "has_more" => false,
      "total" => 2
    }
  end

  def delete_file_response do
    %{
      "id" => "file-abc123",
      "object" => "file",
      "deleted" => true
    }
  end

  def signed_url_response do
    %{
      "signed_url" =>
        "https://storage.googleapis.com/mistral-files/file-abc123?signed=true&expires=1640995200",
      "expires_at" => 1_640_995_200
    }
  end

  def error_response do
    %{
      "error" => %{
        "message" => "File not found",
        "type" => "invalid_request_error",
        "code" => "file_not_found"
      }
    }
  end

  def sample_file_content do
    """
    {"messages": [{"role": "user", "content": "Hello"}, {"role": "assistant", "content": "Hi there!"}]}
    {"messages": [{"role": "user", "content": "How are you?"}, {"role": "assistant", "content": "I'm doing well!"}]}
    """
  end

  def create_test_file(path, content \\ nil) do
    content = content || sample_file_content()
    File.write!(path, content)
    path
  end

  def cleanup_test_file(path) do
    if File.exists?(path) do
      File.rm!(path)
    end
  end
end
