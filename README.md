# claude-plugins

Information Applied's Claude Code plugin marketplace.

Marketplace name: `ia-plugins`

> **Status:** design approved (rev 2), not yet implemented. This repo is currently private
> and will be flipped public once the first plugin is built. See
> [docs/design](docs/design/2026-07-09-workflow-plugin-design.md).

## Planned plugins

| Plugin | Description |
|---|---|
| _(name TBD — see spec)_ | A portable, issue-driven development workflow: lifecycle, worktrees, review-before-PR, PRD-linked requirements, and board discipline. Firm/project specifics come from local config, not the plugin. |

## Install (once public)

```
/plugin marketplace add informationapplied/claude-plugins
/plugin install <plugin>@ia-plugins
```

No credentials required — the marketplace is public.

## Design

- [Design (rev 2)](docs/design/2026-07-09-workflow-plugin-design.md)
- [Rev 1 review findings](docs/design/2026-07-10-rev1-review-findings.md)
