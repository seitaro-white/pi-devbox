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

Configuration and state survive container replacement. Pi integrations refresh
at startup; the skill lives at `~/.agents/skills/herdr`. Use Pi's `/reload` after updates.

For version updates, see [Updating tools and extensions](../README.md#updating-tools-and-extensions).
