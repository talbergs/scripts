#!/bin/bash
#
# i18n-diff-2 - Bash wrapper for compatibility
#
# This wrapper provides a simple interface to the Python-based i18n-diff-2 tool.
# It can be used standalone (if Python dependencies are installed) or via Docker.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/i18n-diff-2.py"

# Check if running in Docker (Python script should be in /usr/local/bin)
if [ -f /usr/local/bin/i18n-diff-2 ]; then
    exec python3 /usr/local/bin/i18n-diff-2 "$@"
# Check if Python script exists locally
elif [ -f "$PYTHON_SCRIPT" ]; then
    exec python3 "$PYTHON_SCRIPT" "$@"
else
    echo "Error: Cannot find i18n-diff-2.py" >&2
    echo "Make sure you're running this script from the correct directory or use Docker." >&2
    exit 1
fi
