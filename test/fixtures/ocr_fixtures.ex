defmodule MistralClient.Test.OCRFixtures do
  @moduledoc """
  Test fixtures for OCR API testing.
  """

  def document_url_chunk_fixture do
    %{
      "document_url" => "https://example.com/document.pdf",
      "document_name" => "sample_document.pdf",
      "type" => "document_url"
    }
  end

  def image_url_chunk_fixture do
    %{
      "image_url" => %{
        "url" =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
      },
      "type" => "image_url"
    }
  end

  def ocr_request_fixture do
    %{
      "model" => "pixtral-12b-2024-12-19",
      "document" => document_url_chunk_fixture(),
      "id" => "ocr-request-123",
      "pages" => [0, 1, 2],
      "include_image_base64" => true,
      "image_limit" => 10,
      "image_min_size" => 100
    }
  end

  def ocr_page_dimensions_fixture do
    %{
      "dpi" => 300,
      "height" => 1200,
      "width" => 800
    }
  end

  def ocr_image_object_fixture do
    %{
      "id" => "img-001",
      "top_left_x" => 100,
      "top_left_y" => 200,
      "bottom_right_x" => 300,
      "bottom_right_y" => 400,
      "image_base64" =>
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
      "image_annotation" => "{\"description\": \"A sample image\"}"
    }
  end

  def ocr_page_object_fixture do
    %{
      "index" => 0,
      "markdown" => "# Sample Document\n\nThis is a sample document with some text content.",
      "images" => [ocr_image_object_fixture()],
      "dimensions" => ocr_page_dimensions_fixture()
    }
  end

  def ocr_usage_info_fixture do
    %{
      "pages_processed" => 3,
      "doc_size_bytes" => 1_024_000
    }
  end

  def ocr_response_fixture do
    %{
      "pages" => [
        ocr_page_object_fixture(),
        %{
          "index" => 1,
          "markdown" => "## Page 2\n\nMore content on the second page.",
          "images" => [],
          "dimensions" => ocr_page_dimensions_fixture()
        },
        %{
          "index" => 2,
          "markdown" => "## Page 3\n\nFinal page content.",
          "images" => [
            %{
              "id" => "img-002",
              "top_left_x" => 50,
              "top_left_y" => 100,
              "bottom_right_x" => 250,
              "bottom_right_y" => 300,
              "image_base64" => nil,
              "image_annotation" => nil
            }
          ],
          "dimensions" => ocr_page_dimensions_fixture()
        }
      ],
      "model" => "pixtral-12b-2024-12-19",
      "usage_info" => ocr_usage_info_fixture(),
      "document_annotation" => "{\"title\": \"Sample Document\", \"pages\": 3}"
    }
  end

  def ocr_error_response_fixture do
    %{
      "detail" => [
        %{
          "loc" => ["body", "model"],
          "msg" => "field required",
          "type" => "value_error.missing"
        }
      ]
    }
  end

  def ocr_validation_error_fixture do
    %{
      "detail" => [
        %{
          "loc" => ["body", "document", "document_url"],
          "msg" => "invalid url format",
          "type" => "value_error.url"
        }
      ]
    }
  end

  def ocr_server_error_fixture do
    %{
      "message" => "Internal server error occurred during OCR processing",
      "error" => "server_error"
    }
  end

  def ocr_rate_limit_error_fixture do
    %{
      "message" => "Rate limit exceeded. Please try again later.",
      "error" => "rate_limit_exceeded"
    }
  end

  # Minimal fixtures for testing edge cases
  def minimal_ocr_request_fixture do
    %{
      "model" => "pixtral-12b-2024-12-19",
      "document" => %{
        "document_url" => "https://example.com/simple.pdf",
        "type" => "document_url"
      }
    }
  end

  def minimal_ocr_response_fixture do
    %{
      "pages" => [
        %{
          "index" => 0,
          "markdown" => "Simple text content.",
          "images" => [],
          "dimensions" => nil
        }
      ],
      "model" => "pixtral-12b-2024-12-19",
      "usage_info" => %{
        "pages_processed" => 1,
        "doc_size_bytes" => nil
      },
      "document_annotation" => nil
    }
  end

  # Image-based fixtures
  def image_ocr_request_fixture do
    %{
      "model" => "pixtral-12b-2024-12-19",
      "document" => image_url_chunk_fixture(),
      "include_image_base64" => false,
      "image_limit" => 5
    }
  end

  def image_ocr_response_fixture do
    %{
      "pages" => [
        %{
          "index" => 0,
          "markdown" => "Text extracted from image.",
          "images" => [
            %{
              "id" => "img-001",
              "top_left_x" => 0,
              "top_left_y" => 0,
              "bottom_right_x" => 100,
              "bottom_right_y" => 100,
              "image_base64" => nil,
              "image_annotation" => nil
            }
          ],
          "dimensions" => %{
            "dpi" => 72,
            "height" => 100,
            "width" => 100
          }
        }
      ],
      "model" => "pixtral-12b-2024-12-19",
      "usage_info" => %{
        "pages_processed" => 1,
        "doc_size_bytes" => 2048
      },
      "document_annotation" => nil
    }
  end

  # Structured annotation fixtures
  def structured_annotation_request_fixture do
    %{
      "model" => "pixtral-12b-2024-12-19",
      "document" => document_url_chunk_fixture(),
      "bbox_annotation_format" => %{
        "type" => "json_schema",
        "json_schema" => %{
          "name" => "BoundingBoxInfo",
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "description" => %{"type" => "string"},
              "confidence" => %{"type" => "number"}
            }
          }
        }
      },
      "document_annotation_format" => %{
        "type" => "json_schema",
        "json_schema" => %{
          "name" => "DocumentInfo",
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string"},
              "summary" => %{"type" => "string"},
              "page_count" => %{"type" => "integer"}
            }
          }
        }
      }
    }
  end

  def structured_annotation_response_fixture do
    %{
      "pages" => [
        %{
          "index" => 0,
          "markdown" => "# Document Title\n\nDocument content here.",
          "images" => [
            %{
              "id" => "img-001",
              "top_left_x" => 100,
              "top_left_y" => 200,
              "bottom_right_x" => 300,
              "bottom_right_y" => 400,
              "image_base64" => nil,
              "image_annotation" =>
                "{\"description\": \"Chart showing quarterly results\", \"confidence\": 0.95}"
            }
          ],
          "dimensions" => ocr_page_dimensions_fixture()
        }
      ],
      "model" => "pixtral-12b-2024-12-19",
      "usage_info" => ocr_usage_info_fixture(),
      "document_annotation" =>
        "{\"title\": \"Quarterly Report\", \"summary\": \"Financial results for Q3\", \"page_count\": 1}"
    }
  end
end
