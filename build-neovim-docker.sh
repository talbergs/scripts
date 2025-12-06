#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="neovim-nix"
NEOVIMVERSION="004"

echo "🔨 Building Neovim Docker image with Nix..."
echo "📁 Working directory: $SCRIPT_DIR"

cd "$SCRIPT_DIR"

# Build for ARM64 (Apple Silicon)
docker buildx build \
  --platform linux/arm64 \
  -f Dockerfile.neovim \
  -t "${IMAGE_NAME}:${NEOVIMVERSION}" \
  .

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Image built successfully: ${IMAGE_NAME}:${NEOVIMVERSION}"
  echo ""
  echo "Usage examples:"
  echo "  # Open current directory in Neovim:"
  echo "  docker run -it --rm -v \"\$(pwd):/workspace\" ${IMAGE_NAME}:${NEOVIMVERSION}"
  echo ""
  echo "  # Edit a specific file:"
  echo "  docker run -it --rm -v \"\$(pwd):/workspace\" ${IMAGE_NAME}:${NEOVIMVERSION} myfile.txt"
  echo ""
  echo "  # Interactive shell with Neovim available:"
  echo "  docker run -it --rm -v \"\$(pwd):/workspace\" --entrypoint /bin/sh ${IMAGE_NAME}:${NEOVIMVERSION}"
else
  echo ""
  echo "❌ Build failed"
  exit 1
fi
