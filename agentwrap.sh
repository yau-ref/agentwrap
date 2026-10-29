#! /usr/bin/env bash
set -euo pipefail

DEFAULT_CPUS=1
DEFAULT_MEMORY=512m

usage() {
    echo "Usage: $(basename "$0") [codex|claude] [-r|--resume <session-id>] [-c|--cpus <n>] [-m|--memory <size>] [prompt]" >&2
    echo "       $(basename "$0") build [codex|claude]" >&2
    exit 1
}

build_overlay() {
    local dockerfile="$1" base_image="$2" tag="$3"
    echo "==> Building ${tag} from ${dockerfile} (base: ${base_image})"
    container build \
        --build-arg "BASE_IMAGE=${base_image}" \
        -f "$dockerfile" \
        -t "$tag" \
        .
}

require_system_running() {
    if ! container system status >/dev/null 2>&1; then
        echo "The container system service isn't running." >&2
        echo "Run: container system start then try again." >&2
        exit 1
    fi
}

RESUME_ID=""
CPUS=""
MEMORY=""
ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--resume)
            if [ "$#" -lt 2 ]; then
                usage
            fi
            RESUME_ID="$2"
            shift 2
            ;;
        -c|--cpus)
            if [ "$#" -lt 2 ]; then
                usage
            fi
            CPUS="$2"
            shift 2
            ;;
        -m|--memory)
            if [ "$#" -lt 2 ]; then
                usage
            fi
            MEMORY="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done
set -- "${ARGS[@]}"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

require_system_running

if [ "$1" = "build" ]; then
    if [ -n "$RESUME_ID" ] || [ -n "$CPUS" ] || [ -n "$MEMORY" ]; then
        usage
    fi
    if [ "$#" -ne 2 ]; then
        usage
    fi
    AGENT="$2"
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

    build_overlay "$OVERLAY_DOCKERFILE" "$BASE_IMAGE" "$OVERLAY_TAG"

    echo "$OVERLAY_TAG"
    exit 0
fi

CPUS="${CPUS:-$DEFAULT_CPUS}"
MEMORY="${MEMORY:-$DEFAULT_MEMORY}"

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
        usage
        ;;
esac

if ! container image inspect "$IMAGE" >/dev/null 2>&1; then
    if [ -t 0 ]; then
        BUILD_NOW="n"
        read -r -p "Base image ${IMAGE} is not ready. Build it now? [y/N] " BUILD_NOW || true
        case "$BUILD_NOW" in
            y|Y|yes|Yes)
                "$(dirname "$0")/build.sh" "$AGENT"
                ;;
            *)
                echo "Run: $(dirname "$0")/build.sh ${AGENT} to build it, then try again." >&2
                exit 1
                ;;
        esac
    else
        echo "Base image ${IMAGE} is not ready." >&2
        echo "Run: $(dirname "$0")/build.sh ${AGENT} to build it, then try again." >&2
        exit 1
    fi
fi

OVERLAY_DOCKERFILE=".agentwrap/Dockerfile"
if [ -f "$OVERLAY_DOCKERFILE" ]; then
    HASH="$(shasum -a 256 "$OVERLAY_DOCKERFILE" | cut -c1-12)"
    BASE_IMAGE="$IMAGE"
    OVERLAY_TAG="agentwrap-${AGENT}:overlay-${HASH}"
    if container image inspect "$OVERLAY_TAG" >/dev/null 2>&1; then
        IMAGE="$OVERLAY_TAG"
    elif [ -t 0 ]; then
        BUILD_NOW="n"
        read -r -p "An overlay Dockerfile for agentwrap was found (${OVERLAY_DOCKERFILE}) but the image (${OVERLAY_TAG}) hasn't been built yet. Build it now? [y/N] " BUILD_NOW || true
        case "$BUILD_NOW" in
            y|Y|yes|Yes)
                build_overlay "$OVERLAY_DOCKERFILE" "$BASE_IMAGE" "$OVERLAY_TAG"
                IMAGE="$OVERLAY_TAG"
                ;;
            *)
                echo "Continuing with the base image (${IMAGE})." >&2
                ;;
        esac
    else
        echo "Note: an overlay Dockerfile for agentwrap was found (${OVERLAY_DOCKERFILE}) but the image (${OVERLAY_TAG}) hasn't been built yet." >&2
        echo "Run: $(basename "$0") build ${AGENT}   (from this directory) to build it." >&2
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
    --cpus "$CPUS"
    --memory "$MEMORY"
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
            if [ -n "$RESUME_ID" ]; then
                CONTAINER_ARGS+=(codex exec resume --dangerously-bypass-approvals-and-sandbox "$RESUME_ID" "$PROMPT")
            else
                CONTAINER_ARGS+=(codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT")
            fi
            ;;
        claude)
            if [ -n "$RESUME_ID" ]; then
                CONTAINER_ARGS+=(claude --dangerously-skip-permissions --resume "$RESUME_ID" -p "$PROMPT")
            else
                CONTAINER_ARGS+=(claude --dangerously-skip-permissions -p "$PROMPT")
            fi
            ;;
    esac
else
    case "$AGENT" in
        codex)
            if [ -n "$RESUME_ID" ]; then
                CONTAINER_ARGS+=(codex resume --dangerously-bypass-approvals-and-sandbox "$RESUME_ID")
            else
                CONTAINER_ARGS+=(codex --dangerously-bypass-approvals-and-sandbox)
            fi
            ;;
        claude)
            if [ -n "$RESUME_ID" ]; then
                CONTAINER_ARGS+=(claude --dangerously-skip-permissions --resume "$RESUME_ID")
            else
                CONTAINER_ARGS+=(claude --dangerously-skip-permissions)
            fi
            ;;
    esac
fi

container "${CONTAINER_ARGS[@]}"
