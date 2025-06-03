defmodule MistralClient.Config do
  @moduledoc """
  Configuration management for the Mistral AI client.

  This module handles configuration from multiple sources:
  1. Application configuration
  2. Environment variables
  3. Runtime options

  ## Configuration Options

    * `:api_key` - Mistral API key (required)
    * `:base_url` - Base URL for the API (default: "https://api.mistral.ai")
    * `:timeout` - Request timeout in milliseconds (default: 30_000)
    * `:max_retries` - Maximum number of retries (default: 3)
    * `:retry_delay` - Base delay between retries in milliseconds (default: 1_000)
    * `:user_agent` - User agent string (default: "mistral-client-elixir/0.1.0")

  ## Configuration Sources

  ### Application Configuration

      config :mistral_client,
        api_key: "your-api-key",
        base_url: "https://api.mistral.ai",
        timeout: 30_000

  ### Environment Variables

      export MISTRAL_API_KEY="your-api-key"
      export MISTRAL_BASE_URL="https://api.mistral.ai"
      export MISTRAL_TIMEOUT="30000"

  ### Runtime Options

      config = MistralClient.Config.new(api_key: "runtime-key")
  """

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          timeout: integer(),
          max_retries: integer(),
          retry_delay: integer(),
          user_agent: String.t()
        }

  defstruct [
    :api_key,
    base_url: "https://api.mistral.ai",
    timeout: 30_000,
    max_retries: 3,
    retry_delay: 1_000,
    user_agent: "mistral-client-elixir/0.1.0"
  ]

  @doc """
  Get the current configuration.

  Merges configuration from application config and environment variables.

  ## Examples

      config = MistralClient.Config.get()
      %MistralClient.Config{api_key: "your-key", ...}
  """
  @spec get() :: t()
  def get do
    new()
  end

  @doc """
  Create a new configuration with optional overrides.

  ## Parameters

    * `options` - Keyword list of configuration options

  ## Examples

      config = MistralClient.Config.new(api_key: "custom-key")
      config = MistralClient.Config.new(timeout: 60_000, max_retries: 5)
  """
  @spec new(keyword()) :: t()
  def new(options \\ []) do
    base_config = %__MODULE__{
      api_key: get_api_key(),
      base_url: get_base_url(),
      timeout: get_timeout(),
      max_retries: get_max_retries(),
      retry_delay: get_retry_delay(),
      user_agent: get_user_agent()
    }

    struct(base_config, options)
  end

  @doc """
  Validate the configuration.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      :ok = MistralClient.Config.validate(config)
      {:error, "API key is required"} = MistralClient.Config.validate(%Config{api_key: nil})
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = config) do
    cond do
      is_nil(config.api_key) or config.api_key == "" ->
        {:error, "API key is required"}

      not is_binary(config.base_url) or config.base_url == "" ->
        {:error, "Base URL must be a non-empty string"}

      not is_integer(config.timeout) or config.timeout <= 0 ->
        {:error, "Timeout must be a positive integer"}

      not is_integer(config.max_retries) or config.max_retries < 0 ->
        {:error, "Max retries must be a non-negative integer"}

      not is_integer(config.retry_delay) or config.retry_delay < 0 ->
        {:error, "Retry delay must be a non-negative integer"}

      true ->
        :ok
    end
  end

  @doc """
  Get the API key from configuration sources.

  Checks in order:
  1. Application configuration
  2. MISTRAL_API_KEY environment variable

  ## Examples

      "your-api-key" = MistralClient.Config.get_api_key()
  """
  @spec get_api_key() :: String.t() | nil
  def get_api_key do
    Application.get_env(:mistral_client, :api_key) ||
      System.get_env("MISTRAL_API_KEY")
  end

  @doc """
  Get the base URL from configuration sources.

  ## Examples

      "https://api.mistral.ai" = MistralClient.Config.get_base_url()
  """
  @spec get_base_url() :: String.t()
  def get_base_url do
    Application.get_env(:mistral_client, :base_url) ||
      System.get_env("MISTRAL_BASE_URL") ||
      "https://api.mistral.ai"
  end

  @doc """
  Get the timeout from configuration sources.

  ## Examples

      30_000 = MistralClient.Config.get_timeout()
  """
  @spec get_timeout() :: integer()
  def get_timeout do
    case Application.get_env(:mistral_client, :timeout) ||
           System.get_env("MISTRAL_TIMEOUT") do
      nil -> 30_000
      timeout when is_integer(timeout) -> timeout
      timeout when is_binary(timeout) -> String.to_integer(timeout)
    end
  end

  @doc """
  Get the maximum retries from configuration sources.

  ## Examples

      3 = MistralClient.Config.get_max_retries()
  """
  @spec get_max_retries() :: integer()
  def get_max_retries do
    case Application.get_env(:mistral_client, :max_retries) ||
           System.get_env("MISTRAL_MAX_RETRIES") do
      nil -> 3
      retries when is_integer(retries) -> retries
      retries when is_binary(retries) -> String.to_integer(retries)
    end
  end

  @doc """
  Get the retry delay from configuration sources.

  ## Examples

      1_000 = MistralClient.Config.get_retry_delay()
  """
  @spec get_retry_delay() :: integer()
  def get_retry_delay do
    case Application.get_env(:mistral_client, :retry_delay) ||
           System.get_env("MISTRAL_RETRY_DELAY") do
      nil -> 1_000
      delay when is_integer(delay) -> delay
      delay when is_binary(delay) -> String.to_integer(delay)
    end
  end

  @doc """
  Get the user agent from configuration sources.

  ## Examples

      "mistral-client-elixir/0.1.0" = MistralClient.Config.get_user_agent()
  """
  @spec get_user_agent() :: String.t()
  def get_user_agent do
    Application.get_env(:mistral_client, :user_agent) ||
      System.get_env("MISTRAL_USER_AGENT") ||
      "mistral-client-elixir/0.1.0"
  end
end
