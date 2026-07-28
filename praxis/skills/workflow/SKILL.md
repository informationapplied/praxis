---
name: workflow
description: Use when starting, continuing, or finishing any tracked unit of work in a praxis repo — the issue-driven lifecycle (find, scope, start, implement, self-review, docs, test, PR, merge, close) adapted to this repo's .claude/praxis.json. Invoke before beginning issue work; do NOT invoke for quick questions or trivial one-offs.
---

# The praxis workflow

An issue-driven lifecycle: every change maps to a tracked issue and moves through
scope → build → self-review → PR → merge → close, in an isolated worktree, reviewed
before the PR is opened. This skill adapts to the repo. Read the config first.

## Step 0 — Load the config

Read `.claude/praxis.json` from the project root (`$CLAUDE_PROJECT_DIR`, or the repo
root if unset). It parameterizes everything below. If the file is **absent or
malformed**, fall back to these defaults and say so once:

| Key | Meaning | Default if unset |
|---|---|---|
| `tracker` | Where work items live | `github-issues` (plain `gh issue`) |
| `board` | Project board URL | none — skip board moves |
| `statuses` | Board status column names | none |
| `prd.path` / `prd.idScheme` | Product spec + requirement-ID scheme | none — skip PRD steps |
| `sizing` | Allowed size labels | `["XS","S","M","L","XL"]` |
| `devflow` | Whether the devflow MCP server drives sessions | `false` |
| `branchPattern` | Branch naming | `issue-{n}-{slug}` |

State the effective config in one line (tracker, board on/off, PRD on/off, devflow
on/off) before acting, so the plan is visible.

## The lifecycle

Not every issue needs every step — bugs, docs, and small fixes move quickly. Scale the
ceremony to the change.

### 1. Find the next issue
Query the `tracker` (and `board`, if configured) for the highest-priority unstarted
item. Present it and confirm before starting.

### 2. Scope
- If `board`: move the issue to the scoping status.
- Decide whether the change alters **what the product does** (vs. how it's built). If
  yes and `prd` is configured, update `prd.path` and treat this as a PRD change.
- If `prd` is configured, assign requirement IDs — map to existing IDs or mint the next
  sequential one per `prd.idScheme` (e.g. `SEC-017` after `SEC-016`) — and list them in
  the issue body under a `## PRD Requirements` heading.
- Size the issue using `sizing` if not already sized.
- If `board`: move to the approved status when scoping is complete.

### 3. Start work
- **Sync main first** (both paths below). Before the worktree is created, `git fetch
  origin` and `git pull --ff-only` on main, and verify it advanced — so the branch starts
  from current main, not a stale local copy. A stale base starts the work behind and
  invites conflicts at merge.
- **If `devflow: true`** and the devflow MCP server is connected: call
  `start_work_session` — it sets status to in-progress, creates the worktree + branch,
  logs activity start, adds the in-progress label, and returns an `activity_id`. **Save
  the `activity_id` for step 9.**
- **Otherwise (manual path):** create a git worktree as a sibling directory on a branch
  named per `branchPattern`; if `board`, move the issue to the in-progress status by
  hand; skip activity logging. Never instruct devflow tool calls when `devflow` is false.
- All implementation happens in the worktree, not the main clone.

### 4. Implement
Work entirely in the worktree. Commit between changes — after implementation, after
review fixes, after test fixes — not one batched commit. Reference the issue number.

### 5. Self-review (before the PR, not after)
Review the full diff (`git diff <base>..HEAD`). Check for bugs, missing edge cases,
circular imports, fields not threaded through every layer, lint errors, and hard-coded
absolute paths (anything machine- or user-specific, e.g. `/Users/<name>/...`). Fix findings
in **separate** commits — don't amend — so the review trail survives.

### 6. Update docs
Update architecture docs for any architectural change **before pushing**. Add an ADR
(Context, Decision, Rationale) for significant design decisions.

### 7. Test
Run tests for regressions. Write targeted tests for new testable logic. Lint changed
files. Exercise edge cases and fallback behavior.

### 8. Push and open the PR
Push the branch and open a PR whose body tells the story: a summary of changes, the
**review findings** from step 5 and how they were fixed, and **test results**.

### 9. Merge and clean up
- Squash merge to the main branch.
- **If `devflow: true`:** call `end_work_session` with the `activity_id` from step 3 —
  it completes the activity, removes labels, and updates status.
- Remove the worktree **first**, then delete the local branch with `git branch -d` (not
  `-D`) — a branch still checked out in a worktree cannot be deleted (`gh pr merge
  --delete-branch` fails on it, and so does a manual delete). Use `-d`, never `-D`: `-d`
  refuses to delete a branch with unmerged work, while `-D` forces the delete and would
  discard unmerged commits silently. After a squash merge `-d` still *succeeds* but
  prints a harmless `merged to origin/... but not yet merged to HEAD` note — the squash
  commit on main isn't the branch tip, so the branch is merged to its own upstream ref
  but not an ancestor of main. That is expected, not a warning to act on.
- Delete the **remote** branch too — `git push origin --delete <branch>` (`gh pr merge
  --delete-branch` does this, but skips it when the earlier local delete fails). Before
  deleting any leftover branch, **do not trust `git branch --merged`** to tell you it is
  safe: because a squash merge replays the content as a new commit, the branch tip is
  never an ancestor of main and `--merged` reports a false negative. Confirm disposability
  instead by the PR's merged state (`gh pr view <n> --json state`) or that the branch's
  content is already on main.
- Pull the main branch, then **verify it advanced to the merge commit** — don't assume
  the pull succeeded. `git pull --ff-only` can abort (printing a terse "Aborting") and
  leave main at the old commit; a common cause is an untracked file in the main clone
  blocking the fast-forward. Confirm with `git log -1` (or that the merged change is now
  present); if it aborted, resolve the blocker and pull again before closing the issue.
- Close the issue explicitly with a summary of what was done.
- If `board`: move the issue to the done status.

## Escape hatches

**Quick work without a worktree** (docs, process, config): skip the worktree, but still
sync main first (`git fetch` + `git pull --ff-only`) so the commit lands on current main.
If `devflow: true`, bracket it with `log_activity_start` / `log_activity_complete`;
otherwise just do it and commit.

**Unplanned fixes discovered mid-work:** don't fix inline — it muddies the current
issue's PR. File a new issue, set the current work aside (a separate worktree makes this
free), work the fix through this lifecycle, then resume. If the fix is truly trivial and
blocking, committing directly to the main branch is acceptable, but still file a
retroactive issue documenting it.

**Maintenance / tech debt noticed during feature work:** don't fix it in the feature
branch — it inflates the diff and mixes concerns. File a maintenance issue (default low
priority) after the feature merges, and work it on its own branch.

## Key principles
- Start from current main — always sync main before branching or committing, never from a stale base.
- Review before PR, not after — catch bugs before they're visible.
- The PR tells the story — review findings and test results matter as much as the diff.
- Docs before close — architecture docs reflect the current state before an issue closes.
- One issue at a time — finish the lifecycle before starting the next.
- Every change has an issue — even unplanned fixes and maintenance get tracked.
- Paths are portable — never commit hard-coded absolute or machine-specific paths in
  configs, scripts, or code. Use relative paths from the repo root, or a variable the
  environment provides (`$CLAUDE_PROJECT_DIR`, `${CLAUDE_PLUGIN_ROOT}`). An absolute
  path works for its author and breaks for every other user, worktree, and CI run.
- Don't mix concerns — feature branches do features; maintenance branches do cleanup.
- Worktrees over branches — each issue gets its own directory; no stashing, no lost context.
