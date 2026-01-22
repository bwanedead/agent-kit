# Agent Kit - Instructions for AI Agents

This document explains how AI agents should interact with the Agent Kit repository.

## Core Concept

**Agent Kit is the canonical source of truth for all skills.**

The installed skills in `~/.claude/skills/` (or equivalent) are **generated artifacts**, not source files. When modifying skills:

1. Edit files in `agent-kit/skills/<skill-name>/`
2. Run the installer to sync changes to the live installation
3. Never edit installed skills directly (changes will be overwritten)

## Repository Layout

```
agent-kit/
  skills/           # CANONICAL - Edit skills here
  templates/        # CANONICAL - Edit templates here
  profiles/         # Declarative skill bundles
  adapters/         # Tool-specific installers
  install/          # Installer scripts
```

## Workflow: Modifying an Existing Skill

1. **Edit the canonical files:**
   ```
   agent-kit/skills/<skill-name>/SKILL.md
   agent-kit/skills/<skill-name>/scripts/run.ps1
   agent-kit/skills/<skill-name>/scripts/<main>.py
   ```

2. **Sync to live installation:**
   ```powershell
   .\install\install.ps1 -Profile <profile-name>
   ```

3. **Verify:**
   ```powershell
   .\install\install.ps1 -Profile <profile-name> -Doctor
   ```

## Workflow: Creating a New Skill

**Use skill-factory** (recommended):
```powershell
# From Claude, create a new skill in agent-kit/skills/
/skill-factory --name my-new-skill --desc "What it does" --deps "requests"

# Or create and immediately sync to Claude
/skill-factory --name my-new-skill --desc "What it does" --install
```

**Or manually:**
1. Create the canonical skill structure:
   ```
   agent-kit/skills/<new-skill>/
     SKILL.md
     scripts/
       run.ps1
       <main>.py
   ```

2. Add to appropriate profile(s):
   Edit `profiles/<profile>.json` to include the new skill.

3. Install:
   ```powershell
   .\install\install.ps1 -Profile <profile-name>
   ```

## Placeholder System

Canonical skills must use `__SKILLS_ROOT__` instead of hardcoded paths.

### Where to use placeholders

| File | Use Placeholder? |
|------|------------------|
| SKILL.md | YES - in paths shown to user and in the run command |
| scripts/run.ps1 | YES - only if the script needs to reference `$skillsRoot` |
| scripts/*.py | NO - Python files should be path-agnostic |

### Example SKILL.md

```markdown
---
name: my-skill
description: Does something useful
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "[args]"
---

Venv: __SKILLS_ROOT__\my-skill\.venv

Run:

powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\my-skill\scripts\run.ps1 $ARGUMENTS
```

### Example run.ps1 (if it needs skillsRoot)

```powershell
# Only needed if the script explicitly references the skills root
# Most scripts don't need this - they use $PSScriptRoot
$skillsRoot = "__SKILLS_ROOT__"
```

## What Gets Replaced During Installation

The adapter ONLY replaces `__SKILLS_ROOT__` in these whitelisted files:
- `SKILL.md`
- `run.ps1`

**Other files are copied verbatim.** This is intentional - it prevents accidental modification of Python code or user data.

## What Gets Preserved During Reinstall

When re-running the installer on an existing installation:

| Preserved | Replaced |
|-----------|----------|
| `.venv/` | `SKILL.md` |
| `output/` | `scripts/` |
| `logs/` | Everything else |

This means you can update skill code without losing installed dependencies.

## Profile System

Profiles are declarative lists of skills. They define:
- Which skills to install together
- Scope (global vs project - future feature)

### Active Adapters

The default install targets are controlled by:

```
%LOCALAPPDATA%\agent-kit\active-adapters.txt
```

When this file is present, it should list adapter names (comma or newline separated).
If missing or empty, all adapters under `agent-kit/adapters/` are used.

### Creating a New Profile

Add a JSON file to `profiles/`:

```json
{
  "name": "my-profile",
  "description": "Description of this skill bundle",
  "skills": [
    { "name": "skill-factory", "scope": "global" },
    { "name": "my-skill", "scope": "global" }
  ]
}
```

## Common Tasks

### Add a dependency to an existing skill

1. Edit `agent-kit/skills/<skill>/scripts/run.ps1`
2. Add the import check and install logic
3. Run installer to sync

### Change a skill's description or argument hint

1. Edit `agent-kit/skills/<skill>/SKILL.md`
2. Run installer to sync

### Fix a bug in skill Python code

1. Edit `agent-kit/skills/<skill>/scripts/<main>.py`
2. Run installer to sync

### Create a project-specific skill

1. Create the skill in `agent-kit/skills/`
2. Create a project-specific profile that includes it
3. Install with that profile when working on that project

## Validation

Always run doctor mode after making changes:

```powershell
.\install\install.ps1 -Profile <profile> -Doctor
```

This catches:
- Missing files
- Unresolved placeholders
- Incomplete installations

## Do NOT

- Edit files directly in `~/.claude/skills/` - they will be overwritten
- Put hardcoded user paths in canonical skills
- Add `__SKILLS_ROOT__` to Python files
- Create skills directly via skill-factory without adding to agent-kit (for canonical skills)

## skill-factory Behavior

skill-factory now creates skills **canonically in agent-kit/skills/** (not directly in ~/.claude/skills).

The workflow is:
1. `/skill-factory --name my-skill --desc "..."` creates `agent-kit/skills/my-skill/`
2. Adds the skill to a profile (default: `global`, unless `--no-add`)
3. Installs to active adapters by default (use `--no-install` to skip)

**Agent Kit Discovery:** skill-factory locates the agent-kit repo via:
1. `AGENT_KIT_ROOT` environment variable
2. `%LOCALAPPDATA%\agent-kit\agent-kit-root.txt` config file
3. Walking upward from current directory

If working from within the agent-kit tree, discovery happens automatically.
