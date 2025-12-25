#!/bin/bash
#
# i18n-diff: Extract translation strings from PHP files using tree-sitter
#
# Extracts gettext function calls with proper argument handling:
#   _s(msgid)                -> extract arg 1
#   _n(singular, plural, n)  -> extract args 1, 2
#   _x(msgid, context)       -> extract arg 1
#   _xs(msgid, context)      -> extract arg 1
#   _xn(sing, plur, n, ctx)  -> extract args 1, 2
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERY_FILE="${QUERY_FILE:-${SCRIPT_DIR}/i18n-php-gettext.scm}"

REF1_DIR="${REF1_DIR:-/base_sha}"
REF2_DIR="${REF2_DIR:-/head_sha}"
RESULT_DIR="${RESULT_DIR:-/result}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Extract translation strings from PHP files and generate diff lists.

Options:
    -1, --ref1 DIR     Base/old reference directory (default: /base_sha)
    -2, --ref2 DIR     Head/new reference directory (default: /head_sha)
    -o, --output DIR   Output directory (default: /result)
    -q, --query FILE   Tree-sitter query file (default: translations.scm)
    -d, --diff         Show diff between ref1 and ref2
    -h, --help         Show this help message

Output files:
    <output>/ref1.list  - Strings from ref1
    <output>/ref2.list  - Strings from ref2
EOF
    exit 0
}

SHOW_DIFF=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -1|--ref1) REF1_DIR="$2"; shift 2 ;;
        -2|--ref2) REF2_DIR="$2"; shift 2 ;;
        -o|--output) RESULT_DIR="$2"; shift 2 ;;
        -q|--query) QUERY_FILE="$2"; shift 2 ;;
        -d|--diff) SHOW_DIFF=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Verify tree-sitter is available
if ! command -v tree-sitter &>/dev/null; then
    echo "Error: tree-sitter CLI not found" >&2
    exit 1
fi

# Verify query file exists
if [[ ! -f "$QUERY_FILE" ]]; then
    echo "Error: Query file not found: $QUERY_FILE" >&2
    exit 1
fi

mkdir -p "$RESULT_DIR"

# Extract string content from quoted PHP string
# Handles: 'single', "double", and concatenation "foo" . "bar"
parse_string_value() {
    local raw="$1"
    # Remove leading/trailing whitespace
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"

    # Handle concatenation: split on " . " or ' . ' and join
    if [[ "$raw" == *'" . "'* ]] || [[ "$raw" == *"' . '"* ]]; then
        local result=""
        local IFS='.'
        for part in $raw; do
            part="${part#"${part%%[![:space:]]*}"}"
            part="${part%"${part##*[![:space:]]}"}"
            # Strip quotes
            if [[ "$part" =~ ^\"(.*)\"$ ]]; then
                result+="${BASH_REMATCH[1]}"
            elif [[ "$part" =~ ^\'(.*)\'$ ]]; then
                result+="${BASH_REMATCH[1]}"
            fi
        done
        echo "$result"
    elif [[ "$raw" =~ ^\"(.*)\"$ ]]; then
        # Double-quoted string - handle escapes
        local content="${BASH_REMATCH[1]}"
        content="${content//\\\"/\"}"
        content="${content//\\n/$'\n'}"
        content="${content//\\t/$'\t'}"
        echo "$content"
    elif [[ "$raw" =~ ^\'(.*)\'$ ]]; then
        # Single-quoted string
        local content="${BASH_REMATCH[1]}"
        content="${content//\\\'/\'}"
        echo "$content"
    else
        # Skip variables, complex expressions
        return 1
    fi
}

# Run tree-sitter query and extract strings
extract_strings() {
    local dir="$1"
    local tmpfile
    tmpfile=$(mktemp)

    # Find all PHP files and run tree-sitter query
    find "$dir" -name '*.php' -type f | while read -r phpfile; do
        tree-sitter query "$QUERY_FILE" "$phpfile" 2>/dev/null || true
    done > "$tmpfile"

    # Parse tree-sitter output
    # Format: "  capture_name: `text`" or multi-line with row/col info
    local current_func=""
    local arg_count=0

    while IFS= read -r line; do
        # Detect function name capture
        if [[ "$line" =~ _fn:\ \`([^\']+)\` ]]; then
            current_func="${BASH_REMATCH[1]}"
            arg_count=0
        # Detect argument captures
        elif [[ "$line" =~ arg[12]:\ \`(.+)\`$ ]]; then
            local arg_text="${BASH_REMATCH[1]}"
            ((arg_count++)) || true

            # Determine if we should extract this argument
            local should_extract=false
            case "$current_func" in
                _s|_x|_xs)
                    [[ $arg_count -eq 1 ]] && should_extract=true
                    ;;
                _n|_xn)
                    [[ $arg_count -le 2 ]] && should_extract=true
                    ;;
            esac

            if $should_extract; then
                if parsed=$(parse_string_value "$arg_text"); then
                    echo "$parsed"
                fi
            fi
        fi
    done < "$tmpfile"

    rm -f "$tmpfile"
}

# Process ref1 if it exists
if [[ -d "$REF1_DIR" ]]; then
    echo "Processing $REF1_DIR..." >&2
    extract_strings "$REF1_DIR" | sort -u > "$RESULT_DIR/ref1.list"
    echo "  Found $(wc -l < "$RESULT_DIR/ref1.list" | tr -d ' ') unique strings" >&2
else
    echo "Warning: $REF1_DIR does not exist, skipping" >&2
    : > "$RESULT_DIR/ref1.list"
fi

# Process ref2 if it exists
if [[ -d "$REF2_DIR" ]]; then
    echo "Processing $REF2_DIR..." >&2
    extract_strings "$REF2_DIR" | sort -u > "$RESULT_DIR/ref2.list"
    echo "  Found $(wc -l < "$RESULT_DIR/ref2.list" | tr -d ' ') unique strings" >&2
else
    echo "Warning: $REF2_DIR does not exist, skipping" >&2
    : > "$RESULT_DIR/ref2.list"
fi

# Show diff if requested
if [[ "$SHOW_DIFF" == "true" ]]; then
    echo "" >&2
    echo "=== Diff ===" >&2

    removed=$(comm -23 "$RESULT_DIR/ref1.list" "$RESULT_DIR/ref2.list")
    if [[ -n "$removed" ]]; then
        echo "Removed:"
        echo "$removed" | sed 's/^/  - /'
    fi

    added=$(comm -13 "$RESULT_DIR/ref1.list" "$RESULT_DIR/ref2.list")
    if [[ -n "$added" ]]; then
        echo "Added:"
        echo "$added" | sed 's/^/  + /'
    fi

    if [[ -z "$removed" && -z "$added" ]]; then
        echo "No changes in translation strings"
    fi
fi

echo "" >&2
echo "Results written to:" >&2
echo "  $RESULT_DIR/ref1.list" >&2
echo "  $RESULT_DIR/ref2.list" >&2
