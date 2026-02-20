# Debugging Guide

## Overview

Comprehensive logging has been added throughout the conversation flow to make debugging easier. All logs use a consistent format with emojis and prefixes for easy filtering.

## Log Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 [Component] Function name called
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💬 [Component] Specific action description
📝 [Component] Data/state information
✅ [Component] Success message
❌ [Component] Error message
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Components with Logging

### 1. ChatViewModel (ChatView.swift)

**Entry points:**
- `sendMessage()` - User sends a message
- `getAssistantResponse()` - Getting LLM response
- `generateCode()` - Code generation flow

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💬 [ChatViewModel] sendMessage() called
📝 [ChatViewModel] User message: "I want a prime checker"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 [ChatViewModel] Conversation now has 2 messages
💭 [ChatViewModel] Getting assistant response
```

### 2. MLXLLMService (MLXLLMService.swift)

**Key functions:**
- `generateResponse()` - Main LLM inference
- `extractRequirements()` - Pattern matching for function requirements
- `extractRequirementsWithPatternMatching()` - Detailed pattern matching

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 [MLXLLMService] generateResponse() called
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 [MLXLLMService] Conversation has 2 messages
💬 [MLXLLMService] Last user message: "I want a prime checker"
🎯 [MLXLLMService] No special command detected, proceeding with LLM generation
📋 [MLXLLMService] Built ChatML prompt (450 chars)
📋 [MLXLLMService] Prompt preview (first 200 chars):
   <|im_start|>system
You are a coordinator...
🤖 [MLXLLMService] Starting MLX inference...
✅ [MLXLLMService] Generated 85 characters
📄 [MLXLLMService] Raw model output:
   "I can help with that. Say 'generate code' when ready."
✓ [MLXLLMService] No filtering needed
✓ [MLXLLMService] Final response: "I can help with that. Say 'generate code' when ready."
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. Requirements Extraction

**Pattern matching logs:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 [MLXLLMService] extractRequirements() called
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 [MLXLLMService] Conversation history (3 messages):
   [0] user: I want a prime checker
   [1] assistant: I can help with that. Say 'generate code' when ready.
   [2] user: generate code
💭 [MLXLLMService] Using pattern matching extraction (LLM extraction TODO)
🔎 [MLXLLMService] extractRequirementsWithPatternMatching() started
🔍 [MLXLLMService] Examining last 2 user messages:
   [0] I want a prime checker
   [1] generate code
🔍 [MLXLLMService] Checking message 0 (reversed): "generate code"
✗ [MLXLLMService] No pattern matched in this message
🔍 [MLXLLMService] Checking message 1 (reversed): "I want a prime checker"
✓ [MLXLLMService] Matched pattern: PRIME
🎯 [MLXLLMService] Found match, stopping search
📋 [MLXLLMService] Extracted requirements:
   Name: is_prime
   Purpose: Check if a number is prime
   Parameters: 1
   Return Type: bool
   Edge Cases: 3
   Examples: 4
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Filtering Logs

To see specific components:

```bash
# View all MLXLLMService logs
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "[MLXLLMService]"'

# View all ChatViewModel logs
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "[ChatViewModel]"'

# View only errors
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "❌"'

# View pattern matching
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "Matched pattern"'
```

Or simply look at Xcode console output during debugging.

## Common Debugging Scenarios

### Scenario 1: LLM Not Responding Correctly

**Check these logs:**
1. `[ChatViewModel] User message` - Verify what was sent
2. `[MLXLLMService] Last user message` - Confirm it was received
3. `[MLXLLMService] Raw model output` - See what model generated
4. `[MLXLLMService] Cleaned output` - See what was filtered
5. `[MLXLLMService] Final response` - See what was returned

**Example debug flow:**
```
User says: "how about a prime checker?"

Look for:
💬 [ChatViewModel] User message: "how about a prime checker?"
→ ✅ Message received

💬 [MLXLLMService] Last user message: "how about a prime checker?"
→ ✅ Passed to LLM

📄 [MLXLLMService] Raw model output: "Sure, I can help..."
→ ❌ Model didn't follow instructions

🧹 [MLXLLMService] Filtering applied - removed 120 characters
→ ✅ Filtering working

✓ [MLXLLMService] Final response: "I can help with that. Say 'generate code' when ready."
→ ✅ Correct output after filtering
```

### Scenario 2: Wrong Function Generated

**Check these logs:**
1. `[MLXLLMService] Conversation history` - Review full conversation
2. `[MLXLLMService] Examining last N user messages` - See what's being analyzed
3. `[MLXLLMService] Matched pattern: X` - See which pattern matched
4. `[MLXLLMService] Extracted requirements` - Verify extracted details

**Example debug flow:**
```
User first asks for palindrome, then prime.
Code generator returns palindrome function.

Look for:
📝 [MLXLLMService] Conversation history (4 messages):
   [0] user: I want a palindrome checker
   [1] assistant: I can help with that...
   [2] user: how about a prime checker?
   [3] assistant: I can help with that...
→ ✅ Both requests in history

🔍 [MLXLLMService] Examining last 2 user messages:
   [0] I want a palindrome checker
   [1] how about a prime checker?
→ ✅ Both messages being checked

🔍 [MLXLLMService] Checking message 0 (reversed): "how about a prime checker?"
✓ [MLXLLMService] Matched pattern: PRIME
→ ✅ Should extract prime, not palindrome

📋 [MLXLLMService] Extracted requirements:
   Name: is_prime
→ ✅ Correct extraction
```

### Scenario 3: Special Commands Not Detected

**Check these logs:**
1. `[ChatViewModel] User message` - See exact input
2. `[MLXLLMService] Special command detected` - Check detection
3. If no detection, check `[MLXLLMService] proceeding with LLM generation`

**Example debug flow:**
```
User says "generate code" but nothing happens

Look for:
💬 [ChatViewModel] User message: "generate code"
🎯 [ChatViewModel] Detected GENERATE CODE command
→ ✅ Detected in ChatViewModel

🎯 [MLXLLMService] Special command detected: GENERATE_CODE
→ ✅ Also detected in service

🔧 [ChatViewModel] generateCode() called
→ ✅ Function called

📋 [ChatViewModel] Extracted 1 function requirement(s)
   [0] is_prime: Check if a number is prime
→ ✅ Requirements extracted

🌐 [ChatViewModel] Calling serverClient.generateCode()
→ Check if server call succeeds
```

## Log Emoji Key

- 🔍 Function entry / inspection
- 💬 User message / communication
- 📝 Data / state information
- 📋 Structured data (lists, requirements)
- 🎯 Special command detected / important decision
- 💭 Thinking / processing step
- 🔄 Using a service / calling function
- ✅ Success / confirmation
- ✓ Minor success / validation passed
- ❌ Error / failure
- ⚠️ Warning / fallback used
- 🤖 AI/LLM operation
- 🧹 Filtering / cleanup
- 📄 Raw data / output
- 🔧 Code generation
- 🌐 Network call
- 📊 Statistics / counts
- 📱 Platform detection

## Tips

1. **Start from the top** - Follow logs chronologically to see the full flow
2. **Look for breaks** - The `━━━` lines separate different function calls
3. **Check reversals** - Pattern matching processes messages in reverse order
4. **Verify filtering** - Compare "Raw model output" vs "Final response"
5. **Count messages** - Ensure conversation history is correct length
6. **Check platform** - Simulator vs physical device affects which code runs

## Future Improvements

- [ ] Add timestamp to logs
- [ ] Add request ID to track conversations
- [ ] Log inference timing (tokens/sec)
- [ ] Add log level filtering (DEBUG, INFO, ERROR)
- [ ] Export logs to file for bug reports
