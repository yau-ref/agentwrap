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
        mkdir -p "$HOME/.agentwrap/codex"
        VOLUMES=(--volume "$HOME/.agentwrap/codex:/home/agent/.codex")
        ;;
    claude)
        IMAGE="agentwrap-claude:latest"
        mkdir -p "$HOME/.agentwrap/claude"
        [ -f "$HOME/.agentwrap/claude.json" ] || : > "$HOME/.agentwrap/claude.json"
        VOLUMES=(
            --volume "$HOME/.agentwrap/claude:/home/agent/.claude"
            --volume "$HOME/.agentwrap/claude.json:/home/agent/.claude.json"
        )
        ;;
    *)
        echo "Usage: $(basename "$0") [codex|claude] [prompt]" >&2
        exit 1
        ;;
esac

OVERLAY_DOCKERFILE=".agentwrap/Dockerfile"
if [ -f "$OVERLAY_DOCKERFILE" ]; then
    HASH="$(shasum -a 256 "$OVERLAY_DOCKERFILE" | cut -c1-12)"
    OVERLAY_TAG="agentwrap-${AGENT}:overlay-${HASH}"
    if container images inspect "$OVERLAY_TAG" >/dev/null 2>&1; then
        IMAGE="$OVERLAY_TAG"
    else
        echo "Note: ${OVERLAY_DOCKERFILE} found but ${OVERLAY_TAG} hasn't been built." >&2
        echo "Run: agentwrap-build.sh ${AGENT}   (from this directory) to build it." >&2
        echo "Continuing with the base image (${IMAGE})." >&2
    fi
fi

if [ "$#" -eq 2 ]; then
    # No stdin attached: an open, never-closing stdin makes `codex exec`
    # hang on "Reading additional input from stdin...".
    TTY_FLAG=()
else
    TTY_FLAG=(-it)
fi

CONTAINER_ARGS=(
    run --rm "${TTY_FLAG[@]+"${TTY_FLAG[@]}"}"
    --volume "$PWD:/workspace"
    "${VOLUMES[@]}"
    --workdir /workspace
    "$IMAGE"
)

# The container is already the sandbox boundary, so let the agent skip its
# own approval prompts instead of asking twice.
if [ "$#" -eq 2 ]; then
    case "$AGENT" in
        codex)
            CONTAINER_ARGS+=(codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT")
            ;;
        claude)
            CONTAINER_ARGS+=(claude --dangerously-skip-permissions -p "$PROMPT")
            ;;
    esac
else
    case "$AGENT" in
        codex)
            CONTAINER_ARGS+=(codex --dangerously-bypass-approvals-and-sandbox)
            ;;
        claude)
            CONTAINER_ARGS+=(claude --dangerously-skip-permissions)
            ;;
    esac
fi

container "${CONTAINER_ARGS[@]}"
