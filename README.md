# praxis

A portable way of working with Claude Code — from Information Applied.

praxis (n.): turning intent into disciplined practice. An issue-driven lifecycle with worktrees,
review-before-PR, PRD-linked requirements, and board discipline — applied to code, docs, strategy,
and decisions alike. The firm/project specifics come from local config, not the plugin, so the
method itself is generic and reusable.

> **Status:** v0.1.0 — the plugin is built: a SessionStart hook that nudges only in repos with a
> `.claude/praxis.json`, and the `workflow` skill it points to. The skill set will grow from here.

## Identity

- Marketplace: `informationapplied` (this repo, `informationapplied/praxis`)
- Plugin: `praxis`

## Install

```
/plugin marketplace add informationapplied/praxis
/plugin install praxis@informationapplied
```

No credentials required — the marketplace is public.

## Configure (repos you own)

Commit `.claude/praxis.json` with your board URL, PRD path, and options. Without it, praxis runs a
sensible default (plain GitHub issues, no board, manual worktree). See `praxis/config.example.json`.

To make the plugin **travel with the repo** — so a fresh clone or a web session installs it without
a manual step — also commit a `.claude/settings.json` that declares the marketplace and enables the
plugin. Opening the repo then prompts once to trust-and-install:

```json
{
  "extraKnownMarketplaces": {
    "informationapplied": { "source": { "source": "github", "repo": "informationapplied/praxis" } }
  },
  "enabledPlugins": { "praxis@informationapplied": true }
}
```

This repo declares itself that way.

## License

MIT.
