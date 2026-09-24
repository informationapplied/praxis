#!/usr/bin/env bash
# praxis handoff hooks. One script, dispatched on hook_event_name.
#
# Purpose: an issue assigned to a worker that stops mid-flight must not be left
# looking active. The worker's handoff comment is the record of where the work
# got to; these hooks keep it honest.
#
#   Stop        — refuse to end the turn while the branch has commits newer than
#                 the handoff comment. Tells the worker what to write.
#   PreCompact  — context is filling. Remind the worker to refresh the handoff
#                 before detail is compacted away.
#   SessionEnd  — best effort, no model involved: flag the issue so the next
#                 worker (or a sweep) can see the session died mid-work.
#
# Contract: fail OPEN. Any missing tool, unparseable input, network failure or
# unexpected state exits 0 and lets the session proceed. A process hook that
# blocks work because `gh` was offline is worse than no hook at all.
#
# Opt-in: silent unless the repo has committed a .claude/praxis.json.

set -u

MARKER='<!-- praxis:handoff -->'

input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null) || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
PROJECT="${CLAUDE_PROJECT_DIR:-${cwd:-$PWD}}"

# Opt-in gate. A worktree sits beside the repo, so check the git root too.
git_root=$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$PROJECT/.claude/praxis.json" ] || [ -f "$git_root/.claude/praxis.json" ] || exit 0

command -v gh >/dev/null 2>&1 || exit 0

cd "$git_root" 2>/dev/null || exit 0

# --- which issue is this branch working? -------------------------------------
# branchPattern is repo-configurable, so don't parse it: take the first number
# in the branch name. Covers issue-12-slug, 12-slug, feature/12-slug, unit/12.
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
issue=$(printf '%s' "$branch" | grep -oE '[0-9]+' | head -1)
[ -n "$issue" ] || exit 0

# --- is there unhanded-off work? ---------------------------------------------
base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
[ -n "$base" ] || base="origin/main"
git rev-parse --verify "$base" >/dev/null 2>&1 || exit 0

# Count from the fork point, not the remote tip: a diverged or stale local
# default branch would otherwise inflate this into every unrelated commit.
# merge-base exits non-zero on unrelated histories and shallow clones, so fall
# back to the remote tip rather than going quiet.
fork=$(git merge-base "$base" HEAD 2>/dev/null)
if [ -n "$fork" ]; then
  ahead=$(git rev-list --count "$fork..HEAD" 2>/dev/null)
else
  ahead=$(git rev-list --count "$base..HEAD" 2>/dev/null)
fi
[ -n "${ahead:-}" ] || exit 0
[ "$ahead" -gt 0 ] 2>/dev/null || exit 0    # nothing committed, nothing to hand off

# Compare times as UTC digit strings (20260924110000). Git reports the
# committer's offset and GitHub reports Zulu, so comparing the ISO text
# directly misreads by the size of the offset.
last_commit=$(TZ=UTC git log -1 --format=%cd --date=format:'%Y%m%d%H%M%S' 2>/dev/null) || exit 0
[ -n "$last_commit" ] || exit 0
last_commit_h=$(TZ=UTC git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M UTC' 2>/dev/null)

# --- latest handoff comment on the issue -------------------------------------
# updated_at, not created_at: the worker edits one comment in place.
handoff_iso=$(gh api "repos/{owner}/{repo}/issues/$issue/comments" \
    --paginate --jq "[.[] | select(.body | contains(\"$MARKER\")) | .updated_at] | max // empty" \
    2>/dev/null) || exit 0
handoff_at=$(printf '%s' "$handoff_iso" | tr -cd '0-9')

stale=1
if [ -z "$handoff_at" ]; then
  stale=0                                   # no handoff at all
elif [ "$handoff_at" -lt "$last_commit" ] 2>/dev/null; then
  stale=0                                   # handoff predates the latest commit
fi

case "$event" in

  Stop)
    [ "$stale" -eq 0 ] || exit 0
    # Only ever block once per turn, or the worker cannot finish.
    [ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

    if [ -z "$handoff_at" ]; then
      why="Issue #$issue has no handoff comment and this branch has $ahead commit(s)."
    else
      why="The handoff comment on issue #$issue ($handoff_iso) is older than your last commit (${last_commit_h:-$last_commit})."
    fi

    # exit 2 sends stderr back to the model as the reason it may not stop.
    cat >&2 <<EOF
$why

Update the handoff comment on issue #$issue before finishing. Edit the existing
one if there is one, so the issue keeps a single current handoff. Start it with
the line $MARKER and cover:

  - what is done and committed
  - what is in progress and where you left it
  - what you would do next
  - anything you learned that the diff does not show

If the work is not deliverable and you are stopping for good, also unassign
yourself and move the issue back to the ready status.
EOF
    exit 2
    ;;

  PreCompact)
    [ "$stale" -eq 0 ] || exit 0
    jq -n --arg i "$issue" '{
      systemMessage: ("Context is being compacted. Refresh the handoff comment on issue #" + $i +
                      " first — detail you have not written down will not survive the summary.")
    }'
    exit 0
    ;;

  SessionEnd)
    [ "$stale" -eq 0 ] || exit 0
    # /clear and resume are not the session dying mid-work.
    reason=$(jq -r '.reason // "other"' <<<"$input")
    case "$reason" in clear|resume) exit 0 ;; esac

    # Only speak up if this issue is actually assigned to someone.
    assignees=$(gh issue view "$issue" --json assignees --jq '.assignees | length' 2>/dev/null) || exit 0
    [ "${assignees:-0}" -gt 0 ] || exit 0

    gh issue comment "$issue" --body "$MARKER
This session ended (\`$reason\`) with $ahead commit(s) on \`$branch\` newer than the
last handoff. The work may be further along than this issue records. The branch
holds the committed state; treat anything past the last commit as lost.

Whoever picks this up: read the branch, not this comment. If nobody is actively
working it, unassign the current assignee and move it back to the ready status." \
    >/dev/null 2>&1 || exit 0
    exit 0
    ;;

esac

exit 0
