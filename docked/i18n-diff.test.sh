#!/bin/bash
#
# Test suite for i18n-diff
#

set -euo pipefail

IMAGE_NAME="i18n-diff"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1
then
    echo "Image ${IMAGE_NAME}:${IMAGE_TAG} not found, building..." >&2
    "${SCRIPT_DIR}/i18n-diff.build.sh"
fi

mk-case() {
    local test_tmpdir=/tmp/i18n-diff-test
    [[ -d "$test_tmpdir" ]] && rm -rf "$test_tmpdir"

    mkdir -p "$test_tmpdir/result"
    mkdir -p "$test_tmpdir/head_sha"
    mkdir -p "$test_tmpdir/base_sha"

    if [[ ! -f "$1" ]] || [[ ! -f "$2" ]]; then
        echo "Error: Input files do not exist" >&2
        return 1
    fi

    cp "$1" "$test_tmpdir/head_sha/file.php"
    cp "$2" "$test_tmpdir/base_sha/file.php"

    docker run --rm --name "$IMAGE_NAME" \
        -v "$test_tmpdir/base_sha:/base_sha:ro" \
        -v "$test_tmpdir/head_sha:/head_sha:ro" \
        -v "$test_tmpdir/result:/result" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        --diff # script option to show regular string diff
}

mk-case \
    <(echo '<?php _("Base");_("Base");') \
    <(echo '<?php _("Base");_("Bose");')
