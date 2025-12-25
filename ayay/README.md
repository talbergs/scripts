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

<details>
<summary><strong>Models by Characteristic (7B-30B)</strong></summary>

### Code Generation & Understanding
*Stand-out: Trained specifically on code, understand syntax and patterns*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `deepseek-coder:6.7b` | 3.8 GB | Multi-language support, strong at completions |
| `codellama:7b` | 3.8 GB | Meta's code-focused Llama, great for refactoring |

```bash
MODEL=deepseek-coder:6.7b ./agent.sh prompt "Write a Python async HTTP client"
```

### Reasoning & Logic
*Stand-out: Chain-of-thought, math, and complex problem solving*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `llama3.1:8b` | 4.7 GB | Strong logical reasoning, follows instructions well |
| `mistral:7b` | 4.1 GB | Excellent at multi-step reasoning tasks |

```bash
MODEL=llama3.1:8b ./agent.sh prompt "Explain step by step how to solve: 3x + 7 = 22"
```

### Instruction Following
*Stand-out: Precise adherence to prompts, structured output*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `mistral-nemo:12b` | 7.1 GB | Exceptional at following complex instructions |
| `neural-chat:7b` | 4.1 GB | Fine-tuned for accurate task completion |

```bash
MODEL=mistral-nemo:12b ./agent.sh prompt "List exactly 5 bullet points about REST APIs"
```

### Creative Writing
*Stand-out: Natural language flow, storytelling, varied vocabulary*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `llama3.1:8b` | 4.7 GB | Diverse writing styles, good narrative structure |
| `mistral:7b` | 4.1 GB | Fluent prose, creative responses |

```bash
TEMPERATURE=0.9 MODEL=llama3.1:8b ./agent.sh prompt "Write a haiku about debugging"
```

### Long Context Processing
*Stand-out: Handle large documents, maintain coherence over many tokens*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `mistral-nemo:12b` | 7.1 GB | 128K context window |
| `yi:34b` | 19 GB | 200K context, strong document analysis |

```bash
NUM_CTX=32768 MODEL=mistral-nemo:12b ./agent.sh prompt "Summarize this document..."
```

### Speed & Efficiency
*Stand-out: Fast inference, lower resource usage*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `phi3:3.8b` | 2.2 GB | Microsoft's efficient small model |
| `gemma2:9b` | 5.4 GB | Google's optimized architecture |

```bash
MODEL=phi3:3.8b ./agent.sh prompt "Quick answer: what is dependency injection?"
```

### Multilingual
*Stand-out: Strong performance across multiple languages*

| Model | Size | Why It Excels |
|-------|------|---------------|
| `qwen2:7b` | 4.4 GB | Excellent Chinese/English, broad language support |
| `aya:8b` | 4.8 GB | Cohere's 23-language model |

```bash
MODEL=qwen2:7b ./agent.sh prompt "Translate to French: The code works perfectly"
```

</details>

<details>
<summary><strong>Configuration Parameters Explained</strong></summary>

### OLLAMA_HOST
**What it does:** Sets the Ollama API endpoint URL.

**Default:** `http://localhost:11434`

**Purpose:** Connect to Ollama running on a different machine or port.

```bash
# Local (default)
OLLAMA_HOST=http://localhost:11434 ./agent.sh demo

# Remote server
OLLAMA_HOST=http://192.168.1.100:11434 ./agent.sh demo

# Custom port
OLLAMA_HOST=http://localhost:8080 ./agent.sh demo
```

---

### TEMPERATURE
**What it does:** Controls randomness in token selection. Higher = more creative/random, lower = more focused/deterministic.

**Default:** `0.7` | **Range:** `0.0 - 2.0`

**How it affects results:**
- `0.0-0.3`: Factual, consistent, repetitive - best for code, math, factual Q&A
- `0.4-0.7`: Balanced creativity and coherence - good for most tasks
- `0.8-1.2`: Creative, varied - good for writing, brainstorming
- `1.3+`: Highly random, may produce nonsense

```bash
# Precise, deterministic (code generation)
TEMPERATURE=0.1 ./agent.sh prompt "Write a binary search function"

# Balanced (general tasks)
TEMPERATURE=0.7 ./agent.sh prompt "Explain microservices"

# Creative (storytelling)
TEMPERATURE=1.0 ./agent.sh prompt "Write a short story about a robot"
```

---

### TOP_P (Nucleus Sampling)
**What it does:** Limits token selection to the smallest set whose cumulative probability exceeds P. Filters out unlikely tokens.

**Default:** `0.9` | **Range:** `0.0 - 1.0`

**How it affects results:**
- `0.1-0.5`: Very focused, only most likely tokens considered
- `0.7-0.9`: Good balance, filters extreme outliers
- `1.0`: All tokens considered (disabled)

```bash
# Focused output (technical writing)
TOP_P=0.5 ./agent.sh prompt "Document this API endpoint"

# More variety allowed
TOP_P=0.95 ./agent.sh prompt "Suggest project names for a CLI tool"
```

**Tip:** Usually adjust either TEMPERATURE or TOP_P, not both heavily.

---

### TOP_K
**What it does:** Limits selection to the K most likely next tokens. Hard cutoff vs TOP_P's probability-based cutoff.

**Default:** `40` | **Range:** `1 - 100+`

**How it affects results:**
- `1-10`: Very constrained, predictable output
- `20-40`: Balanced, good default
- `50-100`: More diversity, may reduce coherence

```bash
# Highly constrained (structured output)
TOP_K=10 ./agent.sh prompt "List the HTTP methods"

# More options (brainstorming)
TOP_K=80 ./agent.sh prompt "What could cause this bug?"
```

---

### NUM_CTX (Context Window)
**What it does:** Sets the maximum number of tokens the model can process (input + output combined).

**Default:** `4096` | **Common values:** `2048, 4096, 8192, 16384, 32768`

**How it affects results:**
- Larger = can handle longer documents, more conversation history
- Larger = more RAM usage, slower inference
- Too small = truncated input, lost context

**Performance impact:**
| NUM_CTX | RAM Overhead (7B model) | Speed Impact |
|---------|------------------------|--------------|
| 2048 | ~4 GB | Fastest |
| 4096 | ~5 GB | Default |
| 8192 | ~7 GB | Moderate |
| 16384 | ~10 GB | Slower |
| 32768 | ~16 GB | Slowest |

```bash
# Short interactions (faster)
NUM_CTX=2048 ./agent.sh prompt "What is REST?"

# Long document analysis
NUM_CTX=16384 ./agent.sh prompt "Summarize this entire codebase..."

# Maximum context for supported models
NUM_CTX=32768 MODEL=mistral-nemo:12b ./agent.sh prompt "Analyze this log file..."
```

---

### REPEAT_PENALTY
**What it does:** Penalizes the model for repeating tokens it has already generated. Reduces loops and repetitive output.

**Default:** `1.1` | **Range:** `1.0 - 2.0`

**How it affects results:**
- `1.0`: No penalty (may get stuck in loops)
- `1.1`: Light penalty, good default
- `1.3-1.5`: Strong penalty, more varied vocabulary
- `1.5+`: May produce unnatural word choices

```bash
# Default (balanced)
REPEAT_PENALTY=1.1 ./agent.sh prompt "Explain recursion"

# Reduce repetition in long outputs
REPEAT_PENALTY=1.3 ./agent.sh prompt "Write a detailed tutorial on Git"

# No penalty (if you need exact repetition)
REPEAT_PENALTY=1.0 ./agent.sh prompt "Repeat after me: hello world"
```

---

### Combined Examples

```bash
# Code generation: precise, focused, no repetition
TEMPERATURE=0.2 TOP_P=0.8 TOP_K=20 REPEAT_PENALTY=1.1 \
  MODEL=deepseek-coder:6.7b ./agent.sh prompt "Implement quicksort in Python"

# Creative writing: varied, expressive
TEMPERATURE=0.9 TOP_P=0.95 TOP_K=60 REPEAT_PENALTY=1.2 \
  MODEL=llama3.1:8b ./agent.sh prompt "Write a poem about the ocean"

# Long document analysis: large context, focused output
NUM_CTX=16384 TEMPERATURE=0.3 TOP_P=0.85 \
  MODEL=mistral-nemo:12b ./agent.sh prompt "Summarize the key points of this document"

# Fast Q&A: small context, efficient
NUM_CTX=2048 TEMPERATURE=0.5 TOP_K=30 \
  MODEL=phi3:3.8b ./agent.sh prompt "What is the difference between TCP and UDP?"
```

</details>

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
