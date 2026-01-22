param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Args
)

# VENV ISOLATION CONTRACT:
# - ALL pip installs MUST target $VenvPy -m pip
# - NEVER call pip directly (could hit global)
# - ABORT if venv creation/validation fails

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
  $SkillRoot = Split-Path -Parent $PSScriptRoot
  $VenvDir   = Join-Path $SkillRoot ".venv"
  $Script    = Join-Path $SkillRoot "scripts\splice_deed.py"

  function Get-BasePython {
    if (Get-Command py -ErrorAction SilentlyContinue)      { return @{ Cmd="py";      Args=@("-3") } }
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return @{ Cmd="python3"; Args=@() } }
    if (Get-Command python -ErrorAction SilentlyContinue)  { return @{ Cmd="python";  Args=@() } }
    throw "No Python found (py/python/python3 not on PATH)."
  }

  $base = Get-BasePython

  # 0) Ensure script exists
  if (-not (Test-Path $Script)) {
    throw "Missing script: $Script`nCreate scripts\splice_deed.py inside the skill folder."
  }

  # 1) Create venv if missing
  if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating venv at $VenvDir..."
    & $base.Cmd @($base.Args) -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
      throw "FATAL: venv creation failed (exit code $LASTEXITCODE)"
    }
  }

  # 2) Resolve venv python path (Windows + fallback)
  $VenvPy = Join-Path $VenvDir "Scripts\python.exe"
  if (-not (Test-Path $VenvPy)) {
    $VenvPy = Join-Path $VenvDir "bin\python"
  }

  # CRITICAL: Validate venv python exists before ANY pip/python operations
  if (-not (Test-Path $VenvPy)) {
    throw "FATAL: venv python not found at $VenvPy - aborting to prevent global installs"
  }

  # 3) Ensure Pillow installed (import test)
  & $VenvPy -c "from PIL import Image" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing pillow..."
    & $VenvPy -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }
    & $VenvPy -m pip install --upgrade pillow
    if ($LASTEXITCODE -ne 0) { throw "pillow install failed" }
  }

  # 4) Run splitter
  & $VenvPy $Script @Args
  exit $LASTEXITCODE

} catch {
  Write-Error "splice-deed FAILED: $_"
  exit 1
}
