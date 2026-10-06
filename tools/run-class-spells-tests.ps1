param([switch]$Build, [string[]]$Trees = @('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'), [switch]$KeepClasses, [string]$PackageDirectory = '')
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$logRoot = Join-Path $clientRoot 'out/class-spells-tests'
$all = @('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper')
$names = @('Reaver','Blademaster','Earthshaker','Marksman','Arcanist','Lifekeeper')
$focus = @(2,3,1,4,5,5)
foreach ($tree in $Trees) { if ($tree -notin $all) { throw "Unknown class $tree" } }
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned test server did not exit.' }
    }
}
function Invoke-FixtureSql([string]$Sql) {
    & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Sql"
    if ($LASTEXITCODE) { throw 'Isolated starter-spell fixture SQL failed.' }
}
Push-Location $clientRoot
try {
    if ($Build) {
        Stop-OwnedServer
        & (Join-Path $PSScriptRoot 'build-local-passives.ps1') -Jobs 8 *> (Join-Path $logRoot 'build.log')
        if ($LASTEXITCODE) { throw 'Local build failed.' }
    }
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logRoot 'initial-start.log')
    if ($LASTEXITCODE) { throw 'Isolated runtime startup failed.' }
    Stop-OwnedServer
    foreach ($tree in $Trees) {
        $i = [array]::IndexOf($all, $tree); $id = 9006 + $i
        # Fixed disposable IDs; no existing player data is modified.
        if ($id -lt 9006 -or $id -gt 9011) { throw 'Fixture ID outside allowlist.' }
        $sql = @'
INSERT IGNORE INTO accounts(id,name,password,type,premium_ends_at) VALUES (FIXTURE_ID,'FIXTURE_ACCOUNT',SHA1('FIXTURE_ACCOUNT'),1,2147483647);
INSERT IGNORE INTO players(id,name,group_id,account_id,level,vocation,experience,health,healthmax,mana,manamax,cap,town_id,posx,posy,posz,lastlogin,skill_axe,skill_sword,skill_club,skill_dist,skill_shielding,maglevel,soul) VALUES (FIXTURE_ID,'Starter FIXTURE_NAME',1,FIXTURE_ID,40,3,988000,735,735,390,390,10000,1,32097,32219,7,1,60,60,60,60,35,6,100);
'@
        if (-not $KeepClasses) {
            $sql += @'
DELETE FROM player_passives WHERE player_id=FIXTURE_ID;
DELETE FROM player_spells WHERE player_id=FIXTURE_ID;
DELETE FROM player_items WHERE player_id=FIXTURE_ID;
DELETE FROM player_storage WHERE player_id=FIXTURE_ID AND `key` IN (70167,70169,70170);
INSERT INTO player_storage(player_id,`key`,value) VALUES(FIXTURE_ID,70167,7),(FIXTURE_ID,70169,FIXTURE_FOCUS);
UPDATE players SET group_id=1,vocation=3,level=40,experience=988000,health=735,healthmax=735,mana=390,manamax=390,conditions='',ps_mode=0,ps_name='',posx=32097,posy=32219,posz=7,balance=0,skill_axe=60,skill_sword=60,skill_club=60,skill_dist=60,maglevel=6 WHERE id=FIXTURE_ID;
'@
        }
        $sql = $sql.Replace('FIXTURE_ID', [string]$id).Replace('FIXTURE_ACCOUNT', 'class' + $tree).Replace('FIXTURE_NAME', $names[$i]).Replace('FIXTURE_FOCUS', [string]$focus[$i])
        Invoke-FixtureSql $sql | Out-Null
    }
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logRoot 'start.log')
    if ($LASTEXITCODE) { throw 'Starter-spell fixture startup failed.' }
    foreach ($tree in $Trees) {
        $packageParameters = @{}
        if ($PackageDirectory) { $packageParameters.PackageDirectory = $PackageDirectory }
        & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'class-spells.lua' -Tree $tree -Success 'CLASS_SPELLS_OK' -TimeoutSeconds 180 @packageParameters *> (Join-Path $logRoot ($tree + '.log'))
        if ($LASTEXITCODE) { throw "Starter-spell scenario failed: $tree" }
        Write-Host "PASS starter spells $tree"
        Start-Sleep -Seconds 6 # preserve the existing connection throttle
    }
    Write-Host 'Local starter-spell suite complete:' $logRoot
} finally { Pop-Location }
