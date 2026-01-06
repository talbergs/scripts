#!/bin/bash
#
# Build the sass Docker image
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="sass"
IMAGE_TAG="latest"

echo "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Building from: $SCRIPT_DIR"
echo ""

docker build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file "${SCRIPT_DIR}/sass.Dockerfile" \
    "${SCRIPT_DIR}"

echo ""
echo "Build complete!"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
