---
name: pdf-to-png
description: Convert PDFs in a folder into PNG sidecars (one PNG per page). Keeps PDFs untouched.
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "[folder] [--out png] [--dpi 200] [--recursive] [--force] [--organize]"
---

This skill uses a self-managed virtual environment at:

  __SKILLS_ROOT__\pdf-to-png\.venv

On first run (or if missing), it will:
  - create the venv
  - install/update pymupdf

Then it runs the converter via the venv Python.

Default output folder: ./png (inside the input folder), mirroring subfolders if --recursive.

Use --organize to separate files into pdf/ and png/ subfolders (moves source PDFs into pdf/).

Run:

powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\pdf-to-png\scripts\run.ps1 $ARGUMENTS
