defmodule MistralClient.API.OCRTest do
  use ExUnit.Case, async: true

  import Mox
  import MistralClient.Test.OCRFixtures

  alias MistralClient.{Config, Models}
  alias MistralClient.API.OCR
  alias MistralClient.Test.TestHelpers

  setup :verify_on_exit!

  setup do
    # Create a test client with mock HTTP client
    client = TestHelpers.mock_client()
    config = Config.new(api_key: "test-key")
    {:ok, client: client, config: config}
  end

  describe "process/2 with OCRRequest struct" do
    test "successfully processes document URL", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["model"] == "pixtral-12b-2024-12-19"
        assert decoded_body["document"]["document_url"] == "https://example.com/document.pdf"
        assert decoded_body["document"]["type"] == "document_url"

        {:ok, %{status: 200, body: Jason.encode!(ocr_response_fixture())}}
      end)

      assert {:ok, response} = OCR.process(config, request)
      assert %Models.OCRResponse{} = response
      assert response.model == "pixtral-12b-2024-12-19"
      assert length(response.pages) == 3
      assert response.usage_info.pages_processed == 3
    end

    test "successfully processes image URL", %{config: config} do
      image_url = Models.ImageURLChunkImageURL.new("data:image/png;base64,...")
      image_chunk = Models.ImageURLChunk.new(image_url)
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", image_chunk)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["model"] == "pixtral-12b-2024-12-19"
        assert decoded_body["document"]["image_url"]["url"] == "data:image/png;base64,..."
        assert decoded_body["document"]["type"] == "image_url"

        {:ok, %{status: 200, body: Jason.encode!(image_ocr_response_fixture())}}
      end)

      assert {:ok, response} = OCR.process(config, request)
      assert %Models.OCRResponse{} = response
      assert response.model == "pixtral-12b-2024-12-19"
      assert length(response.pages) == 1
    end

    test "processes with all optional parameters", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")

      request =
        Models.OCRRequest.new("pixtral-12b-2024-12-19", document,
          id: "test-id",
          pages: [0, 1],
          include_image_base64: true,
          image_limit: 5,
          image_min_size: 100,
          bbox_annotation_format: %{"type" => "json_schema"},
          document_annotation_format: %{"type" => "json_schema"}
        )

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["id"] == "test-id"
        assert decoded_body["pages"] == [0, 1]
        assert decoded_body["include_image_base64"] == true
        assert decoded_body["image_limit"] == 5
        assert decoded_body["image_min_size"] == 100
        assert decoded_body["bbox_annotation_format"]["type"] == "json_schema"
        assert decoded_body["document_annotation_format"]["type"] == "json_schema"

        {:ok, %{status: 200, body: Jason.encode!(structured_annotation_response_fixture())}}
      end)

      assert {:ok, response} = OCR.process(config, request)
      assert %Models.OCRResponse{} = response
      assert response.document_annotation != nil
    end

    test "returns error for missing model" do
      config = Config.new(api_key: "test-key")
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = %Models.OCRRequest{model: nil, document: document}

      assert {:error, "Model is required"} = OCR.process(config, request)
    end

    test "returns error for missing document" do
      config = Config.new(api_key: "test-key")
      request = %Models.OCRRequest{model: "pixtral-12b-2024-12-19", document: nil}

      assert {:error, "Document is required"} = OCR.process(config, request)
    end

    test "returns error for invalid document type" do
      config = Config.new(api_key: "test-key")
      request = %Models.OCRRequest{model: "pixtral-12b-2024-12-19", document: "invalid"}

      assert {:error, "Document must be a DocumentURLChunk or ImageURLChunk"} =
               OCR.process(config, request)
    end
  end

  describe "process/4 with direct parameters" do
    test "successfully processes with model, document, and options", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["model"] == "pixtral-12b-2024-12-19"
        assert decoded_body["pages"] == [0, 1]
        assert decoded_body["include_image_base64"] == true

        {:ok, %{status: 200, body: Jason.encode!(ocr_response_fixture())}}
      end)

      assert {:ok, response} =
               OCR.process(config, "pixtral-12b-2024-12-19", document,
                 pages: [0, 1],
                 include_image_base64: true
               )

      assert %Models.OCRResponse{} = response
      assert response.model == "pixtral-12b-2024-12-19"
    end

    test "works with minimal parameters", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/simple.pdf")

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["model"] == "pixtral-12b-2024-12-19"
        assert decoded_body["document"]["document_url"] == "https://example.com/simple.pdf"
        refute Map.has_key?(decoded_body, "pages")
        refute Map.has_key?(decoded_body, "include_image_base64")

        {:ok, %{status: 200, body: Jason.encode!(minimal_ocr_response_fixture())}}
      end)

      assert {:ok, response} = OCR.process(config, "pixtral-12b-2024-12-19", document)
      assert %Models.OCRResponse{} = response
    end
  end

  describe "error handling" do
    test "handles 422 validation errors", %{config: config} do
      document = Models.DocumentURLChunk.new("invalid-url")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 422, body: Jason.encode!(ocr_validation_error_fixture())}}
      end)

      assert {:error, %MistralClient.Errors.ValidationError{}} = OCR.process(config, request)
    end

    test "handles 500 server errors", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 500, body: Jason.encode!(ocr_server_error_fixture())}}
      end)

      assert {:error, %MistralClient.Errors.ServerError{}} = OCR.process(config, request)
    end

    test "handles 429 rate limit errors", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 429, body: Jason.encode!(ocr_rate_limit_error_fixture())}}
      end)

      assert {:error, %MistralClient.Errors.RateLimitError{}} = OCR.process(config, request)
    end

    test "handles network errors", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:error, :timeout}
      end)

      assert {:error, %MistralClient.Errors.NetworkError{}} = OCR.process(config, request)
    end
  end

  describe "model parsing" do
    test "correctly parses OCR response with all fields", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!(ocr_response_fixture())}}
      end)

      assert {:ok, response} = OCR.process(config, request)

      # Test main response structure
      assert %Models.OCRResponse{} = response
      assert response.model == "pixtral-12b-2024-12-19"
      assert response.document_annotation == "{\"title\": \"Sample Document\", \"pages\": 3}"

      # Test usage info
      assert %Models.OCRUsageInfo{} = response.usage_info
      assert response.usage_info.pages_processed == 3
      assert response.usage_info.doc_size_bytes == 1_024_000

      # Test pages
      assert length(response.pages) == 3
      [page1, page2, page3] = response.pages

      # Test first page
      assert %Models.OCRPageObject{} = page1
      assert page1.index == 0
      assert page1.markdown =~ "Sample Document"
      assert length(page1.images) == 1
      assert %Models.OCRPageDimensions{} = page1.dimensions
      assert page1.dimensions.dpi == 300

      # Test image object
      [image] = page1.images
      assert %Models.OCRImageObject{} = image
      assert image.id == "img-001"
      assert image.top_left_x == 100
      assert image.image_annotation == "{\"description\": \"A sample image\"}"

      # Test second page (no images)
      assert page2.index == 1
      assert page2.images == []

      # Test third page (image without base64)
      assert page3.index == 2
      assert length(page3.images) == 1
      [image3] = page3.images
      assert image3.image_base64 == nil
    end

    test "correctly parses minimal OCR response", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/simple.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, %{status: 200, body: Jason.encode!(minimal_ocr_response_fixture())}}
      end)

      assert {:ok, response} = OCR.process(config, request)

      assert %Models.OCRResponse{} = response
      assert response.document_annotation == nil
      assert response.usage_info.doc_size_bytes == nil

      [page] = response.pages
      assert page.dimensions == nil
      assert page.images == []
    end
  end

  describe "request serialization" do
    test "correctly serializes DocumentURLChunk", %{config: config} do
      document =
        Models.DocumentURLChunk.new("https://example.com/doc.pdf",
          document_name: "test.pdf"
        )

      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["document"]["document_url"] == "https://example.com/doc.pdf"
        assert decoded_body["document"]["document_name"] == "test.pdf"
        assert decoded_body["document"]["type"] == "document_url"

        {:ok, %{status: 200, body: Jason.encode!(minimal_ocr_response_fixture())}}
      end)

      assert {:ok, _response} = OCR.process(config, request)
    end

    test "correctly serializes ImageURLChunk", %{config: config} do
      image_url = Models.ImageURLChunkImageURL.new("data:image/png;base64,test")
      image_chunk = Models.ImageURLChunk.new(image_url)
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", image_chunk)

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["document"]["image_url"]["url"] == "data:image/png;base64,test"
        assert decoded_body["document"]["type"] == "image_url"

        {:ok, %{status: 200, body: Jason.encode!(minimal_ocr_response_fixture())}}
      end)

      assert {:ok, _response} = OCR.process(config, request)
    end

    test "omits nil values from request", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/doc.pdf")

      request =
        Models.OCRRequest.new("pixtral-12b-2024-12-19", document,
          pages: [0, 1],
          include_image_base64: nil,
          image_limit: nil
        )

      expect(MistralClient.HttpClientMock, :request, fn :post, _url, _headers, body, _opts ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["pages"] == [0, 1]
        refute Map.has_key?(decoded_body, "include_image_base64")
        refute Map.has_key?(decoded_body, "image_limit")

        {:ok, %{status: 200, body: Jason.encode!(minimal_ocr_response_fixture())}}
      end)

      assert {:ok, _response} = OCR.process(config, request)
    end
  end

  describe "HTTP client integration" do
    test "makes request to correct endpoint", %{config: config} do
      document = Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      expect(MistralClient.HttpClientMock, :request, fn :post, url, headers, _body, _opts ->
        assert String.ends_with?(url, "/v1/ocr")
        assert {"authorization", "Bearer test-key"} in headers
        assert {"content-type", "application/json"} in headers

        {:ok, %{status: 200, body: Jason.encode!(minimal_ocr_response_fixture())}}
      end)

      assert {:ok, _response} = OCR.process(config, request)
    end
  end
end
