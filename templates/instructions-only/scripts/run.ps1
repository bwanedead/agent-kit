param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Args
)

Write-Host "This skill is instruction-only. See SKILL.md." -ForegroundColor Yellow
exit 0
