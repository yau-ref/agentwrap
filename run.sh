#! /bin/sh

container run --rm -it \
--volume "$PWD:/workspace" \
--volume "$HOME/.codex:/home/codex/.codex" \
--workdir /workspace \
virtcodex:latest
