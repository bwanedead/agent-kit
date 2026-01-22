$dir = Join-Path $env:LOCALAPPDATA "agent-kit"
if (!(Test-Path $dir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$configFile = Join-Path $dir "agent-kit-root.txt"
"C:\projects\agent-kit" | Set-Content -Encoding UTF8 $configFile
Write-Host "Created: $configFile"
Get-Content $configFile
