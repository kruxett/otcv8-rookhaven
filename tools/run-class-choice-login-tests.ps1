param(
    [ValidateSet('ordinary','magic','sword','unfocused')][string[]]$Phases = @('ordinary','magic','sword','unfocused'),
    [string]$PackageDirectory = ''
)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$localRoot = Join-Path $clientRoot 'out/local-server'
$dbCli = Join-Path $localRoot 'mariadb-11.4.9-winx64/bin/mariadb.exe'
$databaseExe = [IO.Path]::GetFullPath((Join-Path $localRoot 'mariadb-11.4.9-winx64/bin/mariadbd.exe'))
$databaseData = [IO.Path]::GetFullPath((Join-Path $localRoot 'passives-db'))
$runtimeConfig = Join-Path $localRoot 'passives-runtime/config.lua'
$logs = Join-Path $clientRoot ('out/class-choice-login-tests-' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logs -Force | Out-Null

function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned loopback test server did not exit.' }
    }
}
function Invoke-FixtureSql([string]$Sql) {
    $output = & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Sql"
    if ($LASTEXITCODE) { throw 'Isolated login-choice fixture SQL failed.' }
    return $output
}
function Assert-IsolatedFixture {
    $config = [IO.File]::ReadAllText($runtimeConfig)
    foreach ($line in @('ip = "127.0.0.1"','bindOnlyGlobalAddress = true','loginProtocolPort = 7174','gameProtocolPort = 7175','mysqlHost = "127.0.0.1"','mysqlPort = 33308','mysqlDatabase = "rookhaven_passives_test"','serverName = "Rookhaven Local Passives Test"','passiveTestEnabled = true','passiveAdminEnabled = false')) {
        if ($config -notmatch ('(?m)^' + [regex]::Escape($line) + '\s*$')) { throw ('Isolated runtime guard failed: ' + $line) }
    }
    $listener = @(Get-NetTCPConnection -LocalPort 33308 -State Listen -ErrorAction SilentlyContinue)
    if ($listener.Count -ne 1 -or $listener[0].LocalAddress -ne '127.0.0.1') { throw 'Fixture database is not exclusively bound to loopback33308.' }
    $database = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
    if (-not $database -or $database.ExecutablePath -ne $databaseExe -or $database.CommandLine -notlike "*$databaseData*") { throw 'Fixture database process identity mismatch.' }
    $identity = @(Invoke-FixtureSql @'
SELECT CONCAT(DATABASE(),'|',@@port,'|',COUNT(*)) FROM players p JOIN accounts a ON a.id=p.account_id WHERE p.group_id=1 AND a.type=1 AND ((p.id=9003 AND p.name='Passive Initiate' AND a.id=9003 AND a.name='passiveclass') OR (p.id=9004 AND p.name='Passive Mystic' AND a.id=9004 AND a.name='passivemagic') OR (p.id=9005 AND p.name='Passive Veteran' AND a.id=9005 AND a.name='passivelegacy'));
'@)
    if ($identity.Count -ne 1 -or $identity[0] -ne 'rookhaven_passives_test|33308|3') { throw 'Disposable three-character database identity mismatch.' }
}
function Reset-LoginChoiceFixture([int]$Id,[int]$Vocation,[int]$Focus) {
    if ($Id -notin @(9003,9004,9005) -or $Vocation -notin @(2,3) -or $Focus -notin @(-1,3,5)) { throw 'Login-choice seed is outside its disposable allowlist.' }
    if (Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe) { throw 'Stop the owned server before resetting login-choice fixtures.' }
    Assert-IsolatedFixture
    $sql = @'
DELETE FROM player_passives WHERE player_id=FIXTURE_ID;
DELETE FROM player_spells WHERE player_id=FIXTURE_ID AND player_id IN (9003,9004,9005) AND name IN ('Cleaving Arc','Rend','Focused Thrust','Flurry','Crushing Blow','Rolling Thunder','Blitzshot','Scattershot','Resonant Burst','Arcane Surge','Mending Thread','Essence Lash');
INSERT INTO player_spells(player_id,name) SELECT FIXTURE_ID,'Light Healing' WHERE FIXTURE_ID IN (9003,9004,9005) AND NOT EXISTS (SELECT 1 FROM player_spells WHERE player_id=FIXTURE_ID AND name='Light Healing');
DELETE FROM player_storage WHERE player_id=FIXTURE_ID AND `key` IN (70167,70169,70170);
INSERT INTO player_storage(player_id,`key`,value) VALUES(FIXTURE_ID,70167,7),(FIXTURE_ID,70169,FIXTURE_FOCUS);
DELETE FROM player_items WHERE player_id=FIXTURE_ID;
DELETE FROM player_depotitems WHERE player_id=FIXTURE_ID;
INSERT INTO player_items(player_id,pid,sid,itemtype,count,attributes) VALUES (FIXTURE_ID,6,101,2428,1,X'00'),(FIXTURE_ID,5,102,2512,1,X'00'),(FIXTURE_ID,3,103,1988,1,X'00'),(FIXTURE_ID,103,104,2148,37,X'00');
UPDATE players SET group_id=1,vocation=FIXTURE_VOC,level=40,experience=988123,health=735,healthmax=735,mana=390,manamax=390,manaspent=321,cap=10000,posx=32097,posy=32219,posz=7,conditions='',ps_mode=0,ps_name='',balance=10000,skill_fist=30,skill_fist_tries=17,skill_axe=60,skill_axe_tries=123,skill_sword=60,skill_sword_tries=124,skill_club=60,skill_club_tries=125,skill_dist=60,skill_dist_tries=126,skill_shielding=35,skill_shielding_tries=127,skill_fishing=30,skill_fishing_tries=128,maglevel=6 WHERE id=FIXTURE_ID;
'@
    $sql = $sql.Replace('FIXTURE_ID',[string]$Id).Replace('FIXTURE_VOC',[string]$Vocation).Replace('FIXTURE_FOCUS',[string]$Focus)
    Invoke-FixtureSql $sql | Out-Null
}

Push-Location $clientRoot
try {
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'initial-start.log')
    if ($LASTEXITCODE) { throw 'Isolated login-choice runtime startup failed.' }
    foreach ($case in @(@{Id=9003;Voc=2;Focus=-1;Phase='ordinary';Tree='reaver'},@{Id=9004;Voc=3;Focus=5;Phase='magic';Tree='arcanist'},@{Id=9005;Voc=3;Focus=3;Phase='sword';Tree='blademaster'},@{Id=9003;Voc=3;Focus=-1;Phase='unfocused';Tree='earthshaker'})) {
        if ($case.Phase -notin $Phases) { continue }
        Stop-OwnedServer
        Reset-LoginChoiceFixture $case.Id $case.Voc $case.Focus
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs ($case.Phase + '-start.log'))
        if ($LASTEXITCODE) { throw 'Isolated login-choice fixture startup failed.' }
        Assert-IsolatedFixture
        $packageParameters = @{}
        if ($PackageDirectory) { $packageParameters.PackageDirectory = $PackageDirectory }
        $receipt = Join-Path $logs ($case.Phase + '-exit.json')
        $logPath = Join-Path $logs ($case.Phase + '.log')
        $started = [DateTime]::UtcNow
        & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'class-choice-login.lua' -Cap $case.Phase -Tree $case.Tree -Success ('CLASS_CHOICE_LOGIN_OK ' + $case.Phase + ' tree=' + $case.Tree) -TimeoutSeconds 200 -ExitReceiptPath $receipt @packageParameters *> $logPath
        if ($LASTEXITCODE) { throw ('Native login-choice scenario failed: ' + $case.Phase) }
        if (-not (Test-Path -LiteralPath $receipt) -or (Get-Item -LiteralPath $receipt).LastWriteTimeUtc -lt $started) { throw 'Missing fresh native client exit receipt.' }
        $exitReceipt = [IO.File]::ReadAllText($receipt) | ConvertFrom-Json
        if ($exitReceipt.clientExit -ne 0) { throw 'Native login-choice client did not exit0.' }
        $log = [IO.File]::ReadAllText($logPath)
        $required = if ($case.Phase -eq 'ordinary') { @('CLASS_CHOICE_LOGIN_ORDINARY_QUIET_OK vocation=2') } else { @('AUTO_OFFER','FORGED','STALE_CONFIRM','CANCEL_SILENT','REOPEN','RELOGIN_FRESH_TOKEN','COMBAT_REJECT','REMOTE_COMMIT','DOUBLE_COMMIT','CHOSEN_QUIET','PRESERVED') | ForEach-Object { 'CLASS_CHOICE_LOGIN_' + $_ + '_OK ' + $case.Phase } }
        foreach ($marker in $required) { if (-not $log.Contains($marker)) { throw ('Missing native login-choice evidence: ' + $marker) } }
        if ($log -match 'CLASS_CHOICE_LOGIN_FAILED|PASSIVES_PERMANENT_FIXTURE_FAILED') { throw ('Native login-choice assertion failed: ' + $case.Phase) }
        Write-Host ('PASS native login class choice ' + $case.Phase + ' exit=0')
    }
    Write-Host 'Local native login-class-choice suite complete. Owned loopback server remains running. Logs:' $logs
} finally { Pop-Location }
