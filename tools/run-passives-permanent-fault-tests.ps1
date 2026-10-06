param()
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$logs = Join-Path $clientRoot 'out/passives-permanent-tests'
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned server did not exit.' }
    }
}
function Sql([string]$Query) {
    $rows = & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Query"
    if ($LASTEXITCODE) { throw 'Disposable fixture query failed.' }
    return $rows
}
Push-Location $clientRoot
$originalRanks = $null
try {
    Stop-OwnedServer
    $originalRanks = [string](Sql "SELECT ranks FROM player_passives WHERE player_id=9005 AND class_id='reaver'")
    if ($originalRanks -notmatch '^[0-5](,[0-5]){28}$') { throw 'Run the permanent suite first; GUID9005 Reaver fixture required.' }
    Sql "UPDATE player_passives SET ranks='invalid' WHERE player_id=9005 AND class_id='reaver'" | Out-Null
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'fault-start.log')
    & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-permanent-fault.lua' -Cap corrupt -Success 'PASSIVES_PERMANENT_FAULT_OK rejected' -TimeoutSeconds 35 *> (Join-Path $logs 'fault-rejected.log')
    if ($LASTEXITCODE) { throw 'Corrupt permanent login was not safely rejected.' }
    $serverLog=Get-Content -LiteralPath (Join-Path $clientRoot 'out/local-server/passives-runtime/server-stdout.log') -Raw
    if ($serverLog -notmatch '\[Passives\] Permanent restore failed for GUID 9005: Saved permanent class data is invalid\.') { throw 'Expected corrupt-ledger rejection was not recorded by the server.' }
    if ([int](Sql 'SELECT COUNT(*) FROM players_online WHERE player_id=9005') -ne 0) { throw 'Rejected fixture remains online.' }
    if ([string](Sql 'SELECT ranks FROM player_passives WHERE player_id=9005') -ne 'invalid') { throw 'Rejected login rewrote saved ranks.' }
    Stop-OwnedServer
    Sql ("UPDATE player_passives SET ranks='" + $originalRanks + "' WHERE player_id=9005 AND class_id='reaver'") | Out-Null
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'fault-repair-start.log')
    & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-permanent-fault.lua' -Cap repair -Success 'PASSIVES_PERMANENT_FAULT_OK repaired' -TimeoutSeconds 35 *> (Join-Path $logs 'fault-repaired.log')
    if ($LASTEXITCODE) { throw 'Repaired fixture did not recover its permanent build.' }
    Write-Host 'PASS permanent invalid-row login rejection and recovery.'
} finally {
    if ($originalRanks) {
        Stop-OwnedServer
        Sql ("UPDATE player_passives SET ranks='" + $originalRanks + "' WHERE player_id=9005 AND class_id='reaver'") | Out-Null
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'fault-restored-start.log')
    }
    Pop-Location
}
