# ia-workflow: Packaging Claude Code config for reuse across machines and teams

**Date:** 2026-07-09
**Status:** Approved design, not yet implemented
**Owner:** Glenn King

## Problem

Claude Code configuration currently lives in two places that do not travel:

- `~/.claude/settings.json` — permissions, enabled plugins, harness options. Machine-local.
- `lilly_lumen/CLAUDE.md` — a nine-step issue-driven development lifecycle, PRD requirement-ID
  conventions, GitHub project board states, coding rules, and escape hatches for unplanned fixes
  and maintenance. Repo-local.

The lifecycle is house style, not a lilly_lumen quirk. It should govern every repo Glenn or his
team opens. Today it governs one, and a new machine or a new teammate starts from nothing.

Three requirements, established during brainstorming:

1. **Every repo.** The lifecycle applies anywhere Claude Code runs, not just this project.
2. **Layered.** Glenn's config is a base teammates extend, not a template they fork. Improvements
   flow outward without anyone re-copying files.
3. **Four surfaces.** CLI on multiple Macs, the desktop app, the IDE extension, and
   claude.ai/code web sessions.

Requirement 3 is the hard one. Web sessions run in an Anthropic-managed sandbox with no access to
the user's home directory. Nothing in `~/.claude` reaches them — not settings, not plugins, not
memory. Only the cloned repository does.

## Verified constraints

These were confirmed against the current Claude Code implementation, not assumed.

| Constraint | Consequence for this design |
|---|---|
| A plugin can ship skills, commands, agents, hooks, MCP servers, and `bin/` executables | The lifecycle can be plugin-owned |
| A plugin's `SessionStart` hook prints to stdout, and that text enters context | Always-on rules are possible without CLAUDE.md — this is how `superpowers` works |
| A plugin's `settings.json` honors only `agent` and `subagentStatusLine` | Permissions **cannot** ship in a plugin |
| Project `.claude/settings.json` may declare `extraKnownMarketplaces` and `enabledPlugins` | Repos can advertise the plugin, but only *prompt* for install — never silent |
| `allow`/`deny` permission lists **merge** across precedence levels; a deny at any level applies | Layering is free; a teammate cannot loosen a team deny |
| Precedence: managed > CLI args > `.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json` | Personal settings are the weakest layer, which is correct |
| `CLAUDE.md` supports `@path` imports, relative or absolute, to a depth of 4 | The vendored rules file can be pulled into context by import |
| Web sessions see only the cloned repo | Rules must be vendored in-repo to reach web |
| Private GitHub marketplaces authenticate via git credential helper; background auto-update requires `GITHUB_TOKEN` | Onboarding needs `gh auth login` plus an env var |

## Architecture

Two repositories with disjoint audiences.

### `informationapplied/claude-plugins` (private) — the shared base

```
.claude-plugin/marketplace.json          # marketplace name: ia-plugins
ia-workflow/
  .claude-plugin/plugin.json
  rules/workflow.md                      # single source of truth for the house rules
  hooks/hooks.json                       # SessionStart matcher: startup|clear|compact
  hooks/session-start.sh
  skills/
    scope-issue/SKILL.md                 # lifecycle step 2
    finish-issue/SKILL.md                # lifecycle step 9
  commands/
    standup.md                           # the "what's next" board briefing
  template/
    CLAUDE.md.example
    settings.json.example
README.md                                # onboarding, token scopes, troubleshooting
```

`rules/workflow.md` holds the nine-step lifecycle, the key principles, the two coding rules (no
hardcoded paths; UTC timestamps everywhere), and the unplanned-fix and maintenance escape hatches.
It exists once and is consumed two ways.

### `glennking/dotfiles` (private) — Glenn's machines only

```
claude/settings.json                     # symlinked to ~/.claude/settings.json
install.sh                               # idempotent symlink bootstrap
```

Contains no team content. Never contains `~/.claude.json` (per-project history and MCP auth state)
and never contains `GITHUB_TOKEN`, which belongs in the shell profile or keychain.

## Data flow: how rules reach each surface

**CLI, desktop, IDE.** The plugin's `SessionStart` hook reads `rules/workflow.md` and prints it.
Rules are live in every repo with zero per-repo setup. This is what satisfies "every repo."

**Web.** A project repo vendors a copy to `.claude/rules/workflow.md`. Its `CLAUDE.md` pulls it in
with `@.claude/rules/workflow.md`. The copy is refreshed by `make sync-rules`.

**Deduplication.** A repo that has vendored the rules would otherwise load them twice on CLI — once
from the hook, once from the import. `session-start.sh` therefore checks for
`.claude/rules/workflow.md` in the working directory and prints nothing if it exists. The repo copy
wins where present; the plugin fills the gap everywhere else.

## Component contracts

**`rules/workflow.md`** — Input: none. Output: the canonical rules text. Depends on nothing. Any
consumer may read it; nothing may write it but a human.

**`hooks/session-start.sh`** — Input: the working directory. Output: rules text on stdout, or
nothing. Must exit 0 unconditionally: a broken hook must not be able to break a session. Depends on
`rules/workflow.md` via `$CLAUDE_PLUGIN_ROOT`, never a hardcoded path.

**`make sync-rules`** — Writes the canonical `rules/workflow.md` to the consuming repo's
`.claude/rules/workflow.md`. Idempotent.

It must not read from the local plugin cache: that path is version-stamped
(`~/.claude/plugins/cache/ia-plugins/ia-workflow/<version>/`) and absent entirely on a machine that
never installed the plugin, including CI runners. It fetches from the source of truth instead, which
works for a private repo because `gh` is already authenticated:

```
gh api repos/informationapplied/claude-plugins/contents/ia-workflow/rules/workflow.md \
  --jq '.content' | base64 -d > .claude/rules/workflow.md
```

The CI drift check runs the same fetch to a temporary file and diffs it against the committed copy,
failing the build when they differ.

**`template/settings.json.example`** — The team layer. Carries `extraKnownMarketplaces`,
`enabledPlugins`, and the shared destructive-command `deny` list (`rm -rf`, `rm -r`, `sudo rm`,
force-push in both spellings, `git clean -f`/`-fd`, `git branch -D`, `chmod -R 777`). Carries no
`allow` entries — those are personal.

## Permission layering

Permissions split by audience, and the merge semantics do the work.

- **Team denies** live in each project's committed `.claude/settings.json`. Because denies merge
  across levels and a deny at any level applies, no teammate can loosen them.
- **Personal allows** — npm, python, swift, brew, gh, and the rest of Glenn's current list — stay in
  `~/.claude/settings.json`, the weakest layer.
- **Per-repo personal overrides** go in `.claude/settings.local.json`, which every adopting repo
  adds to `.gitignore`.

No code implements this. It falls out of the precedence rules.

## devflow: conditional, not assumed

Lifecycle steps 3 and 9 currently call `start_work_session` and `end_work_session` from the devflow
MCP server. devflow is deliberately out of scope for this package. Distributing rules that call
tools a teammate does not have would make those steps fail silently.

`rules/workflow.md` therefore phrases both steps conditionally: use the devflow tools when the
server is connected; otherwise create the worktree and update the board by hand, and skip activity
logging. Nobody receives instructions for tools they do not have.

## Memory is not shareable

`~/.claude/projects/*/memory/` holds Glenn's personal context — his role, Lumen Phase 0 scope, team
role boundaries. It never enters the team package.

Syncing it across Glenn's own machines is possible but fragile: the directory name is derived from
the repository's absolute path (`-Users-glennking-repos-lilly-lumen`), so it only lines up when
username and checkout location match on every machine. **Decision: leave memory machine-local.** It
is personal context rather than configuration, and regenerating it is cheap. Revisit only if the
drift proves annoying in practice.

## Onboarding

Once per machine, for a teammate:

```bash
gh auth login                                    # repo scope; needed to clone a private marketplace
echo 'export GITHUB_TOKEN=…' >> ~/.zshrc         # needed only for background auto-update
```

```
/plugin marketplace add informationapplied/claude-plugins
/plugin install ia-workflow@ia-plugins
```

The credential helper covers the manual install. The environment variable is what lets Claude Code
refresh a private marketplace in the background; without it the plugin still works but goes stale
silently.

If a teammate skips this, each project repo's committed `.claude/settings.json` advertises the
marketplace and prompts them to install on trusting the repo. Onboarding is one command, not zero.
This is a limitation of `enabledPlugins`, not an oversight.

Once per adopting repo:

1. Copy `template/CLAUDE.md.example` to `CLAUDE.md`; fill in project-specific facts only.
2. Copy `template/settings.json.example` to `.claude/settings.json`.
3. Run `make sync-rules` to vendor `.claude/rules/workflow.md`.
4. Add `.claude/settings.local.json` to `.gitignore`.

## Update flow

Edit `rules/workflow.md`, push to `informationapplied/claude-plugins`. Every teammate's next session
picks it up on CLI, desktop, and IDE. Repos refresh their vendored web copy on the next
`make sync-rules`; the CI drift check fails the build when a repo's copy lags, so no web session
runs stale rules unnoticed.

## Error handling

| Failure | Guard |
|---|---|
| Vendored rules drift from the plugin | CI diffs the two files and fails the build |
| Rules injected twice on CLI | `session-start.sh` skips when `.claude/rules/workflow.md` exists |
| Private marketplace clone fails | Auth error surfaces directly; README documents required token scopes |
| `session-start.sh` errors | Script exits 0 and prints nothing; a broken hook cannot break a session |
| Teammate never installs the plugin | Repo `.claude/settings.json` prompts on trust; rules still reach them via the vendored copy and `@` import |

## Testing

The design reduces to one distinction, and one test pair covers it.

1. **Scratch directory, no `.claude/rules/`.** Start a session. The house rules appear — the hook
   fired.
2. **A vendoring repo.** Start a session. The house rules appear **exactly once** — the hook stood
   down and the import supplied them.

Additionally: `make sync-rules` is idempotent (running twice produces no diff), and the CI drift
check fails when `.claude/rules/workflow.md` is edited by hand.

## First application: lilly_lumen

`lilly_lumen/CLAUDE.md` is migrated to the template. It loses the nine-step lifecycle, the key
principles, the escape hatches, and the board conventions — all now plugin-owned. It retains what is
genuinely project-specific: the directory table, the pre-commit command, and the project board URL.

The unfilled template stubs are deleted rather than migrated: the `src/`/`tests/` Tech column, the
commented-out Common Commands block, the empty Architecture diagram, and the empty Key Patterns
heading.

## Out of scope

- Packaging or distributing the devflow MCP server.
- Server-managed (enterprise) settings. This is the only mechanism that would reach web sessions
  without vendoring and enforce consistency without per-repo work, but it *replaces* lower tiers
  rather than merging them — the "locked" model that was explicitly rejected — and it requires
  admin access Glenn may not hold on a client engagement. Reconsider if Information Applied moves
  to an enterprise plan.
- Syncing `~/.claude/projects/*/memory/` across machines.
- Additional plugins in the `ia-plugins` marketplace. The marketplace is structured to hold more,
  but `ia-workflow` ships alone.
