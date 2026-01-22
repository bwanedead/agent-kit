# AGENT KIT NATIVE SKILL FACTORY
# Creates canonical skills in agent-kit/skills/ (not directly in ~/.claude/skills)
# Use the Agent Kit installer to sync skills to Claude after creation

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================================
# ARGUMENT HANDLING
# Use the automatic $args variable (works correctly with -File invocation)
# ============================================================================
$ScriptArgs = $args
if ($ScriptArgs.Count -eq 1 -and $ScriptArgs[0] -match '\s') {
  $ScriptArgs = $ScriptArgs[0] -split '\s+' | Where-Object { $_ }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
function Get-ArgValue($name) {
  for ($i = 0; $i -lt $ScriptArgs.Count; $i++) {
    if ($ScriptArgs[$i] -eq $name -and ($i + 1) -lt $ScriptArgs.Count) {
      return $ScriptArgs[$i + 1]
    }
  }
  return $null
}

function Has-Flag($name) {
  return $ScriptArgs -contains $name
}

function Find-AgentKitRoot {
  # Discovery order (first match wins):
  # 1. AGENT_KIT_ROOT environment variable
  # 2. User-level config file (persistent, survives reinstalls)
  # 3. Walk upward from current directory to find agent-kit structure

  # Method 1: Environment variable
  $envRoot = [System.Environment]::GetEnvironmentVariable("AGENT_KIT_ROOT")
  if ($envRoot -and (Test-Path $envRoot)) {
    if (Test-AgentKitStructure $envRoot) {
      return $envRoot
    }
  }

  # Method 2: User-level config file (NOT inside installed skill folder)
  # Windows: %LOCALAPPDATA%\agent-kit\agent-kit-root.txt
  $configDir = Join-Path $env:LOCALAPPDATA "agent-kit"
  $configFile = Join-Path $configDir "agent-kit-root.txt"
  if (Test-Path $configFile) {
    $configRoot = (Get-Content $configFile -Raw).Trim()
    if ($configRoot -and (Test-Path $configRoot)) {
      if (Test-AgentKitStructure $configRoot) {
        return $configRoot
      }
    }
  }

  # Method 3: Walk upward from current working directory
  $current = (Get-Location).Path
  while ($current) {
    if (Test-AgentKitStructure $current) {
      # Auto-create user config for future use
      Save-AgentKitRoot $current
      return $current
    }
    $parent = Split-Path -Parent $current
    if ($parent -eq $current) { break }
    $current = $parent
  }

  return $null
}

function Test-AgentKitStructure($path) {
  # Validate path contains agent-kit canonical structure
  $required = @("profiles", "install", "skills", "templates")
  foreach ($dir in $required) {
    if (-not (Test-Path (Join-Path $path $dir))) {
      return $false
    }
  }
  return $true
}

function Save-AgentKitRoot($path) {
  # Save discovered root to user-level config for future use
  $configDir = Join-Path $env:LOCALAPPDATA "agent-kit"
  $configFile = Join-Path $configDir "agent-kit-root.txt"
  try {
    if (-not (Test-Path $configDir)) {
      New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    $path | Set-Content -Encoding UTF8 $configFile
    Write-Host "  Saved agent-kit root to: $configFile" -ForegroundColor Gray
  } catch {
    # Non-fatal - just continue
  }
}

function Get-ActiveAdapters($root) {
  $adaptersDir = Join-Path $root "adapters"
  $available = @()
  if (Test-Path $adaptersDir) {
    $available = Get-ChildItem -Directory $adaptersDir | Select-Object -ExpandProperty Name
  }

  $configDir = Join-Path $env:LOCALAPPDATA "agent-kit"
  $configFile = Join-Path $configDir "active-adapters.txt"
  if (Test-Path $configFile) {
    $raw = (Get-Content $configFile -Raw).Trim()
    if ($raw) {
      $items = $raw -split "[,`r`n]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
      $valid = @()
      foreach ($item in $items) {
        if ($available -contains $item) {
          $valid += $item
        } else {
          Write-Host "  Warning: unknown adapter in active list: $item" -ForegroundColor Yellow
        }
      }
      if ($valid.Count -gt 0) {
        return $valid
      }
    }
  }

  return $available
}

function Ensure-ProfileIncludesSkill($profilesDir, $profileName, $skillName) {
  $profilePath = Join-Path $profilesDir "$profileName.json"
  $created = $false

  if (-not (Test-Path $profilePath)) {
    $profile = @{
      name = $profileName
      description = "Auto-managed profile"
      skills = @()
    }
    $created = $true
  } else {
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json
    if (-not $profile.skills) {
      $profile.skills = @()
    }
  }

  $already = $false
  foreach ($s in $profile.skills) {
    if ($s.name -eq $skillName) {
      $already = $true
      break
    }
  }

  if (-not $already) {
    $profile.skills += @{ name = $skillName; scope = "global" }
  }

  $profile | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $profilePath
  if ($created) {
    Write-Host "  Created profile: $profileName" -ForegroundColor Gray
  } elseif (-not $already) {
    Write-Host "  Added to profile: $profileName" -ForegroundColor Gray
  }
}

function Show-Help {
  Write-Host "skill-factory - Create new Agent Kit skills from templates" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host '  skill-factory --name <skill-name> --desc "..." [options]'
  Write-Host "  skill-factory --list-templates"
  Write-Host "  skill-factory --sync --profile <name>"
  Write-Host ""
  Write-Host "CREATE OPTIONS:" -ForegroundColor Yellow
  Write-Host "  --name <name>         Required. Name for the new skill"
  Write-Host '  --desc "..."          Description (default: TODO)'
  Write-Host "  --template <name>     Template to use (default: python-venv-ps)"
  Write-Host '  --deps "pkg1,pkg2"    Python dependencies'
  Write-Host '  --arg-hint "..."      Argument hint for SKILL.md'
  Write-Host "  --dest <path>         Override destination (advanced)"
  Write-Host "  --overwrite           Overwrite existing skill"
  Write-Host "  --install             Install after creation (default: on)"
  Write-Host "  --no-install          Do not install after creation"
  Write-Host "  --adapter <name>      Limit install/sync to one adapter"
  Write-Host '  --adapters "a,b,c"    Limit install/sync to multiple adapters'
  Write-Host "  --add-to-profile <n>  Add skill to profile (default: global)"
  Write-Host "  --no-add              Do not add skill to any profile"
  Write-Host "  --profile <name>      Profile for --install/--sync (default: global)"
  Write-Host ""
  Write-Host "OTHER COMMANDS:" -ForegroundColor Yellow
  Write-Host "  --list-templates      Show available templates"
  Write-Host "  --sync                Just run installer (requires --profile)"
  Write-Host "  --help                Show this help"
  Write-Host ""
  Write-Host "AGENT KIT DISCOVERY:" -ForegroundColor Yellow
  Write-Host "  1. AGENT_KIT_ROOT environment variable"
  Write-Host "  2. %LOCALAPPDATA%\agent-kit\agent-kit-root.txt"
  Write-Host "  3. Walk upward from current directory"
  Write-Host ""
  Write-Host "ACTIVE ADAPTERS:" -ForegroundColor Yellow
  Write-Host "  %LOCALAPPDATA%\agent-kit\active-adapters.txt"
  Write-Host "  (comma or newline separated adapter names)"
}

# ============================================================================
# MAIN
# ============================================================================
try {
  # --help
  if (Has-Flag "--help") {
    Show-Help
    exit 0
  }

  # Discover agent-kit root
  $agentKitRoot = Find-AgentKitRoot
  if (-not $agentKitRoot) {
    Write-Host "ERROR: Cannot find agent-kit repository." -ForegroundColor Red
    Write-Host ""
    Write-Host "Set one of the following:" -ForegroundColor Yellow
    Write-Host "  1. Set AGENT_KIT_ROOT environment variable"
    Write-Host "  2. Create: $env:LOCALAPPDATA\agent-kit\agent-kit-root.txt"
    Write-Host "     (with the absolute path to agent-kit repo)"
    Write-Host "  3. Run from inside the agent-kit directory tree"
    exit 1
  }

  # Agent-kit paths
  $akSkillsDir = Join-Path $agentKitRoot "skills"
  $akTemplatesDir = Join-Path $agentKitRoot "templates"
  $akProfilesDir = Join-Path $agentKitRoot "profiles"
  $akInstallScript = Join-Path (Join-Path $agentKitRoot "install") "install.ps1"

  Write-Host "Agent Kit: $agentKitRoot" -ForegroundColor Gray

  # --list-templates: show available templates
  if (Has-Flag "--list-templates") {
    Write-Host "Available templates:" -ForegroundColor Cyan
    if (-not (Test-Path $akTemplatesDir)) {
      Write-Host "  (no templates directory found)" -ForegroundColor Yellow
      exit 0
    }
    Get-ChildItem -Directory $akTemplatesDir | ForEach-Object {
      $tplJson = Join-Path $_.FullName "template.json"
      if (Test-Path $tplJson) {
        $meta = Get-Content $tplJson -Raw | ConvertFrom-Json
        Write-Host "  $($_.Name)" -ForegroundColor Green -NoNewline
        Write-Host " - $($meta.description)"
      } else {
        Write-Host "  $($_.Name)" -ForegroundColor Green
      }
    }
    exit 0
  }

  # --sync: just run installer
  if (Has-Flag "--sync") {
    $profile = Get-ArgValue "--profile"
    if (-not $profile) {
      throw "--sync requires --profile <name>"
    }
    $adapterArg = Get-ArgValue "--adapter"
    $adaptersArg = Get-ArgValue "--adapters"
    $adapterList = @()
    if ($adapterArg) {
      $adapterList = @($adapterArg)
    } elseif ($adaptersArg) {
      $adapterList = $adaptersArg -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
      $adapterList = Get-ActiveAdapters $agentKitRoot
    }

    if ($adapterList.Count -eq 0) {
      throw "No adapters found for --sync"
    }

    $failed = $false
    foreach ($adapter in $adapterList) {
      Write-Host "Syncing profile: $profile (adapter: $adapter)" -ForegroundColor Cyan
      & $akInstallScript -Profile $profile -Adapter $adapter
      if ($LASTEXITCODE -ne 0) { $failed = $true }
    }
    if ($failed) { exit 1 }
    exit 0
  }

  # Parse create arguments
  $name      = Get-ArgValue "--name"
  $desc      = Get-ArgValue "--desc"
  $templateN = Get-ArgValue "--template"
  $deps      = Get-ArgValue "--deps"
  $argh      = Get-ArgValue "--arg-hint"
  $destOver  = Get-ArgValue "--dest"
  $profile   = Get-ArgValue "--profile"
  $addProfile = Get-ArgValue "--add-to-profile"
  $adapterArg = Get-ArgValue "--adapter"
  $adaptersArg = Get-ArgValue "--adapters"
  $overwrite = Has-Flag "--overwrite"
  $doInstall = Has-Flag "--install"
  $noInstall = Has-Flag "--no-install"
  $noAdd = Has-Flag "--no-add"

  # Validate required args
  if (-not $name) {
    Show-Help
    exit 1
  }

  # Validate skill name (no forbidden filesystem characters)
  if ($name -match '[<>:"/\\|?*]') {
    throw "Invalid --name (contains forbidden filesystem characters): $name"
  }

  # Defaults
  if (-not $desc) { $desc = "TODO: describe skill" }
  if (-not $templateN) { $templateN = "python-venv-ps" }
  if (-not $argh) { $argh = "[args]" }
  if (-not $profile) { $profile = "global" }
  if (-not $addProfile) { $addProfile = $profile }
  if (-not $doInstall -and -not $noInstall) { $doInstall = $true }

  # Resolve template source (from agent-kit/templates/)
  $templateSource = Join-Path $akTemplatesDir $templateN
  if (-not (Test-Path $templateSource)) {
    throw "Template not found: $templateSource"
  }

  # Validate template contract
  $contractFiles = @(
    "SKILL.template.md",
    "template.json",
    (Join-Path "scripts" "run.ps1")
  )
  foreach ($f in $contractFiles) {
    $fp = Join-Path $templateSource $f
    if (-not (Test-Path $fp)) {
      throw "Template contract violation - missing: $f"
    }
  }

  # Resolve destination (default: agent-kit/skills/)
  $dest = if ($destOver) { $destOver } else { Join-Path $akSkillsDir $name }

  # Handle existing skill
  if (Test-Path $dest) {
    if (-not $overwrite) {
      throw "Skill already exists: $dest (use --overwrite)"
    }
    Write-Host "Removing existing: $dest" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $dest
  }

  # Copy template to destination
  Write-Host "Creating skill: $name" -ForegroundColor Cyan
  Write-Host "  Template: $templateN"
  Write-Host "  Destination: $dest"
  Copy-Item -Recurse -Force $templateSource $dest

  # Render SKILL.md from SKILL.template.md
  $skillMdTemplate = Join-Path $dest "SKILL.template.md"
  $skillMdOut      = Join-Path $dest "SKILL.md"

  # CANONICAL PLACEHOLDER HANDLING:
  # Use __SKILLS_ROOT__\<name> - do NOT expand to machine path
  # The installer handles placeholder replacement at deploy time
  # NOTE: Construct placeholder dynamically so installer doesn't replace it
  $placeholder = "__" + "SKILLS_ROOT" + "__"
  $canonicalSkillRoot = "$placeholder\$name"

  $render = (Get-Content $skillMdTemplate -Raw)
  $render = $render.Replace("__SKILL_NAME__", $name)
  $render = $render.Replace("__SKILL_DESCRIPTION__", $desc)
  $render = $render.Replace("__ARG_HINT__", $argh)
  $render = $render.Replace("__SKILL_ROOT__", $canonicalSkillRoot)
  $render | Set-Content -Encoding UTF8 $skillMdOut
  Remove-Item -Force $skillMdTemplate

  # Remove template.json from created skill (it's factory metadata)
  $destTplJson = Join-Path $dest "template.json"
  if (Test-Path $destTplJson) {
    Remove-Item -Force $destTplJson
  }

  # Replace placeholders in main.py if present (name/desc only, not paths)
  $mainPy = Join-Path $dest "scripts\main.py"
  if (Test-Path $mainPy) {
    $pyContent = (Get-Content $mainPy -Raw)
    $pyContent = $pyContent.Replace("__SKILL_NAME__", $name)
    $pyContent = $pyContent.Replace("__SKILL_DESCRIPTION__", $desc)
    $pyContent | Set-Content -Encoding UTF8 $mainPy
  }

  # Handle deps.txt
  $depsFile = Join-Path $dest "deps.txt"
  if ($deps) {
    # User provided deps - write them
    $deps | Set-Content -Encoding UTF8 $depsFile
  } elseif (Test-Path $depsFile) {
    # Template has deps.txt - check if it's just comments/empty
    $existingDeps = (Get-Content $depsFile -Raw).Trim()
    $hasRealDeps = $existingDeps -split "`n" | Where-Object { $_ -and -not $_.StartsWith("#") }
    if (-not $hasRealDeps) {
      # Remove empty/comment-only deps.txt
      Remove-Item -Force $depsFile
    }
  }

  Write-Host ""
  Write-Host "Created canonical skill: $name" -ForegroundColor Green
  Write-Host "  Path: $dest"
  Write-Host ""

  if (-not $noAdd) {
    Ensure-ProfileIncludesSkill $akProfilesDir $addProfile $name
  }

  # --install: run installer to sync to adapters (default: all)
  if ($doInstall) {
    $adapterList = @()
    if ($adapterArg) {
      $adapterList = @($adapterArg)
    } elseif ($adaptersArg) {
      $adapterList = $adaptersArg -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
      $adapterList = Get-ActiveAdapters $agentKitRoot
    }

    if ($adapterList.Count -eq 0) {
      throw "No adapters found for --install"
    }

    $failed = $false
    foreach ($adapter in $adapterList) {
      Write-Host "Installing (profile: $profile, adapter: $adapter)..." -ForegroundColor Cyan
      & $akInstallScript -Profile $profile -Adapter $adapter
      if ($LASTEXITCODE -ne 0) { $failed = $true }
    }

    if ($failed) { throw "Installer failed" }
  } else {
    # Print follow-up instructions
    Write-Host "NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  1. Edit the skill files in: $dest"
    Write-Host "  2. Add skill to a profile in: $agentKitRoot\profiles\"
    Write-Host "  3. Sync to adapters:"
    Write-Host ""
    Write-Host "     $akInstallScript -Profile $profile -Adapter <adapter>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Or re-run with --install to sync immediately."
  }

} catch {
  Write-Error "skill-factory FAILED: $_"
  exit 1
}
