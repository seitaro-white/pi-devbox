### Goal

Implement `plans/host-storage/plan.md`: move the Compose image's `/state` from a
named volume to a host directory (`STATE_DIR`, default
`${HOME}/pi-box-data/state`), keep `/workspace` as a named volume with an
optional `WORKSPACE_DIR` bind, and delete the state-volume seeding, preflight and
migration machinery. The plan is authoritative; `draft.md` is superseded.

### Scope

- In: everything under "Changes" in the plan — `compose.yaml`, `.env.example`,
  Dockerfile (`common`, `recommended`), entrypoint seeding, Makefile and the
  scripts/tests it lists for deletion, docs (`README.md`, `docs/advanced.md`,
  `docs/sandboxes.md`, `docs/herdr.md`, `container/skills/pi-box/SKILL.md`, repo
  `AGENTS.md`), CI build args, and the integration test updates.
- Out: sidecar volumes (PostgreSQL, Phoenix); the sandbox Dockerfile stage and
  any runtime path derivation for the sandbox; new safeguards or checks not in
  the plan.

### Context

- User priorities: less total complexity and code; no extra safeguards. The
  plan expects a net removal of roughly 400+ lines.
- In-container paths stay `/workspace` and `/state/<tool>`; tool env vars,
  `~/.pi/agent -> /state/pi` and Herdr links are unchanged.
- Entrypoint must create `/state/pi` and seed `/state/herdr` (only when absent)
  before `init-git`/`init-agent`.
- `.dockerignore` and `.containerignore` are allowlists: keep them in step if
  build inputs change (e.g. removed scripts).
- Never touch the user's real volumes or containers. There is no Docker socket
  in Pi-box, so integration tests cannot run here; run `npm test` and say
  clearly what was not run.
- Open question from the plan: `groupmod` fails if the GID already exists in the
  image. Handle only if it comes up, and tell me how.

### Done when

- All plan changes are made on branch `host-storage-impl`, committed in logical
  commits.
- `npm test` passes.
- No remaining references to `STATE_VOLUME`, `make migrate`, `make check`,
  `check-container`, `check-disposable-files` or `migrate-state` outside
  `plans/`.
- You report back with a summary, line counts (`git diff --stat main`), and
  anything you could not verify (integration tests, Docker Desktop, Linux).

### Escalate if

- Any plan step turns out unworkable or needs a design change (e.g. the GID
  collision, ownership of a Docker-created `STATE_DIR`, CI permissions).
- You want to add code or checks beyond the plan.
