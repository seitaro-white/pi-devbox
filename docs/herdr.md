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
