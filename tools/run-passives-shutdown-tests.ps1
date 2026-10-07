param([string]$PackageDirectory = '')
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$runtime = Join-Path $clientRoot 'out/local-server/passives-runtime'
$databaseCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$logs = Join-Path $clientRoot ('out/passives-shutdown-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned loopback server did not stop.' }
    }
}
function Sql([string]$Text) {
    $rows = & $databaseCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Text"
    if ($LASTEXITCODE) { throw 'Owned local shutdown fixture SQL failed.' }
    return $rows
}
function Assert-OwnedFixture {
    $config = [IO.File]::ReadAllText((Join-Path $runtime 'config.lua'))
    foreach ($pattern in @('(?m)^\s*ip\s*=\s*"127\.0\.0\.1"\s*$','(?m)^\s*bindOnlyGlobalAddress\s*=\s*true\s*$',
        '(?m)^\s*loginProtocolPort\s*=\s*7174\s*$','(?m)^\s*gameProtocolPort\s*=\s*7175\s*$',
        '(?m)^\s*mysqlHost\s*=\s*"127\.0\.0\.1"\s*$','(?m)^\s*mysqlPort\s*=\s*33308\s*$',
        '(?m)^\s*mysqlDatabase\s*=\s*"rookhaven_passives_test"\s*$','(?m)^\s*serverName\s*=\s*"Rookhaven Local Passives Test"\s*$',
        '(?m)^\s*passiveTestEnabled\s*=\s*true\s*$')) {
        if ($config -notmatch $pattern) { throw 'Expected owned loopback runtime required.' }
    }
    if ([string](Sql 'SELECT CONCAT(@@port,CHAR(58),DATABASE())') -ne '33308:rookhaven_passives_test') { throw 'Unexpected database identity.' }
    $identity = "SELECT COUNT(*) FROM players p JOIN accounts a ON a.id=p.account_id JOIN player_passives t ON t.player_id=p.id WHERE p.id=9008 AND p.name='Starter Earthshaker' AND p.group_id=1 AND p.vocation=3 AND p.level=40 AND a.name='classearthshaker' AND a.type=1 AND t.class_id='earthshaker';"
    if ([int](Sql $identity) -ne 1) { throw 'Owned ordinary Earthshaker fixture required; run the starter suite first.' }
}
function Reset-OwnedSubject {
    if (Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe) { throw 'Stop owned server before resetting its disposable subject.' }
    $reset = @'
START TRANSACTION;
UPDATE player_passives SET earned_points=16,respec_count=0,ranks='0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0' WHERE player_id=9008 AND class_id='earthshaker';
UPDATE players SET health=735,healthmax=735,mana=390,manamax=390,conditions='',ps_mode=0,ps_name='',posx=32097,posy=32219,posz=7 WHERE id=9008;
DELETE FROM player_storage WHERE player_id=9008 AND `key`=70175;
COMMIT;
'@
    Sql $reset | Out-Null
}
Push-Location $clientRoot
$validated = $false
try {
    Assert-OwnedFixture; $validated = $true
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    Stop-OwnedServer; Reset-OwnedSubject
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'start.log')
    if ($LASTEXITCODE) { throw 'Owned shutdown fixture startup failed.' }
    $ownedServers = @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)
    if ($ownedServers.Count -ne 1) { throw 'Exactly one owned loopback server required.' }
    $shutdownServer = $ownedServers[0]; $null = $shutdownServer.Handle
    $beforeDumps = @(Get-ChildItem -LiteralPath $runtime -Filter '*.dmp' -File | ForEach-Object Name)
    $packageArgs = @{}
    if ($PackageDirectory) { $packageArgs.PackageDirectory = $PackageDirectory }
    & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-shutdown.lua' -Success 'PASSIVES_SHUTDOWN_CLIENT_OK' -TimeoutSeconds 100 -ExitReceiptPath (Join-Path $logs 'client-exit.json') @packageArgs *> (Join-Path $logs 'probe.log')
    if ($LASTEXITCODE) { throw 'Actual shutdown client probe failed.' }
    $clientReceipt = [IO.File]::ReadAllText((Join-Path $logs 'client-exit.json')) | ConvertFrom-Json
    if ($null -eq $clientReceipt.clientExit -or $clientReceipt.clientExit -ne 0) { throw 'Actual client exit receipt failed.' }
    $probeLog = [IO.File]::ReadAllText((Join-Path $logs 'probe.log'))
    foreach ($marker in @('PASSIVES_SHUTDOWN_CLIENT_OK','PASSIVES_SHUTDOWN_DELAYED_CANCEL_OK')) {
        if ($probeLog -notmatch [regex]::Escape($marker)) { throw 'Actual client evidence marker missing.' }
    }
    if (-not $shutdownServer.WaitForExit(15000)) { throw 'Ordinary shutdown did not terminate the owned server.' }
    $shutdownServer.Refresh(); $nativeExit = $shutdownServer.ExitCode
    Copy-Item -LiteralPath (Join-Path $runtime 'server-stdout.log') -Destination (Join-Path $logs 'server.log') -Force
    $serverLog = [IO.File]::ReadAllText((Join-Path $logs 'server.log'))
    $newDumps = @(Get-ChildItem -LiteralPath $runtime -Filter '*.dmp' -File | Where-Object Name -NotIn $beforeDumps)
    if ($nativeExit -ne 0) { throw "Ordinary server shutdown exit=$nativeExit" }
    if ($newDumps.Count) { throw 'Ordinary shutdown produced a new crash dump.' }
    if ($serverLog -notmatch 'PASSIVE_SHUTDOWN_QA .*"label":"shutdown"' -or $serverLog -match 'unexpected-long-timer|unexpected-cancelled-timer|PASSIVE_SHUTDOWN_QA .*"label":"failed"') {
        throw 'Fresh real pending-timer shutdown evidence missing or failed.'
    }
    $result = @{
        nativeExit = $nativeExit; clientExit = $clientReceipt.clientExit; newDumps = $newDumps.Count
        serverSha256 = (Get-FileHash -LiteralPath $serverExe -Algorithm SHA256).Hash
        markers = @('PASSIVES_SHUTDOWN_CLIENT_OK','PASSIVES_SHUTDOWN_DELAYED_CANCEL_OK','PASSIVE_SHUTDOWN_QA shutdown pendingActions>=1')
        finishedUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $logs 'result.json'), $result, [Text.UTF8Encoding]::new($false))
    Write-Host "PASSIVES_SHUTDOWN_NATIVE_OK exit=$nativeExit newDumps=$($newDumps.Count) actualDeferredTimer=true actualStopEvent=true logs=$logs"
} finally {
    if ($validated) {
        Copy-Item -LiteralPath (Join-Path $runtime 'server-stdout.log') -Destination (Join-Path $logs 'final-server.log') -Force -ErrorAction SilentlyContinue
        Stop-OwnedServer; Reset-OwnedSubject
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'restore.log')
        if ($LASTEXITCODE) { throw 'Owned shutdown fixture restoration failed.' }
    }
    Pop-Location
}
