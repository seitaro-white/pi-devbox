# Plan: store Compose state in a host directory

## Goal

Move the Compose image's `/state` from a named volume to a host directory, so
that:

- tool state can be opened directly from the host;
- the Dockerfile, scripts and Makefile no longer seed and check a state volume,
  reducing total complexity and lines of code;
- Compose and the Docker Sandbox shared-storage variant use the same host
  directory layout.

`/workspace` stays a named volume by default, with an optional host directory.

## Agreed constraints

- `/state` is always a host directory.
- `/workspace` defaults to the existing named volume; setting `WORKSPACE_DIR`
  binds a host directory instead. Benchmarked on the user's Mac (Docker Desktop,
  VirtioFS), bind mounts were 10–20× slower for metadata-heavy operations
  (`git status` 8 ms vs 1 ms; scanning ~6,700 files 109 ms vs 6 ms), so the Mac
  keeps the volume. Repositories are on GitHub; host access to them is through
  VS Code "Attach to Running Container" or a host clone.
- Must work on Docker Desktop for macOS now, and on a Linux host later.
- Drop the replacement preflight: `scripts/check-container.mjs`, its test and
  `scripts/check-disposable-files.sh`.
- In-container paths stay `/workspace` and `/state/<tool>`, so tool env vars,
  `~/.pi/agent -> /state/pi` and the Herdr links are unchanged.
- Sandbox: unify the host layout only. The sandbox stays mountless by default;
  its tool paths are not derived at runtime.
- Sidecar volumes (PostgreSQL, Phoenix) are out of scope.
- Herdr's sockets can stay in `/state/herdr/config`: a Unix socket in a bind-mounted
  directory was checked on the user's Mac (Docker Desktop) and works.

## Layout

```
~/pi-box-data/            host directory, mode 0700 (suggested)
  state/      -> /state      STATE_DIR, default ${HOME}/pi-box-data/state
  workspace/  -> /workspace  only if WORKSPACE_DIR is set; otherwise the
                             pi-box-workspace named volume
```

## Changes

### Compose and `.env.example`

`compose.yaml`:

```yaml
    volumes:
      # A host path binds a directory; the default is the named volume below.
      - ${WORKSPACE_DIR:-workspace}:/workspace
      - ${STATE_DIR:-${HOME}/pi-box-data/state}:/state
    build:
      args:
        PI_BOX_UID: ${PI_BOX_UID:-1000}
        PI_BOX_GID: ${PI_BOX_GID:-1000}

volumes:
  workspace:
    name: ${WORKSPACE_VOLUME:-pi-box-workspace}
```

Remove the `state` volume. `.env.example`: `STATE_DIR` replaces `STATE_VOLUME`;
document `WORKSPACE_DIR` (host path only; leave unset for the volume) and
`PI_BOX_UID`/`PI_BOX_GID` for Linux hosts (`id -u`, `id -g`), which Docker
Desktop does not need.

### Dockerfile (`common`, `recommended`)

- `common`: `ARG PI_BOX_UID=1000 PI_BOX_GID=1000`, then `groupmod -g` /
  `usermod -u` on `node` before any `--chown=node` copies (a no-op at the default
  1000). Sandbox stage untouched (sbx requires UID 1000).
- Drop `/state`, `/state/pi` and `/state/herdr/...` from `install -d`. Keep
  `/workspace` (Docker seeds a fresh named volume with its `node` ownership),
  `~/.pi`, `~/.config` and the `~/.pi/agent -> /state/pi` link.
- `recommended`: copy `herdr.toml` to `/opt/pi/defaults/` instead of into `/state`,
  since bind mounts are not seeded from the image. Update the seeding comment.

### Entrypoint

Before `init-git`/`init-agent` (which would otherwise hit the dangling
`~/.pi/agent` link):

```sh
mkdir -p /state/pi
if [ ! -d /state/herdr ]; then
    mkdir -p /state/herdr/config /state/herdr/state
    cp /opt/pi/defaults/herdr.toml /state/herdr/config/config.toml
fi
```

Seeding only when `/state/herdr` is absent keeps today's behaviour: a config the
user deletes is not recreated.

### Makefile and scripts

- Delete `scripts/check-container.mjs`, `scripts/check-disposable-files.sh`,
  `scripts/migrate-state.sh`, `tests/check-container.test.mjs` and
  `tests/fixtures/fake-docker.cjs`.
- Makefile: remove `check` and `migrate`; `replace` and `up` no longer run the
  preflight.

### Migration from the state volume (docs only)

`docs/advanced.md` replaces "State volume migration" with a short host-side
procedure: create the empty directory, stop the container, copy the volume with
one throwaway container, `make up`, verify, then remove the old volume.

```sh
mkdir -m 700 -p ~/pi-box-data/state
docker compose stop pi-box
docker run --rm -u 0 --entrypoint sh \
  -v pi-box-state:/from:ro -v ~/pi-box-data/state:/to pi-box:0.2.0 \
  -c 'cp -a /from/. /to/'
```

Paths inside the container are unchanged, so uv installs keep working. The
workspace volume is untouched. Users still on the older three-volume layout
migrate with the previous release first.

### Sandbox alignment (docs only)

`docs/sandboxes.md` shared storage: rename `repos/` to `workspace/` so the host
directory has the same layout as Compose; note that both can use the same
`state/`, one at a time.

### Docs and guidance

- `README.md`: quick start creates `~/pi-box-data/state` with mode 0700 before
  `docker compose up` (on Linux, Docker would otherwise create it owned by root).
  Storage paragraph: state on the host (readable there, including login tokens),
  workspace in a volume or optionally a host directory, files elsewhere lost on
  replacement. Remove the old migration paragraph.
- `docs/advanced.md`: also note the macOS trade-off for `WORKSPACE_DIR` and
  VS Code "Attach to Running Container" for GUI access to the volume.
- `docs/herdr.md`, `container/skills/pi-box/SKILL.md`, `AGENTS.md` (repo):
  replace state-volume wording and `make migrate`.

### CI and tests

- CI: build `recommended` with `PI_BOX_UID`/`PI_BOX_GID` set to the runner's IDs,
  so the container can write to, and the runner can clean up, test directories.
- `tests/helpers/compose-project.mjs`: set `STATE_DIR` to a 0700 directory inside
  the temporary project directory (cleanup already removes it); keep
  `WORKSPACE_VOLUME`.
- `tests/smoke.mjs`: bind a temporary state directory; keep the workspace volume.
- `tests/compose.mjs`: remove the two refusal steps; replacement keeps storage;
  assert a state file written in the container is visible in `STATE_DIR` on the host.
- `tests/compose-configuration.mjs`: assert the state bind and workspace volume,
  and that setting `WORKSPACE_DIR` binds it instead.
- `tests/herdr-integration.mjs`: assert the state bind instead of a volume name.
- `tests/README.md`: note `PI_BOX_UID`/`PI_BOX_GID` for Linux local runs.

## Open questions

- `groupmod` fails if the requested GID already exists in the image; handle if
  it comes up.

## Expected size

Removes roughly 450 lines (`check-container.mjs` 172, its test 169,
`migrate-state.sh` 91, `check-disposable-files.sh` 9, the fake Docker fixture,
Makefile targets, Dockerfile seeding, the state volume, two refusal test steps).
Adds roughly 25 (entrypoint seeding, UID arguments, `WORKSPACE_DIR`, CI build
args, test directory setup) plus short migration docs.
