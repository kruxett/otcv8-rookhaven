param([string]$PackageDirectory = '')
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $clientRoot ('out/passives-admin-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$serverLog = Join-Path $clientRoot 'out/local-server/passives-runtime/server-stdout.log'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
Write-Host ('Native admin evidence: ' + $logs)
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned local server did not exit.' }
    }
}
function Start-AdminCase([bool]$Enabled) {
    Stop-OwnedServer
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh -AdminQA:$Enabled *> (Join-Path $logs 'start.log')
    if ($LASTEXITCODE) { throw 'Admin audit startup failed.' }
}
function Invoke-AdminCase([string]$Name) {
    # Preserve Ban::acceptConnection's normal five-second counter window.
    # Each native login creates separate login/game connections.
    Start-Sleep -Milliseconds 5500
    $parameters = @{}
    if ($PackageDirectory) { $parameters.PackageDirectory = $PackageDirectory }
    $script:caseNumber++
    $caseLog = Join-Path $logs ('{0:D2}-{1}.log' -f $script:caseNumber,$Name)
    $caseServerLog = Join-Path $logs ('{0:D2}-{1}-server.log' -f $script:caseNumber,$Name)
    $success = if ($Name -eq 'death') { 'PASSIVES_ADMIN_DEATH_CONNECTION_ENDED' } else { 'PASSIVES_ADMIN_OK' }
    try {
        & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-admin.lua' -Cap $Name -Success $success -TimeoutSeconds 50 @parameters *> $caseLog
    } finally {
        if (Test-Path -LiteralPath $serverLog) { Copy-Item -LiteralPath $serverLog -Destination $caseServerLog -Force }
    }
    if ($LASTEXITCODE) { throw ('Native admin case failed: ' + $Name) }
    if ($Name -eq 'death') {
        $nativeEvidence = [IO.File]::ReadAllText($caseServerLog)
        if ($nativeEvidence -notmatch 'PASSIVE_ADMIN_DEAD_GUARD_OK actualNativeDeath=true hp0=true actorStillConnected=true noRankMutation=true' -or
            $nativeEvidence -notmatch 'PASSIVE_ADMIN_QA_OK death' -or $nativeEvidence -match 'PASSIVE_ADMIN_QA_FAILED death') {
            throw 'Native zero-HP death guard was not confirmed by server evidence.'
        }
    }
    Write-Host ('PASS native admin ' + $Name)
}
Push-Location $clientRoot
$needsCleanup = $false
$script:caseNumber = 0
try {
    Start-AdminCase $false
    Invoke-AdminCase 'off'
    Start-AdminCase $true
    $needsCleanup = $true
    Invoke-AdminCase 'exercise'
    Invoke-AdminCase 'persist'
    Invoke-AdminCase 'death'
    Invoke-AdminCase 'persist'
    Start-AdminCase $false
    Invoke-AdminCase 'off'
    Start-AdminCase $true
    Invoke-AdminCase 'high'
    Start-AdminCase $false
    Invoke-AdminCase 'off'
    Start-AdminCase $true
    Invoke-AdminCase 'cleanup'
    $needsCleanup = $false
    Write-Host 'Admin/God native QA gates passed; normal local overlay access remains separate.'
} finally {
    if ($needsCleanup) {
        try { Start-AdminCase $true; Invoke-AdminCase 'cleanup' } catch { Write-Warning ('Owned GUID9001 cleanup failed: ' + $_.Exception.Message) }
    }
    Start-AdminCase $false
    Pop-Location
}
