# Babyccino ☕️

Conversational development tool for iPad that helps you design and implement functions through natural conversation, with AI-generated flowcharts and production-ready code.

## Architecture

- **iPad App** (Swift/SwiftUI): Conversational interface with local LLM for requirement gathering and flowchart generation
- **Python Server** (FastAPI): Code generation, testing, and complexity analysis using local LLMs via Ollama

## Features

- 🗣️ Natural conversation about function requirements (on-device)
- 📊 Visual flowchart generation (on-device)
- 💻 Production-ready Python code generation (server)
- ✅ Automatic unit test generation and execution (server)
- 📈 Complexity analysis (Big-O notation)
- 🔒 Fully local - no API calls, privacy-first

## Quick Start

### Server Setup (Mac with Apple Silicon)

```bash
cd server
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Install and start Ollama with DeepSeek Coder
brew install ollama
ollama pull deepseek-coder:33b

# Run server
python -m babyccino_server.main
```

Server runs on `http://0.0.0.0:8000`

### iPad App Setup

Coming in Phase 3 - see [SPEC.md](./SPEC.md)

## Development Status

- ✅ Phase 1: Server Foundation (in progress)
- ⏳ Phase 2: Flowchart & Code Generation
- ⏳ Phase 3: iPad App Shell
- ⏳ Phase 4: Chat Interface
- ⏳ Phase 5: Visual Elements
- ⏳ Phase 6: Integration & Polish

## Repository Structure

```
babyccino/
├── server/              # Python FastAPI server
│   └── babyccino_server/
├── ios/                 # iOS/iPad app (coming soon)
└── SPEC.md             # Full specification
```

## Tech Stack

- **Server**: Python 3.10+, FastAPI, Ollama (DeepSeek Coder 33B)
- **iPad**: Swift, SwiftUI, MLX Swift (Llama 3.2 3B)
- **Communication**: REST API over local network

## License

MIT
