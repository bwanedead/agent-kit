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
  $Script    = Join-Path $SkillRoot "scripts\pdf_to_png.py"

  function Get-BasePython {
    if (Get-Command py -ErrorAction SilentlyContinue)      { return @{ Cmd="py";      Args=@("-3") } }
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return @{ Cmd="python3"; Args=@() } }
    if (Get-Command python -ErrorAction SilentlyContinue)  { return @{ Cmd="python";  Args=@() } }
    throw "No Python found (py/python/python3 not on PATH)."
  }

  $base = Get-BasePython

  # 0) Ensure converter exists
  if (-not (Test-Path $Script)) {
    throw "Missing script: $Script`nCreate scripts\pdf_to_png.py inside the skill folder."
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

  # 3) Ensure PyMuPDF installed (import test)
  & $VenvPy -c "import fitz" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing pymupdf..."
    & $VenvPy -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }
    & $VenvPy -m pip install --upgrade pymupdf
    if ($LASTEXITCODE -ne 0) { throw "pymupdf install failed" }
  }

  # 4) Run converter
  & $VenvPy $Script @Args
  exit $LASTEXITCODE

} catch {
  Write-Error "pdf-to-png FAILED: $_"
  exit 1
}
