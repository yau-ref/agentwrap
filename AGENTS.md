# Agent instructions

- Never build or rebuild container images. The user handles all container builds.
- Do not run `container build`, `docker build`, `podman build`, or any command that implicitly builds an image.
- Validate container-related changes with static checks only unless the user explicitly requests another non-build verification.
