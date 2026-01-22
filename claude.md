# Claude Code Integration

This document provides Claude Code-specific guidance for working with Agent Kit.

## What is Agent Kit?

Agent Kit is the canonical repository for Claude Code skills. Instead of editing skills directly in `~/.claude/skills/`, all skill development happens here. The installer syncs canonical skills to Claude's skills directory.

## Why This Matters for Claude

When you're asked to modify, fix, or enhance a skill:

1. **Check if you're in agent-kit** - If the working directory is agent-kit, edit the canonical files
2. **Check if the skill exists here** - Look in `skills/<skill-name>/`
3. **Edit canonical, then install** - Don't edit `~/.claude/skills/` directly

## Directory Mapping

| Canonical (agent-kit) | Installed (Claude) |
|-----------------------|-------------------|
| `skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` |
| `skills/<name>/scripts/` | `~/.claude/skills/<name>/scripts/` |
| `templates/` | `~/.claude/skills/skill-factory/templates/` |

## When Working in This Repo

### Modifying a Skill

```
1. Edit: agent-kit/skills/<skill>/SKILL.md or scripts/*
2. Sync: powershell .\install\install.ps1 -Profile media
3. Test: Use the skill normally via /skill-name
```

### Creating a New Skill

**Via skill-factory (recommended):**
```powershell
# Create skill in agent-kit/skills/
/skill-factory --name my-skill --desc "Description" --deps "requests"

# Create and immediately sync to Claude
/skill-factory --name my-skill --desc "Description" --install
```

**Manually:**
```
1. Create: agent-kit/skills/<new-skill>/
     - SKILL.md (with __SKILLS_ROOT__ placeholders)
     - scripts/run.ps1
     - scripts/<main>.py
2. Add to profile: Edit profiles/<profile>.json
3. Install: powershell .\install\install.ps1 -Profile <profile>
```

### Fixing a Bug

```
1. Locate: agent-kit/skills/<skill>/scripts/<file>
2. Fix the bug
3. Sync: powershell .\install\install.ps1 -Profile media
4. Verify: .\install\install.ps1 -Profile media -Doctor
```

## Placeholder Rules

In `SKILL.md` and `run.ps1`, use `__SKILLS_ROOT__` for any path that references the skills directory:

**SKILL.md:**
```markdown
Run:
powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\my-skill\scripts\run.ps1 $ARGUMENTS
```

**run.ps1 (only if needed):**
```powershell
$skillsRoot = "__SKILLS_ROOT__"
```

**Python files:** No placeholders. Use relative paths or `$PSScriptRoot` passed from the launcher.

## Skill Structure Template

```
skills/<skill-name>/
  SKILL.md              # Required - skill metadata and run command
  scripts/
    run.ps1             # Required - PowerShell launcher with venv isolation
    <main>.py           # Main Python implementation
  deps.txt              # Optional - pip dependencies (for template-based skills)
```

## SKILL.md Template

```markdown
---
name: <skill-name>
description: <what it does>
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "<argument pattern>"
---

<Optional description of venv location, behavior, etc.>

Run:

powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\<skill-name>\scripts\run.ps1 $ARGUMENTS
```

## Testing Changes

After any modification:

```powershell
# Sync to Claude's skills directory
.\install\install.ps1 -Profile media

# Verify installation
.\install\install.ps1 -Profile media -Doctor

# Test the skill
# (exit agent-kit and use the skill normally)
```

## Common Patterns

### Adding a CLI argument to a skill

1. Edit `skills/<skill>/scripts/<main>.py` - add argparse argument
2. Edit `skills/<skill>/SKILL.md` - update argument-hint
3. Run installer

### Adding a Python dependency

1. Edit `skills/<skill>/scripts/run.ps1` - add import check and pip install
2. Run installer

### Changing skill behavior

1. Edit `skills/<skill>/scripts/<main>.py`
2. Run installer

## What NOT to Do

| Don't | Instead |
|-------|---------|
| Edit `~/.claude/skills/*` | Edit `agent-kit/skills/*` then install |
| Hardcode `C:\Users\...` paths | Use `__SKILLS_ROOT__` placeholder |
| Add `__SKILLS_ROOT__` to .py files | Keep Python path-agnostic |

## Profiles

Current profiles:

- **minimal**: Just skill-factory
- **media**: skill-factory, pdf-to-png, splice-deed

To install a specific profile:
```powershell
.\install\install.ps1 -Profile minimal
```

## skill-factory Integration

skill-factory now creates skills **canonically in agent-kit/skills/** (not directly in Claude).

**Agent Kit Discovery:** skill-factory finds agent-kit via:
1. `AGENT_KIT_ROOT` environment variable
2. `%LOCALAPPDATA%\agent-kit\agent-kit-root.txt` config file
3. Walking upward from current directory

**Usage from Claude:**
```powershell
/skill-factory --list-templates              # See available templates
/skill-factory --name foo --desc "..."       # Create in agent-kit/skills/
/skill-factory --name foo --desc "..." --install  # Create and sync
/skill-factory --sync --profile media        # Just sync existing skills
```

## Quick Reference

```powershell
# Install all media skills
.\install\install.ps1 -Profile media

# Install minimal (just skill-factory)
.\install\install.ps1 -Profile minimal

# Check installation health
.\install\install.ps1 -Profile media -Doctor

# Custom target directory
.\install\install.ps1 -Profile media -Target "C:\custom\path"
```
