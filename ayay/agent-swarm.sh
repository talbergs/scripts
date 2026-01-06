#!/bin/bash
bindir="$(cd "$(dirname "$0")";pwd)"
agent="$bindir/agent.sh"
source "$agent" nop # source env

prompt() {
    MODEL="${MODEL:-mistral:latest}" \
    OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}" \
    TEMPERATURE="${TEMPERATURE:-0.7}" \
    TOP_P="${TOP_P:-0.9}" \
    TOP_K="${TOP_K:-40}" \
    NUM_CTX="${NUM_CTX:-4096}" \
    REPEAT_PENALTY="${REPEAT_PENALTY:-1.1}" "$agent" prompt "$@"
}

log_info "===  ==="
# @CLAUDE_TODO using the available api (functions) in *.sh files here, strategize and deliver a dynamic and observable system that spawns and chains agent prompts with dynamic contexts and dynamic prompts in order to achieve code quality measures.
