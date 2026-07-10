#!/usr/bin/env bash
# praxis SessionStart hook.
#
# Contract: this must ALWAYS exit 0 and never emit an error that could break a
# session. Invoked as `bash session-start.sh`, so a lost executable bit is
# harmless. Whatever it prints to stdout enters the session context.
#
# Skeleton stage: it prints a sentinel that also echoes the launch cwd and the
# resolved project dir, so we can confirm across every surface that (a) the hook
# fires, (b) its stdout reaches context, and (c) $CLAUDE_PROJECT_DIR anchors to
# the repo root regardless of the directory Claude was launched from. Once the
# mechanism is validated, this echo is replaced by the real one-line nudge.

set -u

echo "PRAXIS_HOOK_OK cwd=${PWD} project=${CLAUDE_PROJECT_DIR:-unset} plugin_root=${CLAUDE_PLUGIN_ROOT:-unset}"

exit 0
