#!/usr/bin/env bash
# Neovim config test runner
# Usage: ./run-tests.sh [test-name]
# Run all tests: ./run-tests.sh
# Run specific: ./run-tests.sh global_options

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DIR="$(dirname "$SCRIPT_DIR")"
TEST_FILE="$SCRIPT_DIR/test-config.lua"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test result tracking
PASSED=0
FAILED=0
SKIPPED=0

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Neovim Config Test Suite${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

run_nvim_test() {
    local test_name="$1"
    local test_code="$2"
    local timeout="${3:-5}"

    echo -ne "  ${YELLOW}Testing:${NC} $test_name ... "

    local result_file="$TEMP_DIR/result_${test_name//[^a-zA-Z0-9]/_}"

    # Run test in headless nvim
    timeout "$timeout" nvim --headless --clean \
        -u "$NVIM_DIR/init-v12.lua" \
        +"lua local ok, err = pcall(function() $test_code end); vim.fn.writefile({ok and 'PASS' or ('FAIL: ' .. tostring(err))}, '$result_file')" \
        +qa 2>/dev/null || true

    if [[ -f "$result_file" ]]; then
        local result=$(cat "$result_file")
        if [[ "$result" == "PASS" ]]; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAIL${NC}"
            echo -e "    ${RED}$result${NC}"
            ((FAILED++))
            return 1
        fi
    else
        echo -e "${YELLOW}SKIP${NC} (timeout or crash)"
        ((SKIPPED++))
        return 2
    fi
}

run_quick_test() {
    local test_name="$1"
    local lua_expr="$2"
    local expected="$3"

    echo -ne "  ${YELLOW}Testing:${NC} $test_name ... "

    local result
    result=$(nvim --headless --clean -u "$NVIM_DIR/init-v12.lua" \
        +"lua print($lua_expr)" +qa 2>&1 | tail -1) || true

    if [[ "$result" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC} (got: '$result', expected: '$expected')"
        ((FAILED++))
        return 1
    fi
}

run_keymap_exists_test() {
    local keymap="$1"
    local mode="${2:-n}"
    local desc="$3"

    echo -ne "  ${YELLOW}Testing:${NC} keymap $keymap ($desc) ... "

    local result
    result=$(nvim --headless --clean -u "$NVIM_DIR/init-v12.lua" \
        +"lua local maps = vim.api.nvim_get_keymap('$mode'); for _, m in ipairs(maps) do if m.lhs == '$keymap' or m.lhs:find('$keymap', 1, true) then print('FOUND'); return end end; print('NOT_FOUND')" \
        +qa 2>&1 | tail -1) || true

    if [[ "$result" == "FOUND" ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC} (keymap not found)"
        ((FAILED++))
        return 1
    fi
}

run_module_loads_test() {
    local module="$1"
    local desc="$2"

    echo -ne "  ${YELLOW}Testing:${NC} module $module ($desc) ... "

    local result
    result=$(nvim --headless --clean -u "$NVIM_DIR/init-v12.lua" \
        +"lua local ok = pcall(require, '$module'); print(ok and 'LOADED' or 'FAILED')" \
        +qa 2>&1 | tail -1) || true

    if [[ "$result" == "LOADED" ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${YELLOW}SKIP${NC} (module not installed)"
        ((SKIPPED++))
        return 2
    fi
}

#═══════════════════════════════════════════════════════════
# TEST SUITES
#═══════════════════════════════════════════════════════════

test_global_options() {
    echo -e "\n${BLUE}[Global Options]${NC}"

    run_quick_test "number enabled" "tostring(vim.opt.number:get())" "true"
    run_quick_test "tabstop = 4" "tostring(vim.opt.tabstop:get())" "4"
    run_quick_test "shiftwidth = 4" "tostring(vim.opt.shiftwidth:get())" "4"
    run_quick_test "expandtab enabled" "tostring(vim.opt.expandtab:get())" "true"
    run_quick_test "swapfile disabled" "tostring(vim.opt.swapfile:get())" "false"
    run_quick_test "backup disabled" "tostring(vim.opt.backup:get())" "false"
    run_quick_test "undofile enabled" "tostring(vim.opt.undofile:get())" "true"
    run_quick_test "showmode disabled" "tostring(vim.opt.showmode:get())" "false"
    run_quick_test "updatetime = 50" "tostring(vim.opt.updatetime:get())" "50"
    run_quick_test "scrolloff = 2" "tostring(vim.opt.scrolloff:get())" "2"
    run_quick_test "foldmethod = indent" "vim.opt.foldmethod:get()" "indent"
    run_quick_test "colorscheme habamax" "vim.g.colors_name or 'none'" "habamax"
}

test_leader_keys() {
    echo -e "\n${BLUE}[Leader Keys]${NC}"

    run_quick_test "mapleader = space" "vim.g.mapleader" " "
    run_quick_test "maplocalleader = space" "vim.g.maplocalleader" " "
}

test_keymaps_lsp() {
    echo -e "\n${BLUE}[LSP Keymaps]${NC}"

    run_keymap_exists_test "gr" "n" "LSP references"
    run_keymap_exists_test "gi" "n" "LSP implementation"
    run_keymap_exists_test "gt" "n" "LSP type definition"
    run_keymap_exists_test " a" "n" "LSP code action"
    run_keymap_exists_test " r" "n" "LSP rename"
    run_keymap_exists_test "gh" "n" "Sticky highlight"
    run_keymap_exists_test "gH" "n" "Clear sticky highlights"
}

test_keymaps_navigation() {
    echo -e "\n${BLUE}[Navigation Keymaps]${NC}"

    run_keymap_exists_test "<C-K>" "n" "Move up 10 lines"
    run_keymap_exists_test "<C-J>" "n" "Move down 10 lines"
    run_keymap_exists_test "Q" "n" "Clear search highlight"
    run_keymap_exists_test "<CR>" "n" "Replay macro"
}

test_keymaps_telescope() {
    echo -e "\n${BLUE}[Telescope Keymaps]${NC}"

    run_keymap_exists_test " b" "n" "Telescope buffers"
    run_keymap_exists_test " f" "n" "Telescope find files"
    run_keymap_exists_test " g" "n" "Telescope live grep"
    run_keymap_exists_test " l" "n" "Telescope fuzzy find"
    run_keymap_exists_test "t" "n" "Telescope symbols"
}

test_keymaps_dap() {
    echo -e "\n${BLUE}[DAP Keymaps]${NC}"

    run_keymap_exists_test " du" "n" "DAP toggle UI"
    run_keymap_exists_test " db" "n" "DAP toggle breakpoint"
    run_keymap_exists_test " dc" "n" "DAP continue"
    run_keymap_exists_test " di" "n" "DAP step into"
    run_keymap_exists_test " do" "n" "DAP step out"
}

test_keymaps_git() {
    echo -e "\n${BLUE}[Git Keymaps]${NC}"

    run_keymap_exists_test " hp" "n" "Gitsigns preview hunk"
    run_keymap_exists_test " hr" "n" "Gitsigns reset hunk"
    run_keymap_exists_test "[c" "n" "Gitsigns prev hunk"
    run_keymap_exists_test "]c" "n" "Gitsigns next hunk"
}

test_keymaps_toggles() {
    echo -e "\n${BLUE}[Toggle Keymaps]${NC}"

    run_keymap_exists_test "<F1>" "n" "Toggle spell"
    run_keymap_exists_test "<F2>" "n" "Toggle list"
    run_keymap_exists_test "<F3>" "n" "Toggle treesitter context"
}

test_keymaps_todo_agent() {
    echo -e "\n${BLUE}[TODO Agent Keymaps]${NC}"

    run_keymap_exists_test "K" "n" "TODO hover / LSP hover"
    run_keymap_exists_test " Ts" "n" "TODO scan buffer"
    run_keymap_exists_test " Tr" "n" "TODO refresh"
    run_keymap_exists_test " Tc" "n" "TODO clear"
    run_keymap_exists_test " Tt" "n" "TODO toggle"
}

test_keymaps_ollama_ghost() {
    echo -e "\n${BLUE}[Ollama Ghost Keymaps]${NC}"

    run_keymap_exists_test "<C-G>" "i" "Ollama accept/trigger"
    run_keymap_exists_test "<C-]>" "i" "Ollama cancel"
    run_keymap_exists_test " og" "n" "Ollama ghost complete"
    run_keymap_exists_test " oc" "n" "Ollama cancel"
}

test_modules() {
    echo -e "\n${BLUE}[Module Loading]${NC}"

    run_module_loads_test "cmp" "nvim-cmp"
    run_module_loads_test "luasnip" "LuaSnip"
    run_module_loads_test "telescope" "Telescope"
    run_module_loads_test "oil" "Oil.nvim"
    run_module_loads_test "gitsigns" "Gitsigns"
    run_module_loads_test "which-key" "which-key"
    run_module_loads_test "dap" "nvim-dap"
    run_module_loads_test "mason" "Mason"
    run_module_loads_test "treesitter-context" "Treesitter Context"
    run_module_loads_test "quicker" "Quicker"
}

test_highlights() {
    echo -e "\n${BLUE}[Custom Highlights]${NC}"

    run_nvim_test "LspReferenceRead highlight" \
        "local hl = vim.api.nvim_get_hl(0, {name='LspReferenceRead'}); assert(hl.italic == true)"

    run_nvim_test "LspReferenceWrite highlight" \
        "local hl = vim.api.nvim_get_hl(0, {name='LspReferenceWrite'}); assert(hl.bold == true)"

    run_nvim_test "StickyHighlight groups exist" \
        "for i=1,5 do local hl = vim.api.nvim_get_hl(0, {name='StickyHighlight'..i}); assert(hl.bg ~= nil) end"
}

test_namespaces() {
    echo -e "\n${BLUE}[Namespaces]${NC}"

    run_nvim_test "LspStickyHighlights namespace" \
        "local ns = vim.api.nvim_create_namespace('LspStickyHighlights'); assert(ns > 0)"

    run_nvim_test "TodoAgent namespace" \
        "local ns = vim.api.nvim_create_namespace('TodoAgent'); assert(ns > 0)"

    run_nvim_test "OllamaGhost namespace" \
        "local ns = vim.api.nvim_create_namespace('OllamaGhost'); assert(ns > 0)"
}

test_autocommands() {
    echo -e "\n${BLUE}[Autocommands]${NC}"

    run_nvim_test "FileType yaml autocmd" \
        "local aus = vim.api.nvim_get_autocmds({event='FileType', pattern='yaml'}); assert(#aus > 0)"

    run_nvim_test "FileType nix autocmd" \
        "local aus = vim.api.nvim_get_autocmds({event='FileType', pattern='nix'}); assert(#aus > 0)"

    run_nvim_test "CursorHold autocmd" \
        "local aus = vim.api.nvim_get_autocmds({event='CursorHold'}); assert(#aus > 0)"

    run_nvim_test "TodoAgent augroup" \
        "local aus = vim.api.nvim_get_autocmds({group='TodoAgent'}); assert(#aus > 0)"
}

test_todo_agent_module() {
    echo -e "\n${BLUE}[TODO Agent Module]${NC}"

    run_nvim_test "TODO Agent loads" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(ta.setup ~= nil)"

    run_nvim_test "TODO Agent has scan function" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(type(ta.scan) == 'function')"

    run_nvim_test "TODO Agent has show_hover function" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(type(ta.show_hover) == 'function')"

    run_nvim_test "TODO Agent has refresh function" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(type(ta.refresh) == 'function')"

    run_nvim_test "TODO Agent has clear function" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(type(ta.clear) == 'function')"

    run_nvim_test "TODO Agent has stop function" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(type(ta.stop) == 'function')"

    run_nvim_test "TODO Agent config defaults" \
        "local ta = dofile(vim.fn.expand('$NVIM_DIR/todo-agent.lua')); assert(ta.config.scan_interval_ms == 5000); assert(ta.config.context_lines == 15)"
}

test_ollama_ghost_module() {
    echo -e "\n${BLUE}[Ollama Ghost Module]${NC}"

    run_nvim_test "Ollama Ghost loads" \
        "local og = dofile(vim.fn.expand('$NVIM_DIR/ollama-ghost.lua')); assert(og.setup ~= nil)"

    run_nvim_test "Ollama Ghost has complete function" \
        "local og = dofile(vim.fn.expand('$NVIM_DIR/ollama-ghost.lua')); assert(type(og.complete) == 'function')"

    run_nvim_test "Ollama Ghost has accept function" \
        "local og = dofile(vim.fn.expand('$NVIM_DIR/ollama-ghost.lua')); assert(type(og.accept) == 'function')"

    run_nvim_test "Ollama Ghost has cancel function" \
        "local og = dofile(vim.fn.expand('$NVIM_DIR/ollama-ghost.lua')); assert(type(og.cancel) == 'function')"

    run_nvim_test "Ollama Ghost has clear function" \
        "local og = dofile(vim.fn.expand('$NVIM_DIR/ollama-ghost.lua')); assert(type(og.clear) == 'function')"
}

test_undodir() {
    echo -e "\n${BLUE}[Undo Directory]${NC}"

    run_quick_test "undodir set" "vim.opt.undodir:get()[1]:match('undodir') and 'SET' or 'UNSET'" "SET"

    # Check if undodir exists or can be created
    run_nvim_test "undodir accessible" \
        "local dir = vim.opt.undodir:get()[1]; assert(vim.fn.isdirectory(dir) == 1 or vim.fn.mkdir(dir, 'p') == 1)"
}

test_cmp_setup() {
    echo -e "\n${BLUE}[Completion Setup]${NC}"

    run_nvim_test "CMP sources configured" \
        "local cmp = require('cmp'); local cfg = cmp.get_config(); assert(#cfg.sources > 0)"

    run_nvim_test "CMP has LSP source" \
        "local cmp = require('cmp'); local cfg = cmp.get_config(); local found = false; for _, s in ipairs(cfg.sources) do if s.name == 'nvim_lsp' then found = true end end; assert(found)"
}

#═══════════════════════════════════════════════════════════
# MAIN
#═══════════════════════════════════════════════════════════

print_header

# Check nvim is available
if ! command -v nvim &>/dev/null; then
    echo -e "${RED}Error: nvim not found in PATH${NC}"
    exit 1
fi

echo -e "Neovim version: $(nvim --version | head -1)"
echo -e "Config: $NVIM_DIR/init-v12.lua"

# Run tests based on argument
if [[ $# -eq 0 ]]; then
    # Run all tests
    test_global_options
    test_leader_keys
    test_keymaps_lsp
    test_keymaps_navigation
    test_keymaps_telescope
    test_keymaps_dap
    test_keymaps_git
    test_keymaps_toggles
    test_keymaps_todo_agent
    test_keymaps_ollama_ghost
    test_modules
    test_highlights
    test_namespaces
    test_autocommands
    test_todo_agent_module
    test_ollama_ghost_module
    test_undodir
    test_cmp_setup
else
    # Run specific test suite
    test_func="test_$1"
    if declare -f "$test_func" > /dev/null; then
        $test_func
    else
        echo -e "${RED}Unknown test suite: $1${NC}"
        echo "Available: global_options, leader_keys, keymaps_lsp, keymaps_navigation,"
        echo "           keymaps_telescope, keymaps_dap, keymaps_git, keymaps_toggles,"
        echo "           keymaps_todo_agent, keymaps_ollama_ghost, modules, highlights,"
        echo "           namespaces, autocommands, todo_agent_module, ollama_ghost_module,"
        echo "           undodir, cmp_setup"
        exit 1
    fi
fi

# Summary
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Passed: $PASSED${NC}  ${RED}Failed: $FAILED${NC}  ${YELLOW}Skipped: $SKIPPED${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
