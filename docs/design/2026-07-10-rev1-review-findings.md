# Review findings on rev 1 of the workflow-plugin design

**Date:** 2026-07-10
**Reviewers:** a Claude Code docs fact-check (sequential) and an adversarial design review (sequential)
**Subject:** rev 1 of the workflow-plugin spec (private marketplace + per-repo vendoring)

These findings drove the rev 2 rewrite. Kept as the decision trail.

## Fact-check results

Nine of ten claims in rev 1's "Verified constraints" table were CONFIRMED against
code.claude.com/docs and plugin source on disk:

- SessionStart hook stdout enters context; non-zero exit is non-blocking for SessionStart.
- A plugin's `settings.json` honors only `agent` and `subagentStatusLine`; permissions cannot ship in a plugin.
- Project `.claude/settings.json` `extraKnownMarketplaces` + `enabledPlugins` **prompts** on trust; does not silently auto-install.
- `allow`/`deny` permission lists merge across levels; a deny at any level wins; a user allow cannot override a project deny.
- Precedence: managed > CLI args > local > project > user.
- `@path` imports work relative (resolved to the importing file) and absolute, to a depth of 4.
- `$CLAUDE_PLUGIN_ROOT` is the correct hook env var.
- Cache path is `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.
- `owner/repo` marketplace shorthand is valid; `GITHUB_TOKEN`/`GH_TOKEN` gate background auto-update of a *private* marketplace.

**WRONG (the load-bearing one):** rev 1 claimed "web sessions see only the cloned repo, therefore
rules must be vendored." Web sessions also install plugins a repo *declares* from a marketplace,
and receive org server-managed settings. Vendoring's premise was false. (Caveat the fact-check did
not fully resolve: a *private* marketplace install on web needs credentials — which is exactly why
rev 2 goes public.)

## Adversarial design findings (ranked)

- **C1 — Client-repo contamination.** "Every repo" dragged in EliLillyCo repos; following the
  adoption steps there would commit IA's private marketplace pointer and internal methodology into
  the client's git history and break every Lilly employee's session. → rev 2: own-repos-only rule;
  public marketplace removes the confidentiality dimension.
- **C2 — Vendoring redundant-or-harmful.** Redundant on owned repos (web can install the declared
  plugin), and its only value case was a client employee on a client repo — the one place you must
  not vendor. → rev 2: vendoring removed entirely.
- **H1 — Dedup guard misfires.** Keyed off cwd; a subdirectory launch fires hook *and* import →
  double load. Also file-present ≠ import-fired → possible silent zero-load. → rev 2: no vendoring,
  so no guard; skill anchors config lookup to `$CLAUDE_PROJECT_DIR`.
- **H2 — CI drift token never worked.** GitHub Actions' default token can't read a second private
  repo; fork PRs get no secrets. → rev 2: no drift check.
- **H3 — No versioning/rollback; two sources of truth.** Hook read installed version, sync read
  HEAD; the CI check enforced the wrong equality. → rev 2: semver + single source of truth (the
  installed plugin); `next`-branch staging.
- **H4 — Token posture.** `repo`-scope token in plaintext `~/.zshrc`, on a machine with client
  write access, for a job needing read-only one-repo access. → rev 2: public marketplace needs no
  token.
- **M1 — Wrong mechanism.** Full lifecycle injected every session, re-injected on `compact`;
  mis-cited superpowers (which is a thin dispatcher over on-demand skills). → rev 2: nudge + skill;
  drop `compact`.
- **M2 — `make sync-rules` never delivered; assumed make/Makefile/gh everywhere.** → rev 2: gone.
- **M3 — Org-managed-settings dismissal was partly wrong.** Glenn is admin of his *own* org; the
  client-admin objection conflated two orgs. → rev 2: kept out of scope but noted as a viable future
  option for owned repos.
- **L1–L3 — Silent-but-non-fatal failure modes, root-only test coverage, deny-guarantee holds only
  for the file as committed.** → rev 2: addressed in error-handling and testing sections; L3
  acknowledged as inherent without managed settings.
