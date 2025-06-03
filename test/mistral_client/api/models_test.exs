defmodule MistralClient.API.ModelsTest do
  use ExUnit.Case, async: true
  import Mox

  alias MistralClient.API.Models
  alias MistralClient.{Client, Errors}
  alias MistralClient.Test.ModelFixtures
  import MistralClient.Test.TestHelpers

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "list/1" do
    test "successfully lists models" do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_list_success()
      end)

      client = Client.new(test_config())
      assert {:ok, model_list} = Models.list(client)
      assert %MistralClient.Models.ModelList{} = model_list
      assert model_list.object == "list"
      assert length(model_list.data) == 2

      # Check first model (base model)
      [base_model, ft_model] = model_list.data
      assert %MistralClient.Models.BaseModelCard{} = base_model
      assert base_model.id == "mistral-large-latest"
      assert base_model.owned_by == "mistralai"

      # Check second model (fine-tuned model)
      assert %MistralClient.Models.FTModelCard{} = ft_model
      assert ft_model.id == "ft:open-mistral-7b:587a6b29:20240514:7e773925"
      assert ft_model.job == "ftjob-abc123"
      assert ft_model.root == "open-mistral-7b"
    end

    test "handles server errors" do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_server_error()
      end)

      client = Client.new(test_config())
      assert {:error, %Errors.ServerError{}} = Models.list(client)
    end

    test "handles unauthorized errors" do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_unauthorized_error()
      end)

      client = Client.new(test_config())
      assert {:error, %Errors.AuthenticationError{}} = Models.list(client)
    end
  end

  describe "retrieve/2" do
    test "successfully retrieves a base model" do
      model_id = "mistral-large-latest"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_retrieve_base_model_success()
      end)

      client = Client.new(test_config())
      assert {:ok, model} = Models.retrieve(model_id, client)
      assert %MistralClient.Models.BaseModelCard{} = model
      assert model.id == model_id
      assert model.owned_by == "mistralai"
      assert model.capabilities.completion_chat == true
      assert model.capabilities.vision == true
    end

    test "successfully retrieves a fine-tuned model" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_retrieve_ft_model_success()
      end)

      client = Client.new(test_config())
      assert {:ok, model} = Models.retrieve(model_id, client)
      assert %MistralClient.Models.FTModelCard{} = model
      assert model.id == model_id
      assert model.job == "ftjob-abc123"
      assert model.root == "open-mistral-7b"
      assert model.archived == false
    end

    test "handles model not found" do
      model_id = "non-existent-model"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_not_found_error()
      end)

      client = Client.new(test_config())
      assert {:error, %Errors.NotFoundError{}} = Models.retrieve(model_id, client)
    end

    test "validates model ID" do
      client = Client.new(test_config())
      assert {:error, %Errors.ValidationError{}} = Models.retrieve("", client)
      assert {:error, %Errors.ValidationError{}} = Models.retrieve(nil, client)
    end
  end

  describe "delete/2" do
    test "successfully deletes a fine-tuned model" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      expect(MistralClient.HttpClientMock, :request, fn
        :delete, _url, _headers, _body, _options ->
          ModelFixtures.mock_delete_success()
      end)

      client = Client.new(test_config())
      assert {:ok, delete_result} = Models.delete(model_id, client)
      assert %MistralClient.Models.DeleteModelOut{} = delete_result
      assert delete_result.id == model_id
      assert delete_result.deleted == true
    end

    test "handles permission denied" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      expect(MistralClient.HttpClientMock, :request, fn
        :delete, _url, _headers, _body, _options ->
          ModelFixtures.mock_permission_denied_error()
      end)

      client = Client.new(test_config())
      assert {:error, %Errors.PermissionError{}} = Models.delete(model_id, client)
    end

    test "validates model ID" do
      client = Client.new(test_config())
      assert {:error, %Errors.ValidationError{}} = Models.delete("", client)
    end
  end

  describe "update/3" do
    test "successfully updates a model" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"
      updates = %{name: "Updated Model Name", description: "Updated description"}

      expect(MistralClient.HttpClientMock, :request, fn
        :patch, _url, _headers, body, _options ->
          parsed_body = Jason.decode!(body)
          assert parsed_body["name"] == "Updated Model Name"
          assert parsed_body["description"] == "Updated description"
          ModelFixtures.mock_update_success()
      end)

      client = Client.new(test_config())
      assert {:ok, model} = Models.update(model_id, updates, client)
      assert %MistralClient.Models.FTModelCard{} = model
      assert model.name == "Updated Model Name"
      assert model.description == "Updated description for the model"
    end

    test "validates update fields" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      client = Client.new(test_config())

      # Empty updates
      assert {:error, %Errors.ValidationError{}} = Models.update(model_id, %{}, client)

      # Invalid name
      assert {:error, %Errors.ValidationError{}} = Models.update(model_id, %{name: ""}, client)
      assert {:error, %Errors.ValidationError{}} = Models.update(model_id, %{name: 123}, client)

      # Invalid description
      assert {:error, %Errors.ValidationError{}} =
               Models.update(model_id, %{description: 123}, client)

      # Invalid metadata
      assert {:error, %Errors.ValidationError{}} =
               Models.update(model_id, %{metadata: "invalid"}, client)
    end

    test "filters allowed fields" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      updates = %{
        name: "Valid Name",
        invalid_field: "should be filtered",
        description: "Valid Description"
      }

      expect(MistralClient.HttpClientMock, :request, fn
        :patch, _url, _headers, body, _options ->
          parsed_body = Jason.decode!(body)
          assert parsed_body["name"] == "Valid Name"
          assert parsed_body["description"] == "Valid Description"
          refute Map.has_key?(parsed_body, "invalid_field")
          ModelFixtures.mock_update_success()
      end)

      client = Client.new(test_config())
      assert {:ok, _model} = Models.update(model_id, updates, client)
    end
  end

  describe "archive/2" do
    test "successfully archives a model" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      expect(MistralClient.HttpClientMock, :request, fn
        :post, _url, _headers, _body, _options ->
          ModelFixtures.mock_archive_success()
      end)

      client = Client.new(test_config())
      assert {:ok, archive_result} = Models.archive(model_id, client)
      assert %MistralClient.Models.ArchiveFTModelOut{} = archive_result
      assert archive_result.id == model_id
      assert archive_result.archived == true
    end

    test "validates model ID" do
      client = Client.new(test_config())
      assert {:error, %Errors.ValidationError{}} = Models.archive("", client)
    end
  end

  describe "unarchive/2" do
    test "successfully unarchives a model" do
      model_id = "ft:open-mistral-7b:587a6b29:20240514:7e773925"

      expect(MistralClient.HttpClientMock, :request, fn
        :post, _url, _headers, _body, _options ->
          ModelFixtures.mock_unarchive_success()
      end)

      client = Client.new(test_config())
      assert {:ok, unarchive_result} = Models.unarchive(model_id, client)
      assert %MistralClient.Models.UnarchiveFTModelOut{} = unarchive_result
      assert unarchive_result.id == model_id
      assert unarchive_result.archived == false
    end

    test "validates model ID" do
      client = Client.new(test_config())
      assert {:error, %Errors.ValidationError{}} = Models.unarchive("", client)
    end
  end

  describe "exists?/2" do
    test "returns true when model exists" do
      model_id = "mistral-large-latest"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_retrieve_base_model_success()
      end)

      client = Client.new(test_config())
      assert Models.exists?(model_id, client) == true
    end

    test "returns false when model not found" do
      model_id = "non-existent-model"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_not_found_error()
      end)

      client = Client.new(test_config())
      assert Models.exists?(model_id, client) == false
    end

    test "returns false on other errors" do
      model_id = "some-model"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_server_error()
      end)

      client = Client.new(test_config())
      assert Models.exists?(model_id, client) == false
    end
  end

  describe "filter_models/2" do
    setup do
      base_model = ModelFixtures.create_base_model_card()
      ft_model = ModelFixtures.create_ft_model_card()
      models = [base_model, ft_model]
      {:ok, models: models, base_model: base_model, ft_model: ft_model}
    end

    test "filters base models", %{models: models, base_model: base_model} do
      result = Models.filter_models(models, :base)
      assert length(result) == 1
      assert hd(result) == base_model
    end

    test "filters fine-tuned models", %{models: models, ft_model: ft_model} do
      result = Models.filter_models(models, :fine_tuned)
      assert length(result) == 1
      assert hd(result) == ft_model
    end

    test "filters owned models", %{models: models, ft_model: ft_model} do
      result = Models.filter_models(models, :owned)
      assert length(result) == 1
      assert hd(result) == ft_model
    end

    test "returns all models for unknown filter", %{models: models} do
      result = Models.filter_models(models, :unknown)
      assert length(result) == 2
      assert result == models
    end
  end

  describe "with custom client" do
    test "uses provided client for requests" do
      custom_client = Client.new(api_key: "custom-key")
      model_id = "mistral-large-latest"

      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_retrieve_base_model_success()
      end)

      assert {:ok, _model} = Models.retrieve(model_id, custom_client)
    end
  end

  describe "error handling" do
    test "handles rate limit errors" do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_rate_limit_error()
      end)

      client = Client.new(test_config())
      assert {:error, %Errors.RateLimitError{}} = Models.list(client)
    end

    test "handles validation errors" do
      expect(MistralClient.HttpClientMock, :request, fn
        :get, _url, _headers, _body, _options ->
          ModelFixtures.mock_validation_error()
      end)

      client = Client.new(test_config())
      assert {:error, %Errors.ValidationError{}} = Models.retrieve("invalid-id", client)
    end
  end
end
