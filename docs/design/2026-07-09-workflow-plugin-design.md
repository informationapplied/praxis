# A public Claude Code workflow plugin: portable dev process across machines and teams

**Date:** 2026-07-09 (rev. 2026-07-10)
**Status:** Approved design (rev 2), not yet implemented
**Owner:** Glenn King / Information Applied

## Revision note

Rev 1 designed a *private* marketplace plus a vendored copy of the rules committed into
every repo, to reach web sessions. Two independent reviews (a docs fact-check and an
adversarial design review — findings recorded in
[`2026-07-10-rev1-review-findings.md`](2026-07-10-rev1-review-findings.md)) found the
vendoring premise was factually wrong and the design was contaminating client repos.

Rev 2 resolves this by going **public and generic**. A public marketplace needs no
credentials, so web and local sessions converge on a single mechanism — install the
plugin — which deletes vendoring, the deduplication guard, the CI drift check, and the
`GITHUB_TOKEN` requirement outright. See "What rev 2 removes" below.

## Problem

The house development workflow — an issue-driven lifecycle with worktrees, review-before-PR,
PRD-linked requirements, and board discipline — currently lives in one repo's `CLAUDE.md` and
one machine's `~/.claude/settings.json`. It should apply anywhere Glenn or his team runs Claude
Code, on every surface (CLI on multiple Macs, desktop app, IDE extension, and claude.ai/code
web), and it should be adoptable by teammates without forking.

Two hard constraints shaped rev 1 and still hold:

1. A plugin cannot ship permissions — its `settings.json` honors only `agent` and
   `subagentStatusLine`. Permissions live in user/project/local settings, which merge.
2. Nothing in `~/.claude` reaches a web session. Only the cloned repo and any plugin the repo
   *declares* (installed from a marketplace at session start) travel there.

Rev 1 mishandled constraint 2 by vendoring. Rev 2 handles it by making the plugin public, so the
repo-declared plugin installs on web with no auth.

## Design principles (rev 2)

- **Generic core, local specifics.** The public plugin contains a *portable* workflow. Anything
  Information Applied-specific — the GitHub project board URL, the devflow MCP integration, the
  PRD-ID scheme — is *read* from local configuration, never *baked into* the plugin. This is both
  what makes it publishable and what keeps it out of client repos.
- **Nudge, not dump.** The full lifecycle is not injected into every session. A short SessionStart
  nudge states that the repo uses the workflow and points at the skill; the heavy process loads
  on demand via a skill. This is how `superpowers` actually works.
- **Own repos only.** The workflow is configured only in repos Information Applied/Glenn owns.
  Client repos (e.g. EliLillyCo) receive no committed `.claude` workflow config. With a public
  marketplace this is a professional-courtesy rule, not a confidentiality risk — nothing secret
  would leak — but it stands: a client's repo is their process choice, and configuring it would
  prompt their employees to install a plugin that isn't their workflow.

## Architecture

One public repository, one plugin to start.

### `informationapplied/claude-plugins` (public) — the marketplace

```
LICENSE                                  # MIT
.claude-plugin/marketplace.json          # marketplace name: ia-plugins
<plugin-name>/                           # see "Naming" — final name TBD
  .claude-plugin/plugin.json             # semver versioned
  hooks/hooks.json                       # SessionStart matcher: startup|clear  (NOT compact)
  hooks/session-start.sh                 # emits a SHORT nudge; exits 0 unconditionally
  rules/workflow.md                      # the full portable lifecycle (loaded by the skill, not the hook)
  skills/
    workflow/SKILL.md                    # on-demand: the full lifecycle, adapted to local config
    scope-issue/SKILL.md                 # lifecycle step: PRD IDs, sizing, board move
    finish-issue/SKILL.md                # lifecycle step: merge, close, board → done
  commands/
    standup.md                           # the "what's next" board briefing
  config.example.json                    # the shape of per-repo workflow config
README.md                                # what it is, install, how to configure
docs/design/                             # this spec + review findings
```

### Configuration: how the generic plugin learns your specifics

A repo Glenn owns commits `.claude/workflow.json` (name TBD), e.g.:

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

The `workflow` skill reads this and adapts its instructions. If the file is absent, the skill
runs in a sensible default mode: plain GitHub issues, no board, manual worktree, `devflow: false`.
This is the mechanism that keeps IA specifics out of the public plugin **and** out of client
repos, and it is what makes the plugin genuinely reusable by strangers.

## Data flow: one mechanism, every surface

| Surface | How the plugin arrives | How rules arrive |
|---|---|---|
| CLI / desktop / IDE | User installs once, or `~/.claude/settings.json` `enabledPlugins` | Hook nudge at startup; `workflow` skill on demand |
| Web (claude.ai/code) | Repo `.claude/settings.json` declares the public marketplace + `enabledPlugins`; user prompted to install on trust — no credentials needed because the marketplace is public | Same hook + skill, running in the cloud session |

There is no second code path for web. That is the whole payoff of going public: the thing that
was impossible for a private marketplace (install in a cloud session with no creds) is trivial for
a public one.

## devflow: conditional, unchanged

The `devflow` MCP server stays out of scope as a distributed artifact. The `workflow` skill uses
`start_work_session`/`end_work_session` **only when `config.devflow === true` and the server is
connected**; otherwise it instructs the manual path (create the worktree, update the board by
hand, skip activity logging). No user is ever told to call a tool they don't have.

## Permissions (unchanged reasoning)

- **Team denies** (the destructive-command list: `rm -rf`, `rm -r`, `sudo rm`, force-push both
  spellings, `git clean -f`/`-fd`, `git branch -D`, `chmod -R 777`) go in each owned repo's
  committed `.claude/settings.json`.
- **Personal allows** (npm, python, swift, brew, gh, …) stay in `~/.claude/settings.json`, the
  weakest layer.
- Because `allow`/`deny` merge and a deny at any level wins, teammates extend without being able
  to loosen a team deny. This falls out of precedence; no code implements it.
- Known limit (review L3): the guarantee holds only for the file as committed; a contributor can
  edit the committed settings on their own branch. Only server-managed settings would prevent
  that, and that is out of scope.

## Syncing Glenn's own machines

`glennking/dotfiles` (private) holds `claude/settings.json` and an idempotent `install.sh` that
symlinks exactly one file to `~/.claude/settings.json` (personal allows + `enabledPlugins` listing
the public plugin). No `GITHUB_TOKEN` is needed now — the marketplace is public. `~/.claude.json`
(per-project history, MCP auth) is never committed. Memory (`~/.claude/projects/*/memory/`) stays
machine-local: it is personal context, its directory name is derived from an absolute checkout
path, and regenerating it is cheap.

## Versioning and rollback

The plugin is semver-versioned with a changelog and Git release tags — standard OSS practice, and
the fix for rev 1's "a push governs everyone instantly" finding. Background auto-update pulls the
marketplace's default branch, so risky changes land on a `next` branch and merge to `main` only
after use; a bad change is rolled back by reverting on `main`. There is a single source of truth
now (the installed plugin), so rev 1's HEAD-vs-installed divergence cannot occur.

## What rev 2 removes (and why it's safe)

| Rev 1 mechanism | Removed because |
|---|---|
| Vendored `.claude/rules/workflow.md` per repo | Public plugin installs on web directly; vendoring was redundant on owned repos and contaminating on client repos |
| `make sync-rules` | Nothing to sync; rules ship in the plugin |
| CI drift check via `gh api` on a private repo | No vendored copy to drift; also the cross-private-repo token never worked |
| SessionStart dedup guard | Rules come from exactly one place (the hook/skill); no double-load possible |
| `GITHUB_TOKEN` in `~/.zshrc` | Public marketplace needs no auth for install or background update |
| Full-lifecycle always-on injection | Replaced by a short nudge + on-demand skill; `compact` dropped from the matcher so nothing is re-injected after compaction |

## Error handling

| Failure | Guard |
|---|---|
| `session-start.sh` errors or plugin mid-update | Script exits 0 and prints nothing; invoked as `bash session-start.sh` so a lost +x bit doesn't matter; a broken hook cannot break a session |
| Teammate never installs the plugin | Repo `.claude/settings.json` prompts on trust; public marketplace means the prompt actually succeeds |
| `config.json` absent or malformed | Skill falls back to generic default mode; malformed config surfaces a clear message, not a crash |
| `gh` not installed | Manual-worktree path in the skill still works; only board automation degrades |

## Testing

1. **Fresh machine, plugin installed, no repo config.** Start a session in any repo: the nudge
   appears; invoking the `workflow` skill runs generic default mode.
2. **Owned repo with `.claude/workflow.json`.** The skill adapts to the configured board, PRD
   path, and `devflow` flag.
3. **Web session on an owned repo declaring the marketplace.** Trust prompt → install succeeds
   with no credentials → nudge and skill behave identically to local.
4. **Subdirectory launch.** Start Claude from a package subdir: nudge fires once, skill resolves
   config from the project root (anchored to `$CLAUDE_PROJECT_DIR`, not cwd — rev 1's H1 bug).
5. `session-start.sh` exits 0 and emits nothing when `rules/` is missing.

## Naming (decide during rewrite)

Marketplace stays `ia-plugins` (an author/firm namespace, like a GitHub handle — fine for a public
repo that may host more than one plugin). Plugin name candidates:

- `issue-driven-dev` — descriptive; reads as a general tool, not one firm's config. **Recommended.**
- `shipflow` — short and memorable, but vaguer about what it does.
- `ia-workflow` — clear provenance, but reads as an internal tool, which undercuts "publishable."

Recommendation: `issue-driven-dev`, with `ia-` reserved as the marketplace namespace.

## First application: lilly_lumen

`lilly_lumen/CLAUDE.md` is migrated. The nine-step lifecycle, principles, escape hatches, and board
conventions become plugin-owned (generic) plus a committed `.claude/workflow.json` (the lilly_lumen
specifics: board #22, `docs/prd.md`, `devflow: true`). `CLAUDE.md` keeps only what is truly
project-local — the directory table and the pre-commit command — and the unfilled template stubs
(`src`/`tests` tech column, empty Common Commands, empty Architecture, empty Key Patterns) are
deleted.

## Out of scope

- Packaging/distributing the devflow MCP server.
- Server-managed (enterprise) settings. Still the only way to *enforce* consistency and prevent a
  contributor editing committed settings (L3), but it replaces rather than merges (the rejected
  "locked" model) and needs org-admin work. Reconsider if IA wants enforcement later; note that for
  IA's *own* org Glenn is admin, so it remains a viable future option for owned repos.
- Syncing `~/.claude/projects/*/memory/` across machines.
- Additional plugins in `ia-plugins`. The marketplace can hold more; this ships one.

## Publish gate

The repo stays **private** until the plugin is built and Glenn approves flipping it public.
Going public is a hard-to-reverse outward action; "public in principle" is not authorization to
publish a design doc today. Flip to public at implementation time, with the LICENSE and README in
place.
