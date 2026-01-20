# MLX On-Device LLM Integration

This document describes the MLX Swift integration for on-device inference on iPad.

## Overview

Babyccino uses MLX Swift to run quantized LLMs directly on the iPad M3, enabling:
- **Privacy**: No API calls, all inference happens on-device
- **Low latency**: ~100-500ms response time for small models
- **Offline capability**: Works without internet connection
- **Cost-effective**: No API charges

## Current Status

✅ **Phase 3F - Skeleton Implementation (COMPLETED)**
- MLXLLMService class with full structure
- Model configuration for Qwen2.5 0.5B and 1.5B
- Chat prompt formatting (ChatML format)
- Placeholder inference that shows it's working
- Integrated with LLMServiceFactory
- Builds successfully on Mac Catalyst

🚧 **Phase 3G - Full Implementation (IN PROGRESS)**
- Actual MLX inference loop
- Model downloading from HuggingFace
- Tokenization/detokenization
- Real LLM-based complexity classification

## Architecture

```
iPad M3 (8GB unified memory)
├── MLXLLMService
│   ├── Model: Qwen2.5-0.5B-Instruct-4bit (~300MB)
│   ├── Inference: MLX Swift framework
│   ├── Chat: Handles conversation with system prompts
│   └── Classification: Routes flowcharts (simple vs complex)
├── FlowchartRouter
│   ├── Simple → Local generator (instant)
│   └── Complex → Server endpoint
└── ServerClient
    ├── Code generation → Mac server
    └── Complex flowcharts → Mac server
```

## Recommended Models

### Qwen2.5 0.5B (Recommended for MVP)
- **Size**: ~300MB (4-bit quantized)
- **Speed**: ~50 tokens/sec on iPad M3
- **Quality**: Good for chat, classification, simple tasks
- **Memory**: ~1GB RAM during inference
- **HuggingFace**: `mlx-community/Qwen2.5-0.5B-Instruct-4bit`

### Qwen2.5 1.5B (Better Quality)
- **Size**: ~900MB (4-bit quantized)
- **Speed**: ~30 tokens/sec on iPad M3
- **Quality**: Better reasoning, more coherent responses
- **Memory**: ~2GB RAM during inference
- **HuggingFace**: `mlx-community/Qwen2.5-1.5B-Instruct-4bit`

### Phi-3 Mini 3.8B (High Quality)
- **Size**: ~2.3GB (4-bit quantized)
- **Speed**: ~15 tokens/sec on iPad M3
- **Quality**: Excellent reasoning, close to GPT-3.5
- **Memory**: ~4GB RAM during inference
- **HuggingFace**: `mlx-community/Phi-3-mini-4k-instruct-4bit`

## Implementation Guide

### Step 1: Add MLX LLM Library

Add the MLX LLM library to your Swift Package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.30.0"),
    .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "0.1.0")
]
```

### Step 2: Implement Model Loading

Replace the TODO in `loadModel()`:

```swift
private func loadModel() async {
    do {
        // Download model if not cached
        let modelURL = try await ModelDownloader.download(
            repo: config.modelPath,
            cachePath: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("mlx-models")
        )

        // Load weights
        let loader = ModelLoader()
        self.modelWeights = try await loader.load(from: modelURL)

        // Load tokenizer
        self.tokenizer = try Tokenizer(path: modelURL.appendingPathComponent("tokenizer.json").path)

        modelLoaded = true
        print("✅ MLX model loaded: \(config.modelPath)")

    } catch {
        print("❌ Failed to load MLX model: \(error)")
        modelLoaded = false
    }
}
```

### Step 3: Implement Inference Loop

Replace the placeholder in `generateResponse()`:

```swift
func generateResponse(messages: [ChatMessage]) async throws -> String {
    guard isReady else {
        throw MLXError.modelNotReady
    }

    // Format prompt
    let prompt = formatChatPrompt(messages: messages)

    // Tokenize
    let tokens = try tokenize(prompt)
    var currentTokens = tokens

    // Generate tokens
    var generatedText = ""
    for _ in 0..<config.maxTokens {
        // Forward pass through model
        let logits = try forward(tokens: currentTokens)

        // Sample next token
        let nextToken = sample(logits: logits, temperature: config.temperature)

        // Check for EOS
        if nextToken == tokenizer?.eosTokenId {
            break
        }

        // Add to sequence
        currentTokens.append(nextToken)

        // Detokenize and append
        let tokenText = try detokenize([nextToken])
        generatedText += tokenText

        // Stop at special tokens
        if tokenText.contains("<|im_end|>") {
            break
        }
    }

    return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

### Step 4: Implement Forward Pass

Add the forward pass through the transformer:

```swift
private func forward(tokens: [Int]) throws -> MLXArray {
    // Convert tokens to MLX array
    let input = MLXArray(tokens)

    // Embed tokens
    let embeddings = modelWeights["model.embed_tokens.weight"]?[input]

    // Run through transformer layers
    var hidden = embeddings
    for i in 0..<numLayers {
        hidden = try transformerBlock(hidden, layer: i)
    }

    // Project to vocabulary
    let logits = hidden.matmul(modelWeights["lm_head.weight"]!.T)

    return logits[-1]  // Return logits for last token
}
```

### Step 5: Test on Physical Device

Build and run on iPad:

```bash
# Build for iPad
xcodebuild -scheme Babyccino \
  -destination 'platform=iOS,name=Your iPad' \
  build

# Or use Xcode:
# 1. Select your iPad as destination
# 2. Cmd+R to build and run
```

## Performance Expectations

### Qwen2.5 0.5B on iPad M3
- **First token**: ~200ms (includes model loading)
- **Subsequent tokens**: ~20ms each
- **Memory**: ~1GB
- **Battery**: Minimal impact for short conversations

### Typical Conversation
```
User: "I need a function to calculate fibonacci"
Assistant: (responds in ~1-2 seconds)

User: "show me the flow"
Router: Classifies as "complex" (~100ms)
→ Sends to server for flowchart generation
```

## Testing

### Unit Tests

```swift
func testMLXServiceInitialization() async throws {
    let service = MLXLLMService(config: .qwen05b)

    // Wait for model to load
    try await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertTrue(service.isReady)
}

func testGenerateResponse() async throws {
    let service = MLXLLMService(config: .qwen05b)

    let messages = [
        ChatMessage.system("You are a helpful assistant."),
        ChatMessage.user("Hello!")
    ]

    let response = try await service.generateResponse(messages: messages)
    XCTAssertFalse(response.isEmpty)
}
```

### Integration Tests

1. Test conversation flow
2. Test flowchart classification
3. Test server integration
4. Test offline mode

## Troubleshooting

### Model Not Loading
- Check internet connection for first download
- Verify HuggingFace model path is correct
- Check available disk space (need ~500MB-2GB)

### Slow Inference
- Use smaller model (0.5B instead of 1.5B)
- Reduce max_tokens in config
- Ensure app is running on physical device, not simulator

### Memory Issues
- Use 4-bit quantized models
- Reduce context length
- Clear model cache periodically

## Future Enhancements

1. **Model Caching**: Cache downloaded models for faster startup
2. **Dynamic Model Selection**: Let user choose model size
3. **Streaming**: Stream tokens as they're generated
4. **Quantization Options**: Support 2-bit, 3-bit, 4-bit, 8-bit
5. **Multi-turn Context**: Maintain conversation history
6. **Fine-tuning**: Fine-tune on code generation examples

## References

- [MLX Swift GitHub](https://github.com/ml-explore/mlx-swift)
- [MLX Swift Examples](https://github.com/ml-explore/mlx-swift-examples)
- [Qwen2.5 Models](https://huggingface.co/collections/Qwen/qwen25-66e81a666513e518adb90d9e)
- [MLX Community Models](https://huggingface.co/mlx-community)
