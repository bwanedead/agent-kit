---
name: __SKILL_NAME__
description: __SKILL_DESCRIPTION__
allowed-tools: PowerShell
disable-model-invocation: true
argument-hint: "__ARG_HINT__"
---

Venv: __SKILL_ROOT__\.venv

Run:

powershell -NoProfile -ExecutionPolicy Bypass -File __SKILL_ROOT__\scripts\run.ps1 $ARGUMENTS
