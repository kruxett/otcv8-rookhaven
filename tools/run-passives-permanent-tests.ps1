param([switch]$Build, [switch]$MainOnly, [string]$PackageDirectory = '')
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$logs = Join-Path $clientRoot 'out/passives-permanent-tests'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned local server did not exit.' }
    }
}
function Invoke-FixtureSql([string]$Sql) {
    & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Sql"
    if ($LASTEXITCODE) { throw 'Disposable permanent fixture SQL failed.' }
}
function Reset-Fixture([int]$Id,[int]$Vocation,[int]$Focus) {
    if ($Id -notin @(9003,9004,9005)) { throw 'Only the three disposable permanent fixture IDs are permitted.' }
    if (Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe) { throw 'Stop the owned server before resetting fixture progression.' }
    $sql = @'
DELETE FROM player_passives WHERE player_id=FIXTURE_ID;
-- Reset only the twelve new class starters on allowlisted disposable players.
DELETE FROM player_spells WHERE player_id=FIXTURE_ID AND player_id IN (9003,9004,9005) AND name IN ('Cleaving Arc','Rend','Focused Thrust','Flurry','Crushing Blow','Rolling Thunder','Blitzshot','Scattershot','Resonant Burst','Arcane Surge','Mending Thread','Essence Lash');
-- Preserve all legacy learning; an idempotent seed proves normal save/restore retains it.
INSERT INTO player_spells(player_id,name) SELECT FIXTURE_ID,'Light Healing' WHERE FIXTURE_ID IN (9003,9004,9005) AND NOT EXISTS (SELECT 1 FROM player_spells WHERE player_id=FIXTURE_ID AND name='Light Healing');
DELETE FROM player_storage WHERE player_id=FIXTURE_ID AND `key` IN (70167,70169,70170);
INSERT INTO player_storage(player_id,`key`,value) VALUES (FIXTURE_ID,70167,7),(FIXTURE_ID,70169,FIXTURE_FOCUS);
DELETE FROM player_items WHERE player_id=FIXTURE_ID;
DELETE FROM player_depotitems WHERE player_id=FIXTURE_ID;
UPDATE players SET group_id=1,vocation=FIXTURE_VOC,level=40,experience=988000,health=735,healthmax=735,mana=390,manamax=390,cap=10000,posx=32097,posy=32219,posz=7,conditions='',ps_mode=0,ps_name='',balance=0,skill_axe=60,skill_sword=60,skill_club=60,skill_dist=60,skill_shielding=35,maglevel=6 WHERE id=FIXTURE_ID;
'@
    $sql = $sql.Replace('FIXTURE_ID',[string]$Id).Replace('FIXTURE_VOC',[string]$Vocation).Replace('FIXTURE_FOCUS',[string]$Focus)
    Invoke-FixtureSql $sql | Out-Null
}
Push-Location $clientRoot
try {
    if ($Build) {
        Stop-OwnedServer
        & (Join-Path $PSScriptRoot 'build-local-passives.ps1') -Jobs 8 *> (Join-Path $logs 'build.log')
        if ($LASTEXITCODE) { throw 'Local build failed.' }
    }
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'seed.log')
    if ($LASTEXITCODE) { throw 'Local schema/fixture seed failed.' }
    $cases = @(@{Id=9003;Voc=2;Focus=-1;Tree='reaver';Phase='berserker';Log='third-ascension'})
    if (-not $MainOnly) {
        $cases += @(
            @{Id=9005;Voc=3;Focus=2;Tree='reaver';Phase='legacy';Log='legacy-axe'},
            @{Id=9004;Voc=3;Focus=5;Tree='arcanist';Phase='magic';Log='legacy-wand'},
            @{Id=9004;Voc=3;Focus=5;Tree='lifekeeper';Phase='magic';Log='legacy-rod'}
        )
    }
    foreach ($case in $cases) {
        Stop-OwnedServer
        Reset-Fixture $case.Id $case.Voc $case.Focus
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs ($case.Log + '-start.log'))
        if ($LASTEXITCODE) { throw 'Local permanent fixture startup failed.' }
        $packageParameters = @{}
        if ($PackageDirectory) { $packageParameters.PackageDirectory = $PackageDirectory }
        & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-permanent.lua' -Tree $case.Tree -Cap $case.Phase -Success 'PASSIVES_PERMANENT_OK' -TimeoutSeconds 310 @packageParameters *> (Join-Path $logs ($case.Log + '.log'))
        if ($LASTEXITCODE) { throw ('Permanent scenario failed: ' + $case.Log) }
        Write-Host ('PASS permanent ' + $case.Log)
    }
    Write-Host 'Permanent slice verified locally. Owned local server remains running. Logs:' $logs
} finally { Pop-Location }
