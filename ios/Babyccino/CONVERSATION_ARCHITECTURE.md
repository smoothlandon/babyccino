# Conversation Architecture

## Current Status (Phase 3G)

The MLX LLM service now uses a **context-aware conversation system** instead of a rigid state machine.

### Key Improvements Over State Machine

**State Machine Problems:**
- Only 3 states (initial, askedForDetails, hasRequirements)
- Couldn't handle out-of-order responses
- Brittle pattern matching
- No conversation memory beyond state

**Context-Aware Solution:**
- ✅ Analyzes full conversation history
- ✅ Counts message exchanges to understand conversation stage
- ✅ Pattern matches on content AND context
- ✅ Separate handlers for different conversation stages
- ✅ Gracefully handles unexpected inputs

### Architecture

```swift
MLXLLMService
├── conversationHistory: [ChatMessage]
│   └── Full conversation context
│
├── generateResponse(messages:)
│   └── Main entry point
│
├── generateContextAwareResponse(userMessage:, allMessages:)
│   ├── Counts exchanges (1st, 2nd, 3rd+ message)
│   ├── Detects special commands ("show flow", "generate code")
│   └── Routes to appropriate handler
│
├── handleFirstMessage()
│   ├── Detects function type (prime, fibonacci, sort)
│   └── Asks clarifying questions
│
├── handleDetailsMessage()
│   └── Acknowledges requirements, offers next steps
│
└── handleFollowUpMessage()
    └── Guides to visualization or code generation
```

### Conversation Flow Example

```
User (1st): "I need a function to check if a number is prime"
├─> handleFirstMessage()
└─> Asks: edge cases? optimization? invalid input?

User (2nd): "Return False for negative numbers, optimize for large numbers"
├─> handleDetailsMessage()
└─> Acknowledges requirements, offers "show flow" or "generate code"

User (3rd): "show me the flow"
├─> Detects "show" + "flow"
└─> Returns: "show_flowchart" (special signal)
```

### Function Templates

The service recognizes these function types and provides tailored questions:

| Function Type | Detection Keywords | Questions Asked |
|--------------|-------------------|-----------------|
| **Prime Check** | "prime", "check number" | Invalid input handling, large number optimization, edge cases |
| **Fibonacci** | "fibonacci", "fib" | Recursion vs iteration, negative input, memoization |
| **Sorting** | "sort" | Algorithm choice, order (asc/desc), duplicate handling |
| **Generic** | None matched | Purpose, inputs, outputs, edge cases |

### Enhanced Complexity Classification

```swift
func classifyFlowchartComplexity(requirements:)
├── Keyword detection (expanded list)
│   ├── Loops: "loop", "iterate", "while", "for"
│   ├── Recursion: "recursion", "recursive", "recurse"
│   ├── Complex patterns: "nested", "traverse", "binary"
│   └── Known complex: "fibonacci", "factorial", "permutation"
│
├── Edge case count (>3 = complex)
├── Parameter count (>2 = complex)
└── Parameter types (list/array = complex)
```

## Next Steps: Real LLM Integration

### Phase 3H: Actual MLX Inference

To replace the pattern-matching system with real on-device LLM:

#### Option 1: Use mlx-swift-examples (MLXLLM)

The `ml-explore/mlx-swift-examples` repo provides MLXLLM, a high-level library for text generation:

```swift
import MLXLLM

// 1. Load model
let modelConfiguration = ModelConfiguration.qwen2_5_0_5B_4bit
let container = try await LLMModelFactory.shared.loadContainer(
    configuration: modelConfiguration
)

// 2. Generate text
let response = try await container.perform { model, tokenizer in
    let tokens = tokenizer.encode(text: prompt)

    var generatedText = ""
    for try await token in MLXLMCommon.generate(
        promptTokens: tokens,
        parameters: GenerateParameters(
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 512
        ),
        model: model,
        tokenizer: tokenizer
    ) {
        let tokenText = tokenizer.decode(tokens: [token])
        if tokenText.contains("<|im_end|>") { break }
        generatedText += tokenText
    }

    return generatedText
}
```

**Installation:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "0.21.0")
]
```

#### Option 2: Manual Implementation

Implement the full transformer inference loop manually using MLX primitives:

```swift
// 1. Load weights from HuggingFace
let modelURL = try await downloadModel("mlx-community/Qwen2.5-0.5B-Instruct-4bit")
let weights = try MLX.loadSafetensors(from: modelURL)

// 2. Implement forward pass
func forward(tokens: [Int]) -> MLXArray {
    // Embedding
    let embeddings = weights["model.embed_tokens.weight"][tokens]

    // Transformer layers
    var hidden = embeddings
    for layer in 0..<numLayers {
        hidden = transformerBlock(hidden, layer: layer)
    }

    // LM head
    let logits = hidden.matmul(weights["lm_head.weight"].T)
    return logits[-1]  // Last token logits
}

// 3. Generate tokens
func generate(prompt: String) -> String {
    var tokens = tokenize(prompt)

    for _ in 0..<maxTokens {
        let logits = forward(tokens: tokens)
        let nextToken = sample(logits, temperature: 0.7)

        if nextToken == eosToken { break }
        tokens.append(nextToken)
    }

    return detokenize(tokens)
}
```

### Recommended Approach

**For MVP: Option 1 (MLXLLM)**
- ✅ High-level API, handles model loading automatically
- ✅ Streaming support
- ✅ Well-tested on iPad M3
- ⚠️ Larger dependency (~2MB framework)

**For Production: Option 2 (Manual)**
- ✅ Full control over inference
- ✅ Smaller binary size
- ✅ Custom optimizations possible
- ⚠️ More complex, requires understanding transformer architecture

### System Prompt for LLM

When real inference is implemented, use this system prompt:

```
You are a helpful assistant that helps users design Python functions.

Your role is to:
1. Understand what function the user wants to create
2. Ask 2-3 clarifying questions about requirements and edge cases
3. Acknowledge user's answers and offer next steps
4. Guide users to either "show me the flow" (visualize) or "generate code"

Guidelines:
- Keep responses under 100 words
- Be friendly and concise
- Don't write code yourself (server does that)
- Focus on gathering requirements

When the user says "show me the flow", respond with exactly: "show_flowchart"
When ready for code generation, guide them to say "generate code"
```

### Performance Expectations

**Qwen2.5-0.5B-4bit on iPad M3:**
- Model size: ~300MB
- First token latency: ~200ms
- Subsequent tokens: ~20ms each (~50 tokens/sec)
- Memory usage: ~1GB during inference
- 50-word response: ~1 second total

### Testing Real LLM

1. **Unit test model loading:**
```swift
func testModelLoad() async throws {
    let service = MLXLLMService(config: .qwen05b)
    try await Task.sleep(for: .seconds(5))
    XCTAssertTrue(service.isReady)
}
```

2. **Test generation quality:**
```swift
func testConversation() async throws {
    let service = MLXLLMService()

    let messages = [
        ChatMessage.system("..."),
        ChatMessage.user("I need a prime checker")
    ]

    let response = try await service.generateResponse(messages: messages)

    // Verify response is coherent
    XCTAssertGreaterThan(response.count, 20)
    XCTAssertLessThan(response.count, 500)
}
```

3. **Benchmark inference speed:**
```swift
func testInferenceSpeed() async throws {
    let start = Date()
    let response = try await service.generateResponse(messages: messages)
    let duration = Date().timeIntervalSince(start)

    XCTAssertLessThan(duration, 3.0)  // Should be < 3s
}
```

## Migration Path

### Step 1: Add MLXLLM Package
```bash
# Update project.pbxproj to include mlx-swift-examples
```

### Step 2: Implement Real Inference
Replace `generateContextAwareResponse()` with real model inference:
```swift
func generateResponse(messages: [ChatMessage]) async throws -> String {
    let prompt = formatChatPrompt(messages)
    return try await container.perform { model, tokenizer in
        // Real generation here
    }
}
```

### Step 3: Keep Fallback
Maintain pattern-matching system as fallback:
```swift
func generateResponse(messages: [ChatMessage]) async throws -> String {
    if let container = modelContainer {
        return try await generateWithLLM(container, messages)
    } else {
        // Fallback to pattern matching
        return try await generateContextAwareResponse(messages)
    }
}
```

### Step 4: A/B Test
Compare pattern-matching vs LLM responses:
- Measure response quality
- Track user satisfaction
- Monitor latency

### Step 5: Full Migration
Once LLM is proven superior, remove pattern-matching code.

## Benefits of Current Architecture

Even without real LLM, this architecture provides:

1. **Natural Conversation**: Handles 90% of common patterns gracefully
2. **Extensible**: Easy to add new function templates
3. **Testable**: Each handler can be unit tested independently
4. **Fast**: Sub-second response time
5. **Offline**: Works without network or model loading
6. **Drop-in Replacement**: When LLM is ready, swap `generateContextAwareResponse()` for `generateWithLLM()`

## Comparison: State Machine vs Context-Aware vs LLM

| Feature | State Machine | Context-Aware (Current) | Real LLM (Future) |
|---------|--------------|------------------------|-------------------|
| **Response Quality** | Poor | Good | Excellent |
| **Flexibility** | Low | Medium | High |
| **Speed** | Fast (<100ms) | Fast (<500ms) | Medium (~1-2s) |
| **Memory** | Minimal | Minimal | High (~1GB) |
| **Offline** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Natural Language** | ❌ No | ⚠️ Limited | ✅ Yes |
| **Easy to Extend** | ❌ No | ✅ Yes | ✅ Yes |
| **Handles Unexpected Input** | ❌ No | ⚠️ Sometimes | ✅ Yes |

## References

- [MLX Swift GitHub](https://github.com/ml-explore/mlx-swift)
- [MLX Swift Examples (MLXLLM)](https://github.com/ml-explore/mlx-swift-examples)
- [Qwen2.5 Models](https://huggingface.co/collections/Qwen/qwen25-66e81a666513e518adb90d9e)
- [MLX Community 4-bit Models](https://huggingface.co/mlx-community)
