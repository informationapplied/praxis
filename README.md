# praxis

A portable way of working with Claude Code — from Information Applied.

praxis (n.): turning intent into disciplined practice. An issue-driven lifecycle with worktrees,
review-before-PR, PRD-linked requirements, and board discipline — applied to code, docs, strategy,
and decisions alike. The firm/project specifics come from local config, not the plugin, so the
method itself is generic and reusable.

> **Status:** design approved (rev 2), not yet implemented. This repo is currently private and will
> be flipped public once the plugin is built. See
> [docs/design](docs/design/2026-07-09-workflow-plugin-design.md).

## Identity

- Marketplace: `informationapplied` (this repo, `informationapplied/praxis`)
- Plugin: `praxis`

## Install (once public)

```
/plugin marketplace add informationapplied/praxis
/plugin install praxis@informationapplied
```

No credentials required — the marketplace is public.

## Configure (repos you own)

Commit `.claude/praxis.json` with your board URL, PRD path, and options. Without it, praxis runs a
sensible default (plain GitHub issues, no board, manual worktree). See `praxis/config.example.json`.

## License

MIT.
