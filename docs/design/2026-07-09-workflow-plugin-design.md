# praxis: a portable way of working with Claude, across machines and teams

**Date:** 2026-07-09 (rev. 2026-07-10)
**Status:** Approved design (rev 2), not yet implemented
**Owner:** Glenn King / Information Applied

## Revision note

Rev 1 designed a *private* marketplace plus a vendored copy of the rules committed into every repo,
to reach web sessions. Two independent reviews (a docs fact-check and an adversarial design review —
findings in [`2026-07-10-rev1-review-findings.md`](2026-07-10-rev1-review-findings.md)) found the
vendoring premise was factually wrong and the design was contaminating client repos.

Rev 2 goes **public and generic**. A public marketplace needs no credentials, so web and local
sessions converge on a single mechanism — install the plugin — which deletes vendoring, the
deduplication guard, the CI drift check, and the `GITHUB_TOKEN` requirement outright.

Naming/shape resolved during rev 2: this is not a narrow "dev workflow" but *the way Glenn works
with Claude across everything* — code, docs, strategy, decisions. It follows the `superpowers`
model: **one richly-skilled plugin named after a concept**, growing by skills rather than a shelf of
separate plugins. The concept is **praxis** — turning intent into disciplined practice.

## Identity

| Knob | Value | Notes |
|---|---|---|
| GitHub repo (the visible brand) | `informationapplied/praxis` | What users type: `/plugin marketplace add informationapplied/praxis` |
| Marketplace `name` | `informationapplied` | The `@suffix` on installs |
| Plugin `name` | `praxis` | Install target: `praxis@informationapplied` |

`informationapplied` (a GitHub org) sits in the same slot as `obra` in `obra/superpowers`; the clean
read comes from the repo path, not the marketplace's internal name.

## Problem

The house way of working — an issue-driven lifecycle with worktrees, review-before-PR, PRD-linked
requirements, and board discipline, plus whatever other practices accrete — currently lives in one
repo's `CLAUDE.md` and one machine's `~/.claude/settings.json`. It should apply anywhere Glenn or his
team runs Claude Code, on every surface (CLI on multiple Macs, desktop, IDE, and claude.ai/code web),
and be adoptable by teammates without forking.

Two hard constraints:

1. A plugin cannot ship permissions — its `settings.json` honors only `agent` and
   `subagentStatusLine`. Permissions live in user/project/local settings, which merge.
2. Nothing in `~/.claude` reaches a web session. Only the cloned repo and any plugin the repo
   *declares* (installed from a marketplace at session start) travel there — and a **public**
   marketplace installs there with no credentials.

## Design principles

- **Generic core, local specifics.** The public `praxis` plugin contains a *portable* method.
  Information Applied-specific details — the GitHub project board URL, the devflow MCP integration,
  the PRD-ID scheme — are *read* from local config, never baked into the plugin. This is what makes
  it publishable and what keeps it out of client repos.
- **Nudge, not dump.** A short SessionStart nudge says the repo uses praxis and points at the skill;
  the heavy process loads on demand via a skill. This is how `superpowers` works.
- **Own repos only.** praxis is configured only in repos Information Applied/Glenn owns. Client repos
  (e.g. EliLillyCo) get no committed `.claude` config. With a public marketplace this is
  professional courtesy, not a confidentiality risk, but it stands.

## Architecture

One public repository, one flagship plugin that grows by skills.

```
informationapplied/praxis  (public once built)
  LICENSE                                  # MIT
  .claude-plugin/marketplace.json          # name: informationapplied
  praxis/
    .claude-plugin/plugin.json             # semver versioned
    hooks/hooks.json                       # SessionStart matcher: startup|clear  (NOT compact)
    hooks/session-start.sh                 # short nudge; exits 0 unconditionally
    rules/workflow.md                      # the full portable lifecycle (loaded by the skill)
    skills/
      workflow/SKILL.md                    # on-demand: the lifecycle, adapted to local config
      scope-issue/SKILL.md                 # step: PRD IDs, sizing, board move
      finish-issue/SKILL.md                # step: merge, close, board → done
      …                                    # room for more practices over time
    commands/
      standup.md                           # the "what's next" board briefing
    config.example.json                    # the shape of per-repo config
  README.md
  docs/design/                             # this spec + review findings
```

### Configuration: how generic praxis learns your specifics

A repo Glenn owns commits `.claude/praxis.json`:

```json
{
  "tracker": "github-projects",
  "board": "https://github.com/users/glennking/projects/22",
  "statuses": ["Suggested","Scoping","Approved","In progress","In review","Done","Declined"],
  "prd": { "path": "docs/prd.md", "idScheme": "SECTION-NNN" },
  "sizing": ["XS","S","M","L","XL"],
  "devflow": true,
  "branchPattern": "issue-{n}-{slug}"
}
```

The `workflow` skill reads this and adapts. Absent the file, it runs a sensible default: plain
GitHub issues, no board, manual worktree, `devflow: false`. This keeps IA specifics out of the
public plugin *and* out of client repos, and makes praxis reusable by strangers.

## Data flow: one mechanism, every surface

| Surface | How praxis arrives | How rules arrive |
|---|---|---|
| CLI / desktop / IDE | User installs once, or `~/.claude/settings.json` `enabledPlugins` | Hook nudge at startup; `workflow` skill on demand |
| Web (claude.ai/code) | Repo `.claude/settings.json` declares `informationapplied/praxis` + `enabledPlugins: praxis@informationapplied`; user prompted to install on trust — no credentials, marketplace is public | Same hook + skill, in the cloud session |

There is no second code path for web. That is the payoff of going public.

## devflow: conditional

The `devflow` MCP server stays out of scope as a distributed artifact. The `workflow` skill uses
`start_work_session`/`end_work_session` only when `config.devflow === true` and the server is
connected; otherwise it instructs the manual path (worktree by hand, board by hand, skip activity
logging). No user is told to call a tool they don't have.

## Permissions (unchanged reasoning)

- **Team denies** (`rm -rf`, `rm -r`, `sudo rm`, force-push both spellings, `git clean -f`/`-fd`,
  `git branch -D`, `chmod -R 777`) go in each owned repo's committed `.claude/settings.json`.
- **Personal allows** stay in `~/.claude/settings.json`, the weakest layer.
- `allow`/`deny` merge and a deny at any level wins, so teammates extend without loosening a team
  deny. Falls out of precedence; no code implements it.
- Known limit (review L3): holds only for the file as committed; a contributor can edit committed
  settings on a branch. Only server-managed settings would prevent that — out of scope.

## Syncing Glenn's own machines

`glennking/dotfiles` (private) holds `claude/settings.json` and an idempotent `install.sh` that
symlinks one file to `~/.claude/settings.json` (personal allows + `enabledPlugins: praxis@informationapplied`).
No `GITHUB_TOKEN` — the marketplace is public. `~/.claude.json` is never committed. Memory
(`~/.claude/projects/*/memory/`) stays machine-local.

## Versioning and rollback

`praxis` is semver-versioned with a changelog and Git release tags. Risky changes land on a `next`
branch and merge to `main` only after use; a bad change is rolled back by reverting `main`. Single
source of truth (the installed plugin), so rev 1's HEAD-vs-installed divergence cannot occur.

## What rev 2 removes

| Rev 1 mechanism | Removed because |
|---|---|
| Vendored `.claude/rules/workflow.md` per repo | Public plugin installs on web directly |
| `make sync-rules` | Nothing to sync; rules ship in the plugin |
| CI drift check via `gh api` on a private repo | No vendored copy to drift; token never worked |
| SessionStart dedup guard | Rules come from one place; no double-load possible |
| `GITHUB_TOKEN` in `~/.zshrc` | Public marketplace needs no auth |
| Full-lifecycle always-on injection | Replaced by a nudge + on-demand skill; `compact` dropped |

## Error handling

| Failure | Guard |
|---|---|
| `session-start.sh` errors / plugin mid-update | Exits 0, prints nothing; invoked as `bash session-start.sh` so a lost +x bit is harmless; a broken hook can't break a session |
| Teammate never installs praxis | Repo `.claude/settings.json` prompts on trust; public marketplace makes the prompt succeed |
| `praxis.json` absent/malformed | Skill falls back to default mode; malformed config surfaces a clear message, not a crash |
| `gh` not installed | Manual path in the skill still works; only board automation degrades |

## Testing

1. Fresh machine, praxis installed, no repo config → nudge appears; `workflow` skill runs default mode.
2. Owned repo with `.claude/praxis.json` → skill adapts to board, PRD path, `devflow` flag.
3. Web session on an owned repo declaring the marketplace → trust prompt → install succeeds with no
   credentials → nudge and skill behave identically to local.
4. Subdirectory launch → nudge fires once; skill resolves config from `$CLAUDE_PROJECT_DIR`, not cwd
   (rev 1's H1 bug).
5. `session-start.sh` exits 0 and emits nothing when `rules/` is missing.

## First application: lilly_lumen

`lilly_lumen/CLAUDE.md` is migrated. The nine-step lifecycle, principles, escape hatches, and board
conventions become praxis-owned (generic) plus a committed `.claude/praxis.json` (lilly_lumen
specifics: board #22, `docs/prd.md`, `devflow: true`). `CLAUDE.md` keeps only what is truly
project-local — the directory table and the pre-commit command — and the unfilled template stubs are
deleted.

## Out of scope

- Packaging/distributing the devflow MCP server.
- Server-managed (enterprise) settings. Still the only way to *enforce* consistency (L3), but it
  replaces rather than merges and needs org-admin work. Viable future option for IA's own org, where
  Glenn is admin.
- Syncing `~/.claude/projects/*/memory/` across machines.
- A second plugin in the marketplace. The repo can hold more; praxis ships as one rich plugin first.

## Publish gate

The repo stays **private** until the plugin is built and Glenn approves flipping it public. Going
public is a hard-to-reverse outward action; flip at implementation time, with LICENSE and README in
place.
