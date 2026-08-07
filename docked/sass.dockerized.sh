#!/bin/bash
# Run sass to build Zabbix themes and assets
# Uses local sass if available, falls back to Docker
#
# Usage:
#   ./$0    # Compile all themes and copy assets
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SASS_DIR="${SASS_DIR:-sass/stylesheets/sass}"
CSS_DIR="${CSS_DIR:-ui/assets/styles}"

if [ ! -d "$SASS_DIR" ]; then
    echo "Error: sass directory not found: $SASS_DIR" >&2
    exit 1
fi

echo "Source: $SASS_DIR/"
echo "Output: $CSS_DIR/"
echo ""

# Detect sass runner: local binary first, Docker as fallback
SASS_CMD=""
IMAGE_NAME="sass"
IMAGE_TAG="latest"
if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1; then
    echo "Image ${IMAGE_NAME}:${IMAGE_TAG} not found, building..." >&2
    "${SCRIPT_DIR}/${IMAGE_NAME}.build.sh"
fi
echo "Using Docker sass"

# Build all themes
THEMES=(
    "hc-dark"
    "hc-light"
    "dark-theme"
    "blue-theme"
    "dark-classic-theme"
    "blue-classic-theme"
)

echo "Compiling themes..."
for theme in "${THEMES[@]}"; do
    if [ -f "${SASS_DIR}/${theme}.scss" ]; then
        echo "  ${theme}.scss -> ${theme}.css"
        if [ "$SASS_CMD" = "sass" ]; then
            sass --no-source-map --quiet "${SASS_DIR}/${theme}.scss" "${CSS_DIR}/${theme}.css"
        elif [ "$SASS_CMD" = "sassc" ]; then
            sassc "${SASS_DIR}/${theme}.scss" "${CSS_DIR}/${theme}.css"
        else
            docker run --rm \
                -v "$PWD:/workspace" \
                -w /workspace \
                "${IMAGE_NAME}:${IMAGE_TAG}" \
                --no-cache --sourcemap=none \
                "${SASS_DIR}/${theme}.scss" "${CSS_DIR}/${theme}.css"
        fi
    fi
done

echo ""
echo "Done."
