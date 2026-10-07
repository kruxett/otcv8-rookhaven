param([string]$PackageDirectory = '')
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$runtimeConfig = Join-Path $clientRoot 'out/local-server/passives-runtime/config.lua'
$logs = Join-Path $clientRoot ('out/passives-guard-balance-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned isolated server did not exit.' }
    }
}
function Sql([string]$Text) {
    $rows = & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Text"
    if ($LASTEXITCODE) { throw 'Owned guard QA fixture SQL failed.' }
    return $rows
}
function Assert-OwnedFixture {
    $config = [IO.File]::ReadAllText($runtimeConfig)
    foreach ($pattern in @('(?m)^\s*ip\s*=\s*"127\.0\.0\.1"\s*$','(?m)^\s*bindOnlyGlobalAddress\s*=\s*true\s*$',
        '(?m)^\s*loginProtocolPort\s*=\s*7174\s*$','(?m)^\s*gameProtocolPort\s*=\s*7175\s*$',
        '(?m)^\s*mysqlHost\s*=\s*"127\.0\.0\.1"\s*$','(?m)^\s*mysqlPort\s*=\s*33308\s*$','(?m)^\s*mysqlDatabase\s*=\s*"rookhaven_passives_test"\s*$',
        '(?m)^\s*serverName\s*=\s*"Rookhaven Local Passives Test"\s*$','(?m)^\s*passiveTestEnabled\s*=\s*true\s*$')) {
        if ($config -notmatch $pattern) { throw 'Expected owned loopback fixture required.' }
    }
    if ([string](Sql 'SELECT CONCAT(@@port,CHAR(58),DATABASE())') -ne '33308:rookhaven_passives_test') { throw 'Unexpected fixture database identity.' }
    $check = @'
SELECT COUNT(*) FROM players p JOIN accounts a ON a.id=p.account_id JOIN player_passives t ON t.player_id=p.id
WHERE p.group_id=1 AND p.vocation=3 AND p.level=40 AND a.type=1 AND
((p.id=9006 AND p.name='Starter Reaver' AND a.name='classreaver' AND t.class_id='reaver') OR
 (p.id=9008 AND p.name='Starter Earthshaker' AND a.name='classearthshaker' AND t.class_id='earthshaker'));
'@
    if ([int](Sql $check) -ne 2) { throw 'Existing ordinary starter fixture GUID9006/9008 identities required; run starter class tests first.' }
}
function Reset-OwnedLedgers {
    if (Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe) { throw 'Stop owned server before resetting guard fixtures.' }
    $reset = @'
START TRANSACTION;
UPDATE player_passives SET earned_points=16,respec_count=0,ranks='0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0' WHERE (player_id=9006 AND class_id='reaver') OR (player_id=9008 AND class_id='earthshaker');
UPDATE players SET health=735,healthmax=735,mana=390,manamax=390,conditions='',ps_mode=0,ps_name='',posx=32097,posy=32219,posz=7 WHERE id IN (9006,9008);
DELETE FROM player_storage WHERE player_id IN (9006,9008) AND `key`=70175;
COMMIT;
'@
    Sql $reset | Out-Null
}
Push-Location $clientRoot
$validated = $false
try {
    Assert-OwnedFixture; $validated = $true
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    Write-Host ('Ordinary native guard evidence: ' + $logs)
    foreach ($cap in @('bloodguard','stonebond','stoneguard')) {
        Stop-OwnedServer; Reset-OwnedLedgers
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs ($cap + '-start.log'))
        $argsForPackage = @{}
        if ($PackageDirectory) { $argsForPackage.PackageDirectory = $PackageDirectory }
        try {
            & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-guard-balance.lua' -Cap $cap -Success ('PASSIVES_GUARD_BALANCE_OK ' + $cap) -TimeoutSeconds 190 @argsForPackage *> (Join-Path $logs ($cap + '.log'))
        } finally {
            Copy-Item -LiteralPath (Join-Path $clientRoot 'out/local-server/passives-runtime/server-stdout.log') -Destination (Join-Path $logs ($cap + '-server.log')) -Force
        }
        Write-Host ('PASS ordinary native guard budget ' + $cap)
    }
} finally {
    if ($validated) {
        Stop-OwnedServer; Reset-OwnedLedgers
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'restore.log')
    }
    Pop-Location
}
