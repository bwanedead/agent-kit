---
name: skill-factory
description: Create new Agent Kit skills from templates and sync them to supported CLIs.
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "--name <skill-name> --desc \"...\" [--template <name>] [--deps \"pkg1,pkg2\"] [--install | --no-install] [--adapter <name> | --adapters \"a,b\"] [--add-to-profile <name> | --no-add] | --list-templates | --sync --profile <name> [--adapter <name> | --adapters \"a,b\"] | --help"
---

Creates canonical skills in **agent-kit/skills/** (not directly in ~/.claude/skills).
Use the Agent Kit installer to sync skills to supported CLIs after creation.

## Usage

```
# List available templates
/skill-factory --list-templates

# Create a new skill (in agent-kit/skills/)
/skill-factory --name my-tool --desc "Does something useful" --deps "requests"

# Create and immediately install to all active adapters
/skill-factory --name my-tool --desc "Does something useful" --install

# Sync all skills from a profile to a specific adapter
/skill-factory --sync --profile media

# Sync to multiple adapters
/skill-factory --sync --profile media --adapters "claude,codex"

# Show help
/skill-factory --help
```

## Options

| Option | Description |
|--------|-------------|
| `--name <name>` | Required. Name for the new skill |
| `--desc "..."` | Description (default: TODO) |
| `--template <name>` | Template to use (default: python-venv-ps) |
| `--deps "pkg1,pkg2"` | Python dependencies |
| `--arg-hint "..."` | Argument hint for SKILL.md |
| `--dest <path>` | Override destination (advanced) |
| `--overwrite` | Overwrite existing skill |
| `--install` | Install after creation (default: on) |
| `--no-install` | Do not install after creation |
| `--adapter <name>` | Limit install/sync to one adapter |
| `--adapters "a,b"` | Limit install/sync to multiple adapters |
| `--add-to-profile <name>` | Add new skill to a profile (default: global) |
| `--no-add` | Do not add the new skill to any profile |
| `--profile <name>` | Profile for --install/--sync (default: global) |

## Agent Kit Discovery

The factory locates agent-kit via (first match wins):
1. `AGENT_KIT_ROOT` environment variable
2. `%LOCALAPPDATA%\agent-kit\agent-kit-root.txt` config file
3. Walking upward from current directory

## Active Adapters

By default, `--install` and `--sync` target all active adapters listed in:

```
%LOCALAPPDATA%\agent-kit\active-adapters.txt
```

The file can be comma- or newline-separated (for example `claude,codex`).
If the file is missing or empty, all adapters in `agent-kit/adapters/` are used.

## Run

```
powershell -NoProfile -ExecutionPolicy Bypass -File __SKILLS_ROOT__\skill-factory\scripts\run.ps1 $ARGUMENTS
```
