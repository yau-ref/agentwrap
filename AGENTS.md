# Agent instructions

- Never build or rebuild container images unless explicitly asked by the user.
- Do not run `container build`, `docker build`, `podman build`, or any command that implicitly builds an image unless explicitly requested by the user.
- Validate container-related changes with static checks only unless the user explicitly requests another non-build verification.
