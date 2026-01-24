---
name: ralph-services
description: Bootstrap, validate, and update Ralph workflow infrastructure in projects
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "--init <path> | --update [<path>] [--force] | --doctor [<path>] | --print-root | --set-root <path>"
---

Ralph Services - manage Ralph workflow infrastructure across projects.

## Commands

### Initialize Ralph in a project
```
/ralph-services --init <target-path>
```
Creates the Ralph directory structure and copies templates from the canonical source.

### Update Ralph templates
```
/ralph-services --update [<target-path>] [--force]
```
Syncs templates from canonical source. Preserves `runs/` directory. Defaults to current directory.
Refuses to run if canonical repo has uncommitted changes (use `--force` to override).

### Validate Ralph setup
```
/ralph-services --doctor [<target-path>]
```
Checks Ralph installation health. Shows version mismatch if project is behind canonical.

### Print canonical root
```
/ralph-services --print-root
```
Shows the resolved canonical Ralph root and where it came from (env/config/fallback).

### Set canonical Ralph root
```
/ralph-services --set-root <path>
```
Saves the canonical Ralph source path to user config.

## Discovery

The canonical Ralph root is found via (first match wins):
1. `RALPH_ROOT` environment variable
2. `%LOCALAPPDATA%\ralph\ralph-root.txt` config file
3. Fallback: `C:\projects\ralph`

## Run

```
powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\ralph-services\scripts\run.ps1 $ARGUMENTS
```
