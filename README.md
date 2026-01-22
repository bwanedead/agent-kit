# Agent Kit

Portable, canonical skill library for Claude Code (and future tools).

## Overview

Agent Kit is the **single source of truth** for all Claude Code skills, templates, and adapters. The system supports:

- Cross-machine portability (clone + install)
- Clear separation between canonical skill definitions and tool-specific installed copies
- Profiles (bundles of skills) for different use cases
- Global vs project-scoped skills (future)

**Core Principle:** Agent Kit is the library. Claude's skills folder is a generated installation target.

## Quick Start

```powershell
# Clone the repository
git clone https://github.com/yourusername/agent-kit.git
cd agent-kit

# Install the media profile (includes all skills)
.\install\install.ps1 -Profile media

# Or install just the minimal profile (skill-factory only)
.\install\install.ps1 -Profile minimal

# Verify installation
.\install\install.ps1 -Profile media -Doctor
```

## First-Time Setup

After installing, skill-factory needs to find this repo when invoked from Claude. The discovery happens automatically if you run from inside agent-kit, but for convenience you should set one of:

**Option 1: Environment variable (recommended)**
```powershell
[System.Environment]::SetEnvironmentVariable("AGENT_KIT_ROOT", "C:\path\to\agent-kit", "User")
```

**Option 2: User-level config file**
```powershell
# Windows: creates %LOCALAPPDATA%\agent-kit\agent-kit-root.txt
$dir = Join-Path $env:LOCALAPPDATA "agent-kit"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
"C:\path\to\agent-kit" | Set-Content (Join-Path $dir "agent-kit-root.txt")
```

This config persists across reinstalls (unlike files inside installed skills).

## Repository Structure

```
agent-kit/
  skills/           # Canonical skill definitions (EDIT HERE)
    skill-factory/
    splice-deed/
    pdf-to-png/
  templates/        # Canonical templates for skill-factory
    python-venv-ps/
  profiles/         # Named bundles of skills
    minimal.json
    media.json
  adapters/         # Tool-specific installers
    claude/
  install/          # Installer entry points
    install.ps1
  AGENTS.md         # Instructions for AI agents
  claude.md         # Claude Code specific guidance
```

## Installer

### Install a Profile

```powershell
.\install\install.ps1 -Profile media
```

### Doctor Mode

Run diagnostics to verify installation health:

```powershell
.\install\install.ps1 -Profile media -Doctor
```

Doctor checks:
- Profile and skills exist in canonical repo
- Skills are installed in target directory
- No unresolved `__SKILLS_ROOT__` placeholders remain
- Version stamps are present
- Required files (SKILL.md, run.ps1) exist

### Custom Target

```powershell
.\install\install.ps1 -Profile media -Target "C:\custom\skills"
```

## Profiles

Profiles define which skills get installed together.

| Profile | Skills | Use Case |
|---------|--------|----------|
| minimal | skill-factory | Just the skill creator |
| media | skill-factory, pdf-to-png, splice-deed | Document/image processing |

## Skills

### skill-factory

Creates new Claude skills **canonically in agent-kit/skills/** (not directly in Claude). Use the installer to sync.

```powershell
# List available templates
/skill-factory --list-templates

# Create a new skill (in agent-kit/skills/)
/skill-factory --name my-tool --desc "My tool description" --deps "requests,pillow"

# Create and immediately sync to Claude
/skill-factory --name my-tool --desc "My tool" --install

# Just sync existing skills to Claude
/skill-factory --sync --profile media
```

**Workflow:**
1. skill-factory creates canonical skill in `agent-kit/skills/`
2. Add skill to a profile (edit `profiles/media.json`)
3. Run installer to sync: `.\install\install.ps1 -Profile media`

### pdf-to-png

Converts PDFs to PNG images (one per page).

```powershell
/pdf-to-png .
/pdf-to-png . --recursive --dpi 300
```

### splice-deed

Splits double-page deed images into single-page images.

```powershell
/splice-deed .
/splice-deed . --recursive --organize
```

## Installation Behavior

### Idempotent Updates

Re-running the installer safely updates skills:

- **Preserved on reinstall:** `.venv`, `output/`, `logs/`
- **Replaced on reinstall:** All other skill files

This means you can update skills without losing installed dependencies or output data.

### Version Stamps

Each installed skill gets a `.agent-kit-meta.json` file containing:

```json
{
  "skill_name": "pdf-to-png",
  "installed_at": "2024-01-15T10:30:00Z",
  "installed_from_profile": "media",
  "installed_from_commit": "abc1234",
  "agent_kit_version": "1.0.0"
}
```

### Placeholder Contract

Canonical skills use `__SKILLS_ROOT__` placeholder. The adapter:

1. Only replaces in whitelisted files (`SKILL.md`, `run.ps1`)
2. Fails if any placeholder remains after installation
3. Never modifies Python files or user data

## Design Principles

1. **Edit canonical, install live** - All changes happen in agent-kit first, then sync to installed copies
2. **Canonical skills are tool-agnostic** - Use `__SKILLS_ROOT__` placeholder instead of hardcoded paths
3. **Adapters handle path resolution** - The adapter replaces placeholders during installation
4. **Profiles are declarative** - Lists of skills only, no logic
5. **Installer is idempotent** - Safe to re-run, preserves runtime artifacts
6. **Fail-loud behavior** - Errors abort immediately with clear messages

## For AI Agents

See [AGENTS.md](AGENTS.md) for instructions on how AI agents should interact with this repository.

See [claude.md](claude.md) for Claude Code specific guidance.

## License

MIT
