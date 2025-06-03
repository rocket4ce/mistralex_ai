# Configure Mox for testing
Mox.defmock(MistralClient.HttpClientMock, for: MistralClient.Behaviours.HttpClient)

# Set up application configuration for testing
Application.put_env(:mistralex_ai, :http_client, MistralClient.HttpClientMock)
Application.put_env(:mistralex_ai, :api_key, "test-api-key")

# Start ExUnit
ExUnit.start()
