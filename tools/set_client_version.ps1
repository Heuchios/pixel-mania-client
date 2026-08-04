param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Version
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch "^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$") {
  throw "Version must look like 1.2.3, optionally with a prerelease/build suffix."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$networkManagerPath = Join-Path $repoRoot "Scripts/network_manager.gd"

if (-not (Test-Path $networkManagerPath)) {
  throw "Missing file: $networkManagerPath"
}

$content = Get-Content -LiteralPath $networkManagerPath -Raw
$pattern = 'const\s+CLIENT_VERSION\s*:=\s*"([^"]+)"'
$match = [regex]::Match($content, $pattern)

if (-not $match.Success) {
  throw "Could not find CLIENT_VERSION in $networkManagerPath"
}

$oldVersion = $match.Groups[1].Value
$newContent = [regex]::Replace(
  $content,
  $pattern,
  ('const CLIENT_VERSION := "' + $Version + '"'),
  1
)

if ($newContent -eq $content) {
  Write-Host "CLIENT_VERSION is already $Version"
  exit 0
}

Set-Content -LiteralPath $networkManagerPath -Value $newContent -NoNewline

Write-Host "Updated CLIENT_VERSION from $oldVersion to $Version"
Write-Host "Next: export the client build, upload it, then deploy backend with:"
Write-Host ".\backend\deploy_to_droplet.ps1 <droplet-ip> -ClientVersion $Version -ForceClientUpdate"
