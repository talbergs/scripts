#!/bin/bash
#
# Build the i18n-diff-2 Docker image
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="i18n-diff-2"
IMAGE_TAG="latest"

echo "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Building from: $SCRIPT_DIR"
echo ""

# Use timestamp to bust cache and ensure latest code is copied
CACHEBUST=$(date +%s)

docker build \
    --build-arg CACHEBUST="${CACHEBUST}" \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file "${SCRIPT_DIR}/i18n-diff-2.Dockerfile" \
    "${SCRIPT_DIR}"

echo ""
echo "Build complete!"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Test it with:"
echo "  ./docker-run.sh --help"
echo "  ./docker-run.sh --ticket YOUR-TICKET-123"
