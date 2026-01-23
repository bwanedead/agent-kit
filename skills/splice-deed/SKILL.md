---
name: splice-deed
description: Split landscape double-page deed images into single-page images (writes splices to a subfolder; originals untouched by default).
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "[folder] [--out splice] [--recursive] [--force] [--organize] [--mode auto|vertical|horizontal] [--search 0.12] [--band 0.01]"
---

This skill uses a self-managed virtual environment at:

  __SKILLS_ROOT__\splice-deed\.venv

On first run (or if missing), it will:
  - create the venv
  - install/update pillow

Default output folder: ./splice (inside the input folder), mirroring subfolders if --recursive.

Use --organize to move successfully-split originals into ./double (mirrors structure), while splices go into ./splice.

Run:

powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\splice-deed\scripts\run.ps1 $ARGUMENTS
