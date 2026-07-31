# agentwrap

agentwrap is a small setup for running [Codex](https://openai.com/codex/) or [Claude Code](https://claude.com/product/claude-code) in a Linux container on Apple silicon Macs using Apple's `container` CLI. It gives the agent an isolated environment while keeping the current project available as its workspace.

> **Disclaimer:** This project is provided as-is, with no warranty of any kind. Use it at your own risk — you're responsible for reviewing the setup and for anything that happens as a result of running it.

## Prerequisites

agentwrap relies on Apple's [`container`](https://github.com/apple/container) CLI, which requires Apple silicon and macOS 15 or later. Broad strokes:

- Install the `container` tool (via the signed installer package or Homebrew).
- Start the container system service with `container system start`.
- Verify it's working with `container system status`.

See Apple's official [installation instructions](https://github.com/apple/container/#get-started) for full setup and troubleshooting details.

## Set up

Build the image for the agent you want (each build produces its own tag):

```sh
container build --target codex -t agentwrap-codex:latest .
container build --target claude -t agentwrap-claude:latest .
```

To avoid typing the full path to `agentwrap.sh` every time, add an alias to your shell config, replacing `/path/to/agentwrap` with the actual path to this repo:

```sh
# ~/.zshrc or ~/.bashrc
alias aw="/path/to/agentwrap/agentwrap.sh"
```

Reload your shell config (`source ~/.zshrc`, or open a new terminal) so the alias is available.

The first time you run either agent you'll need to authenticate inside the container (`/login` for Claude, the Codex login flow for Codex) — this is separate from any login you've already done for the CLI on your host. It only needs to happen once; the credentials are persisted under `~/.agentwrap` on the host — see [Configuration and credentials](#configuration-and-credentials) below.

## Usage

Run it from the project directory you want it to work in:

```sh
aw codex
aw claude
aw codex "Review the authentication flow for security issues"
```

The launcher mounts the current directory at `/workspace`, plus each agent's config/auth directories — see [Configuration and credentials](#configuration-and-credentials) below. It removes the container when the agent exits.

The optional second argument is run non-interactively: the agent executes the
prompt, prints its output, and exits (`claude -p` / `codex exec`).

## Configuration and credentials

The launcher mounts:

- the current directory at `/workspace`
- for Codex: `~/.agentwrap/codex` at `/home/agent/.codex` for configuration and authentication
- for Claude: `~/.agentwrap/claude` at `/home/agent/.claude` and `~/.agentwrap/claude.json` at `/home/agent/.claude.json` for configuration and authentication

The agent can access those mounted locations, but the rest of the host filesystem is not exposed to the container by this project.

These live under a dedicated `~/.agentwrap` directory rather than the CLIs' normal `~/.codex` / `~/.claude` locations, so the container has its own separate login/identity instead of sharing credentials with an agent you run directly on your host. **This separate identity is shared across every container you run for a given agent, not just within a single run** — `aw codex` always mounts the same `~/.agentwrap/codex`, and `aw claude` always mounts the same `~/.agentwrap/claude` / `~/.agentwrap/claude.json`, so containers share login/identity with each other instead of each getting its own. If the container is ever compromised, the blast radius is limited to this throwaway identity, which you can revoke independently of your host session.

They're still mounted directly from the host, not copied, so history and settings persist across runs of the container. Any changes the agent makes inside the container to these files (config edits, credential refreshes, etc.) are written straight back to `~/.agentwrap` on the host, and vice versa — **treat the container's access to these files as equivalent to running the agent directly on your host** with this identity.
