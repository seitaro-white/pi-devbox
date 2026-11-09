# Plan: store Compose workspace and state in a host directory

## Goal

Replace the Compose image's two named volumes (`/workspace`, `/state`) with
bind mounts from one host directory, so that:

- files can be opened directly from the host, including with GUI tools;
- the Dockerfile, scripts and Makefile no longer create, seed and check named
  volumes, reducing total complexity and lines of code;
- Compose and the Docker Sandbox shared-storage variant use the same host
  directory layout.

## Agreed constraints

- Both `workspace` and `state` move to the host. Benchmarked on the user's Mac
  (Docker Desktop, VirtioFS): `npm install` 8.4 s vs 8.6 s on a named volume;
  `git status` 8 ms vs 1 ms; scanning ~6,700 files 109 ms vs 6 ms. Metadata-heavy
  operations are ~10–20× slower but small in absolute terms; accepted.
- Must work on Docker Desktop for macOS now, and on a Linux host later.
- Drop the replacement preflight: `scripts/check-container.mjs`, its test and
  `scripts/check-disposable-files.sh`.
- In-container paths stay `/workspace` and `/state/<tool>`, so tool env vars,
  `~/.pi/agent -> /state/pi` and the Herdr links are unchanged.
- Sandbox: unify the host layout only. The sandbox stays mountless by default;
  its tool paths are not derived at runtime.
- Sidecar volumes (PostgreSQL, Phoenix) are out of scope.

## Layout

```
$PI_BOX_DATA/             host directory, mode 0700 (default ${HOME}/pi-box-data)
  workspace/  -> /workspace
  state/      -> /state      (pi/, git/, gcloud/, claude/, uv/, herdr/ as today)
```

## Changes

### Compose and `.env.example`

- `compose.yaml`: replace the named volumes with
  `${PI_BOX_DATA:-${HOME}/pi-box-data}/workspace:/workspace` and `.../state:/state`.
  Remove the top-level `volumes:` block.
- Add `build.args: { PI_BOX_UID: ${PI_BOX_UID:-1000}, PI_BOX_GID: ${PI_BOX_GID:-1000} }`.
- `.env.example`: `PI_BOX_DATA` replaces `WORKSPACE_VOLUME` and `STATE_VOLUME`;
  document `PI_BOX_UID`/`PI_BOX_GID` for Linux hosts (`id -u`, `id -g`), not
  needed on Docker Desktop.

### Dockerfile (`common`, `recommended`)

- `common`: `ARG PI_BOX_UID=1000 PI_BOX_GID=1000`, then
  `groupmod -g` / `usermod -u` on `node` (skipped when already 1000), before any
  `--chown=node` copies. Sandbox stage untouched (sbx requires UID 1000).
- Drop `/workspace`, `/state`, `/state/pi`, `/state/herdr/...` from `install -d`;
  keep `~/.pi`, `~/.config` and the `~/.pi/agent -> /state/pi` link.
- `recommended`: drop the `COPY ... herdr.toml /state/herdr/config/config.toml`
  (bind mounts are not seeded from the image); copy it to `/opt/pi/defaults/` instead.
  Remove the "Docker seeds a fresh state volume" comment.

### Entrypoint

Before `init-git`/`init-agent` (which would otherwise hit the dangling
`~/.pi/agent` link):

```sh
mkdir -p /state/pi
if [ ! -d /state/herdr ]; then   # recommended image only
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

### Migration from named volumes (docs only)

`docs/advanced.md` replaces "State volume migration" with a short host-side
procedure: create the empty directory, stop the container, copy both volumes with
one throwaway container, `make up`, verify, then remove the old volumes.

```sh
mkdir -m 700 -p ~/pi-box-data
docker compose stop pi-box
docker run --rm -u 0 --entrypoint sh \
  -v pi-box-workspace:/from/workspace:ro -v pi-box-state:/from/state:ro \
  -v ~/pi-box-data:/to pi-box:0.2.0 -c 'cp -a /from/. /to/'
```

Paths inside the container are unchanged, so uv installs keep working. Users
still on the older three-volume layout migrate with the previous release first.

### Sandbox alignment (docs only)

`docs/sandboxes.md` shared storage: rename `repos/` to `workspace/` so the host
directory has the same layout as Compose; note that both can use the same
directory, one at a time.

### Docs and guidance

- `README.md`: quick start creates `~/pi-box-data/{workspace,state}` with mode
  0700 before `docker compose up`; storage paragraph describes the host directory,
  that it is readable from the host (including login tokens), and that files
  outside it are lost on replacement. Remove the old migration paragraph.
- `docs/advanced.md`, `docs/herdr.md`, `container/skills/pi-box/SKILL.md`,
  `AGENTS.md` (repo): replace volume wording and `make migrate`.

### CI and tests

- CI: build `recommended` with `PI_BOX_UID`/`PI_BOX_GID` set to the runner's
  IDs, so the container can write to, and the runner can clean up, test directories.
- `tests/helpers/compose-project.mjs`: set `PI_BOX_DATA` to a 0700 directory
  inside the temporary project directory; cleanup removes it.
- `tests/smoke.mjs`: bind temporary directories instead of creating volumes.
- `tests/compose.mjs`: remove the two refusal steps; replacement keeps storage;
  assert a file written in the container is visible in the host directory.
- `tests/compose-configuration.mjs`, `tests/herdr-integration.mjs`: assert bind
  mounts from `PI_BOX_DATA` instead of volume names.
- `tests/README.md`: note `PI_BOX_UID`/`PI_BOX_GID` for Linux local runs.

## Open questions

- Herdr keeps `herdr.sock` and `herdr-client.sock` in `/state/herdr/config`.
  Unix sockets on Docker Desktop bind mounts must be checked live on the Mac.
  If they fail, move the sockets out of the bind mount (Herdr option to be found).
- `groupmod` fails if the requested GID already exists in the image; handle if
  it comes up.
