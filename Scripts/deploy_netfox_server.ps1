param(
  [string]$RemoteIp = "165.227.33.94",
  [string]$RemoteUser = "root",
  [string]$RemoteProjectDir = "/root/pixel-mania-netfox",
  [string]$RemoteServiceDir = "/root/PixelManiaNetfox",
  [string]$World = "START",
  [int]$Port = 24566,
  [string]$PublicHost = "",
  [string]$ApiBase = "https://api.pixelmaniagame.com",
  [string]$ServerToken = "",
  [string]$SshKeyPath = "",
  [string]$GodotVersion = "4.6.3-stable",
  [string]$GodotDownloadUrl = "",
  [switch]$PackageOnly,
  [switch]$SkipUpload,
  [switch]$NoStart
)

$ErrorActionPreference = "Stop"

if (-not $PublicHost) {
  $PublicHost = $RemoteIp
}

if (-not $ServerToken) {
  $ServerToken = $env:PIXELMANIA_NETFOX_SERVER_TOKEN
}

$cleanWorld = ($World.Trim()).ToUpperInvariant()
if (-not $cleanWorld -or $cleanWorld -notmatch "^[A-Z0-9_ -]{1,32}$") {
  throw "World must be 1-32 characters and contain only letters, numbers, spaces, underscores, or hyphens."
}
$appWorld = ($cleanWorld -replace "[^A-Z0-9_-]", "_").ToLowerInvariant()
$appName = "pixelmania-netfox-$appWorld"

if ($Port -lt 1 -or $Port -gt 65535) {
  throw "Port must be between 1 and 65535."
}

if (-not $GodotDownloadUrl) {
  $GodotDownloadUrl = "https://github.com/godotengine/godot-builds/releases/download/$GodotVersion/Godot_v$($GodotVersion)_linux.x86_64.zip"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$requiredPaths = @("project.godot", "image.png", "image.png.import", "addons", "Assets", "Scenes", "Scripts", "custom_movement_test")
foreach ($relative in $requiredPaths) {
  $path = Join-Path $repoRoot $relative
  if (-not (Test-Path $path)) {
    throw "Missing required Godot project path: $path"
  }
}

function Invoke-CheckedNative {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath failed with exit code $LASTEXITCODE"
  }
}

function Invoke-Robocopy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Destination
  )

  & robocopy $Source $Destination /E /NFL /NDL /NJH /NJS /NC /NS /NP /XF *.tmp
  if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed for $Source -> $Destination with exit code $LASTEXITCODE"
  }
  $global:LASTEXITCODE = 0
}

function Escape-SingleQuotedBash {
  param([string]$Value)
  return "'" + ($Value -replace "'", "'\''") + "'"
}

function Test-NetfoxBackendRouteEndpoint {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CleanApiBase,
    [Parameter(Mandatory = $true)]
    [string]$WorldName,
    [Parameter(Mandatory = $true)]
    [string]$Token,
    [Parameter(Mandatory = $true)]
    [string]$DeployHint
  )

  $routeUri = "$($CleanApiBase.TrimEnd('/'))/netfox/server/route?world=$([uri]::EscapeDataString($WorldName))"
  $headers = @{
    Authorization = "Bearer $Token"
    "X-Netfox-Server-Token" = $Token
  }

  try {
    Invoke-WebRequest -Method GET -Uri $routeUri -Headers $headers -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-Host "Backend Netfox route endpoint is available: $routeUri"
  } catch {
    $statusCode = 0
    if ($_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -eq 404) {
      throw "Production backend is missing /netfox/server/route. Deploy backend first: $DeployHint"
    }
    if ($statusCode -eq 401 -or $statusCode -eq 403) {
      throw "Production backend rejected the Netfox server token for /netfox/server/route. Make sure NETFOX_SERVER_WORLD_STATE_TOKEN_HASH matches this raw token and restart the backend PM2 apps."
    }

    throw "Backend Netfox route endpoint preflight failed. status=$statusCode url=$routeUri error=$($_.Exception.Message)"
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$stageRoot = Join-Path $env:TEMP "pixelmania_netfox_package_$stamp"
$archivePath = Join-Path $env:TEMP "pixelmania_netfox_project_$stamp.tar.gz"

if (Test-Path $stageRoot) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stageRoot | Out-Null

Write-Host "Packaging Godot Netfox project from $repoRoot ..."
Copy-Item -LiteralPath (Join-Path $repoRoot "project.godot") -Destination $stageRoot
foreach ($rootResource in @("image.png", "image.png.import")) {
  Copy-Item -LiteralPath (Join-Path $repoRoot $rootResource) -Destination (Join-Path $stageRoot $rootResource) -Force
}
foreach ($directory in @("addons", "Assets", "Scenes", "Scripts", "custom_movement_test")) {
  Invoke-Robocopy (Join-Path $repoRoot $directory) (Join-Path $stageRoot $directory)
}

$godotStageRoot = Join-Path $stageRoot ".godot"
$godotImported = Join-Path $repoRoot ".godot\imported"
if (Test-Path $godotImported) {
  New-Item -ItemType Directory -Path $godotStageRoot -Force | Out-Null
  Invoke-Robocopy $godotImported (Join-Path $godotStageRoot "imported")
}

foreach ($cacheFile in @("uid_cache.bin", "global_script_class_cache.cfg")) {
  $sourceCacheFile = Join-Path (Join-Path $repoRoot ".godot") $cacheFile
  if (Test-Path $sourceCacheFile) {
    New-Item -ItemType Directory -Path $godotStageRoot -Force | Out-Null
    Copy-Item -LiteralPath $sourceCacheFile -Destination (Join-Path $godotStageRoot $cacheFile)
  }
}

if (Test-Path $archivePath) {
  Remove-Item -LiteralPath $archivePath -Force
}
Push-Location $stageRoot
try {
  Invoke-CheckedNative tar -czf $archivePath .
} finally {
  Pop-Location
}

$archiveSizeMb = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
Write-Host "Package ready: $archivePath ($archiveSizeMb MB)"

if ($PackageOnly) {
  Write-Host "PackageOnly set; skipping upload/start."
  exit 0
}

if (-not $ServerToken -and -not $NoStart) {
  throw "ServerToken is required unless -NoStart is used. Pass -ServerToken `$NETFOX_TOKEN or set `$env:PIXELMANIA_NETFOX_SERVER_TOKEN."
}

if (-not $NoStart) {
  Test-NetfoxBackendRouteEndpoint `
    -CleanApiBase $ApiBase `
    -WorldName $cleanWorld `
    -Token $ServerToken `
    -DeployHint ".\backend\deploy_to_droplet.ps1 $RemoteIp"
}

$sshTarget = "$RemoteUser@$RemoteIp"
$sshArgs = @()
$scpArgs = @()
if ($SshKeyPath) {
  $sshArgs += @("-i", $SshKeyPath)
  $scpArgs += @("-i", $SshKeyPath)
}

$remoteArchive = "/tmp/pixelmania-netfox-project-$stamp.tar.gz"
if (-not $SkipUpload) {
  Write-Host "Uploading project package to $sshTarget ..."
  Invoke-CheckedNative scp @scpArgs $archivePath "${sshTarget}:$remoteArchive"
}

$safeRemoteProjectDir = Escape-SingleQuotedBash $RemoteProjectDir
$safeRemoteServiceDir = Escape-SingleQuotedBash $RemoteServiceDir
$safeRemoteArchive = Escape-SingleQuotedBash $remoteArchive
$safeGodotVersion = Escape-SingleQuotedBash $GodotVersion
$safeGodotUrl = Escape-SingleQuotedBash $GodotDownloadUrl
$safeWorld = Escape-SingleQuotedBash $cleanWorld
$safeApiBase = Escape-SingleQuotedBash $ApiBase
$safePublicHost = Escape-SingleQuotedBash $PublicHost
$safeToken = Escape-SingleQuotedBash $ServerToken
$safeAppName = Escape-SingleQuotedBash $appName

$remoteScript = @"
set -euo pipefail

PROJECT_DIR=$safeRemoteProjectDir
SERVICE_DIR=$safeRemoteServiceDir
ARCHIVE=$safeRemoteArchive
GODOT_VERSION=$safeGodotVersion
GODOT_URL=$safeGodotUrl
WORLD_NAME=$safeWorld
NETFOX_PORT=$Port
PUBLIC_HOST=$safePublicHost
API_BASE=$safeApiBase
APP_NAME=$safeAppName

case "`$PROJECT_DIR" in
  /root/pixel-mania-netfox|/root/pixel-mania-netfox/*|/opt/pixelmania/*) ;;
  *) echo "Refusing unsafe project dir: `$PROJECT_DIR" >&2; exit 64 ;;
esac

mkdir -p /opt/godot "`$SERVICE_DIR"

if ! command -v unzip >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  apt-get update
  apt-get install -y unzip curl ca-certificates
fi

GODOT_BIN="/opt/godot/Godot_v`${GODOT_VERSION}_linux.x86_64"
if [ ! -x "`$GODOT_BIN" ]; then
  echo "Installing Godot `$GODOT_VERSION ..."
  curl -fL "`$GODOT_URL" -o /tmp/godot-netfox.zip
  unzip -o /tmp/godot-netfox.zip -d /opt/godot
  chmod +x "`$GODOT_BIN"
fi

if [ -f "`$ARCHIVE" ]; then
  echo "Installing Godot project to `$PROJECT_DIR ..."
  rm -rf "`$PROJECT_DIR.next"
  mkdir -p "`$PROJECT_DIR.next"
  tar -xzf "`$ARCHIVE" -C "`$PROJECT_DIR.next"
  rm -rf "`$PROJECT_DIR.prev"
  if [ -d "`$PROJECT_DIR" ]; then
    mv "`$PROJECT_DIR" "`$PROJECT_DIR.prev"
  fi
  mv "`$PROJECT_DIR.next" "`$PROJECT_DIR"
fi

for required_project_path in \
  "Scenes/main.tscn" \
  "image.png" \
  "image.png.import" \
  "Assets/player/body_parts/left_foot_idle_1.png" \
  "Assets/player/expressions/idle.png" \
  "Assets/font/font.ttf" \
  "custom_movement_test/scripts/custom_movement_protocol.gd" \
  "custom_movement_test/scripts/custom_snapshot_interpolator.gd" \
  "custom_movement_test/scenes/custom_real_player.tscn" \
  ".godot/imported" \
  ".godot/uid_cache.bin" \
  ".godot/global_script_class_cache.cfg"; do
  if [ ! -e "`$PROJECT_DIR/`$required_project_path" ]; then
    echo "Netfox project install is missing `$required_project_path in `$PROJECT_DIR" >&2
    exit 65
  fi
done

if [ -z "`$(find "`$PROJECT_DIR/.godot/imported" -type f -print -quit)" ]; then
  echo "Netfox project install has an empty .godot/imported cache in `$PROJECT_DIR" >&2
  exit 65
fi

cat > "`$SERVICE_DIR/.env" <<EOF
PIXELMANIA_PROJECT_DIR=`$PROJECT_DIR
GODOT_BIN=`$GODOT_BIN
NETFOX_WORLD=`$WORLD_NAME
NETFOX_PORT=`$NETFOX_PORT
PIXELMANIA_NETFOX_PUBLIC_HOST=`$PUBLIC_HOST
PIXELMANIA_API_BASE=`$API_BASE
PIXELMANIA_NETFOX_SERVER_TOKEN=$safeToken
EOF
chmod 600 "`$SERVICE_DIR/.env"

cat > "`$SERVICE_DIR/start-netfox-world.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SERVICE_DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
set -a
source "`$SERVICE_DIR/.env"
set +a

exec "`$GODOT_BIN" \
  --headless \
  --path "`$PIXELMANIA_PROJECT_DIR" \
  --netfox-server \
  --world "`$NETFOX_WORLD" \
  --netfox-port "`$NETFOX_PORT" \
  --netfox-public-host "`$PIXELMANIA_NETFOX_PUBLIC_HOST" \
  --netfox-public-port "`$NETFOX_PORT" \
  --netfox-server-token "`$PIXELMANIA_NETFOX_SERVER_TOKEN" \
  --pixelmania-api-base "`$PIXELMANIA_API_BASE"
EOF
chmod +x "`$SERVICE_DIR/start-netfox-world.sh"

cat > "`$SERVICE_DIR/ecosystem.config.js" <<EOF
module.exports = {
  apps: [
    {
      name: "$appName",
      script: "$RemoteServiceDir/start-netfox-world.sh",
      interpreter: "bash",
      cwd: "$RemoteProjectDir",
      autorestart: true,
      watch: false,
      max_memory_restart: "700M",
      kill_timeout: 5000,
      env: {
        NODE_ENV: "production"
      }
    }
  ]
};
EOF

if command -v ufw >/dev/null 2>&1 && ufw status | grep -qi active; then
  ufw allow "`$NETFOX_PORT/udp" || true
fi
"@

if ($NoStart) {
  $remoteScript += @"

echo "NoStart requested; project and service files are installed but PM2 app was not started."
"@
} else {
  $remoteScript += @"

pm2 startOrReload "`$SERVICE_DIR/ecosystem.config.js" --update-env
pm2 save
sleep 4
pm2 list
ss -lunp | grep ":`$NETFOX_PORT" || true
pm2 logs "`$APP_NAME" --lines 120 --nostream

set -a
source "`$SERVICE_DIR/.env"
set +a

echo "Waiting for Netfox backend route registration for `$WORLD_NAME ..."
ROUTE_JSON=""
for attempt in `$(seq 1 45); do
  ROUTE_RESPONSE_FILE="`$(mktemp)"
  HTTP_STATUS="`$(curl -sS --get \
    -H "Authorization: Bearer `$PIXELMANIA_NETFOX_SERVER_TOKEN" \
    -H "X-Netfox-Server-Token: `$PIXELMANIA_NETFOX_SERVER_TOKEN" \
    --data-urlencode "world=`$WORLD_NAME" \
    -o "`$ROUTE_RESPONSE_FILE" \
    -w "%{http_code}" \
    "`$API_BASE/netfox/server/route" || true)"
  ROUTE_JSON="`$(cat "`$ROUTE_RESPONSE_FILE" 2>/dev/null || true)"
  rm -f "`$ROUTE_RESPONSE_FILE"

  case "`$HTTP_STATUS" in
    404)
      echo "Backend API is missing /netfox/server/route. Deploy the backend route changes first, then rerun this script." >&2
      exit 67
      ;;
    401|403)
      echo "Backend API rejected the Netfox server token for /netfox/server/route. Check NETFOX_SERVER_WORLD_STATE_TOKEN_HASH and restart backend PM2 apps." >&2
      echo "Response: `$ROUTE_JSON" >&2
      exit 68
      ;;
  esac

  if echo "`$ROUTE_JSON" | grep -q '"route_found":true'; then
    echo "Netfox backend route is registered:"
    echo "`$ROUTE_JSON"
    break
  fi
  sleep 2
done

if ! echo "`$ROUTE_JSON" | grep -q '"route_found":true'; then
  echo "Netfox backend route did not become ready for `$WORLD_NAME within 90 seconds." >&2
  echo "Last route response: `$ROUTE_JSON" >&2
  exit 66
fi
"@
}

$installerPath = Join-Path $env:TEMP "pixelmania_netfox_install_$stamp.sh"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($installerPath, $remoteScript, $utf8NoBom)
$remoteInstaller = "/tmp/pixelmania-netfox-install-$stamp.sh"

Write-Host "Uploading Netfox installer to $sshTarget ..."
Invoke-CheckedNative scp @scpArgs $installerPath "${sshTarget}:$remoteInstaller"

Write-Host "Installing Netfox service on $sshTarget ..."
Invoke-CheckedNative ssh @sshArgs $sshTarget "bash '$remoteInstaller'"

Write-Host "Netfox deployment helper finished for $appName on $RemoteIp`:$Port."
