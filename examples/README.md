# Mistral SDK Examples

This directory contains practical examples demonstrating how to use the Mistral SDK for Elixir in real-world scenarios.

## Table of Contents

- [Basic Examples](#basic-examples)
- [Advanced Examples](#advanced-examples)
- [Integration Examples](#integration-examples)
- [Production Examples](#production-examples)

## Basic Examples

### [basic_chat.exs](basic_chat.exs)
Simple chat completion with error handling and configuration.

### [streaming_chat.exs](streaming_chat.exs)
Real-time streaming chat responses with callback handling.

### [embeddings_similarity.exs](embeddings_similarity.exs)
Text embeddings and similarity search implementation.

### [function_calling.exs](function_calling.exs)
Function calling (tools) with weather and search examples.

## Advanced Examples

### [fine_tuning_workflow.exs](fine_tuning_workflow.exs)
Complete fine-tuning workflow from data preparation to model deployment.

### [conversation_manager.exs](conversation_manager.exs)
GenServer-based conversation management with history and context.

### [batch_processing.exs](batch_processing.exs)
Efficient batch processing for large datasets.

### [model_comparison.exs](model_comparison.exs)
A/B testing and comparison between different models.

## Integration Examples

### [phoenix_integration.exs](phoenix_integration.exs)
Integration with Phoenix web framework for chat applications.

### [livebook_examples.livemd](livebook_examples.livemd)
Interactive Livebook examples for data science and exploration.

### [genserver_agent.exs](genserver_agent.exs)
Building AI agents using GenServer and OTP patterns.

## Production Examples

### [production_chat_service.exs](production_chat_service.exs)
Production-ready chat service with monitoring, rate limiting, and error handling.

### [content_moderation.exs](content_moderation.exs)
Content moderation and classification pipeline.

### [document_analysis.exs](document_analysis.exs)
Document analysis using OCR and chat completion.

## Running Examples

Each example is a standalone Elixir script that can be run with:

```bash
# Set your API key
export MISTRAL_API_KEY="your-api-key-here"

# Run an example
cd mistralex_sdk
elixir examples/basic_chat.exs
```

## Configuration

Most examples expect your Mistral API key to be set as an environment variable:

```bash
export MISTRAL_API_KEY="your-api-key-here"
```

Alternatively, you can modify the examples to use a different configuration method.

## Dependencies

Make sure you have the Mistral SDK dependencies installed:

```bash
cd mistralex_sdk
mix deps.get
```

## Contributing

Feel free to contribute additional examples! Please follow these guidelines:

1. **Clear Documentation**: Each example should have clear comments explaining what it does
2. **Error Handling**: Include proper error handling patterns
3. **Real-world Scenarios**: Focus on practical, real-world use cases
4. **Self-contained**: Examples should be runnable with minimal setup
5. **Best Practices**: Demonstrate Elixir and SDK best practices

## Support

If you have questions about these examples or need help adapting them to your use case:

- Check the [main documentation](../docs/README.md)
- Review the [API documentation](../docs/api/)
- Open an issue on GitHub
