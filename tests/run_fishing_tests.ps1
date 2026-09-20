param([string]$Godot = 'D:/Pixelmania/atlas-ui-tools/Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('pixelmania-fishing-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
$env:APPDATA = Join-Path $testRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $testRoot 'localappdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
$files = @(
    'Scripts/fishing_manager.gd', 'Scripts/fishing_pull_game.gd', 'Scripts/fishing_rod_attachment.gd',
    'Scripts/input_manager.gd', 'Scripts/touch_input_guard.gd',
    'Scripts/UIAtlasDB.gd', 'Scripts/atlas_texture_factory.gd',
    'Scripts/ui/fishing_minigame_ui.gd', 'Scripts/ui/fishing_journal_ui.gd',
    'Scripts/ui/fishing_catch_spotlight.gd',
    'Scripts/ui/pixel_ui_style.gd', 'Scripts/ui/panel_drop_shadow.gd',
    'Scripts/ui/global_font_manager.gd', 'Scenes/fishing_bobber.tscn',
    'Assets/ui/UI_3.0.png', 'Assets/items/lures/worm_lure.png',
    'Assets/items/fish/pond_fish_small.png', 'Assets/items/fish/crystal_fish.png',
    'Assets/font/font.ttf', 'tests/fishing_minigame_test.gd',
    'tests/fixtures/fishing_test_world.gd', 'tests/mobile_single_tap_input_test.gd',
    'tests/fishing_ui_preview.gd'
)
foreach ($relative in $files) {
    $destination = Join-Path $testRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $destination
    if (Test-Path -LiteralPath ((Join-Path $projectRoot $relative) + '.import')) {
        Copy-Item -LiteralPath ((Join-Path $projectRoot $relative) + '.import') -Destination ($destination + '.import')
    }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'Assets/ui/atlas') -Destination (Join-Path $testRoot 'Assets/ui/atlas') -Recurse
@'
config_version=5
[application]
config/name="Fishing Test"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[input_devices]
pointing/emulate_mouse_from_touch=true
[rendering]
renderer/rendering_method="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
'@ | Set-Content -LiteralPath (Join-Path $testRoot 'project.godot')
Write-Output "Fishing test project: $testRoot"
& $Godot --headless --path $testRoot --log-file (Join-Path $testRoot 'import.log') --editor --import --quit 2>&1 | Out-File (Join-Path $testRoot 'import-output.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $testRoot 'import-output.log'); exit $LASTEXITCODE }
@'
[autoload]
GlobalFontManager="*res://Scripts/ui/global_font_manager.gd"
[gui]
theme/custom="res://Assets/ui/atlas/theme.tres"
'@ | Add-Content -LiteralPath (Join-Path $testRoot 'project.godot')
foreach ($test in @('fishing_minigame_test', 'mobile_single_tap_input_test')) {
    & $Godot --headless --path $testRoot --log-file (Join-Path $testRoot ($test + '.log')) --script ('res://tests/' + $test + '.gd')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $runtimeErrors = Get-Content -LiteralPath (Join-Path $testRoot ($test + '.log')) | Where-Object {
        $_ -match '^(SCRIPT ERROR|ERROR):' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.$'
    }
    if ($runtimeErrors) { throw ($runtimeErrors -join [Environment]::NewLine) }
}

} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
