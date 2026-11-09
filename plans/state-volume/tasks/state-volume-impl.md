### Goal

Implement `plans/state-volume/plan.md` (GitHub issue #43): consolidate the Compose `agent`, `git` and `herdr` volumes into one `/state` volume laid out by tool, add the one-off migration, and update docs and tests.

### Scope

- In: everything under "Changes" in `plans/state-volume/plan.md`: Dockerfile (`common`, `recommended`), `container/gitconfig`, `compose.yaml`, `.env.example`, `scripts/check-container.mjs`, `scripts/migrate-state.sh` and `make migrate`, `docs/sandboxes.md` (docs only), `container/skills/pi-box/SKILL.md`, `README.md`, `docs/*`, and the unit and integration tests and fixtures.
- Out: the sandbox stage, `sbxenv.yaml` and the sandbox's mountless default; image-owned files in `~`; `init-git.mjs`, `init-agent.mjs`. Do not run the migration against real volumes. Ignore `plans/state-volume/draft.md`; `plan.md` is authoritative.

### Context

- Compose is a Docker named volume, not a host bind mount. Keep it that way.
- Docker seeds a fresh named volume from the image tree, so list every `/state` subfolder explicitly in the Dockerfile (owned by `node`, mode 0700).
- `~/.pi/agent` becomes a symlink to `/state/pi`; do not rely on `PI_CODING_AGENT_DIR`.
- Commit in small logical steps on this branch. Follow the `write-code` skill.

### Done when

- All items in `plan.md` "Changes" are implemented, including the Tests section.
- Unit tests pass, and the Docker integration tests pass if they can run in this environment; otherwise say which could not run and why.
- `scripts/migrate-state.sh` is written and reviewed by reading it, with its behaviour checked on throwaway test volumes only.
- Tick the matching boxes in issue #43 as parts complete, then message the orchestrator with a summary.

### Escalate if

- The plan conflicts with what the code actually does, or a layout decision must change.
- Anything would touch the user's real volumes, or needs the host or Docker socket.
- Tests cannot be run, or a failure is not clearly caused by your change.
