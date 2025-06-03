defmodule MistralClient.Test.Mocks do
  @moduledoc """
  Mock definitions for testing the Mistral SDK.

  This module defines all the Mox mocks used throughout the test suite.
  """

  import Mox

  # Define the HTTP client mock
  defmock(MistralClient.Test.MockHttpClient, for: MistralClient.Behaviours.HttpClient)

  @doc """
  Sets up mocks for testing.

  This function should be called in test_helper.exs to configure
  the application to use mocks during testing.
  """
  def setup_mocks do
    # Configure the application to use the mock HTTP client
    Application.put_env(:mistralex_ai, :http_client, MistralClient.Test.MockHttpClient)

    # Set Mox to verify mocks on exit
    Mox.defmock(MistralClient.Test.MockHttpClient, for: MistralClient.Behaviours.HttpClient)
  end

  @doc """
  Verifies that all mocks have been called as expected.

  This should be called in test setup to ensure mocks are verified.
  """
  def verify_mocks do
    verify_on_exit!()
  end
end
