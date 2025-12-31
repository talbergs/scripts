#!/bin/bash
set -euo pipefail

# Configuration
MODEL="${MODEL:-mistral:latest}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
TEMPERATURE="${TEMPERATURE:-0.7}"
TOP_P="${TOP_P:-0.9}"
TOP_K="${TOP_K:-40}"
NUM_CTX="${NUM_CTX:-4096}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if Ollama is installed
check_ollama() {
    log_info "Checking Ollama installation..."
    if ! command -v ollama &> /dev/null; then
        log_error "Ollama is not installed."
        log_info "Install it with: brew install ollama"
        log_info "Or visit: https://ollama.ai/download"
        exit 1
    fi
    log_success "Ollama is installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
}

# Check if Ollama server is running
check_server() {
    log_info "Checking Ollama server at ${OLLAMA_HOST}..."
    if ! curl -s "${OLLAMA_HOST}/api/tags" > /dev/null 2>&1; then
        log_warn "Ollama server not running. Starting it..."
        ollama serve &> /dev/null &
        sleep 3
        if ! curl -s "${OLLAMA_HOST}/api/tags" > /dev/null 2>&1; then
            log_error "Failed to start Ollama server"
            exit 1
        fi
    fi
    log_success "Ollama server is running"
}

# Ensure model is available
ensure_model() {
    log_info "Checking if model '${MODEL}' is available..."

    if ollama show "${MODEL}" &>/dev/null; then
        log_success "Model '${MODEL}' is already pulled"
    else
        log_info "Pulling model '${MODEL}'... (this may take a while)"
        if ollama pull "${MODEL}"; then
            log_success "Model '${MODEL}' pulled successfully"
        else
            log_error "Failed to pull model '${MODEL}'"
            exit 1
        fi
    fi
}

# Run a prompt with full parameters
run_prompt() {
    local system_prompt="$1"
    local user_prompt="$2"
    local context="${3:-}"

    log_info "Running prompt against ${MODEL}..."
    echo ""

    # Build the JSON payload using jq to properly escape strings
    local payload
    payload=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$user_prompt" \
        --arg system "$system_prompt" \
        --argjson temp "$TEMPERATURE" \
        --argjson top_p "$TOP_P" \
        --argjson top_k "$TOP_K" \
        --argjson num_ctx "$NUM_CTX" \
        --argjson repeat_penalty "$REPEAT_PENALTY" \
        '{
            model: $model,
            prompt: $prompt,
            system: $system,
            stream: false,
            options: {
                temperature: $temp,
                top_p: $top_p,
                top_k: $top_k,
                num_ctx: $num_ctx,
                repeat_penalty: $repeat_penalty
            }
        }')

    # Add context if provided
    if [[ -n "$context" ]]; then
        payload=$(echo "$payload" | jq --arg ctx "$context" '. + {context: $ctx}')
    fi

    # Make the API call
    local response
    response=$(curl -s "${OLLAMA_HOST}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$payload")

    # Extract and return the response
    echo "$response" | jq -r '.response // .error // "No response received"'
}

# Chat-style interaction with message history
run_chat() {
    local system_prompt="$1"
    shift

    # Build messages array from remaining arguments (pairs of role,content)
    local messages_json="[]"
    while [[ $# -gt 1 ]]; do
        local role="$1"
        local content="$2"
        messages_json=$(echo "$messages_json" | jq \
            --arg role "$role" \
            --arg content "$content" \
            '. + [{role: $role, content: $content}]')
        shift 2
    done

    local payload
    payload=$(jq -n \
        --arg model "$MODEL" \
        --argjson messages "$messages_json" \
        --argjson temp "$TEMPERATURE" \
        --argjson top_p "$TOP_P" \
        --argjson top_k "$TOP_K" \
        --argjson num_ctx "$NUM_CTX" \
        --argjson repeat_penalty "$REPEAT_PENALTY" \
        '{
            model: $model,
            messages: $messages,
            stream: false,
            options: {
                temperature: $temp,
                top_p: $top_p,
                top_k: $top_k,
                num_ctx: $num_ctx,
                repeat_penalty: $repeat_penalty
            }
        }')

    local response
    response=$(curl -s "${OLLAMA_HOST}/api/chat" \
        -H "Content-Type: application/json" \
        -d "$payload")

    echo "$response" | jq -r '.message.content // .error // "No response received"'
}

# Simple agent that can be composed
create_agent() {
    local name="$1"
    local system_prompt="$2"

    log_info "Creating agent: ${name}"

    # Return a function-like construct
    echo "AGENT:${name}:${system_prompt}"
}

# Run agent with input
run_agent() {
    local agent_def="$1"
    local input="$2"

    local name
    name=$(echo "$agent_def" | cut -d: -f2)
    local system_prompt
    system_prompt=$(echo "$agent_def" | cut -d: -f3-)

    log_info "Running agent: ${name}"
    run_prompt "$system_prompt" "$input"
}

# Main demonstration
demo() {
    log_info "=== Agent System Demo ==="
    echo ""

    check_ollama
    check_server
    ensure_model

    echo ""
    log_info "=== Example 1: Simple Prompt ==="

    local system="You are a helpful assistant. Be concise and direct."
    local prompt="What are three key principles of good software architecture?"

    echo -e "${YELLOW}System:${NC} $system"
    echo -e "${YELLOW}Prompt:${NC} $prompt"
    echo ""
    echo -e "${GREEN}Response:${NC}"
    run_prompt "$system" "$prompt"

    echo ""
    echo ""
    log_info "=== Example 2: Chat with History ==="

    echo -e "${GREEN}Response:${NC}"
    run_chat "You are a coding assistant." \
        "user" "What is a closure in programming?" \
        "assistant" "A closure is a function that captures variables from its enclosing scope." \
        "user" "Can you give a simple example in JavaScript?"

    echo ""
    echo ""
    log_info "=== Example 3: Agent Chaining ==="

    # Create simple agents
    local analyzer
    analyzer=$(create_agent "Analyzer" "You analyze text and identify key themes. Output only the themes as a bullet list.")

    local summarizer
    summarizer=$(create_agent "Summarizer" "You take a list of themes and create a one-sentence summary.")

    local input_text="The rapid advancement of artificial intelligence has transformed industries from healthcare to finance. Machine learning models are now capable of tasks that were once thought impossible, raising both excitement and concerns about the future of work."

    echo -e "${YELLOW}Input:${NC} $input_text"
    echo ""

    # Run through agent chain
    local themes
    themes=$(run_agent "$analyzer" "$input_text")
    echo -e "${GREEN}Analyzer Output:${NC}"
    echo "$themes"
    echo ""

    local summary
    summary=$(run_agent "$summarizer" "$themes")
    echo -e "${GREEN}Summarizer Output:${NC}"
    echo "$summary"

    echo ""
    log_success "Demo complete!"
}

# Usage help
usage() {
    cat <<EOF
Usage: $0 [command] [options]

Commands:
    demo              Run demonstration of agent capabilities
    prompt            Run a single prompt
    chat              Run a chat interaction
    check             Check Ollama setup
    pull              Ensure model is pulled

Environment Variables:
    MODEL             Model to use (default: mistral:latest)
    OLLAMA_HOST       Ollama server URL (default: http://localhost:11434)
    TEMPERATURE       Sampling temperature (default: 0.7)
    TOP_P             Top-p sampling (default: 0.9)
    TOP_K             Top-k sampling (default: 40)
    NUM_CTX           Context window size (default: 4096)
    REPEAT_PENALTY    Repeat penalty (default: 1.1)

Examples:
    $0 demo
    MODEL=llama2 $0 demo
    $0 prompt "What is 2+2?"
    $0 check
EOF
}

# Entry point
main() {
    local cmd="${1:-demo}"

    case "$cmd" in
        nop) ;;
        demo)
            demo
            ;;
        prompt)
            check_ollama
            check_server
            ensure_model
            shift
            run_prompt "You are a helpful assistant." "${1:-Hello}"
            ;;
        chat)
            check_ollama
            check_server
            ensure_model
            log_info "Starting chat mode... (type 'exit' to quit)"
            # Simple interactive chat
            local history=()
            while true; do
                echo -n "You: "
                read -r input
                [[ "$input" == "exit" ]] && break
                history+=("user" "$input")
                response=$(run_chat "You are a helpful assistant." "${history[@]}")
                echo "Assistant: $response"
                history+=("assistant" "$response")
            done
            ;;
        check)
            check_ollama
            check_server
            ensure_model
            log_success "All checks passed!"
            ;;
        pull)
            check_ollama
            check_server
            ensure_model
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
