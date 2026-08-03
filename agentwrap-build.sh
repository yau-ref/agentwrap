#! /usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [codex|claude]" >&2
    echo "Run from the project directory containing .agentwrap/Dockerfile" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    usage
fi

AGENT="$1"

case "$AGENT" in
    codex|claude)
        ;;
    *)
        usage
        ;;
esac

OVERLAY_DOCKERFILE=".agentwrap/Dockerfile"

if [ ! -f "$OVERLAY_DOCKERFILE" ]; then
    echo "No ${OVERLAY_DOCKERFILE} found in $(pwd)." >&2
    exit 1
fi

HASH="$(shasum -a 256 "$OVERLAY_DOCKERFILE" | cut -c1-12)"
BASE_IMAGE="agentwrap-${AGENT}:latest"
OVERLAY_TAG="agentwrap-${AGENT}:overlay-${HASH}"

echo "==> Building ${OVERLAY_TAG} from ${OVERLAY_DOCKERFILE} (base: ${BASE_IMAGE})"
container build \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    -f "$OVERLAY_DOCKERFILE" \
    -t "$OVERLAY_TAG" \
    .

echo "$OVERLAY_TAG"
