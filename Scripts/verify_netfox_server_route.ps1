param(
  [string]$ApiBase = "https://api.pixelmaniagame.com",
  [string]$World = "START",
  [Alias("Host")]
  [string]$NetfoxHost = "165.227.33.94",
  [int]$Port = 24566,
  [int]$MaxClients = 50,
  [string]$ServerToken = "",
  [switch]$Register
)

$ErrorActionPreference = "Stop"

if (-not $ServerToken) {
  $ServerToken = $env:PIXELMANIA_NETFOX_SERVER_TOKEN
}
if (-not $ServerToken) {
  $ServerToken = $env:NETFOX_TOKEN
}
if (-not $ServerToken) {
  throw "ServerToken is required. Pass -ServerToken `$NETFOX_TOKEN or set `$env:PIXELMANIA_NETFOX_SERVER_TOKEN."
}
if ($ServerToken -eq "PASTE_RAW_TOKEN_HERE" -or $ServerToken -eq "<random-long-secret>" -or $ServerToken -like "YOUR_*") {
  throw "ServerToken is still a placeholder. Set `$env:NETFOX_TOKEN to the real raw token, then rerun this script."
}

$cleanApiBase = $ApiBase.TrimEnd("/")
$cleanWorld = $World.Trim().ToUpperInvariant()
if (-not $cleanWorld) {
  throw "World is required."
}
if ($Port -lt 1 -or $Port -gt 65535) {
  throw "Port must be between 1 and 65535."
}

$headers = @{
  Authorization = "Bearer $ServerToken"
  "X-Netfox-Server-Token" = $ServerToken
}

function Invoke-NetfoxJson {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Method,
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [object]$Body = $null
  )

  try {
    if ($null -eq $Body) {
      return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -UseBasicParsing
    }

    $jsonBody = $Body | ConvertTo-Json -Depth 8
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $jsonBody -UseBasicParsing
  } catch {
    $detail = $_.Exception.Message
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
      $detail = "$detail $($_.ErrorDetails.Message)"
    }

    $statusCode = 0
    $response = $_.Exception.Response
    if ($response) {
      if ($null -ne $response.StatusCode) {
        $statusCode = [int]$response.StatusCode
      }

      $responseText = ""
      $responseTypeName = $response.GetType().FullName
      try {
        if ($responseTypeName -eq "System.Net.Http.HttpResponseMessage") {
          if ($response.Content) {
            $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
          }
        } elseif ($response.PSObject.Methods.Name -contains "GetResponseStream") {
          $stream = $response.GetResponseStream()
          if ($stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            try {
              $responseText = $reader.ReadToEnd()
            } finally {
              $reader.Dispose()
            }
          }
        }
      } catch {
        $responseText = ""
      }

      if ($responseText) {
        $detail = "$detail $responseText"
      }
    }
    if ($statusCode -eq 404 -and $Url -like "*/netfox/server/route*") {
      throw "Backend API is missing /netfox/server/route. Deploy backend/server.js first, then restart all backend PM2 apps."
    }
    if (($statusCode -eq 401 -or $statusCode -eq 403) -and $Url -like "*/netfox/server/route*") {
      throw "Backend API rejected the Netfox server token. Check NETFOX_SERVER_WORLD_STATE_TOKEN_HASH and restart all backend PM2 apps."
    }
    throw "Request failed: $Method $Url :: $detail"
  }
}

Write-Host "Checking PixelMania Netfox route for world $cleanWorld at $cleanApiBase"

if ($Register) {
  if (-not $NetfoxHost.Trim()) {
    throw "Host is required when -Register is used."
  }

  $registerBody = @{
    world = $cleanWorld
    host = $NetfoxHost.Trim()
    port = $Port
    max_clients = $MaxClients
  }
  $registered = Invoke-NetfoxJson -Method "POST" -Url "$cleanApiBase/netfox/server/register-route" -Body $registerBody
  Write-Host "Manual route registration:"
  $registered | ConvertTo-Json -Depth 8
}

$route = Invoke-NetfoxJson -Method "GET" -Url "$cleanApiBase/netfox/server/route?world=$([uri]::EscapeDataString($cleanWorld))"
Write-Host "Route lookup:"
$route | ConvertTo-Json -Depth 8

$health = Invoke-RestMethod -Method "GET" -Uri "$cleanApiBase/health" -UseBasicParsing
Write-Host "Health netfox movement:"
$health.features.netfox_movement | ConvertTo-Json -Depth 8
Write-Host "Redis key counts:"
$health.persistence.redis_stats.key_counts | ConvertTo-Json -Depth 8

if (-not $route.route_found) {
  throw "No live Netfox route found for $cleanWorld. Start/restart the dedicated Netfox server and check its route-registration logs."
}

if ($Register -and ($route.route.host -ne $NetfoxHost.Trim() -or [int]$route.route.port -ne $Port)) {
  throw "Route found, but it does not match the expected public endpoint $($NetfoxHost.Trim()):$Port."
}

Write-Host "Netfox route is live for $cleanWorld at $($route.route.host):$($route.route.port)."
