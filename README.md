# agentwrap

agentwrap is a small setup for running [Codex](https://openai.com/codex/) or [Claude Code](https://claude.com/product/claude-code) in a Linux container on Apple silicon Macs using Apple's `container` CLI. It gives the agent an isolated environment while keeping the current project available as its workspace.

## Usage

Build the image for the agent you want (each build produces its own tag):

```sh
container build --build-arg AGENT=codex -t agentwrap-codex:latest .
container build --build-arg AGENT=claude -t agentwrap-claude:latest .
```

Then run it from the project directory you want it to work in:

```sh
/path/to/codex-virtualized/run.sh codex
/path/to/codex-virtualized/run.sh claude
```

The launcher removes the container when the agent exits and mounts:

- the current directory at `/workspace`
- for Codex: `~/.codex` at `/home/agent/.codex` for configuration and authentication
- for Claude: `~/.claude` at `/home/agent/.claude` and `~/.claude.json` at `/home/agent/.claude.json` for configuration and authentication

The agent can access those mounted locations, but the rest of the host filesystem is not exposed to the container by this project.
