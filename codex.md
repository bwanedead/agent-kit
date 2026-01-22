# Codex CLI Skills (Agent Kit Notes)

This doc summarizes how Codex skills are structured and how Agent Kit installs them.

## Skill layout

A Codex skill is a folder with a required `SKILL.md` plus optional folders:

- `SKILL.md` (required)
- `scripts/` (optional)
- `references/` (optional)
- `assets/` (optional)

Codex reads the skill `name` and `description` at startup, then loads the full file when invoked.

## SKILL.md front matter

`SKILL.md` must start with YAML front matter and include at least:

- `name`
- `description`

Other keys are optional (for example `short-description`, `allowed-tools`, etc.).

## Where Codex loads skills

Codex loads skills from multiple locations with higher precedence overriding lower ones:

1. `./.codex/skills` (repo scope)
2. Parent `./.codex/skills` (repo scope)
3. Repo root `./.codex/skills`
4. User scope: `~/.codex/skills`
5. Admin scope: `/etc/codex/skills`
6. Bundled skills

Codex also supports symlinked skill folders.

## Codex home and config

- Codex home defaults to `~/.codex`
- Config file: `~/.codex/config.toml`
- Per-skill enable/disable is supported via `[[skills.config]]` entries in `config.toml`

## Agent Kit integration

Agent Kit installs skills into Codex via the `codex` adapter.

- Adapter path: `agent-kit/adapters/codex`
- Default target: `~/.codex/skills`
- Placeholders: `__SKILLS_ROOT__` is replaced during install

### Install a profile to Codex

```powershell
.\install\install.ps1 -Profile media -Adapter codex
```

### Install to both Claude and Codex

```powershell
.\install\install.ps1 -Profile media -Adapter claude
.\install\install.ps1 -Profile media -Adapter codex
```

### From skill-factory

```powershell
/skill-factory --name my-skill --desc "..." --install
```

By default, `--install` runs the installer for all adapters.
