# JSON Structured Output Architecture

## Overview

The on-device LLM now uses **structured JSON output** instead of free-form text. This separates intent interpretation (what the LLM is good at) from response generation (where we need control).

## Why This Approach?

### Previous Problem
Small models (Qwen 0.5B, 1.5B, Phi-3) struggled to follow strict constraints:
- ❌ Kept explaining implementations despite "NEVER explain" instructions
- ❌ Verbose responses when we wanted brevity
- ❌ Fighting against their training to be helpful/conversational

### New Solution
**Separate concerns:**
1. ✅ LLM interprets user intent → outputs structured JSON
2. ✅ We control user-facing responses → hardcoded templates

## Architecture

```
User: "Can you write me a palindrome function?"
    ↓
┌─────────────────────────────────────────────────────┐
│ LLM (Intent Analyzer)                               │
│ - Understands variations in phrasing                │
│ - Classifies function type (well_known vs custom)   │
│ - Determines if clarification needed                │
│ - Outputs ONLY JSON                                 │
└─────────────────────────────────────────────────────┘
    ↓
{
  "function_name": "is_palindrome",
  "function_type": "well_known",
  "needs_clarification": false,
  "questions": [],
  "purpose": "Check if a string is a palindrome"
}
    ↓
┌─────────────────────────────────────────────────────┐
│ Response Generator (Hardcoded Templates)            │
│ - Consistent, concise responses                     │
│ - No risk of verbosity                              │
│ - Easy to modify                                    │
└─────────────────────────────────────────────────────┘
    ↓
"I can help with that. Say 'generate code' when ready."
```

## JSON Schema

### IntentAnalysis Structure

```swift
struct IntentAnalysis: Codable {
    let functionName: String        // e.g., "is_palindrome"
    let functionType: FunctionType  // "well_known" or "custom"
    let needsClarification: Bool    // Does user need to answer questions?
    let questions: [String]         // 1-2 brief questions (if needed)
    let purpose: String?            // Brief description

    enum FunctionType: String, Codable {
        case wellKnown = "well_known"  // palindrome, prime, fibonacci, etc.
        case custom = "custom"          // anything else
    }
}
```

### Example Outputs

**Well-known function (no clarification):**
```json
{
  "function_name": "is_prime",
  "function_type": "well_known",
  "needs_clarification": false,
  "questions": [],
  "purpose": "Check if a number is prime"
}
```

**Custom function (needs clarification):**
```json
{
  "function_name": "process_data",
  "function_type": "custom",
  "needs_clarification": true,
  "questions": [
    "What type of data will be processed?",
    "What should the function return?"
  ],
  "purpose": "Process data according to specifications"
}
```

## System Prompt

```
You are a function intent analyzer. Output ONLY valid JSON, no other text.

Analyze the user's request and respond with this exact JSON structure:
{
  "function_name": "suggested_function_name",
  "function_type": "well_known" or "custom",
  "needs_clarification": true or false,
  "questions": ["brief question 1", "brief question 2"],
  "purpose": "brief description"
}

Well-known functions: palindrome, prime, fibonacci, factorial, sort, reverse, sum, max, min, gcd, lcm
Custom functions: anything else

Rules:
- needs_clarification = false for well-known functions
- needs_clarification = true if inputs/outputs/logic unclear
- questions array: 1-2 brief questions maximum (empty array if none needed)
- Each question under 15 words
- NO explanations, NO code, NO implementation details in questions

Output ONLY the JSON. No markdown, no code blocks, no extra text.
```

## Response Templates

### Template Enum
```swift
enum ResponseTemplate {
    case readyToGenerate
    case needsClarification(questions: [String])
    case awaitingCommand

    var text: String {
        switch self {
        case .readyToGenerate:
            return "I can help with that. Say 'generate code' when ready."

        case .needsClarification(let questions):
            if questions.count == 1 {
                return questions[0]
            } else {
                let numbered = questions.enumerated()
                    .map { "\($0 + 1). \($1)" }
                    .joined(separator: "\n")
                return "A few questions:\n\n\(numbered)"
            }

        case .awaitingCommand:
            return "Say 'generate code' to create the function."
        }
    }
}
```

### Example Responses

**Well-known concept:**
```
User: "write a palindrome checker"
→ JSON: { needs_clarification: false, ... }
→ Response: "I can help with that. Say 'generate code' when ready."
```

**Needs clarification:**
```
User: "I need a data processor"
→ JSON: {
    needs_clarification: true,
    questions: ["What type of data?", "What should it return?"]
  }
→ Response: "A few questions:

1. What type of data?
2. What should it return?"
```

## Implementation Flow

### 1. User Input
```
User: "Can you create a function to test if a string is a palindrome?"
```

### 2. LLM Generates JSON
```swift
// In MLXLLMService.generateResponse()
let prompt = buildChatMLPrompt(messages: conversationHistory, systemPrompt: systemPrompt)
let generatedText = try await modelContainer.perform { context in
    // ... MLX inference ...
}
// generatedText = '{"function_name":"is_palindrome", ...}'
```

### 3. Parse JSON
```swift
let intent = parseJSONAndGenerateResponse(from: generatedText)
// Extracts JSON, handles markdown code blocks
// Decodes into IntentAnalysis struct
lastIntentAnalysis = intent  // Store for later
```

### 4. Generate Template Response
```swift
let response: String
if intent.needsClarification {
    response = ResponseTemplate.needsClarification(questions: intent.questions).text
} else {
    response = ResponseTemplate.readyToGenerate.text
}
return response
```

### 5. Extract Requirements
```swift
// Later, when user says "generate code"
func extractRequirements() -> FunctionRequirements {
    guard let intent = lastIntentAnalysis else {
        // Fallback to pattern matching
    }
    return convertIntentToRequirements(intent)
}
```

## Benefits

### ✅ Flexibility
- LLM understands variations: "palindrome function", "palindrome checker", "detect palindromes", etc.
- Natural language understanding preserved

### ✅ Consistency
- All responses use templates
- No unexpected verbosity
- Easy to modify response style

### ✅ Debuggability
- JSON is inspectable
- Can see exactly what LLM interpreted
- Clear separation of concerns

### ✅ Reliability
- JSON schema prevents hallucinations
- If JSON parsing fails, fallback to pattern matching
- Robust error handling

### ✅ Scalability
- Easy to add new function types
- Templates can be localized
- JSON can include more metadata (confidence scores, etc.)

## Debugging

### Log Output Example
```
🔍 [MLXLLMService] generateResponse() called
💬 [MLXLLMService] Last user message: "write a palindrome checker"
🤖 [MLXLLMService] Starting MLX inference...
✅ [MLXLLMService] Generated 120 characters
📄 [MLXLLMService] Raw model output:
   {"function_name":"is_palindrome","function_type":"well_known",...}
🔍 [MLXLLMService] Parsing JSON response...
✅ [MLXLLMService] Successfully parsed JSON
   Function: is_palindrome
   Type: well_known
   Needs clarification: false
   Questions: []
📝 [MLXLLMService] Generated template response: "I can help with that. Say 'generate code' when ready."
```

### Error Handling
```
⚠️ [MLXLLMService] Failed to parse JSON, falling back to raw output
   Attempted to parse: "Here's a function that..."
→ Falls back to removeCodeBlocks() filtering
```

## Well-Known Functions

Current list (easily extensible):
- palindrome
- prime
- fibonacci
- factorial
- sort
- reverse
- sum
- max
- min
- gcd
- lcm

## Future Enhancements

1. **Confidence Scores**
```json
{
  "function_name": "is_palindrome",
  "confidence": 0.95,
  ...
}
```

2. **Multi-function Detection**
```json
{
  "functions": [
    {"name": "is_palindrome", ...},
    {"name": "reverse_string", ...}
  ]
}
```

3. **Parameter Extraction**
```json
{
  "function_name": "is_palindrome",
  "parameters": [
    {"name": "text", "type": "str", "description": "String to check"}
  ]
}
```

4. **Edge Case Detection**
```json
{
  "function_name": "is_palindrome",
  "edge_cases_mentioned": ["empty string", "case sensitivity"]
}
```

## Comparison: Before vs After

### Before (Free-form Text)
```
User: "Can you write a palindrome function?"

LLM: "Certainly! To create a function for testing palindrome checks,
we'll start by defining what a palindrome is. A palindrome is a word
that reads the same forwards and backwards. We'll need to:

1. Input Parameters: The input string will be provided as a parameter
2. Output: Returns boolean
3. Logic: Compare the input with its reverse

Let me know if you have any questions!"

→ ❌ Too verbose
→ ❌ Explains implementation
→ ❌ Filtering struggles to clean this up
```

### After (JSON + Templates)
```
User: "Can you write a palindrome function?"

LLM generates: {"function_name":"is_palindrome","function_type":"well_known",...}

Response: "I can help with that. Say 'generate code' when ready."

→ ✅ Concise
→ ✅ Consistent
→ ✅ No explanations
```

## Testing

The system is resilient to:
- ✅ Model adding markdown code blocks around JSON
- ✅ Model adding extra text before/after JSON
- ✅ JSON parsing failures (falls back to pattern matching)
- ✅ Missing fields (optional fields have defaults)
- ✅ Various phrasing: "palindrome function", "palindrome checker", "detect palindromes"

## Conclusion

By separating **interpretation** (LLM strength) from **response generation** (where we need control), we get:
- Natural language understanding
- Consistent, concise responses
- Debuggable, structured data
- Reliable behavior

This architecture scales to future features like flowchart generation, multi-function requests, and integration planning.
