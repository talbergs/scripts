# Fish Config v42

Minimal, transient fish shell configuration with informative prompts.

## Features

**Transient Prompt** - Previous commands show minimal `⊱⋅` prompt, current line shows full context.

**Left Prompt**
- Background jobs list with status (`◆` running, `◇` stopped)
- Exit code on failure (`× code`)
- Full PWD with `~` home substitution
- Git branch + state (REBASING, MERGING, CHERRY-PICKING, BISECTING)

**Right Prompt** (two lines)
- Shell depth chain: `zsh › fish (lvl 2)`
- Command duration with timestamps: `2025-12-22 [14:30:00 → 14:30:24](~24s)`

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl-Z` | Bring background job to foreground |
| `Ctrl-F` | Fuzzy file picker (fd + fzf) |

## Functions

- `pwd:get` - cd to last used directory (persisted across sessions)
- `l` - ls with details, sorted by time
- `h` - merge shell history

## Abbreviations

`g` git, `gst` status, `ga` add, `gc` commit, `gp` push, `gb` branch, `gd` diff, `gr` remote, `gco` checkout, `glog` log, `+x` chmod +x, `rmf` rm -rf

## Icons

```
⋕  root prompt
⊱⋅ user prompt
◆  running job
◇  stopped job
×  failed command
›  shell chain
```

## Auto-Completion Generator (Ollama)

Generates Fish completions for binaries that lack them using local Ollama 7B model.

### Two-Phase System

**Phase 1 (Stub)** - Fast, creates minimal completion structure
```bash
fish_generate_completions phase1
```

**Phase 2 (Inference)** - Uses Ollama to generate intelligent completions
```bash
fish_generate_completions phase2
```

**Installation** - Copies generated completions to Fish config
```bash
fish_generate_completions install
```

**Full workflow**
```bash
fish_generate_completions all
```

### Architecture

- **completions-generator.fish** - Main two-phase orchestrator, PATH scanning, stub generation
- **parallel-inference.fish** - Parallel/piped inference strategies, job queue, smart composition
- **gen-completions** - Entry point alias

Uses parallel inference with intelligent composition:
- Single binary → piped strategy (refinement)
- Few binaries (≤5) → batched inference
- Many binaries → parallel individual jobs

### Configuration

Edit in `completions-generator.fish`:
```fish
set -g OLLAMA_MODEL llama2  # Change to your 7B model name
set -g MAX_CONCURRENT_JOBS 2  # Adjust parallelism
```

## Requirements

- fish shell
- fd (file finder)
- fzf (fuzzy finder)
- git
- ollama (for completion generation)
