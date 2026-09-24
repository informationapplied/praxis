---
name: workflow
description: Use when starting, continuing, or finishing any tracked unit of work in a praxis repo — the issue-driven lifecycle (find, scope, start, implement, self-review, docs, test, PR, merge, close) adapted to this repo's .claude/praxis.json. Invoke before beginning issue work; do NOT invoke for quick questions or trivial one-offs.
---

# The praxis workflow

An issue-driven lifecycle: every change maps to a tracked issue and moves through
claim → build → self-review → review → merge → close, in an isolated worktree, with the
PR opened as a draft at the claim and reviewed before it is marked ready. This skill
adapts to the repo. Read the config first.

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
Query the `tracker` (and `board`, if configured) for the highest-priority unstarted item
**whose dependencies are all met** — an issue you would immediately be blocked on is not
the next issue. With a `board`, take from the status step 2 approves into: that is where
takeable work sits, and anything earlier has not been scoped yet.

Where several issues tie at the top priority, choose among them at random. Workers
applying the same rule to the same board otherwise converge on the same issue.

Take one that is well enough defined to deliver on its own. If it does not say what done
looks like, scope it (step 2) — but only if scoping is yours to do; see the note there.

**Claim it before doing any work**, in two steps:

1. Create the branch ref at the base commit: `git push origin <base-sha>:refs/heads/<branch>`,
   named per `branchPattern`. Ref creation is an atomic compare-and-swap — exactly one
   worker succeeds and the rest are rejected in under a second, before anyone has spent
   effort.
2. Open a **draft PR** from that branch whose body closes the issue.

Then assign yourself — or the person you are acting for — and move the issue to the
in-progress status. Assignment and the board make the claim visible; they do not grant
it. The assignee field cannot: workers may share an account, and an agent acting for a
person assigns that person, so "who holds this?" is not answerable from the board alone.

The draft PR is the durable half. A branch ref can be deleted and recreated, which would
let a second worker claim an issue the first still holds; the PR survives that, records
who claimed and when, and is what the handoff hooks read to link a branch to its issue —
from the first commit rather than from the end of the lifecycle.

With a human in the loop, present the issue and confirm before claiming. Working
autonomously, just take it.

### 2. Scope
**Scoping may not be yours to do.** If the repo reserves `prd.path`, specs or plans to a
particular role — check its AGENTS.md or equivalent — a worker that finds an unready
issue says so on the issue and takes something else, rather than scoping it itself. Only
scope where the repo permits you to edit those files. The steps below assume it does.

- If `board`: move the issue to the scoping status.
- Decide whether the change alters **what the product does** (vs. how it's built). If
  yes and `prd` is configured, update `prd.path` and treat this as a PRD change.
- If `prd` is configured, assign requirement IDs — map to existing IDs or mint the next
  sequential one per `prd.idScheme` (e.g. `SEC-017` after `SEC-016`) — and list them in
  the issue body under a `## PRD Requirements` heading.
- Size the issue using `sizing` if not already sized.
- If `board`: move to the approved status when scoping is complete.

### 3. Start work
The branch already exists — you created it as the claim in step 1, and the base commit
was fixed then. This step checks it out; it does not create it.

- **Sync main first.** `git fetch origin` and `git pull --ff-only` on the default branch,
  and verify it advanced, so you are reasoning about current state rather than a stale
  local copy. Claim from current main in step 1 for the same reason: a stale base starts
  the work behind and invites conflicts at merge.
- **If `devflow: true`** and the devflow MCP server is connected: call
  `start_work_session` — it logs activity start, adds the in-progress label, and returns
  an `activity_id`. **Save the `activity_id` for step 9.** Where it would create a branch
  or set status, the claim has already done both; do not let it create a second branch.
- **Otherwise (manual path):** add a git worktree as a sibling directory on the branch you
  claimed — `git worktree add <path> <branch>`, with no `-b`. Skip activity logging. Never
  instruct devflow tool calls when `devflow` is false.
- All implementation happens in the worktree, not the main clone.

### 4. Implement
Work entirely in the worktree. Commit between changes — after implementation, after
review fixes, after test fixes — not one batched commit. Reference the issue number.

Keep the handoff comment current as you go (below). Update it whenever you commit or
make a decision you would have to explain to whoever takes over.

### 5. Self-review (before the PR is ready, not after)
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

### 8. Mark the PR ready
The PR already exists — it was opened as a draft when you claimed the issue. Push the
branch and fill its body out into the story: a summary of changes, the **review
findings** from step 5 and how they were fixed, and **test results**. Then mark it ready
for review.

Do not force-push to integrate the default branch. A work branch may be held by a
successor or carry a reviewer's commit, and a force-push silently discards them; merge
the default branch in instead. Repos that enforce this deny force-push on work branches,
in which case the push simply fails.

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

## Handing off unfinished work

Work stops mid-issue all the time — a session hits its limit, a worker is interrupted,
priorities move. What must not happen is an issue left looking active with nothing
recording where it got to.

**Keep one handoff comment current.** While an issue is assigned to you, maintain a
single comment on it, edited in place rather than re-posted. Start it with the line
`<!-- praxis:handoff -->` so tooling can find it, then a line identifying you:

```
<!-- praxis:handoff -->
worker: <id> · <service> · branch <branch> · head <sha> · <UTC timestamp>
```

The identity line matters more than it looks. The assignee field cannot carry it —
several workers may run under one account, and an agent acting for a person assigns
that person — so without it "who holds this, and when were they last alive?" has no
answer, and neither "is this stalled?" nor "did I write this?" can be decided.

Then the substance:

- what is done and committed
- what is in progress, and where you left it
- what you would do next
- the last time you ran the acceptance or test command, and its verbatim result
  (or that you did not run it)
- anything you learned that the diff does not show — a dead end, a surprising
  constraint, a decision and why

**Update it as you go, not at the end.** By the time a session is out of budget it has
no room left to write anything thoughtful. A handoff refreshed at each commit means an
abrupt end costs one step, not the whole session. This matters more than any warning
signal: nothing reliably tells you that you are about to be cut off.

**When you stop before the work is deliverable:** update the comment, unassign yourself,
and move the issue back to the status it was takeable in — the one step 2 approves into,
not an earlier one, or the work silently leaves the pool. Leave the branch pushed: it is
the real record, and the next worker should read it rather than trust prose.

**Picking up someone else's work:** the branch is authoritative; the handoff comment is
orientation. Treat anything past the last commit as lost. If an issue is assigned to a
worker that has plainly stopped — the identity line and the branch head both older than
the work would take — unassign them and take it.

Run the acceptance command before adding to an inherited branch. The handoff is prose
written by the worker that produced the work, asserting what is done; running the command
is the only thing that checks it.

An inherited branch can be wrong rather than merely unfinished, and building on a wrong
one is the most expensive way to fail. You may discard it and restart from the base —
record in the handoff comment what you discarded and why, so the next reader does not
resurrect it.

Add your own identity line when you take over; do not overwrite the previous worker's.
The record of who wrote what has to survive the handoff, because it is what decides who
is allowed to review it.

Three hooks enforce the mechanical part of this, and stay silent in repos without a
`.claude/praxis.json`. `Stop` refuses to end a turn while the branch has commits newer
than the handoff comment. `PreCompact` warns when context is about to be summarised.
`SessionEnd` flags the issue if a session dies mid-work. All of them fail open.

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
- Review before the PR is ready, not after — catch bugs before anyone else sees them.
- The PR tells the story — review findings and test results matter as much as the diff.
- Docs before close — architecture docs reflect the current state before an issue closes.
- One issue at a time — finish the lifecycle before starting the next.
- Claim before you work — the branch ref and a draft PR, not the assignee field.
- Never leave an issue assigned and silent — the handoff comment stays current, or the issue goes back to the takeable status.
- Every change has an issue — even unplanned fixes and maintenance get tracked.
- Bump the version when a plugin changes — installed copies are cached by version, so a merge with
  an unchanged version reaches nobody and says nothing about it.
- Paths are portable — never commit hard-coded absolute or machine-specific paths in
  configs, scripts, or code. Use relative paths from the repo root, or a variable the
  environment provides (`$CLAUDE_PROJECT_DIR`, `${CLAUDE_PLUGIN_ROOT}`). An absolute
  path works for its author and breaks for every other user, worktree, and CI run.
- Don't mix concerns — feature branches do features; maintenance branches do cleanup.
- Worktrees over branches — each issue gets its own directory; no stashing, no lost context.
