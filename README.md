# agentwrap

agentwrap is a small setup for running [Codex](https://openai.com/codex/) or [Claude Code](https://claude.com/product/claude-code) in a Linux container on Apple silicon Macs using Apple's `container` CLI. It gives the agent an isolated environment while keeping the current project available as its workspace.

## Prerequisites

agentwrap relies on Apple's [`container`](https://github.com/apple/container) CLI, which requires Apple silicon and macOS 15 or later. Broad strokes:

- Install the `container` tool (via the signed installer package or Homebrew).
- Start the container system service with `container system start`.
- Verify it's working with `container system status`.

See Apple's official [installation instructions](https://github.com/apple/container/#get-started) for full setup and troubleshooting details.

## Usage

Build the image for the agent you want (each build produces its own tag):

```sh
container build --target codex -t agentwrap-codex:latest .
container build --target claude -t agentwrap-claude:latest .
```

Then run it from the project directory you want it to work in:

```sh
/path/to/codex-virtualized/agentwrap.sh codex
/path/to/codex-virtualized/agentwrap.sh claude
```

The launcher removes the container when the agent exits and mounts:

- the current directory at `/workspace`
- for Codex: `~/.codex` at `/home/agent/.codex` for configuration and authentication
- for Claude: `~/.claude` at `/home/agent/.claude` and `~/.claude.json` at `/home/agent/.claude.json` for configuration and authentication

The agent can access those mounted locations, but the rest of the host filesystem is not exposed to the container by this project.

These are mounted directly from the host, not copied, so that history and settings persist across runs and you can switch smoothly between running the agent raw on your host and running it inside agentwrap.

**Warning:** as a consequence, at least for now, any changes the agent makes inside the container to `~/.codex`, `~/.claude`, or `~/.claude.json` (config edits, credential refreshes, etc.) are written straight back to the host, and vice versa. Treat the container's access to these files as equivalent to running the agent directly on your host.

For Claude, the first time you run the container you may need to run `/login` inside it to authenticate. This only needs to happen once — the credentials are persisted to `~/.claude` / `~/.claude.json` on the host via the mounts above, and logging in inside the container does not log you out of Claude on macOS.

## Shell alias

To avoid typing the full path to `agentwrap.sh` every time, add an alias to your shell config, replacing `/path/to/agentwrap` with the actual path to this repo:

```sh
# ~/.zshrc or ~/.bashrc
alias aw="/path/to/agentwrap/agentwrap.sh"
```

Reload your shell config (`source ~/.zshrc`, or open a new terminal), then run:

```sh
aw codex
aw claude
aw codex "Review the authentication flow for security issues"
```

The optional second argument is run non-interactively: the agent executes the
prompt, prints its output, and exits (`claude -p` / `codex exec`).
