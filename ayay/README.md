 Core Features:
  - Ollama integration - Checks installation, starts server if needed, pulls models
  - Simple prompts - run_prompt() sends a system + user prompt to the LLM
  - Chat mode - run_chat() supports multi-turn conversations with message history
  - Agent abstraction - create_agent() and run_agent() let you define named agents with specific system prompts
  - Agent chaining - chain_agents() pipes output from one agent to the next

  Commands:
  | Command | Description                |
  |---------|----------------------------|
  | demo    | Runs a full demonstration  |
  | prompt  | Single prompt execution    |
  | chat    | Interactive chat session   |
  | check   | Verify Ollama setup        |
  | pull    | Ensure model is downloaded |

  Configuration via env vars:
  - MODEL (default: mistral:latest)
  - OLLAMA_HOST, TEMPERATURE, TOP_P, TOP_K, NUM_CTX, REPEAT_PENALTY

  It's a lightweight way to run local LLM agents from the command line, with support for chaining multiple specialized agents together.
  (e.g., an "Analyzer" agent feeding into a "Summarizer" agent).

## Real-World Example: Code Review Pipeline

```bash
# Create specialized agents for code review
reviewer=$(create_agent "CodeReviewer" "You review code for bugs, security issues, and best practices. List issues found.")
suggester=$(create_agent "Suggester" "You take a list of code issues and provide specific fix suggestions with code examples.")

# Review a code snippet
code_to_review=$(cat my_script.py)
issues=$(run_agent "$reviewer" "$code_to_review")
fixes=$(run_agent "$suggester" "$issues")
echo "$fixes"
```

Other use cases:
- **Document processing**: Summarizer -> Translator -> Formatter chain
- **Data analysis**: Extractor -> Analyzer -> Report Generator
- **Content creation**: Outliner -> Writer -> Editor pipeline

## Privacy & Local Execution

All LLM inference runs **entirely on your local machine** via Ollama.
Your prompts and data never leave your computer - no API calls to external services, no cloud processing.

While the agents themselves could theoretically execute shell commands or access the web (if you extend them), the base framework:
- Uses only local HTTP calls to `localhost:11434` (Ollama)
- Stores no data externally
- Requires no internet connection after model download

This makes it suitable for processing sensitive data, proprietary code, or any content you don't want shared with third-party AI providers.

## Recommended Models

| Model | Size | RAM Required | Best For |
|-------|------|--------------|----------|
| `mistral:7b` | 4.1 GB | 8 GB | General purpose, good balance of speed/quality |
| `llama3.2:3b` | 2.0 GB | 8 GB | Fast responses, lighter tasks |
| `llama3.1:8b` | 4.7 GB | 8 GB | Strong reasoning, coding |
| `codellama:7b` | 3.8 GB | 8 GB | Code generation and review |
| `deepseek-coder:6.7b` | 3.8 GB | 8 GB | Code-focused tasks |
| `mistral-nemo:12b` | 7.1 GB | 16 GB | Higher quality, slower |
| `llama3.1:70b` | 40 GB | 64 GB | Best quality, requires high-end hardware |

```bash
# Switch models via environment variable
MODEL=llama3.2:3b ./agent.sh demo
MODEL=deepseek-coder:6.7b ./agent.sh prompt "Review this Python function..."
```

## Hardware Recommendations

### Apple Silicon Macs
| Machine | RAM | Recommended Models |
|---------|-----|-------------------|
| MacBook Air M1/M2 (2022-2024) | 8 GB | 3B models, 7B with slower inference |
| MacBook Pro M1/M2/M3 (2022-2024) | 16 GB | 7B-12B models comfortably |
| MacBook Pro M2/M3 Pro/Max (2023-2025) | 32 GB+ | Up to 30B models |
| Mac Studio M2 Ultra (2023-2025) | 64 GB+ | 70B models feasible |

### Windows/Linux Laptops
| Machine | Specs | Recommended Models |
|---------|-------|-------------------|
| ThinkPad T14 Gen 3+ | 16 GB RAM, Intel/AMD | 7B models (CPU inference) |
| ThinkPad P16/P1 Gen 5+ | 32 GB RAM, RTX 3000+ | 7B-12B with GPU acceleration |
| Dell XPS 15 (2022+) | 16 GB RAM, RTX 3050 | 7B models with GPU |
| Dell Precision 5680/7680 | 32-64 GB, RTX 4000+ | Up to 30B models |

**Performance tips:**
- Apple Silicon uses unified memory - the entire RAM is available for models
- NVIDIA GPUs significantly accelerate inference (install CUDA for Ollama)
- For CPU-only inference, expect ~10-20 tokens/sec on 7B models
- SSD storage recommended for faster model loading
