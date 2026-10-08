param([int]$TimeoutSeconds = 190)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clientRoot = Split-Path -Parent $PSScriptRoot
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '..\Rookhaven\build\local-passives\tfs.exe'))
$configPath = Join-Path $clientRoot 'out\local-server\passives-runtime\config.lua'
$config = [IO.File]::ReadAllText($configPath)
foreach ($line in @('ip = "127.0.0.1"','loginProtocolPort = 7174','gameProtocolPort = 7175','mysqlHost = "127.0.0.1"','mysqlPort = 33308','mysqlDatabase = "rookhaven_passives_test"','serverName = "Rookhaven Local Passives Test"','passiveTestEnabled = true')) {
    if ([regex]::Matches($config, '(?m)^' + [regex]::Escape($line) + '\s*$').Count -ne 1) { throw "Owned local fixture guard failed: $line" }
}
$server = @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)
if ($server.Count -ne 1) { throw 'Expected exactly one owned local test server.' }
foreach ($port in @(7174,7175)) {
    $listener = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
    if (-not $listener.Count -or @($listener | Where-Object OwningProcess -ne $server[0].Id).Count) { throw "Port $port is not owned by the local test server." }
}
if (Get-Process RookhavenClient -ErrorAction SilentlyContinue) { throw 'Native slot is occupied; run serially.' }
$configHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
$startedUtc = [DateTime]::UtcNow
$logs = Join-Path $clientRoot ('out\cyclopedia-passives-allocated-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logs | Out-Null
$receipt = Join-Path $logs 'client-exit.json'
& (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'cyclopedia-passives-allocated.lua' -Success 'CYCLOPEDIA_ALLOCATED_COMPLETE' -TimeoutSeconds $TimeoutSeconds -ExitReceiptPath $receipt *> (Join-Path $logs 'native.log')
$result = [IO.File]::ReadAllText((Join-Path $logs 'native.log'))
$exit = Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json
if ($exit.clientExit -ne 0) { throw 'Allocated native client did not exit cleanly.' }
if ([regex]::Matches($result,'(?m)^CYCLOPEDIA_ALLOCATED_UI_OK ').Count -ne 12) { throw 'Expected six classes in both actual viewport sizes.' }
if ((Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne $configHash) { throw 'Owned runtime config changed during read-only UI suite.' }
if (Get-Process RookhavenClient -ErrorAction SilentlyContinue) { throw 'Native client remained after suite.' }
$imageDirectory = [regex]::Match($result,'(?m)^CYCLOPEDIA_ALLOCATED_SCREENSHOT_DIRECTORY (.+)$').Groups[1].Value.Trim()
$images = @(Get-ChildItem -LiteralPath $imageDirectory -Filter 'cyclopedia-allocated-*.png' -File | Where-Object LastWriteTimeUtc -ge $startedUtc)
if ($images.Count -ne 24) { throw 'Expected 24 actual A/B screenshots.' }
foreach ($file in $images) { Copy-Item -LiteralPath $file.FullName -Destination $logs }
@{passed=$true;clientExit=0;classes=6;cases=12;screenshots=24;runtimeConfigUnchanged=$true;serverPid=$server[0].Id;logDirectory=$logs} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'result.json') -Encoding utf8
Write-Output "CYCLOPEDIA_ALLOCATED_SUITE_OK $logs"
