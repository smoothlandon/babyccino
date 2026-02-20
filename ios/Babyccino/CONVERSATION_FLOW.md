# Conversation Flow Architecture

## Overview

The on-device LLM (MLX) acts as a **coordinator** between the user and the backend software engineer. Its job is to gather complete specifications through targeted questions, ensuring the engineer has everything needed to implement the function correctly.

## Conversation Roles

### On-Device LLM (MLX) - The Coordinator
**Purpose:** Interview the user to gather complete specifications

**Role:** Act as a requirements analyst/interviewer, NOT as an implementer or explainer

**Responsibilities:**
1. **Understand the user's intent**
   - What function do they want?
   - What's the high-level purpose?

2. **Clarify inputs**
   - Parameter names
   - Parameter types
   - Value constraints/ranges
   - Default values

3. **Clarify outputs**
   - Return type
   - Return format
   - Success/failure cases

4. **Clarify logic** (critical for non-standard functions)
   - For well-known concepts (prime, palindrome, fibonacci, sort):
     - Just confirm basic approach
   - For custom logic:
     - Ask detailed questions about the algorithm
     - Understand step-by-step logic
     - NO ASSUMPTIONS - ask before deciding

5. **Clarify edge cases**
   - Error handling
   - Boundary conditions
   - Special input cases

**What NOT to do:**
- ❌ Write Python code
- ❌ Generate implementations
- ❌ Explain how functions work
- ❌ Describe implementations
- ❌ Assume algorithm details for custom logic
- ❌ Make statements - only ask questions

**Key principle:** The coordinator should **only ask questions**, never explain solutions

### Server
**Purpose:** Generate actual Python code and complex visualizations

**Responsibilities:**
1. **Code generation** - Write complete, tested Python functions
2. **Complex flowcharts** - Generate detailed flowcharts for complex logic
3. **Multiple functions** - Handle multi-function generation

### Local Flowchart Generator
**Purpose:** Quick visualization for simple, well-known patterns

**Handles:**
- Prime number checkers
- Palindrome checkers
- Simple predicates (even/odd, vowel/consonant)

## Example Conversation Flow

### Example 1: Well-Known Concept (Prime)
```
User: "I want a prime number checker"

LLM: "I can help with that. Say 'generate code' when ready."

User: "generate code"

→ Pattern matching extracts: is_prime requirements
→ Server generates optimized Python code
```

**Alternative if edge cases unclear:**
```
User: "I want a prime number checker"

LLM: "Handle negative numbers? (typically False)"

User: "Yes, standard approach"

LLM: "Ready. Say 'generate code' when ready."
```

### Example 2: Custom Logic
```
User: "I want a function that finds duplicate items in a list"

Coordinator: "Questions for the engineer:
- Return the duplicate items themselves, or their indices?
- Return all duplicates, or stop at the first?
- Items appearing 3+ times - include once or multiple times?
- What order for the results?"

User: "Return all items that appear more than once, in the order first seen"

Coordinator: "To confirm - if we have [1,2,3,2,4,3]:
Should it return [2,3] (order first seen) or [3,2] (duplication order)?"

User: "Order first seen - [2,3]"

Coordinator: "Got it! Ready. Say 'show me the flow' or 'generate code'."

User: "generate code"

→ LLM extraction builds detailed requirements from Q&A
→ Server generates Python implementation
```

### Example 3: Ambiguous Logic
```
User: "Create a function to validate email addresses"

Coordinator: "Email validation varies. Questions:
- Basic format (has @ and .) or RFC-compliant?
- Check for disposable domains?
- Verify DNS records?
What level of validation?"

User: "Just basic format - has @, domain, and extension"

Coordinator: "For the engineer:
- Allow subdomains (user@mail.company.com)?
- Length limits?
- Which special characters (+, -, _) are allowed?"

User: "Allow all standard characters and subdomains, no length limit"

Coordinator: "Ready! Say 'show me the flow' or 'generate code'."
```

## Response Filtering

If the LLM accidentally generates code or explanations despite the system prompt, they're automatically removed:

**Before filtering:**
```
"Sure, I can help! Here's a function that checks if a string is a palindrome:

```python
def is_palindrome(s):
    return s == s[::-1]
```

This function checks if the string equals its reverse. It removes spaces and converts to lowercase.

What would you like to do next?"
```

**After filtering:**
```
"What would you like to do next?"
```

The system silently removes:
- Code blocks (```python ... ```)
- Explanatory sentences ("This function...", "It checks...", "Here's a...")
- Implementation descriptions

Only questions and coordinating statements remain.

## Special Commands

- **"show me the flow"** → Triggers flowchart generation
  - Simple functions: Local algorithm
  - Complex functions: Server generation

- **"generate code"** → Triggers code generation
  - Extracts requirements from conversation
  - Sends to server
  - Returns formatted Python code

## System Prompt

```
You are a coordinator. Your ONLY job is to ask questions to gather specifications for FUNCTION CREATION.

NEVER explain how functions work. NEVER describe implementations. NEVER write code.

When the user asks to create a function (e.g., "a function that...", "how about a function...", "write a function..."):
- For well-known concepts (palindrome, prime, fibonacci, sort): Say "I can help with that. Say 'generate code' when ready."
- For unclear requests: Ask 1-2 brief questions about inputs, outputs, or edge cases.

Do NOT ask for test input values. You are designing functions, not running them.

Keep responses under 20 words. ONLY ask questions or confirm readiness.
```

## Benefits of This Architecture

1. **Clear separation of concerns**
   - LLM = Requirements gathering
   - Server = Code generation
   - No confusion about which generates code

2. **Better code quality**
   - Server has more context and capability
   - Can use larger models
   - Can run tests and validation

3. **Consistent UX**
   - User always knows when code is being generated
   - Code always appears in the same format
   - No duplicate code from different sources

4. **Offline capability**
   - LLM works offline for conversation
   - Server connection only needed for final code generation
   - Can save battery/data by deferring to server

5. **Flexibility**
   - Can enhance LLM prompts without changing code generation
   - Can improve server code quality without changing conversation
   - Can add new function types without retraining model
