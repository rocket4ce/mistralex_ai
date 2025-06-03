defmodule MistralClient.API.OCR do
  @moduledoc """
  OCR (Optical Character Recognition) API operations.

  This module provides functionality for processing documents and images
  using Mistral's OCR capabilities, extracting text and structured data
  from various document formats.

  ## Features

    * Document URL processing
    * Image URL processing
    * Page-specific processing
    * Image extraction with base64 encoding
    * Structured annotation formats
    * Bounding box annotations

  ## Usage

      # Process a document URL
      document = MistralClient.Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = MistralClient.Models.OCRRequest.new("pixtral-12b-2024-12-19", document)

      {:ok, response} = MistralClient.API.OCR.process(config, request)

      # Process an image URL
      image_url = MistralClient.Models.ImageURLChunkImageURL.new("data:image/png;base64,...")
      image_chunk = MistralClient.Models.ImageURLChunk.new(image_url)
      request = MistralClient.Models.OCRRequest.new("pixtral-12b-2024-12-19", image_chunk)

      {:ok, response} = MistralClient.API.OCR.process(config, request)

      # Process specific pages with options
      document = MistralClient.Models.DocumentURLChunk.new("https://example.com/document.pdf")
      request = MistralClient.Models.OCRRequest.new("pixtral-12b-2024-12-19", document,
        pages: [0, 1, 2],
        include_image_base64: true,
        image_limit: 10
      )

      {:ok, response} = MistralClient.API.OCR.process(config, request)
  """

  alias MistralClient.{Client, Config, Models}

  @doc """
  Process a document or image using OCR.

  ## Parameters

    * `config` - Client configuration
    * `request` - OCR request with model, document, and options

  ## Options

    * `:id` - Request identifier
    * `:pages` - List of specific page numbers to process (0-indexed)
    * `:include_image_base64` - Include base64-encoded images in response
    * `:image_limit` - Maximum number of images to extract
    * `:image_min_size` - Minimum size (height and width) for image extraction
    * `:bbox_annotation_format` - Structured output format for bounding boxes
    * `:document_annotation_format` - Structured output format for the document

  ## Returns

    * `{:ok, OCRResponse.t()}` - Successful OCR processing
    * `{:error, term()}` - Error occurred during processing

  ## Examples

      # Basic document processing
      document = MistralClient.Models.DocumentURLChunk.new("https://example.com/doc.pdf")
      request = MistralClient.Models.OCRRequest.new("pixtral-12b-2024-12-19", document)
      {:ok, response} = MistralClient.API.OCR.process(config, request)

      # Image processing with options
      image_url = MistralClient.Models.ImageURLChunkImageURL.new("data:image/png;base64,...")
      image_chunk = MistralClient.Models.ImageURLChunk.new(image_url)
      request = MistralClient.Models.OCRRequest.new("pixtral-12b-2024-12-19", image_chunk,
        include_image_base64: true,
        image_limit: 5
      )
      {:ok, response} = MistralClient.API.OCR.process(config, request)
  """
  @spec process(Config.t(), Models.OCRRequest.t()) ::
          {:ok, Models.OCRResponse.t()} | {:error, term()}
  def process(%Config{} = config, %Models.OCRRequest{} = request) do
    with :ok <- validate_request(request),
         body <- Models.OCRRequest.to_map(request),
         client <- Client.new(config),
         {:ok, response} <- Client.request(client, :post, "/ocr", body) do
      {:ok, Models.OCRResponse.from_map(response)}
    end
  end

  @doc """
  Process a document or image using OCR with direct parameters.

  This is a convenience function that creates an OCRRequest internally.

  ## Parameters

    * `config` - Client configuration
    * `model` - Model to use for OCR processing
    * `document` - Document or image to process
    * `opts` - Additional options (see `process/2` for details)

  ## Examples

      # Process document URL
      document = MistralClient.Models.DocumentURLChunk.new("https://example.com/doc.pdf")
      {:ok, response} = MistralClient.API.OCR.process(config, "pixtral-12b-2024-12-19", document)

      # Process with options
      {:ok, response} = MistralClient.API.OCR.process(
        config,
        "pixtral-12b-2024-12-19",
        document,
        pages: [0, 1],
        include_image_base64: true
      )
  """
  @spec process(Config.t(), String.t(), Models.OCRRequest.document_type(), keyword()) ::
          {:ok, Models.OCRResponse.t()} | {:error, term()}
  def process(%Config{} = config, model, document, opts \\ []) when is_binary(model) do
    request = Models.OCRRequest.new(model, document, opts)
    process(config, request)
  end

  # Private functions

  defp validate_request(%Models.OCRRequest{model: model, document: document}) do
    cond do
      is_nil(model) or model == "" ->
        {:error, "Model is required"}

      is_nil(document) ->
        {:error, "Document is required"}

      not valid_document?(document) ->
        {:error, "Document must be a DocumentURLChunk or ImageURLChunk"}

      true ->
        :ok
    end
  end

  defp valid_document?(%Models.DocumentURLChunk{}), do: true
  defp valid_document?(%Models.ImageURLChunk{}), do: true
  defp valid_document?(_), do: false
end
