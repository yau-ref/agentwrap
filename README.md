# Codex Virtualized

Codex Virtualized is a small setup for running [Codex](https://openai.com/codex/) in a Linux container on Apple silicon Macs using Apple's `container` CLI. It gives Codex an isolated environment while keeping the current project available as its workspace.

## Usage

Build the image:

```sh
container build -t virtcodex:latest .
```

Then run Codex from the project directory you want it to work in:

```sh
/path/to/codex-virtualized/run.sh
```

The launcher removes the container when Codex exits and mounts:

- the current directory at `/workspace`
- `~/.codex` at `/home/codex/.codex` for Codex configuration and authentication

Codex can access those mounted locations, but the rest of the host filesystem is not exposed to the container by this project.
