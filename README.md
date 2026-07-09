# claude-plugins

Information Applied's Claude Code plugin marketplace.

Marketplace name: `ia-plugins`

## Plugins

| Plugin | Description |
|---|---|
| `ia-workflow` | The house development workflow: issue-driven lifecycle, PRD requirement conventions, project board discipline, and coding rules. |

## Install

Once per machine:

```bash
gh auth login                             # repo scope, to clone this private marketplace
export GITHUB_TOKEN=…                     # in your shell profile; enables background auto-update
```

Then, inside Claude Code:

```
/plugin marketplace add informationapplied/claude-plugins
/plugin install ia-workflow@ia-plugins
```

Without `GITHUB_TOKEN` the plugin still works, but Claude Code cannot refresh a private marketplace
in the background and your copy will go stale silently.

## Design

See [docs/design/2026-07-09-ia-workflow-plugin-design.md](docs/design/2026-07-09-ia-workflow-plugin-design.md).

## Status

Design approved. Not yet implemented.
