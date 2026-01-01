#!/bin/bash
# vim: foldmethod=marker
#
# i18n-diff: Extract translation strings from PHP files using tree-sitter
#
# Extracts gettext function calls with proper argument handling:
#   _(msgid)                 -> extract arg 1
#   _s(msgid)                -> extract arg 1
#   _n(singular, plural, n)  -> extract args 1, 2
#   _x(msgid, context)       -> extract arg 1
#   _xs(msgid, context)      -> extract arg 1
#   _xn(sing, plur, n, ctx)  -> extract args 1, 2
#
set -euo pipefail

# {{{ pt.1
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
    -h, --help         Show this help message

Output files:
    <output>/ref1.list  - Strings from ref1
    <output>/ref2.list  - Strings from ref2
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -1|--ref1) REF1_DIR="$2"; shift 2 ;;
        -2|--ref2) REF2_DIR="$2"; shift 2 ;;
        -o|--output) RESULT_DIR="$2"; shift 2 ;;
        -q|--query) QUERY_FILE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -d "$REF1_DIR" ]]
then
    echo "Option error: --ref1 $REF1_DIR does not exist" >&2
    exit 4
fi

if [[ ! -d "$REF2_DIR" ]]
then
    echo "Option error: --ref2 $REF2_DIR does not exist" >&2
    exit 4
fi

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
# }}}

# {{{ pt.2
extract_strings() {
    tree-sitter query \
        --paths $1 \
        "$QUERY_FILE" \
    | grep 'capture: [12]' | sed 's/.*`\(.*\)`/\1/'
}

extract_strings \
    <(find "$REF1_DIR" -name '*.php' -type f) \
    | sort -u > "$RESULT_DIR/ref1.list" &
ref1_pid=$!

extract_strings \
    <(find "$REF2_DIR" -name '*.php' -type f) \
    | sort -u > "$RESULT_DIR/ref2.list" &
ref2_pid=$!

wait $ref1_pid $ref2_pid

diff=$(diff "$RESULT_DIR/ref1.list" "$RESULT_DIR/ref2.list")
added=$(echo "$diff" | grep '^> ')
removed=$(echo "$diff" | grep '^< ')

if [[ -z "$added$removed" ]]
then
    echo "No string changes."
    exit 0
fi

if [[ ! -z "$added" ]]
then
    echo "Strings added:"
    echo "$added" | sed "s/.*'\(.*\)'/-_\1_/"
fi

if [[ ! -z "$removed" ]]
then
    echo "Strings removed:"
    echo "$removed" | sed "s/.*'\(.*\)'/-_\1_/"
fi
# }}}
