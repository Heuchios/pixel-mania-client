param([string]$Godot = 'D:/Godot/Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('pixelmania-billing-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot | Out-Null
# Isolated project: no game autoloads, server connection, Android plugin or real checkout.
foreach ($relative in @('Scripts/billing_client.gd', 'Scripts/shop_ui.gd', 'addons/GodotGooglePlayBilling/BillingClient.gd', 'tests/test_google_play_billing.gd')) {
    $destination = Join-Path $testRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $destination
}
Set-Content -LiteralPath (Join-Path $testRoot 'project.godot') -Value 'config_version=5'
& $Godot --headless --path $testRoot --script res://tests/test_google_play_billing.gd
exit $LASTEXITCODE
