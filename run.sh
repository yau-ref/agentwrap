#! /usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $(basename "$0") [codex|claude]" >&2
    exit 1
fi
AGENT="$1"

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
        echo "Usage: $(basename "$0") [codex|claude]" >&2
        exit 1
        ;;
esac

container run --rm -it \
    --volume "$PWD:/workspace" \
    "${VOLUMES[@]}" \
    --workdir /workspace \
    "$IMAGE"
