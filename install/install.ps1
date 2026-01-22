# Agent Kit Installer
# Usage: install.ps1 -Profile <profile-name> [-Target <path>] [-Adapter <adapter-name>] [-Doctor]
#
# Examples:
#   .\install\install.ps1 -Profile media
#   .\install\install.ps1 -Profile minimal -Target "C:\custom\skills"
#   .\install\install.ps1 -Profile media -Adapter claude
#   .\install\install.ps1 -Profile media -Doctor

param(
  [Parameter(Mandatory=$false)]
  [string] $Profile,

  [Parameter(Mandatory=$false)]
  [string] $Target,

  [Parameter(Mandatory=$false)]
  [string] $Adapter = "claude",

  [Parameter(Mandatory=$false)]
  [switch] $Doctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve paths
$AgentKitRoot = Split-Path -Parent $PSScriptRoot
$ProfilesDir = Join-Path $AgentKitRoot "profiles"
$AdaptersDir = Join-Path $AgentKitRoot "adapters"
$SkillsDir = Join-Path $AgentKitRoot "skills"

function Get-RepoCommit {
  try {
    $commit = git -C $AgentKitRoot rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { return $commit }
  } catch {}
  return "unknown"
}

function Resolve-TargetPath {
  param([string] $AdapterName, [string] $ExplicitTarget)

  if ($ExplicitTarget) {
    return [System.Environment]::ExpandEnvironmentVariables($ExplicitTarget)
  }

  # Read adapter config for default target
  $adapterJson = Join-Path (Join-Path $AdaptersDir $AdapterName) "adapter.json"
  if (-not (Test-Path $adapterJson)) {
    throw "Adapter not found: $AdapterName"
  }

  $adapterConfig = Get-Content $adapterJson -Raw | ConvertFrom-Json
  $targetPath = $adapterConfig.target_path

  # Expand ~ to user home directory
  if ($targetPath.StartsWith("~/")) {
    $targetPath = Join-Path $env:USERPROFILE $targetPath.Substring(2)
  } elseif ($targetPath.StartsWith("~\")) {
    $targetPath = Join-Path $env:USERPROFILE $targetPath.Substring(2)
  }

  return $targetPath
}

function Show-AvailableProfiles {
  Write-Host "Available profiles:" -ForegroundColor Yellow
  Get-ChildItem -Path $ProfilesDir -Filter "*.json" | ForEach-Object {
    $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
    Write-Host "  $($_.BaseName)" -ForegroundColor Green -NoNewline
    Write-Host " - $($p.description)"
  }
}

function Invoke-Doctor {
  param(
    [string] $ProfileName,
    [string] $AdapterName,
    [string] $TargetRoot
  )

  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host "  Agent Kit Doctor" -ForegroundColor Cyan
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host ""

  $issues = @()
  $warnings = @()

  # Check 1: Profile exists
  $profilePath = Join-Path $ProfilesDir "$ProfileName.json"
  if (-not (Test-Path $profilePath)) {
    $issues += "Profile not found: $ProfileName"
  } else {
    Write-Host "[OK] Profile exists: $ProfileName" -ForegroundColor Green
    $profileConfig = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Check 2: Each skill in profile exists in canonical repo
    foreach ($skill in $profileConfig.skills) {
      $skillSource = Join-Path $SkillsDir $skill.name
      if (-not (Test-Path $skillSource)) {
        $issues += "Canonical skill missing: $($skill.name)"
      } else {
        Write-Host "[OK] Canonical skill exists: $($skill.name)" -ForegroundColor Green

        # Check skill has SKILL.md
        $skillMd = Join-Path $skillSource "SKILL.md"
        if (-not (Test-Path $skillMd)) {
          $issues += "Skill missing SKILL.md: $($skill.name)"
        }

        # Check skill has run.ps1
        $runPs1 = Join-Path (Join-Path $skillSource "scripts") "run.ps1"
        if (-not (Test-Path $runPs1)) {
          $warnings += "Skill missing scripts/run.ps1: $($skill.name)"
        }
      }
    }

    # Check 3: Installed skills
    Write-Host ""
    Write-Host "Checking installed skills at: $TargetRoot" -ForegroundColor Cyan

    if (-not (Test-Path $TargetRoot)) {
      $warnings += "Target directory does not exist (not installed yet)"
    } else {
      foreach ($skill in $profileConfig.skills) {
        $skillDest = Join-Path $TargetRoot $skill.name
        if (-not (Test-Path $skillDest)) {
          $warnings += "Skill not installed: $($skill.name)"
        } else {
          Write-Host "[OK] Installed: $($skill.name)" -ForegroundColor Green

          # Check for remaining placeholders
          $textExtensions = @(".md", ".ps1", ".py", ".json", ".txt")
          $hasPlaceholder = $false
          Get-ChildItem -Path $skillDest -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -in $textExtensions
          } | ForEach-Object {
            $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content.Contains("__SKILLS_ROOT__")) {
              $hasPlaceholder = $true
              $issues += "Unresolved placeholder in: $($_.FullName)"
            }
          }

          # Check for version stamp
          $metaFile = Join-Path $skillDest ".agent-kit-meta.json"
          if (-not (Test-Path $metaFile)) {
            $warnings += "Missing version stamp: $($skill.name)/.agent-kit-meta.json"
          } else {
            $meta = Get-Content $metaFile -Raw | ConvertFrom-Json
            Write-Host "     Installed: $($meta.installed_at)" -ForegroundColor Gray
            Write-Host "     Commit:    $($meta.installed_from_commit)" -ForegroundColor Gray
          }

          # Check SKILL.md exists in installed
          $installedSkillMd = Join-Path $skillDest "SKILL.md"
          if (-not (Test-Path $installedSkillMd)) {
            $issues += "Installed skill missing SKILL.md: $($skill.name)"
          }
        }
      }
    }
  }

  # Check 4: Adapter exists
  $adapterPath = Join-Path $AdaptersDir $AdapterName
  if (-not (Test-Path $adapterPath)) {
    $issues += "Adapter not found: $AdapterName"
  } else {
    Write-Host "[OK] Adapter exists: $AdapterName" -ForegroundColor Green
  }

  # Summary
  Write-Host ""
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host "  Doctor Summary" -ForegroundColor Cyan
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host ""

  if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "All checks passed!" -ForegroundColor Green
    return 0
  }

  if ($warnings.Count -gt 0) {
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow
    foreach ($w in $warnings) {
      Write-Host "  - $w" -ForegroundColor Yellow
    }
    Write-Host ""
  }

  if ($issues.Count -gt 0) {
    Write-Host "Issues: $($issues.Count)" -ForegroundColor Red
    foreach ($i in $issues) {
      Write-Host "  - $i" -ForegroundColor Red
    }
    return 1
  }

  return 0
}

try {
  # If no profile specified, show help
  if (-not $Profile) {
    Write-Host "Agent Kit Installer" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\install\install.ps1 -Profile <name>          Install a profile"
    Write-Host "  .\install\install.ps1 -Profile <name> -Doctor  Run diagnostics"
    Write-Host ""
    Show-AvailableProfiles
    exit 0
  }

  # Resolve target path
  $targetRoot = Resolve-TargetPath -AdapterName $Adapter -ExplicitTarget $Target

  # Doctor mode
  if ($Doctor) {
    $exitCode = Invoke-Doctor -ProfileName $Profile -AdapterName $Adapter -TargetRoot $targetRoot
    exit $exitCode
  }

  # Normal install mode
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host "  Agent Kit Installer" -ForegroundColor Cyan
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host ""

  # Load profile
  $profilePath = Join-Path $ProfilesDir "$Profile.json"
  if (-not (Test-Path $profilePath)) {
    Write-Host "Profile not found: $Profile" -ForegroundColor Red
    Write-Host ""
    Show-AvailableProfiles
    exit 1
  }

  $profileConfig = Get-Content $profilePath -Raw | ConvertFrom-Json
  $repoCommit = Get-RepoCommit

  Write-Host "Profile: $($profileConfig.name)" -ForegroundColor Green
  Write-Host "  $($profileConfig.description)"
  Write-Host ""
  Write-Host "Target:  $targetRoot" -ForegroundColor Green
  Write-Host "Adapter: $Adapter" -ForegroundColor Green
  Write-Host "Commit:  $repoCommit" -ForegroundColor Green
  Write-Host ""

  # Ensure target directory exists
  if (-not (Test-Path $targetRoot)) {
    Write-Host "Creating target directory: $targetRoot"
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
  }

  # Get adapter install script
  $adapterInstallScript = Join-Path (Join-Path $AdaptersDir $Adapter) "install-skill.ps1"
  if (-not (Test-Path $adapterInstallScript)) {
    throw "Adapter install script not found: $adapterInstallScript"
  }

  # Install each skill in the profile
  Write-Host "Installing skills..." -ForegroundColor Cyan
  Write-Host ""

  $installed = @()
  $failed = @()

  foreach ($skill in $profileConfig.skills) {
    $skillName = $skill.name
    $skillScope = if ($skill.scope) { $skill.scope } else { "global" }

    Write-Host "[$skillName] (scope: $skillScope)" -ForegroundColor Yellow

    try {
      & $adapterInstallScript `
        -SkillName $skillName `
        -SourceRoot $AgentKitRoot `
        -TargetRoot $targetRoot `
        -ProfileName $profileConfig.name `
        -RepoCommit $repoCommit
      $installed += $skillName
    } catch {
      Write-Host "  FAILED: $_" -ForegroundColor Red
      $failed += $skillName
    }

    Write-Host ""
  }

  # Summary
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host "  Installation Summary" -ForegroundColor Cyan
  Write-Host "================================================" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Profile:    $($profileConfig.name)"
  Write-Host "Target:     $targetRoot"
  Write-Host "Adapter:    $Adapter"
  Write-Host "Commit:     $repoCommit"
  Write-Host ""
  Write-Host "Installed:  $($installed.Count) skills" -ForegroundColor Green
  foreach ($s in $installed) {
    Write-Host "  - $s" -ForegroundColor Green
  }

  if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed:     $($failed.Count) skills" -ForegroundColor Red
    foreach ($s in $failed) {
      Write-Host "  - $s" -ForegroundColor Red
    }
    exit 1
  }

  Write-Host ""
  Write-Host "Done!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Run with -Doctor to verify installation:" -ForegroundColor Gray
  Write-Host "  .\install\install.ps1 -Profile $Profile -Doctor" -ForegroundColor Gray

} catch {
  Write-Error "Agent Kit Installer FAILED: $_"
  exit 1
}
