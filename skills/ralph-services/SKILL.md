---
name: ralph-services
description: Bootstrap, validate, and update Ralph workflow infrastructure in projects
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "--init . | --init <path> | --update | --doctor | --print-root | --set-root <path>"
---

Ralph Services - manage Ralph workflow infrastructure across projects.

## Quick Start

```bash
# Initialize Ralph in current project (most common)
/ralph-services --init .

# Initialize Ralph in a specific directory
/ralph-services --init C:\projects\my-project
```

## Commands

### Initialize Ralph in a project
```
/ralph-services --init <target-path>
```
Creates the Ralph directory structure and copies templates from the canonical source.

**target-path**: The project root where `ralph/` directory will be created.
- Use `.` for current directory (most common)
- Use an absolute path like `C:\projects\my-project` for other locations

**Examples:**
```bash
/ralph-services --init .                      # Initialize in current directory
/ralph-services --init C:\projects\algent     # Initialize in specific project
```

### Update Ralph templates
```
/ralph-services --update [<target-path>] [--force]
```
Syncs templates from canonical source. Preserves `runs/` directory. Defaults to current directory.
Refuses to run if canonical repo has uncommitted changes (use `--force` to override).

**Examples:**
```bash
/ralph-services --update          # Update current project
/ralph-services --update --force  # Update even if canonical has uncommitted changes
```

### Validate Ralph setup
```
/ralph-services --doctor [<target-path>]
```
Checks Ralph installation health. Shows version mismatch if project is behind canonical.

**Examples:**
```bash
/ralph-services --doctor          # Check current project
/ralph-services --doctor .        # Same as above
```

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

## Canonical Source Discovery

The canonical Ralph root is found via (first match wins):
1. `RALPH_ROOT` environment variable
2. `%LOCALAPPDATA%\ralph\ralph-root.txt` config file
3. Fallback: `C:\projects\ralph`

## Run

```
powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\ralph-services\scripts\run.ps1 $ARGUMENTS
```
