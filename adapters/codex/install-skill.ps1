# Codex Adapter: Install a single skill
# Usage: install-skill.ps1 -SkillName <name> -SourceRoot <agent-kit-path> -TargetRoot <codex-skills-path> [-ProfileName <name>] [-RepoCommit <hash>]

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
$PlaceholderWhitelist = @(
  "SKILL.md",
  "run.ps1"
)

# PRESERVE: These directories are never deleted on reinstall
$PreserveOnReinstall = @(
  ".venv",
  "output",
  "logs"
)

function Test-PlaceholderWhitelisted($fileName) {
  return $PlaceholderWhitelist -contains $fileName
}

function Remove-SkillExceptPreserved($skillPath) {
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
  Get-ChildItem -Path $source -Force | ForEach-Object {
    $destPath = Join-Path $dest $_.Name
    if ($PreserveOnReinstall -contains $_.Name -and (Test-Path $destPath)) {
      return
    }
    Copy-Item -Recurse -Force $_.FullName $destPath
  }
}

function Test-PlaceholderRemains($skillPath) {
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

function Write-Utf8NoBomFile($path, $content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

try {
  $skillSource = Join-Path (Join-Path $SourceRoot "skills") $SkillName
  $skillDest = Join-Path $TargetRoot $SkillName

  if (-not (Test-Path $skillSource)) {
    throw "Skill not found in agent-kit: $skillSource"
  }

  if (Test-Path $skillDest) {
    Write-Host "  Updating existing: $skillDest"
    Remove-SkillExceptPreserved $skillDest
  } else {
    New-Item -ItemType Directory -Path $skillDest -Force | Out-Null
  }

  Write-Host "  Copying: $skillSource -> $skillDest"
  Copy-SkillFiles $skillSource $skillDest

  Get-ChildItem -Path $skillDest -Recurse -File | ForEach-Object {
    if (Test-PlaceholderWhitelisted $_.Name) {
      $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
      if ($content -and $content.Contains("__SKILLS_ROOT__")) {
        $newContent = $content.Replace("__SKILLS_ROOT__", $TargetRoot)
        if ($_.Name -eq "SKILL.md") {
          Write-Utf8NoBomFile $_.FullName $newContent
        } else {
          $newContent | Set-Content -Encoding UTF8 $_.FullName
        }
        Write-Host "  Patched: $($_.Name)"
      }
    }
  }

  # Codex requires YAML front matter at byte 0; ensure SKILL.md has no BOM
  $skillMdPath = Join-Path $skillDest "SKILL.md"
  if (Test-Path $skillMdPath) {
    $skillMdContent = Get-Content $skillMdPath -Raw -ErrorAction SilentlyContinue
    if ($skillMdContent) {
      Write-Utf8NoBomFile $skillMdPath $skillMdContent
    }
  }

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

  $remainingPlaceholders = @(Test-PlaceholderRemains $skillDest)
  if ($remainingPlaceholders.Count -gt 0) {
    Write-Host "  ERROR: Placeholder __SKILLS_ROOT__ found in installed files:" -ForegroundColor Red
    foreach ($f in $remainingPlaceholders) {
      Write-Host "    - $f" -ForegroundColor Red
    }
    throw "Installation failed: unresolved placeholders remain. Add missing files to whitelist or fix canonical skill."
  }

  Write-VersionStamp $skillDest $SkillName $ProfileName $RepoCommit
  Write-Host "  Stamped: .agent-kit-meta.json"

  Write-Host "  OK: $SkillName installed" -ForegroundColor Green

} catch {
  Write-Error "Failed to install skill '$SkillName': $_"
  exit 1
}
