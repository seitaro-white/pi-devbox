# Herdr in Pi-box

The `recommended` image includes [Herdr](https://herdr.dev/docs/) for interactive
agent panes. Start it in your project:

```sh
docker compose exec -w /workspace/my-project pi-box herdr
```

## Use with Pi

Ask Pi to use Herdr or invoke `/skill:herdr` from a Herdr-managed pane.
The bundled skill teaches Pi the Herdr CLI; the startup-installed official
integration reports session identity and lifecycle state, including blocked
status while Pi waits for questionnaire answers.

Use Herdr for visible interactive sessions and project coordination;
`pi-subagents` handles structured subtasks and collected results. Its
`project.open` action opens a peer Pi session:

```js
subagent({ action: "project.open", cwd: "/workspace/another-project", message: "Review this project's test coverage." })
```

Inspector panes show subagent dashboards, not attached child terminals. Background
work is reported separately, so an idle parent pane can still have working children.
Use separate worktrees for concurrent edits.

## Agent launch profiles

The bundled `hand-off` and `start-worker` skills read image-owned Pi arguments
from `$PI_AGENT_PROFILES/orchestrator.args` and `worker.args`. Pi-box sets
`PI_AGENT_PROFILES=/opt/pi/agent-profiles` in both Pi images. The profiles select
`anthropic/claude-opus-5-5:medium` for the orchestrator and
`openai-codex/gpt-6.1-sol:medium` for workers, disable automatic extension loading,
and explicitly allow each role's extensions. Package entry paths load only
extensions, not package prompt templates.

To customize launches, point `PI_AGENT_PROFILES` at a directory with your own
role files. Each file contains one literal Pi CLI argument per line, without
quoting, blank lines or comments; the skills read it with `mapfile -t` and pass
the arguments before `--append-system-prompt <role prompt>`. A missing variable
or role file means no extra arguments. Role prompts and Herdr coordination stay
in the skills, not the profiles.

## Storage and updates

Herdr uses `/state/herdr` in the host state directory (`STATE_DIR` overrides
`${HOME}/pi-box-data/state`):

- `~/.config/herdr` → `/state/herdr/config`
- `~/.local/state/herdr` → `/state/herdr/state`
- Worktrees: `/workspace/.worktrees`

Configuration, saved workspace/tab layout (`config/session.json`), and state
survive container replacement. Running pane processes do not; Herdr restores its
saved layout when the server next starts.

`HERDR_SOCKET_PATH` points to `~/.local/run/herdr/herdr.sock` inside the container;
Herdr derives `herdr-client.sock` beside it. These temporary sockets must stay off
the host bind mount because Docker Desktop does not support their socket
operations. Existing sockets/logs under `/state/herdr/config` can be left alone;
the socket override ignores the old sockets.

Herdr 0.9.5's explicit named sessions (`--session` / `session attach`) bypass the
socket override, and live server handoff also uses the config directory. Avoid
those features with Docker Desktop host-backed state; use the default session
with multiple workspaces, and stop/restart rather than live handoff.

Pi integrations refresh at startup; the skill lives at `~/.agents/skills/herdr`.
Use Pi's `/reload` after updates.

For version updates, see [Updating tools and extensions](../README.md#updating-tools-and-extensions).
