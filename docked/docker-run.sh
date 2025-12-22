#!/bin/bash
#
# Run i18n-diff-2 in Docker
#
# Usage:
#   ./docker-run.sh                    # Auto-detect ticket from HEAD commit
#   ./docker-run.sh --help
#   ./docker-run.sh HEAD~3 HEAD
#   ./docker-run.sh release/7.4 master
#   ./docker-run.sh --json origin/main HEAD
#   ./docker-run.sh --ticket PROJ-123
#   ./docker-run.sh -t JIRA-456 --json
#

set -e

IMAGE_NAME="i18n-diff-2"
IMAGE_TAG="latest"

# Get the current git repository root
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

if [ ! -d "$GIT_ROOT/.git" ]; then
    echo "Error: Not in a git repository" >&2
    echo "Please run this from within a git repository" >&2
    exit 1
fi

# Run the Docker container with the git repo mounted
docker run --rm \
    -v "${GIT_ROOT}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "$@"
