# Babyccino: Conversational Development Tool with Visual Flowcharts

## Project Overview

Babyccino enables developers to describe software functions conversationally on an iPad, with AI generating flowcharts as visual aids and then producing production-ready code.

**Core Value Proposition:** Describe logic conversationally → See it visualized as a flowchart → Get production-ready, tested code

**Target User:** Hobby project developers who want to work on code architecture during mobile-only time

**MVP Scope:** Conversational interface that produces flowcharts and generates Python functions with unit tests

**Key Insight:** The flowchart is a *byproduct* of the conversation, not the primary input. Users describe what they want in natural language, AI helps refine it through conversation, and the flowchart serves as a visual representation before code generation.

---

## Architecture

### System Components

1. **iPad Native App** (Swift/SwiftUI + MLX Swift)
   - Chat interface powered by local LLM (Llama 3.2 3B or similar)
   - Conversational requirement gathering with AI
   - Flowchart generation (local, on-device)
   - Flowchart viewer for user validation
   - Server connection management
   - Code/test result viewer

2. **Python Server** (FastAPI + Ollama)
   - Receives structured function requirements from iPad
   - Uses local LLM (Qwen 2.5 Coder 7B or DeepSeek Coder) to:
     - Generate Python code from requirements
     - Generate unit tests
     - Analyze complexity
   - Runs unit tests via pytest
   - Returns code, test results, and analysis to iPad

3. **Communication**
   - Local network (192.168.x.x)
   - REST API over HTTP
   - JSON payload format
   - Optimized for LLM-to-LLM efficiency (structured data, not raw conversation)

### Data Flow

```
1. User describes function in chat: "I need a function that checks if a number is prime"
2. iPad LLM asks clarifying questions: "Should it handle negative numbers? What about 0 and 1?"
3. Conversation continues on-device until requirements are clear
4. User says "looks good" or "show me the flow"
5. iPad LLM generates:
   - Flowchart JSON (for visualization)
   - Structured FunctionRequirements (for server)
6. iPad displays flowchart for user review
7. User confirms or requests changes (repeats step 5 if needed)
8. User says "generate code"
9. iPad sends FunctionRequirements to server (POST /generate-code)
10. Server generates code based on structured requirements
11. Server generates unit tests
12. Server runs pytest
13. Server analyzes complexity
14. Server returns:
    - Generated code
    - Test results (pass/fail + output)
    - Complexity analysis (Big-O notation)
15. iPad displays code results
```

---

## iPad App Specification

### UI Structure

#### Main Screen: Conversational Interface

**Chat Area (main content)**
- iMessage-style chat interface
- User messages (right-aligned, blue)
- AI messages (left-aligned, gray)
- Support for text messages and flowchart visualizations inline
- Auto-scroll to latest message
- Keyboard handling (shifts view when keyboard appears)

**Message Types:**
1. **Text message** - Standard chat bubble
2. **Flowchart message** - Embedded interactive flowchart view that user can pan/zoom
3. **Code result message** - Syntax-highlighted code with tabs for tests/complexity

**Input Bar (bottom)**
- Text input field with placeholder: "Describe a function you want to build..."
- Send button
- Microphone button (optional for future voice input)

**Toolbar (top)**
- "New Chat" button (starts fresh conversation)
- Server status indicator (green dot = connected)
- Settings button

**Conversation Flow:**

1. **Initial state:** 
   - Empty chat with welcome message
   - "Hi! I'm Babyccino ☕️. Describe a function you'd like to build, and I'll help you design and implement it."

2. **User describes function:**
   - User: "I need a function that validates email addresses"
   - AI: "Great! Let me clarify a few things:
     - Should it check for proper format (username@domain.extension)?
     - Do you want to verify the domain exists?
     - Should it handle international characters?
     - Any specific validation rules?"

3. **Refinement conversation:**
   - Back-and-forth until requirements are clear
   - AI asks clarifying questions
   - User provides more details

4. **Flowchart generation:**
   - User: "That looks good, show me the flow"
   - AI: "Here's the logic flow for your email validator:"
   - [Flowchart appears in chat as interactive image]
   - AI: "Does this capture what you need? Reply with 'generate code' when ready, or suggest changes."

5. **Code generation:**
   - User: "generate code"
   - AI: "Generating your function with tests..."
   - [Loading indicator]
   - [Code result appears with tabs for Code/Tests/Complexity]

#### Settings Screen

- Server IP address input (default: auto-detect local IP)
- Server port input (default: 8000)
- Connection test button
- API key input (for Claude API, stored in server config)
- About/version info

### Flowchart Visualization (Read-only)

When AI generates a flowchart, it appears as an embedded view in the chat:

**Display Properties:**
- Interactive (pan/zoom with gestures)
- Read-only (user doesn't edit it directly)
- Node types visually distinct:
  - Start/End (rounded rectangle, green/red)
  - Process (rectangle, blue)
  - Decision (diamond, yellow)
  - Input/Output (parallelogram, purple)
- Arrows show flow direction
- Labels on nodes and decision branches

**Interactions:**
- Pinch to zoom
- Pan with one finger
- Tap flowchart to expand to full screen
- "Edit" button below flowchart opens conversation: "What would you like to change about this flow?"

### Conversation State Management

Each conversation has:
- `id`: UUID
- `messages`: array of Message objects
- `flowchart`: optional FlowchartData (latest generated)
- `generatedCode`: optional CodeResult (latest generated)
- `created_at`: timestamp

Message types:
- `user_text`: User's message
- `ai_text`: AI's response
- `ai_flowchart`: Flowchart visualization
- `ai_code`: Generated code with tests/complexity

### User Interactions

1. **Starting conversation:** Type description, hit send
2. **Continuing conversation:** Respond to AI questions naturally
3. **Requesting flowchart:** Say "show me the flow" or "visualize this" or "looks good"
4. **Modifying flowchart:** Describe changes in chat ("make the validation more strict")
5. **Generating code:** Say "generate code" or "build it" or "let's code it"
6. **Reviewing results:** Scroll through tabs (Code/Tests/Complexity)
7. **Iterating:** Continue conversation to refine and regenerate

### Error Handling

- No server connection: Show alert with server IP/port, offer to go to settings
- Message send failure: Show retry button
- Generation failure: AI responds with error explanation in chat
- Network timeout: AI: "That's taking longer than expected. Still working on it..."

---

## Server Specification

### Technology Stack

- **Framework:** FastAPI
- **AI Integration:** Ollama (local LLM - Qwen 2.5 Coder 7B or DeepSeek Coder)
- **Testing:** pytest (subprocess execution)
- **Code Analysis:** LLM-based complexity analyzer
- **State Management:** Stateless (conversation handled on iPad)

### API Endpoints

#### `GET /health`

Health check endpoint to verify server and LLM availability.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0",
  "llm_provider": "ollama",
  "model": "qwen2.5-coder:7b",
  "model_available": true
}
```

#### `POST /generate-code`

Generates code, tests, and complexity analysis from structured requirements.

**Request Body:**
```json
{
  "conversation_id": "uuid-or-null",
  "requirements": {
    "name": "is_prime",
    "purpose": "Check if a number is prime",
    "parameters": [
      {
        "name": "n",
        "type": "int",
        "description": "The number to check for primality"
      }
    ],
    "return_type": "bool",
    "edge_cases": [
      "n < 2 returns False",
      "n = 2 returns True",
      "Handle negative numbers by returning False"
    ],
    "examples": [
      {"input": "2", "output": "True"},
      {"input": "4", "output": "False"},
      {"input": "17", "output": "True"}
    ]
  }
}
```

**Response:**
```json
{
  "conversation_id": "uuid-123",
  "code": {
    "function": "def is_prime(n):\n    \"\"\"Check if a number is prime.\n    \n    Args:\n        n: Integer to check\n        \n    Returns:\n        bool: True if prime, False otherwise\n    \"\"\"\n    if n < 2:\n        return False\n    \n    for i in range(2, int(n ** 0.5) + 1):\n        if n % i == 0:\n            return False\n    \n    return True",
    "tests": {
      "code": "import pytest\nfrom function import is_prime\n\ndef test_primes():\n    assert is_prime(2) == True\n    assert is_prime(3) == True\n    assert is_prime(17) == True\n\ndef test_non_primes():\n    assert is_prime(4) == False\n    assert is_prime(15) == False\n    assert is_prime(100) == False\n\ndef test_edge_cases():\n    assert is_prime(0) == False\n    assert is_prime(1) == False\n    assert is_prime(-5) == False",
      "results": [
        {"name": "test_primes", "passed": true, "output": ""},
        {"name": "test_non_primes", "passed": true, "output": ""},
        {"name": "test_edge_cases", "passed": true, "output": ""}
      ],
      "summary": "3 passed, 0 failed"
    },
    "complexity": {
      "time": "O(√n)",
      "space": "O(1)",
      "explanation": "Time complexity is square root of n due to loop optimization. Space complexity is constant as we only use a few variables."
    }
  }
}
```

### Server Logic

#### 1. Code Generation

**System Prompt:**
```
You are an expert Python developer who writes clean, well-documented code.
Follow PEP 8 style guidelines and use type hints appropriately.
```

**Prompt:**
```
Generate a Python function with these requirements:

Function Name: {name}
Purpose: {purpose}
Return Type: {return_type}

Parameters:
{parameters list}

Edge Cases to Handle:
{edge_cases list}

Examples:
{examples list}

Requirements:
- Include a comprehensive docstring with Args and Returns sections
- Use type hints for parameters and return type
- Handle all specified edge cases
- Write clean, readable code following PEP 8
- Do not include any import statements unless absolutely necessary

Output only the Python function code, no markdown formatting or explanations.
```

#### 2. Test Generation

**Prompt:**
```
Generate pytest unit tests for this function:

[generated function code]

Requirements Context:
- Purpose: {purpose}
- Edge cases to test: {edge_cases}
- Examples: {examples}

Requirements:
- Import the function from 'function' module
- Write multiple test functions (test_normal_cases, test_edge_cases, etc.)
- Use clear test names that describe what is being tested
- Include assertions for all examples and edge cases
- Cover both positive and negative test cases

Output only the Python test code, no markdown formatting or explanations.
```

#### 3. Test Execution

- Write generated function to temp file
- Write test code to temp file
- Run `pytest -v` via subprocess
- Parse pytest output for pass/fail status
- Capture any error messages
- Clean up temp files

#### 4. Complexity Analysis

**Prompt:**
```
Analyze the time and space complexity of this function:

[generated function code]

Consider the algorithm's behavior:
- Loop iterations
- Recursive calls
- Data structure usage
- Memory allocation

Provide:
- Time complexity in Big-O notation
- Space complexity in Big-O notation
- Brief explanation (2-3 sentences) of why

Output as JSON: {"time": "O(...)", "space": "O(...)", "explanation": "..."}
### Environment Setup

**Required:**
- Python 3.10+
- [Ollama](https://ollama.ai/) installed and running
- pip packages: fastapi, uvicorn, ollama, pytest
- Recommended model: `qwen2.5-coder:7b` (or `deepseek-coder:33b` for more complex tasks)

**Configuration:**
- Server runs on 0.0.0.0:8000 (accessible on local network)
- CORS enabled for local network access
- Request timeout: 60 seconds (code generation typically takes 5-15 seconds)
- Stateless design (no conversation history stored)

---

## Communication Protocol

### Network Discovery

- iPad app attempts connection to:
  1. User-configured IP (from settings)
  2. Auto-detected local network IPs (192.168.x.x range)
- Health check on connection to verify server is running

### Request/Response Format

- Content-Type: application/json
- Timeout: 60 seconds (code generation can take time)
- Retry logic: 3 attempts with exponential backoff

### Error Codes

- 400: Invalid flowchart data
- 500: Server error (code generation failed)
- 503: Service unavailable (Claude API error)

---

## Success Criteria for MVP

### Must Have (v0.1.0)

✅ iPad app can:
- Display chat interface for function description
- Send messages to server
- Receive and display AI responses
- Display flowchart visualizations inline in chat
- Display generated code with tabs for tests/complexity
- Handle basic error cases
- Save conversation history (in-memory for session)

✅ Server can:
- Maintain conversation state per conversation_id
- Converse intelligently about function requirements using Claude API
- Ask clarifying questions
- Determine when enough information is gathered
- Generate flowchart JSON from conversation
- Generate Python function from conversation + flowchart
- Generate unit tests based on discussed requirements
- Run tests and report results
- Analyze complexity
- Return all results to iPad

✅ System can:
- Work over local network
- Complete conversation → flowchart → code flow
- Handle errors gracefully
- Complete code generation in <60 seconds

### Nice to Have (future versions)

- Persist conversation history across sessions
- Edit flowchart directly (regenerate code from edits)
- Multiple functions in one conversation/project
- Support for classes (multiple functions → class)
- Export to GitHub
- More language targets (JS, Go, etc.)
- Voice input for describing functions
- Templates for common patterns
- Share conversations

### Non-Goals for MVP

- Authentication/authorization
- Cloud deployment
- Multi-user support
- Real-time collaboration
- Advanced flowchart editing tools
- Integration with external services
- Production deployment infrastructure

---

## Development Phases

### Phase 1: Server Foundation
- Set up FastAPI server
- Implement `/health` endpoint
- Implement `/chat` endpoint with conversation state management
- Integrate Claude API for conversational responses
- Test with curl/Postman

### Phase 2: Flowchart & Code Generation
- Implement `/generate-flowchart` endpoint
- Implement `/generate-code` endpoint
- Add test execution subprocess
- Add complexity analysis
- Test full conversation → flowchart → code flow

### Phase 3: iPad App Shell
- Create SwiftUI app structure
- Implement settings screen
- Implement server connection logic
- Test health check endpoint from iPad

### Phase 4: Chat Interface
- Build chat UI (message bubbles, input bar)
- Implement message sending/receiving
- Handle conversation state
- Test basic text conversation with server

### Phase 5: Visual Elements
- Implement flowchart viewer component
- Implement code result viewer with tabs
- Handle different message types in chat
- Polish UI/animations

### Phase 6: Integration & Polish
- End-to-end testing
- Error handling and edge cases
- Loading states and animations
- Performance optimization
- Bug fixes

---

## Technical Decisions & Rationale

### Why Native iOS?
- Best support for chat interfaces (native keyboard handling, gestures)
- Can leverage SwiftUI's List/ScrollView for smooth chat experience
- Native feel for visual elements (flowcharts, code viewers)
- Better performance for real-time chat interactions

### Why Python Server?
- Excellent AI library support (anthropic SDK)
- Easy subprocess management for running tests
- FastAPI is simple, fast, and has great async support for chat

### Why Conversational-First?
- More natural for developers to describe logic in plain language
- Reduces friction compared to drawing flowcharts directly
- AI can ask clarifying questions that humans might forget
- Flowchart becomes a confirmation/visualization tool, not primary input
- Better mobile experience (typing > complex touch gestures for diagramming)

### Why Local Network?
- No cloud infrastructure needed for MVP
- Lower latency for chat responsiveness
- Privacy (code never leaves local network)
- Can deploy server to cloud later if needed

### Why Local LLMs?
- **Privacy-first**: Code never leaves local network
- **Cost-effective**: No API fees for development or usage
- **Fast iteration**: No network latency for conversation
- **Offline capable**: Works without internet connection
- **Model flexibility**: Easy to swap models or add API providers later

### Why Client-Side Conversation?
- **Better UX**: Instant responses from local iPad LLM (Llama 3.2 3B)
- **Efficient**: Smaller model handles conversation, larger model handles code
- **Optimized communication**: Send structured requirements instead of full conversation history
- **Reduced server load**: Server focuses on heavyweight code generation

---

## Open Questions / Decisions Needed

1. **Conversation persistence:** Should conversations persist across app restarts?
   - **Decision:** In-memory for MVP, add persistence in v2

2. **Flowchart editing:** If user wants to change flowchart, do they edit visually or describe changes in chat?
   - **Decision:** Chat-based for MVP (regenerate flowchart), visual editing in v2

3. **Multiple functions:** Can one conversation generate multiple related functions?
   - **Decision:** Single function per conversation for MVP

4. **Code iteration:** If tests fail, how does user request fixes?
   - **Decision:** Start new conversation with context from failed attempt

5. **iPad LLM Model:** Which model to use on iPad?
   - **Suggestion:** Llama 3.2 3B (good balance) or Phi-3.5 Mini (faster, smaller)

6. **Function naming:** Who decides function name - user or iPad LLM?
   - **Decision:** iPad LLM suggests during conversation, user can override

---

## Getting Started

### For Claude Code:

This spec defines a two-part system:
1. iOS/iPad app (Swift/SwiftUI) with conversational chat interface
2. Python server (FastAPI) for AI-powered conversation, flowchart generation, and code generation

Start with **Phase 1** (Server Foundation) as it has no UI dependencies and can be tested independently with curl/Postman.

Initial server directory structure:
```
babyccino-server/
├── main.py                  # FastAPI app and endpoints
├── models.py                # Pydantic models for request/response
├── conversation.py          # Conversation state management
├── generator.py             # Claude API integration (chat, flowchart, code)
├── test_runner.py           # Test execution and parsing
├── complexity.py            # Complexity analysis
├── requirements.txt         # Dependencies
└── .env.example             # ANTHROPIC_API_KEY placeholder
```

Initial iOS app directory structure:
```
Babyccino/
├── Babyccino.xcodeproj
├── Babyccino/
│   ├── BabyccinoApp.swift           # App entry point
│   ├── Views/
│   │   ├── ChatView.swift           # Main chat interface
│   │   ├── MessageBubbleView.swift  # Individual message display
│   │   ├── FlowchartView.swift      # Flowchart visualization
│   │   ├── CodeResultView.swift     # Code with tabs
│   │   └── SettingsView.swift       # Server settings
│   ├── Models/
│   │   ├── Message.swift            # Chat message model
│   │   ├── Conversation.swift       # Conversation state
│   │   ├── FlowchartData.swift      # Flowchart structure
│   │   └── CodeResult.swift         # Generated code result
│   ├── Services/
│   │   └── ServerClient.swift       # API client
│   └── Assets.xcassets
```

### Example Server Test (curl)

```bash
# Health check
curl http://localhost:8000/health

# Generate code from structured requirements
curl -X POST http://localhost:8000/generate-code \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": null,
    "requirements": {
      "name": "is_palindrome",
      "purpose": "Check if a string is a palindrome",
      "parameters": [
        {
          "name": "s",
          "type": "str",
          "description": "The string to check"
        }
      ],
      "return_type": "bool",
      "edge_cases": [
        "Ignore case differences",
        "Ignore spaces and punctuation",
        "Empty string returns True"
      ],
      "examples": [
        {"input": "\"racecar\"", "output": "True"},
        {"input": "\"hello\"", "output": "False"},
        {"input": "\"A man a plan a canal Panama\"", "output": "True"}
      ]
    }
  }'
```

Ready to build! 🚀
