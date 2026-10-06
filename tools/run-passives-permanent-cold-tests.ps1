param()
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$runtime = Join-Path $clientRoot 'out/local-server/passives-runtime'
$logs = Join-Path $clientRoot 'out/passives-permanent-tests'
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned server did not exit.' }
    }
}
function Sql([string]$Query) {
    $rows = & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Query"
    if ($LASTEXITCODE) { throw 'Disposable cold fixture query failed.' }
    return $rows
}
Push-Location $clientRoot
$original = $null
$captured = $false
try {
    Stop-OwnedServer
    $original = [string](Sql "SELECT CONCAT(ranks,'|',earned_points,'|',respec_count) FROM player_passives WHERE player_id=9005 AND class_id='reaver'")
    if ($original -notmatch '^([0-5](,[0-5]){28})\|([0-9]+)\|([0-9]+)$') { throw 'Run the permanent suite first; GUID9005 Reaver fixture required.' }
    $savedRanks,$savedPoints,$savedCount=$Matches[1],$Matches[3],$Matches[4]
    $captured = $true
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'cold-prepare.log')
    Stop-OwnedServer
    $configPath = Join-Path $runtime 'data/lib/passives/config.lua'
    $config = [IO.File]::ReadAllText($configPath).Replace('startingPoints=3','startingPoints=4').Replace('respecCosts={0,1000,2000,4000,8000}','respecCosts={0,777,2000,4000,8000}').Replace('minorVitality=1,','minorVitality=2,')
    [IO.File]::WriteAllText($configPath,$config,[Text.UTF8Encoding]::new($false))
    $startupPath = Join-Path $runtime 'data/globalevents/scripts/startup.lua'
    $startup = [IO.File]::ReadAllText($startupPath)
    $observer = @'
startupPersonalStoreSellers()
local function coldVendor(label)
 local p=Player('Passive Veteran')
 print('PASSIVES_COLD_VENDOR_'..label..' '..(p and ('id='..p:getId()..' ip='..p:getIp()..' maxHP='..p:getMaxHealth()..' store='..p:getPersonalStore().mode)or 'absent'))
end
coldVendor('BEFORE')
addEvent(coldVendor,10000,'AFTER')
'@
    if (-not $startup.Contains('startupPersonalStoreSellers()')) { throw 'Startup store hook missing.' }
    [IO.File]::WriteAllText($startupPath,$startup.Replace('startupPersonalStoreSellers()',$observer),[Text.UTF8Encoding]::new($false))
    $seed = @'
UPDATE player_passives SET ranks='0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',earned_points=16,respec_count=1 WHERE player_id=9005 AND class_id='reaver';
UPDATE players SET ps_mode=1,ps_name='Cold permanent fixture',posx=32099,posy=32219,posz=7,health=735,healthmax=735,conditions='' WHERE id=9005;
INSERT INTO player_items(player_id,pid,sid,itemtype,count,attributes) VALUES(9005,6,101,2428,1,X'00') ON DUPLICATE KEY UPDATE pid=6,itemtype=2428,count=1,attributes=X'00';
'@
    Sql $seed | Out-Null
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'cold-start.log')
    & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-permanent-fault.lua' -Cap cold -Success 'PASSIVES_PERMANENT_FAULT_OK cold' -TimeoutSeconds 35 *> (Join-Path $logs 'cold-tuning.log')
    if ($LASTEXITCODE) { throw 'Cold offline-store reconnect failed configured tuning.' }
    $serverLog = Get-Content -LiteralPath (Join-Path $runtime 'server-stdout.log') -Raw
    if ($serverLog -notmatch 'PASSIVES_COLD_VENDOR_BEFORE id=\d+ ip=0 maxHP=735 store=1') { throw 'Cold test did not start with a real offline vendor.' }
    Stop-OwnedServer
    Sql "UPDATE player_passives SET ranks='invalid' WHERE player_id=9005; UPDATE players SET ps_mode=1,ps_name='Cold permanent fixture' WHERE id=9005;" | Out-Null
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'cold-invalid-start.log')
    & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-permanent-fault.lua' -Cap corrupt -Success 'PASSIVES_PERMANENT_FAULT_OK rejected' -TimeoutSeconds 35 *> (Join-Path $logs 'cold-invalid.log')
    if ($LASTEXITCODE) { throw 'Corrupt offline-store reconnect was not rejected.' }
    if ([IO.File]::ReadAllText((Join-Path $logs 'cold-invalid.log')) -notmatch 'PASSIVES_PERMANENT_FAULT_LOGIN_ERROR Your passive class could not be restored') { throw 'Cold rejection did not report the permanent-ledger error.' }
    $deadline=(Get-Date).AddSeconds(14)
    do {
        $serverLog=Get-Content -LiteralPath (Join-Path $runtime 'server-stdout.log') -Raw
        if ($serverLog -match 'PASSIVES_COLD_VENDOR_AFTER id=\d+ ip=0 maxHP=735 store=1') { break }
        if ((Get-Date) -gt $deadline) { throw 'Rejected reconnect did not preserve the existing offline vendor.' }
        Start-Sleep -Milliseconds 200
    } while ($true)
    if ([int](Sql 'SELECT ps_mode FROM players WHERE id=9005') -ne 1) { throw 'Rejected reconnect cleared store persistence.' }
    Write-Host 'PASS cold configured offline-store reconnect and failed-reconnect preservation.'
} finally {
    if ($captured) {
        Stop-OwnedServer
        Sql ("UPDATE player_passives SET ranks='"+$savedRanks+"',earned_points="+$savedPoints+",respec_count="+$savedCount+" WHERE player_id=9005 AND class_id='reaver'; UPDATE players SET ps_mode=0,ps_name='' WHERE id=9005;") | Out-Null
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'cold-restored-start.log')
    }
    Pop-Location
}
