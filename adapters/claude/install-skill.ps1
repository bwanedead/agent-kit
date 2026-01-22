# Claude Adapter: Install a single skill
# Usage: install-skill.ps1 -SkillName <name> -SourceRoot <agent-kit-path> -TargetRoot <claude-skills-path> [-ProfileName <name>] [-RepoCommit <hash>]

param(
  [Parameter(Mandatory=$true)]
  [string] $SkillName,

  [Parameter(Mandatory=$true)]
  [string] $SourceRoot,

  [Parameter(Mandatory=$true)]
  [string] $TargetRoot,

  [Parameter(Mandatory=$false)]
  [string] $ProfileName = "",

  [Parameter(Mandatory=$false)]
  [string] $RepoCommit = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# WHITELIST: Only these files get placeholder replacement
# This prevents accidental replacement in user data or unexpected files
$PlaceholderWhitelist = @(
  "SKILL.md",
  "run.ps1"
)

# PRESERVE: These directories are never deleted on reinstall
# Protects runtime artifacts like venvs and user output
$PreserveOnReinstall = @(
  ".venv",
  "output",
  "logs"
)

function Test-PlaceholderWhitelisted($fileName) {
  return $PlaceholderWhitelist -contains $fileName
}

function Remove-SkillExceptPreserved($skillPath) {
  # Remove all files and folders EXCEPT those in PreserveOnReinstall
  if (-not (Test-Path $skillPath)) { return }

  Get-ChildItem -Path $skillPath -Force | ForEach-Object {
    $name = $_.Name
    if ($PreserveOnReinstall -contains $name) {
      Write-Host "  Preserving: $name"
    } else {
      Remove-Item -Recurse -Force $_.FullName
    }
  }
}

function Copy-SkillFiles($source, $dest) {
  # Copy all files from source, but don't overwrite preserved directories
  Get-ChildItem -Path $source -Force | ForEach-Object {
    $destPath = Join-Path $dest $_.Name
    if ($PreserveOnReinstall -contains $_.Name -and (Test-Path $destPath)) {
      # Skip - preserved item already exists
      return
    }
    Copy-Item -Recurse -Force $_.FullName $destPath
  }
}

function Test-PlaceholderRemains($skillPath) {
  # Scan ALL text files for remaining placeholders - this catches mistakes
  $textExtensions = @(".md", ".ps1", ".py", ".json", ".txt", ".yml", ".yaml", ".toml")
  $found = @()

  Get-ChildItem -Path $skillPath -Recurse -File | Where-Object {
    $_.Extension -in $textExtensions
  } | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains("__SKILLS_ROOT__")) {
      $found += $_.FullName
    }
  }

  return $found
}

function Write-VersionStamp($skillPath, $skillName, $profileName, $repoCommit) {
  $stamp = @{
    skill_name = $skillName
    installed_at = (Get-Date -Format "o")
    installed_from_profile = $profileName
    installed_from_commit = $repoCommit
    agent_kit_version = "1.0.0"
  }

  $stampPath = Join-Path $skillPath ".agent-kit-meta.json"
  $stamp | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $stampPath
}

try {
  $skillSource = Join-Path (Join-Path $SourceRoot "skills") $SkillName
  $skillDest = Join-Path $TargetRoot $SkillName

  # Validate source exists
  if (-not (Test-Path $skillSource)) {
    throw "Skill not found in agent-kit: $skillSource"
  }

  # Remove existing installation EXCEPT preserved directories
  if (Test-Path $skillDest) {
    Write-Host "  Updating existing: $skillDest"
    Remove-SkillExceptPreserved $skillDest
  } else {
    New-Item -ItemType Directory -Path $skillDest -Force | Out-Null
  }

  # Copy skill files to destination
  Write-Host "  Copying: $skillSource -> $skillDest"
  Copy-SkillFiles $skillSource $skillDest

  # Replace __SKILLS_ROOT__ placeholder ONLY in whitelisted files
  Get-ChildItem -Path $skillDest -Recurse -File | ForEach-Object {
    if (Test-PlaceholderWhitelisted $_.Name) {
      $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
      if ($content -and $content.Contains("__SKILLS_ROOT__")) {
        $newContent = $content.Replace("__SKILLS_ROOT__", $TargetRoot)
        $newContent | Set-Content -Encoding UTF8 $_.FullName
        Write-Host "  Patched: $($_.Name)"
      }
    }
  }

  # Handle skill-factory special case: copy templates into the installed skill
  if ($SkillName -eq "skill-factory") {
    $templatesSource = Join-Path $SourceRoot "templates"
    $templatesDest = Join-Path $skillDest "templates"

    if (Test-Path $templatesSource) {
      Write-Host "  Copying templates for skill-factory..."
      if (Test-Path $templatesDest) {
        Remove-Item -Recurse -Force $templatesDest
      }
      Copy-Item -Recurse -Force $templatesSource $templatesDest
    }
  }

  # CRITICAL: Verify no placeholders remain (catches missed files or typos)
  $remainingPlaceholders = @(Test-PlaceholderRemains $skillDest)
  if ($remainingPlaceholders.Count -gt 0) {
    Write-Host "  ERROR: Placeholder __SKILLS_ROOT__ found in installed files:" -ForegroundColor Red
    foreach ($f in $remainingPlaceholders) {
      Write-Host "    - $f" -ForegroundColor Red
    }
    throw "Installation failed: unresolved placeholders remain. Add missing files to whitelist or fix canonical skill."
  }

  # Write version stamp
  Write-VersionStamp $skillDest $SkillName $ProfileName $RepoCommit
  Write-Host "  Stamped: .agent-kit-meta.json"

  Write-Host "  OK: $SkillName installed" -ForegroundColor Green

} catch {
  Write-Error "Failed to install skill '$SkillName': $_"
  exit 1
}
