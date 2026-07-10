#!/usr/bin/env bash
# praxis SessionStart hook.
#
# Contract: ALWAYS exit 0 and never emit an error that could break a session.
# Invoked as `bash session-start.sh`, so a lost executable bit is harmless.
# Whatever it prints to stdout enters the session context (it is for Claude to
# read, not a banner for the user).
#
# It nudges ONLY when this repo has opted into praxis by committing a
# .claude/praxis.json. In any other repo it stays silent, so praxis never
# imposes its process on a repo that has not asked for it (e.g. a client repo).

set -u

PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"

if [ -f "$PROJECT/.claude/praxis.json" ]; then
  cat <<'NUDGE'
This repo uses praxis: an issue-driven way of working. Every change maps to a tracked issue and moves through scope → build → self-review → PR → merge → close, using isolated worktrees and reviewing before opening a PR. This repo's specifics — tracker, board, PRD path, whether devflow is available — live in .claude/praxis.json. Before starting or continuing tracked work, invoke the praxis:workflow skill; it loads the full lifecycle adapted to this repo. Do not impose this process on quick questions or trivial one-offs.
NUDGE
fi

exit 0
