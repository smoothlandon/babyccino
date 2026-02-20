# Model Selection and Response Strategies

## Overview

The app only offers models that support **reliable structured JSON output** for intent analysis. This ensures consistent, high-quality responses across all phrasings.

## Available Models

All models use the same **JSON structured output** strategy for maximum flexibility and reliability.

**How it works:**
```
User: "Can you write a palindrome function?"
→ Detects keyword: "palindrome"
→ Response: "I can help with that. Say 'generate code' when ready."

User: "Can you help me write some functions?"
→ No specific keyword detected
→ Response: "Sure! What kind of function would you like? (e.g., palindrome, prime, fibonacci, or describe your own)"
```

**Supported keywords:**
- palindrome → is_palindrome
- prime → is_prime
- fibonacci / fib → fibonacci
- factorial → factorial
- sort → sort_list
- reverse → reverse_string
- sum → calculate_sum
- max → find_max
- min → find_min

### Qwen 1.5B (900MB) - JSON Structured Output
**Why:** Large enough for structured output
**Strategy:** LLM outputs JSON, we use templates for responses
**Pros:** Flexible, understands variations, scalable
**Cons:** Slower, uses more power

**How it works:**
```
User: "write me a palindrome checker"
→ LLM generates JSON:
{
  "function_name": "is_palindrome",
  "function_type": "well_known",
  "needs_clarification": false,
  "questions": [],
  "purpose": "Check if a string is a palindrome"
}
→ We use template: "I can help with that. Say 'generate code' when ready."

User: "I need a data processor"
→ LLM generates JSON:
{
  "function_name": "process_data",
  "function_type": "custom",
  "needs_clarification": true,
  "questions": ["What type of data?", "What should it return?"],
  "purpose": "Process data"
}
→ We use template: "A few questions:\n\n1. What type of data?\n2. What should it return?"
```

### Phi-3 Mini 3.8B (2.3GB) - JSON Structured Output
**Why:** Best quality, most reliable JSON
**Strategy:** Same as 1.5B but more accurate
**Pros:** Excellent understanding, reliable
**Cons:** Slowest, highest power consumption

## Implementation

### Pattern Matching (Qwen 0.5B)

```swift
// In generateResponse()
if config.modelId == "qwen-0.5b" {
    return generatePatternBasedResponse(userMessage: lastUserMessage.content)
}

func generatePatternBasedResponse(userMessage: String) -> String {
    let lower = userMessage.lowercased()

    // Check for keywords
    if lower.contains("palindrome") {
        lastIntentAnalysis = IntentAnalysis(
            functionName: "is_palindrome",
            functionType: .wellKnown,
            needsClarification: false,
            questions: [],
            purpose: "Process palindrome request"
        )
        return "I can help with that. Say 'generate code' when ready."
    }

    // ... more keywords ...

    // Generic fallback
    return "Sure! What kind of function? (e.g., palindrome, prime, fibonacci)"
}
```

### JSON Output (1.5B+)

```swift
// In generateResponse()
let prompt = buildChatMLPrompt(messages: conversationHistory, systemPrompt: systemPrompt)
let generatedText = try await modelContainer.perform { /* MLX inference */ }
let intent = parseJSONAndGenerateResponse(from: generatedText)
return intent
```

## Validation

All models use validation to catch errors:

```swift
func validateIntent(_ intent: IntentAnalysis) -> Bool {
    // Questions array shouldn't contain function names
    if intent.questions.contains(where: { $0.lowercased().contains("palindrome") }) {
        return false  // Model confused
    }

    // Well-known functions shouldn't need clarification
    if intent.functionType == .wellKnown && intent.needsClarification {
        return false
    }

    return true
}
```

If validation fails: `"What kind of function would you like me to help you create?"`

## Recommendations

### For Testing/Development (Default)
**Use: Qwen 1.5B** ⭐ Recommended
- Good balance of speed and quality
- Handles variations well
- Acceptable latency (~30 tokens/sec)
- Reliable JSON output
- 900MB download

### For Production/Best Quality
**Use: Phi-3 Mini 3.8B**
- Best user experience
- Most reliable JSON parsing
- Excellent reasoning
- Handles complex edge cases
- Worth the slower speed (~15 tokens/sec)
- 2.3GB download

## Migration Path

Start with 0.5B pattern matching, then scale up:

1. **0.5B Pattern Matching** ✅
   - Hardcoded keywords
   - Simple, reliable
   - Good for MVP

2. **1.5B JSON Output** (Recommended)
   - Natural language understanding
   - Flexible phrasing
   - Ready for multi-function

3. **3.8B JSON Output** (Future)
   - Best quality
   - Complex queries
   - Multi-agent orchestration

## Switching Models

Users can change models in Settings:
- Downloads happen automatically
- Model selection persists
- Service reinitializes on model change

Code automatically adapts:
```swift
if config.modelId == "qwen-0.5b" {
    // Use pattern matching
} else {
    // Use JSON output
}
```

## Future: Hybrid Approach

Optimal strategy:
1. **Quick pattern check** (instant)
   - If keyword match → use pattern response
   - If no match → defer to LLM

2. **LLM for ambiguous cases** (200-500ms)
   - Only when pattern matching fails
   - Best of both worlds

This would make even 0.5B more flexible while maintaining speed for common cases.

## Benchmarks

| Model | Size | Speed | JSON Reliable | Power | Recommended For |
|-------|------|-------|---------------|-------|-----------------|
| Qwen 1.5B | 900MB | ~30 tok/s | ✅ Good | Medium | Default/Development |
| Phi-3 Mini | 2.3GB | ~15 tok/s | ✅✅ Best | High | Production/Best Quality |

## Debugging

Check which strategy is being used:
```
💭 [MLXLLMService] No special command detected, proceeding with response generation
💡 [MLXLLMService] Using pattern-based response for Qwen 0.5B
🔍 [MLXLLMService] Pattern matching on: "Can you help me write some functions?"
✓ [MLXLLMService] No specific function detected - generic response
```

vs.

```
💭 [MLXLLMService] No special command detected, proceeding with response generation
📋 [MLXLLMService] Built ChatML prompt (450 chars)
🤖 [MLXLLMService] Starting MLX inference...
✅ [MLXLLMService] Successfully parsed JSON
```
