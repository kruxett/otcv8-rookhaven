param([switch]$Stop, [switch]$Refresh, [switch]$AdminQA)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path (Split-Path $clientRoot -Parent) 'Rookhaven'
$localRoot = Join-Path $clientRoot 'out/local-server'
$runtime = Join-Path $localRoot 'passives-runtime'
$dbBin = Join-Path $localRoot 'mariadb-11.4.9-winx64/bin'
$databaseExe = [IO.Path]::GetFullPath((Join-Path $dbBin 'mariadbd.exe'))
$databaseCli = Join-Path $dbBin 'mariadb.exe'
$dbData = Join-Path $localRoot 'passives-db'
$dbPort = 33308
$rootPassword = 'LocalPassiveFixtureOnly'
$serverExe = [IO.Path]::GetFullPath((Join-Path $serverRoot 'build/local-passives/tfs.exe'))
$package = Join-Path $clientRoot 'out/install/x64-LocalPassives'
$ownedServer = Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe
$ownedDatabase = Get-CimInstance Win32_Process -Filter "Name='mariadbd.exe'" | Where-Object { $_.CommandLine -like "*$dbData*" }
if ($Stop) {
    $ownedServer | Stop-Process
    $ownedDatabase | ForEach-Object { Stop-Process -Id $_.ProcessId }
    Write-Host 'Local passives server and its own database stopped.'
    exit
}
foreach ($required in @($databaseExe, $databaseCli, $serverExe, (Join-Path $package 'checksum_expected.txt'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing $required. Run tools/build-local-passives.ps1 first." }
}
if ($Refresh) {
    foreach ($owned in @($ownedServer)) {
        if (-not $owned) { continue }
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned local server did not exit before refresh.' }
    }
    $ownedServer = $null
}
if (-not (Test-Path -LiteralPath (Join-Path $dbData 'mysql'))) {
    & (Join-Path $dbBin 'mariadb-install-db.exe') "--datadir=$dbData" "--port=$dbPort" "--password=$rootPassword" --silent
    if ($LASTEXITCODE) { throw 'Could not initialize the isolated passive database.' }
}
if (-not $ownedDatabase) {
    if (Get-NetTCPConnection -LocalPort $dbPort -State Listen -ErrorAction SilentlyContinue) {
        throw 'Port 33308 belongs to another database. Refusing to use it.'
    }
    Start-Process $databaseExe -ArgumentList '--no-defaults',"--datadir=$dbData",'--bind-address=127.0.0.1',"--port=$dbPort",'--skip-name-resolve','--console' `
        -WindowStyle Hidden -RedirectStandardOutput (Join-Path $localRoot 'passives-db-stdout.log') -RedirectStandardError (Join-Path $localRoot 'passives-db-stderr.log') | Out-Null
}
$deadline = (Get-Date).AddSeconds(20)
while (-not (Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $dbPort -State Listen -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) { throw 'Local MariaDB did not start.' }
    Start-Sleep -Milliseconds 200
}
function Invoke-LocalSql([string]$Sql, [string]$Database = '') {
    $sqlArgs = @('--host=127.0.0.1',"--port=$dbPort",'--user=root',"--password=$rootPassword",'--batch','--skip-column-names')
    if ($Database) { $sqlArgs += "--database=$Database" }
    $result = & $databaseCli @sqlArgs "--execute=$Sql"
    if ($LASTEXITCODE) { throw 'Local fixture SQL failed.' }
    return $result
}
$exists = Invoke-LocalSql "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='rookhaven_passives_test'"
if ([int]$exists -eq 0) {
    # Clone only the known disposable item fixture, never a production database.
    Invoke-LocalSql "CREATE DATABASE rookhaven_passives_test CHARACTER SET utf8; CREATE USER 'rooktest'@'127.0.0.1' IDENTIFIED BY 'LocalItemProofOnly'; GRANT ALL ON rookhaven_passives_test.* TO 'rooktest'@'127.0.0.1';" | Out-Null
    $dumpPath = Join-Path $localRoot 'passives-fixture-seed.sql'
    & (Join-Path $dbBin 'mariadb-dump.exe') --host=127.0.0.1 --port=33307 --user=rooktest --password=LocalItemProofOnly --single-transaction --skip-comments "--result-file=$dumpPath" rookhaven_item_test
    if ($LASTEXITCODE) { throw 'Could not clone the disposable item-test fixture.' }
    Invoke-LocalSql ("SOURCE " + $dumpPath.Replace('\','/')) 'rookhaven_passives_test' | Out-Null
    $seed = @'
INSERT INTO accounts(id,name,password,type,premium_ends_at) VALUES
 (9001,'passivetest',SHA1('passivetest'),6,2147483647),
 (9002,'passivepeer',SHA1('passivepeer'),6,2147483647);
INSERT INTO players(id,name,group_id,account_id,level,vocation,experience,health,healthmax,mana,manamax,cap,town_id,posx,posy,posz,lastlogin,skill_axe,skill_shielding,maglevel,soul) VALUES
 (9001,'Passive Tester',7,9001,40,3,988000,735,735,390,390,10000,1,32097,32219,7,1,60,35,6,100),
 (9002,'Passive Peer',7,9002,40,3,988000,735,735,390,390,10000,1,32098,32219,7,1,60,35,6,100);
INSERT INTO player_spells(player_id,name) VALUES
 (9001,'Head Splitter'),(9001,'Axe Throw'),(9001,'Light Healing'),(9001,'Heal Friend'),
 (9002,'Head Splitter'),(9002,'Axe Throw'),(9002,'Light Healing'),(9002,'Heal Friend');
INSERT INTO player_items(player_id,pid,sid,itemtype,count,attributes) VALUES
 (9001,6,101,2428,1,X'00'),(9001,5,102,2512,1,X'00'),(9001,4,103,2465,1,X'00'),
 (9001,1,104,2462,1,X'00'),(9001,7,105,2647,1,X'00'),(9001,8,106,2643,1,X'00'),
 (9002,6,101,2428,1,X'00'),(9002,5,102,2512,1,X'00'),(9002,4,103,2465,1,X'00');
'@
    Invoke-LocalSql $seed 'rookhaven_passives_test' | Out-Null
}
if (-not $ownedServer) {
    # Idempotent schema and ordinary-player fixtures for the permanent class slice.
    $permanentSchema = Join-Path $serverRoot 'tools/passives-fixture/permanent-schema.sql'
    if (Test-Path -LiteralPath $permanentSchema) {
        Invoke-LocalSql ([IO.File]::ReadAllText($permanentSchema)) 'rookhaven_passives_test' | Out-Null
    }
    $ordinarySeed = @'
INSERT IGNORE INTO accounts(id,name,password,type,premium_ends_at) VALUES
 (9003,'passiveclass',SHA1('passiveclass'),1,2147483647),
 (9004,'passivemagic',SHA1('passivemagic'),1,2147483647),
 (9005,'passivelegacy',SHA1('passivelegacy'),1,2147483647);
INSERT IGNORE INTO players(id,name,group_id,account_id,level,vocation,experience,health,healthmax,mana,manamax,cap,town_id,posx,posy,posz,lastlogin,skill_axe,skill_shielding,maglevel,soul) VALUES
 (9003,'Passive Initiate',1,9003,40,2,988000,735,735,390,390,10000,1,32097,32219,7,1,60,35,6,100),
 (9004,'Passive Mystic',1,9004,40,3,988000,735,735,390,390,10000,1,32098,32219,7,1,60,35,6,100),
 (9005,'Passive Veteran',1,9005,40,3,988000,735,735,390,390,10000,1,32099,32219,7,1,60,35,6,100);
'@
    Invoke-LocalSql $ordinarySeed 'rookhaven_passives_test' | Out-Null
    # Consistent normal weapon skills for the two disposable level-40 fixtures.
    Invoke-LocalSql 'UPDATE players SET skill_sword=60,skill_club=60,skill_dist=60,skill_shielding=60 WHERE id IN (9001,9002);' 'rookhaven_passives_test' | Out-Null
}
if ($Refresh -or -not (Test-Path -LiteralPath (Join-Path $runtime 'config.lua'))) {
    if ($ownedServer) { throw 'Stop the owned passives server before refreshing runtime data.' }
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $serverRoot 'data') -Destination $runtime -Recurse -Force
    $config = @'
ip = "127.0.0.1"
bindOnlyGlobalAddress = true
loginProtocolPort = 7174
gameProtocolPort = 7175
statusProtocolPort = 7174
mysqlHost = "127.0.0.1"
mysqlPort = 33308
mysqlUser = "rooktest"
mysqlPass = "LocalItemProofOnly"
mysqlDatabase = "rookhaven_passives_test"
mapName = "rookalmost"
serverName = "Rookhaven Local Passives Test"
worldType = "no-pvp"
passiveTestEnabled = true
passiveAdminEnabled = false
enforceClientChecksums = true
startupDatabaseOptimization = false
classicEquipmentSlots = true
'@
    if ($AdminQA) { $config = $config.Replace('passiveAdminEnabled = false', 'passiveAdminEnabled = true') }
    [IO.File]::WriteAllText((Join-Path $runtime 'config.lua'), $config, [Text.UTF8Encoding]::new($false))
    # Local-only administrators with player combat flags: no infinite mana,
    # invulnerability, exhaustion bypass, or monster invisibility.
    $groupPath = Join-Path $runtime 'data/XML/groups.xml'
    $groups = [IO.File]::ReadAllText($groupPath)
    $groups = $groups.Replace('</groups>', '<group id="7" name="passive test admin" access="1" maxdepotitems="0" maxvipentries="200"><flags><flag isalwayspremium="1" /></flags></group></groups>')
    [IO.File]::WriteAllText($groupPath, $groups, [Text.UTF8Encoding]::new($false))
    # Runtime-only combat fixtures are never registered in the source game data.
    $fixture = Join-Path $serverRoot 'tools/passives-fixture'
    foreach ($name in @('passiveqa.lua','passive_baseline.lua','passive_lifecycle.lua','passive_permanent.lua','class_spells_qa.lua','passive_routes_qa.lua','passive_character_stats.lua','passive_admin_qa.lua','passive_balance_qa.lua','passive_guard_balance_qa.lua','passive_shutdown_qa.lua','passive_pvp_qa.lua')) {
        Copy-Item -LiteralPath (Join-Path $fixture $name) -Destination (Join-Path $runtime ('data/talkactions/scripts/' + $name)) -Force
    }
    Copy-Item -LiteralPath (Join-Path $fixture 'passive_admin_dead_qa.lua') -Destination (Join-Path $runtime 'data/creaturescripts/scripts/passive_admin_dead_qa.lua') -Force
    Copy-Item -LiteralPath (Join-Path $fixture 'passive_equipment_stats.lua') -Destination (Join-Path $runtime 'data/talkactions/scripts/passive_equipment_stats.lua') -Force
    Copy-Item -LiteralPath (Join-Path $fixture 'passive_test_dummy.xml') -Destination (Join-Path $runtime 'data/monster/monsters/passive_test_dummy.xml') -Force
    Copy-Item -LiteralPath (Join-Path $fixture 'class_spell_dummy.xml') -Destination (Join-Path $runtime 'data/monster/monsters/class_spell_dummy.xml') -Force
    Copy-Item -LiteralPath (Join-Path $fixture 'passive_guard_dummy.xml') -Destination (Join-Path $runtime 'data/monster/monsters/passive_guard_dummy.xml') -Force
    foreach ($dummy in @('passive_bleed_budget_dummy.xml','passive_bleed_immune_dummy.xml')) {
        Copy-Item -LiteralPath (Join-Path $fixture $dummy) -Destination (Join-Path $runtime ('data/monster/monsters/' + $dummy)) -Force
    }
    foreach ($registration in @(
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passiveqa" separator=" " script="passiveqa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passivebaseline" separator=" " script="passive_baseline.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passivelifecycle" separator=" " script="passive_lifecycle.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passivepermanent" separator=" " script="passive_permanent.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/classspellqa" separator=" " script="class_spells_qa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passiverouteqa" separator=" " script="passive_routes_qa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passivecharacterstats" separator=" " script="passive_character_stats.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passiveequipmentstats" separator=" " script="passive_equipment_stats.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passiveadminqa" separator=" " script="passive_admin_qa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passivebalanceqa" separator=" " script="passive_balance_qa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passiveguardbalanceqa" separator=" " script="passive_guard_balance_qa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passiveshutdownqa" separator=" " script="passive_shutdown_qa.lua" />'},
        @{Path='data/talkactions/talkactions.xml'; End='</talkactions>'; Value='<talkaction words="/passivepvpqa" separator=" " script="passive_pvp_qa.lua" />'},
        @{Path='data/creaturescripts/creaturescripts.xml'; End='</creaturescripts>'; Value='<event type="death" name="PassiveAdminDeadQA" script="passive_admin_dead_qa.lua" />'},
        @{Path='data/monster/monsters.xml'; End='</monsters>'; Value='<monster name="Passive Test Dummy" file="monsters/passive_test_dummy.xml" />'},
        @{Path='data/monster/monsters.xml'; End='</monsters>'; Value='<monster name="Passive Bleed Budget Dummy" file="monsters/passive_bleed_budget_dummy.xml" />'},
        @{Path='data/monster/monsters.xml'; End='</monsters>'; Value='<monster name="Passive Bleed Immune Dummy" file="monsters/passive_bleed_immune_dummy.xml" />'},
        @{Path='data/monster/monsters.xml'; End='</monsters>'; Value='<monster name="Class Spell Dummy" file="monsters/class_spell_dummy.xml" />'},
        @{Path='data/monster/monsters.xml'; End='</monsters>'; Value='<monster name="Passive Guard Dummy" file="monsters/passive_guard_dummy.xml" />'}
    )) {
        $path = Join-Path $runtime $registration.Path
        $xml = [IO.File]::ReadAllText($path).Replace($registration.End, $registration.Value + $registration.End)
        [IO.File]::WriteAllText($path, $xml, [Text.UTF8Encoding]::new($false))
    }
    Copy-Item -LiteralPath (Join-Path $package 'checksum_expected.txt') -Destination (Join-Path $runtime 'data/checksum_expected.txt') -Force
    Copy-Item -LiteralPath (Join-Path $package 'checksum_expected.json') -Destination (Join-Path $runtime 'local-package.json') -Force
    # Copies outside data needed by this server's startup loader.
    foreach ($file in @('global.lua','schema.sql','key.pem')) {
        $sourceFile = Join-Path $serverRoot $file
        if (Test-Path -LiteralPath $sourceFile) { Copy-Item -LiteralPath $sourceFile -Destination $runtime -Force }
    }
}
if (-not $ownedServer) {
    if (Get-NetTCPConnection -LocalPort 7174,7175 -State Listen -ErrorAction SilentlyContinue) {
        throw 'A different local server owns 7174/7175. Stop it before starting the passives fixture.'
    }
    Start-Process $serverExe -WorkingDirectory $runtime -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $runtime 'server-stdout.log') -RedirectStandardError (Join-Path $runtime 'server-stderr.log') | Out-Null
}
$deadline = (Get-Date).AddSeconds(30)
while (-not (Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 7175 -State Listen -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) { throw "Passives server did not start. See $runtime/server-stdout.log" }
    Start-Sleep -Milliseconds 250
}
Write-Host 'LOCAL RETRO PASSIVES ready: 127.0.0.1:7174 (game7175), DB33308.'
Write-Host 'Normal-combat admin: passivetest / passivetest; character Passive Tester.'
Write-Host 'Peer: passivepeer / passivepeer; character Passive Peer.'
Write-Host '/passivetest start reaver'
