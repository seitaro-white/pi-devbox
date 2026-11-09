# Pi-devbox

Docker image and Compose setup for a Pi dev container. This file is for agents
working on this repository. `container/defaults/AGENTS.md` is different: it ships
in the image as `/AGENTS.md` and guides agents running *inside* Pi-box.

## Layout

- `Dockerfile`: multi-stage; `recommended` (Compose default) and `sandbox` targets.
- `compose*.yaml`: base service plus PostgreSQL, Browserless and Phoenix overlays.
- `container/`: image inputs (entrypoint, init scripts, defaults, the `pi-box` skill).
  `.dockerignore` and `.containerignore` are allowlists: add new build inputs to both.
- `scripts/`: host-side helpers behind `make` (preflight, version check, migration).
- `docs/`, `README.md`: user docs. Keep them in step with behaviour changes.
- `plans/<feature>/`: plans and task briefs; `plan.md` is authoritative over `draft.md`.

## Dependencies

- Pi and extensions: exact versions or full Git commits in `container/package.json`.
  After editing, run `node container/prepare-runtime.mjs` and refresh
  `container/package-lock.json`; commit all three together.
- Standalone tools (Ruff, ty, Herdr, Hunk, gcloud, Terraform): `container/mise.toml`,
  then `mise -C container lock --platform linux-x64,linux-arm64`.
- `make versions` reports outdated npm pins without changing anything.

## Testing

- `npm test`: Node built-ins only, no install or Docker. Run it before committing.
- `npm run test:integration`: Docker acceptance against prebuilt images; see
  `tests/README.md`. There is no Docker socket inside Pi-box, so this runs on the
  host or in CI (AMD64 and ARM64). Say so when you could not run it.

## Safety

- Never touch the user's real volumes or containers. Tests use disposable Compose
  projects; `make up`, `make replace` and `make migrate` end running sessions.
- Never use `docker compose down -v`, and never bake credentials into the image.
