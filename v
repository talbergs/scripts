#!/bin/bash

# Neovim in Docker wrapper script
# Usage: v [file1] [file2] ...

set -e

NEOVIMVERSION="004"
IMAGE_NAME="neovim-nix:${NEOVIMVERSION}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Docker is available
if ! which build-neovim-docker.sh &> /dev/null; then
    echo "❌ Docker is not available. Will install in 3..2..1."
    sleep 3
    [ $1 != "stop" ] && \
    setup-docker.sh && $0 stop
fi


# Check if image exists, build if not
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "📦 Image '$IMAGE_NAME' not found. Building..."
    cd "$SCRIPT_DIR"
    ./build-neovim-docker.sh
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build image"
        exit 1
    fi
fi

# Get the current working directory
HOST_PWD="$(pwd)"

# Determine mount strategy
# Strategy 1: Mount to /workspace (simple, reliable)
CONTAINER_WORKDIR="/workspace"
MOUNT_ARGS="-v ${HOST_PWD}:${CONTAINER_WORKDIR}"

# Strategy 2: One-to-one mapping (uncomment to enable)
# This mounts the host path to the same path in container
# Useful for LSP servers and tools that use absolute paths
# Note: Requires creating parent directories in container
if [[ "$HOST_PWD" == /Users/* ]] || [[ "$HOST_PWD" == /home/* ]]; then
    CONTAINER_WORKDIR="$HOST_PWD"
    MOUNT_ARGS="-v ${HOST_PWD}:${CONTAINER_WORKDIR}"
fi

# Process file arguments
# Convert absolute paths to container paths
CONTAINER_ARGS=()
for arg in "$@"; do
    if [[ "$arg" == /* ]]; then
        # Absolute path on host - convert to container path
        if [[ "$arg" == ${HOST_PWD}/* ]]; then
            # Path is within PWD
            REL_PATH="${arg#${HOST_PWD}/}"
            CONTAINER_ARGS+=("${CONTAINER_WORKDIR}/${REL_PATH}")
        else
            # Path is outside PWD - warn and use as-is
            echo "⚠️  Warning: '$arg' is outside current directory"
            CONTAINER_ARGS+=("$arg")
        fi
    else
        # Relative path - use as-is
        CONTAINER_ARGS+=("$arg")
    fi
done

# If no arguments, open current directory
if [ ${#CONTAINER_ARGS[@]} -eq 0 ]; then
    CONTAINER_ARGS=(".")
fi

# Run Neovim in Docker
# -it: Interactive with TTY
# --rm: Remove container after exit
# -w: Set working directory
# Mount current directory and run neovim
exec docker run -it --rm \
    -w "$CONTAINER_WORKDIR" \
    $MOUNT_ARGS \
    -e "TERM=${TERM:-xterm-256color}" \
    "$IMAGE_NAME" \
    "${CONTAINER_ARGS[@]}"
