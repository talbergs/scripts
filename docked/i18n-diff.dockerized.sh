#!/bin/bash
#
# Run i18n-diff in Docker
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

set -euo pipefail

IMAGE_NAME="i18n-diff"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

base_sha=""
head_sha=""
head_tag=""
git-refs() {
    if [[ -n "${1:-}" ]]; then
        base_sha=$(git rev-parse --short "$1")
    else
        head_tag=$(git log -1 --format='%s' | sed -n -e 's/.*\[\(.*\)\].*/\1/p')
        if [[ -z "$head_tag" ]]; then
            echo "Error: HEAD commit has no [tag] in message" >&2
            exit 1
        fi

        local recent_merge_sha
        recent_merge_sha=$(git log --grep "$head_tag" --format='%h' --merges | sed 1q)
        if [[ -n "$recent_merge_sha" ]]; then
            base_sha=$(git show "$recent_merge_sha" | sed -n -e '/Merge/p' | cut -d' ' -f 3)
        else
            base_sha=$(git log --grep "$head_tag" --format='%h' | tail -n 1)
        fi
    fi

    if [[ -n "${2:-}" ]]; then
        head_sha=$(git rev-parse --short "$2")
    else
        head_sha=$(git rev-parse --short HEAD)
    fi

    if [[ -n "$head_tag" ]]; then
        echo "Using $head_tag as feature tag found in HEAD($head_sha)." >&2
    fi
    echo "${base_sha} ${head_sha}"
}

# In contrast to git rev-parse --show-toplevel, this works with git-worktree
git-root() {
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    if [[ -z "$git_common_dir" ]]; then
        echo "Error: not in git dir" >&2
        exit 8
    fi
    echo -n "$(cd "$git_common_dir/.." && pwd)"
}

if [ ! -d "$(git-root)/.git" ]; then
    echo "Error: Not in a git repository" >&2
    echo "Please run this from within a git repository" >&2
    exit 1
fi

git-refs "$@"

TMPDIR=/tmp/i18n-diff
[[ -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
mkdir -p "$TMPDIR/result"
mkdir -p "$TMPDIR/head_sha"
mkdir -p "$TMPDIR/base_sha"

# Extract PHP files from each ref
extract_php_files() {
    local ref="$1"
    local target_dir="$2"

    echo "Extracting PHP files from $ref..." >&2

    # Get list of PHP files at this ref
    local php_files
    php_files=$(git ls-tree -r --name-only "$ref" | grep '\.php$' || true)

    if [[ -z "$php_files" ]]; then
        echo "  No PHP files found at $ref" >&2
        return
    fi

    # Extract only PHP files using git archive
    # shellcheck disable=SC2086
    git archive "$ref" $php_files | tar -xf - -C "$target_dir"

    local count
    count=$(echo "$php_files" | wc -l | tr -d ' ')
    echo "  Extracted $count PHP files" >&2
}

# Extract in parallel
extract_php_files "$base_sha" "$TMPDIR/base_sha" &
pid_base=$!
extract_php_files "$head_sha" "$TMPDIR/head_sha" &
pid_head=$!

# Wait for both extractions to complete
wait $pid_base $pid_head

if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1
then
    echo "Image ${IMAGE_NAME}:${IMAGE_TAG} not found, building..." >&2
    "${SCRIPT_DIR}/i18n-diff.build.sh"
fi

# Run container with -d flag to show diff:
#   - Compares translation strings between base_sha and head_sha
#   - "Removed:" = strings in base_sha but not in head_sha (translations deleted)
#   - "Added:" = strings in head_sha but not in base_sha (new translations needed)
#   - Full sorted lists written to /result/ref1.list and /result/ref2.list
docker run --rm --name "$IMAGE_NAME" \
    -v "$TMPDIR/base_sha:/base_sha:ro" \
    -v "$TMPDIR/head_sha:/head_sha:ro" \
    -v "$TMPDIR/result:/result" \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    --diff # script option to show regular string diff
