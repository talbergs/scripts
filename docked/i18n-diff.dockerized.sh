#!/bin/bash
# Run i18n-diff in Docker
#
# Usage:
#   ./$0                    # Auto-detect ticket from HEAD commit
#   ./$0 -- --help          # Args to entrypoint.sh
#   ./$0 HEAD~3             # Implicit HEAD
#   ./$0 HEAD~3 HEAD        # Commitish expression parsed
#   ./$0 release/7.4 master # Refs, sha, tags.
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
        recent_merge_sha=$(git log --grep "$head_tag" --format='%h' --merges -1)
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

trail-args() {
	local found=false
	for arg in "$@"; do
		if [[ "$found" == true ]]; then
			echo -n "$arg "
		elif [[ "$arg" == "--" ]]; then
			found=true
		fi
	done
}

lead-args() {
	local count=0
	for arg in "$@"; do
		[[ "$arg" == "--" ]] && break
		echo -n "$arg "
		((count++)) || true
		[[ $count -ge 2 ]] && break
	done
}

git-refs $(lead-args "$@")

# Extract only changed PHP files between base_sha and head_sha
extract_php_files() {
    local ref="$1"
    local target_dir="$2"

    echo "Extracting changed PHP files from $ref..." >&2

    # Get list of PHP files that changed between base and head
    local changed_files
    changed_files=$(git diff --name-only "$base_sha" "$head_sha" -- '*.php' || true)

    if [[ -z "$changed_files" ]]; then
        echo "  No changed PHP files between $base_sha and $head_sha" >&2
        return
    fi

    # Filter to files that exist at this ref (handles added/deleted files)
    local php_files=""
    while IFS= read -r file; do
        if git cat-file -e "$ref:$file" 2>/dev/null; then
            php_files+="$file"$'\n'
        fi
    done <<< "$changed_files"
    php_files=$(echo "$php_files" | sed '/^$/d')

    if [[ -z "$php_files" ]]; then
        echo "  No PHP files exist at $ref" >&2
        return
    fi

    # Extract only changed PHP files using git archive
    # shellcheck disable=SC2086
    echo "$php_files" | xargs git archive "$ref" -- | tar -xf - -C "$target_dir"

    local count
    count=$(echo "$php_files" | wc -l | tr -d ' ')
    echo "  Extracted $count changed PHP files" >&2
}

TMPDIR="$PWD/i18n-diff.tmp"
[[ -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
mkdir -p "$TMPDIR/$IMAGE_NAME.result"
mkdir -p "$TMPDIR/$IMAGE_NAME.head_sha"
mkdir -p "$TMPDIR/$IMAGE_NAME.base_sha"

# Extract in parallel
extract_php_files "$base_sha" "$TMPDIR/$IMAGE_NAME.base_sha" &
pid_base=$!
extract_php_files "$head_sha" "$TMPDIR/$IMAGE_NAME.head_sha" &
pid_head=$!

# Wait for both extractions to complete
wait $pid_base $pid_head

if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1
then
    echo "Image ${IMAGE_NAME}:${IMAGE_TAG} not found, building..." >&2
    "${SCRIPT_DIR}/$IMAGE_NAME.build.sh"
fi

args="$(trail-args "$@")"
if [ -z "$args" ]
then
    args="-1 /base_sha -2 /head_sha"
	echo "
         - Compares translation strings between $base_sha (base_sha) and $head_sha (head_sha)
         - \"Added:\" = strings in head_sha but not in base_sha (new translations needed)
         - \"Removed:\" = strings in base_sha but not in head_sha (translations deleted)
         - Full sorted lists written to $TMPDIR/$IMAGE_NAME.result/
    " 1>&2
fi

docker run -ti --rm --name "$IMAGE_NAME" \
    -v "$TMPDIR/$IMAGE_NAME.base_sha:/base_sha:ro" \
    -v "$TMPDIR/$IMAGE_NAME.head_sha:/head_sha:ro" \
    -v "$TMPDIR/$IMAGE_NAME.result:/result" \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    $args
