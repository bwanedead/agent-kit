---
name: __SKILL_NAME__
description: __SKILL_DESCRIPTION__
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "__ARG_HINT__"
---

This is an instruction-only skill. There is no tool to run.

Use it for quick, off-the-cuff tasks where you just want agent guidance and direct edits.

Guidelines:
- Keep diffs minimal and focused.
- Prefer direct edits to the relevant files.
- Only run git add/commit/push if the user asks or the repo workflow requires it.
