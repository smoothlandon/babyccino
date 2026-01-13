# Babyccino Server

FastAPI server for code generation, testing, and complexity analysis.

## Setup

### Prerequisites

- Python 3.10 or higher
- [Ollama](https://ollama.ai/) installed
- Apple Silicon Mac (M1/M2/M3/M4) recommended for optimal performance

### Installation

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your settings
```

4. Pull the DeepSeek Coder model:
```bash
ollama pull deepseek-coder:33b
```

### Running the Server

```bash
python -m babyccino_server.main
```

Server will be available at `http://0.0.0.0:8000`

### Testing

```bash
# Health check
curl http://localhost:8000/health

# Generate code (example)
curl -X POST http://localhost:8000/generate-code \
  -H "Content-Type: application/json" \
  -d @test_request.json
```

## API Endpoints

### `GET /health`
Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0",
  "llm_provider": "ollama",
  "model": "deepseek-coder:33b"
}
```

### `POST /generate-code`
Generate code, tests, and complexity analysis from structured requirements.

**Request:**
```json
{
  "conversation_id": "uuid",
  "requirements": {
    "name": "is_prime",
    "purpose": "Check if a number is prime",
    "parameters": [
      {"name": "n", "type": "int", "description": "number to check"}
    ],
    "return_type": "bool",
    "edge_cases": ["n < 2 returns False"],
    "examples": [
      {"input": "2", "output": "True"}
    ]
  }
}
```

**Response:**
```json
{
  "conversation_id": "uuid",
  "code": {
    "function": "def is_prime(n: int) -> bool:...",
    "tests": {
      "code": "def test_is_prime():...",
      "results": [...],
      "summary": "3 passed, 0 failed"
    },
    "complexity": {
      "time": "O(√n)",
      "space": "O(1)",
      "explanation": "..."
    }
  }
}
```

## Architecture

- **LLM Client Abstraction**: Easy to swap between Ollama, Anthropic, OpenAI
- **Code Generation**: DeepSeek Coder for high-quality Python code
- **Test Execution**: Isolated subprocess for running pytest
- **Complexity Analysis**: LLM-based Big-O analysis

## Development

```bash
# Install dev dependencies
pip install -r requirements-dev.txt

# Run tests
pytest

# Format code
black babyccino_server/
ruff check babyccino_server/
```
