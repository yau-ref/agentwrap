#! /usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [codex|claude|all]" >&2
    exit 1
}

if [ "$#" -gt 1 ]; then
    usage
fi

TARGET="${1:-all}"

case "$TARGET" in
    codex|claude)
        TARGETS=("$TARGET")
        ;;
    all)
        TARGETS=(codex claude)
        ;;
    *)
        usage
        ;;
esac

cd "$(dirname "$0")"

for t in "${TARGETS[@]}"; do
    echo "==> Building agentwrap-${t}:latest"
    container build --target "$t" -t "agentwrap-${t}:latest" .
done
