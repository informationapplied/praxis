---
description: Report whether the praxis SessionStart hook fired and what it injected
---

Report the praxis SessionStart hook status by inspecting ONLY what is already in
your context — do not run any tools.

1. State plainly whether a `PRAXIS_HOOK_OK` line is present in your context.
2. If present, quote it verbatim, then break out its fields:
   - `cwd` — the directory Claude was launched from
   - `project` — the resolved `$CLAUDE_PROJECT_DIR`; for a launch inside a repo this
     should be the repo root, even if `cwd` is a subdirectory
   - `plugin_root` — the installed plugin path, confirming marketplace / plugin / version
3. Note whether `project` equals the repo root (anchoring correct) or matches `cwd`
   (either a root launch, or launched outside any repo).
4. If no `PRAXIS_HOOK_OK` line is present, say so directly: the hook did not fire or its
   output did not reach context.
