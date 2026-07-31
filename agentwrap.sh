#! /usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $(basename "$0") [codex|claude] [prompt]" >&2
    exit 1
fi
AGENT="$1"
PROMPT="${2:-}"

case "$AGENT" in
    codex)
        IMAGE="agentwrap-codex:latest"
        VOLUMES=(--volume "$HOME/.codex:/home/agent/.codex")
        ;;
    claude)
        IMAGE="agentwrap-claude:latest"
        mkdir -p "$HOME/.claude"
        [ -f "$HOME/.claude.json" ] || : > "$HOME/.claude.json"
        VOLUMES=(
            --volume "$HOME/.claude:/home/agent/.claude"
            --volume "$HOME/.claude.json:/home/agent/.claude.json"
        )
        ;;
    *)
        echo "Usage: $(basename "$0") [codex|claude] [prompt]" >&2
        exit 1
        ;;
esac

CONTAINER_ARGS=(
    run --rm -it
    --volume "$PWD:/workspace"
    "${VOLUMES[@]}"
    --workdir /workspace
    "$IMAGE"
)

if [ "$#" -eq 2 ]; then
    CONTAINER_ARGS+=("$AGENT" "$PROMPT")
fi

container "${CONTAINER_ARGS[@]}"
