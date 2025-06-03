# Configure Mox for testing
Mox.defmock(MistralClient.HttpClientMock, for: MistralClient.Behaviours.HttpClient)

# Set up application configuration for testing
Application.put_env(:mistral_client, :http_client, MistralClient.HttpClientMock)
Application.put_env(:mistral_client, :api_key, "test-api-key")

# Start ExUnit
ExUnit.start()
