# Docker Sandboxes

Optional micro-VM deployment using native experimental `sbx env` commands
(tested with sbx v0.49.2 on macOS only). sbx supports macOS 14+ on Apple Silicon,
Windows 11 and Ubuntu 24.04+ with KVM. Compose remains the primary workflow.

The default sandbox is mountless. Files and login survive stop/start;
**deleting the sandbox deletes its internal data**. Local sbx does not support
reattachable named volumes; [shared storage](#optional-shared-storage) is optional.

## One-time host setup (macOS)

```bash
brew trust docker/tap
brew install docker/tap/sbx
sbx login
```

For a fresh network policy:

```bash
sbx policy init allow-all
```

For an existing policy, add outbound access with `sbx policy allow network '**'`.
These are host-global settings; explicit denies still apply. Sandbox processes
can transmit any data they can read, including Pi login tokens.

To disable SSH-agent forwarding, finish other sandbox sessions, then run:

```bash
sbx settings set ssh.agentForwardingEnabled false
sbx daemon restart
```

For host-proxied GitHub access:

```bash
gh auth login
sbx secret set github --command 'gh auth token'
```

The resolver keeps the GitHub token on the host while permitting authenticated
requests from the sandbox.

## Create and use

In `sbxenv.yaml`, set `agent` to your checkout directory's name. The sandbox name
is separately configured as `pi-sandbox`.

Run from the checkout:

```bash
sbx env plan ./sbxenv.yaml
sbx env create ./sbxenv.yaml
sbx env exec -it ./sbxenv.yaml -- bash -l
```

Creation builds the local kit from `pi-box.yaml` and the `Dockerfile`'s `sandbox` stage, selected by the `PI_BOX_TARGET` build argument.
It defaults to 4 CPUs/4 GiB RAM, stays running after clients disconnect, and
starts no Pi or tmux session automatically.

Inside:

```bash
cd ~/workspace
git clone https://github.com/OWNER/REPOSITORY.git
cd REPOSITORY
git config --global user.name 'Your Name'
git config --global user.email 'you@example.com'
pi
```

Use Pi `/login` → OpenAI/Codex. Login tokens are stored inside the sandbox and
readable by its processes. Web/search providers need separate authentication.

## Everyday commands

```bash
sbx env run --detach ./sbxenv.yaml         # create/start in background
sbx env exec -it ./sbxenv.yaml -- bash -l # open shell
sbx env exec -it ./sbxenv.yaml -- pi      # run Pi
sbx ls
sbx stop pi-sandbox                      # retain files, end processes
```

Manage tmux manually, e.g. `tmux new-session -A -s dev`. For remote use, SSH to
the hosting Mac and run the same commands. The Mac must remain awake and online;
stop/reboot ends live processes.

## Optional shared storage

Share a dedicated host directory to retain repositories and tool state
independently of sandbox deletion. This variant has not been live-tested here.

On the host:

```bash
mkdir -p /absolute/path/to/pi-box-data/workspace \
  /absolute/path/to/pi-box-data/state/{pi,git/gh,gcloud,claude}
chmod -R 700 /absolute/path/to/pi-box-data
```

Create private `sbxenv.local.yaml` beside `sbxenv.yaml`:

```yaml
name: pi-sandbox-shared
workspace: /absolute/path/to/pi-box-data
env:
  PI_CODING_AGENT_DIR: /absolute/path/to/pi-box-data/state/pi
  GIT_CONFIG_GLOBAL: /absolute/path/to/pi-box-data/state/git/config
  GH_CONFIG_DIR: /absolute/path/to/pi-box-data/state/git/gh
  CLOUDSDK_CONFIG: /absolute/path/to/pi-box-data/state/gcloud
  CLAUDE_CONFIG_DIR: /absolute/path/to/pi-box-data/state/claude
```

The directory is shared read-write at the same absolute path. `workspace/` holds
checkouts; `state/<tool>/` holds Pi, Git/GitHub, gcloud and Claude state. This
optional variant uses `PI_CODING_AGENT_DIR`; Compose instead links `~/.pi/agent`
to `/state/pi`. Omit `env` to share only repositories. Other user-installed tools
remain sandbox-local. Compose and this variant can use the same host `state/`
directory, one at a time.

Use both files for every environment command:

```bash
sbx env plan ./sbxenv.yaml ./sbxenv.local.yaml
sbx env create ./sbxenv.yaml ./sbxenv.local.yaml
# Seed extension defaults once for the new Pi state directory:
sbx env exec ./sbxenv.yaml ./sbxenv.local.yaml -- node /opt/pi/init-agent.mjs
sbx env exec -it ./sbxenv.yaml ./sbxenv.local.yaml -- bash -l
# Inside: cd workspace; clone projects; run pi and /login.
```

Pi can read, modify and delete the shared directory, including login tokens.
Keep it private and use one sandbox at a time per Pi state directory. Mount
changes require a new sandbox; shared host files survive sandbox removal.

## Updates, tests, and deletion

Image/kit changes apply only to newly created sandboxes. Use a different name
for a trial, passing `--name pi-sandbox-trial` consistently to environment commands.
Push or back up internal repositories and other needed files before replacement.
Compose storage is independent.

```bash
npm test                         # Docker-free checks
sbx kit validate .               # live kit build/validation
node tests/sandbox-smoke.mjs     # inspect existing pi-sandbox
# Optional restart check; ends running sessions:
SANDBOX_NAME=pi-sandbox-trial PI_BOX_SANDBOX_RESTART=1 node tests/sandbox-smoke.mjs
```

`sbx env rm ./sbxenv.yaml` deletes the sandbox's internal repositories,
credentials and history. Review its plan before proceeding. Logged-in sandbox
snapshots contain credentials.

Sidecars and remote/cloud deployment are not included in this setup.
