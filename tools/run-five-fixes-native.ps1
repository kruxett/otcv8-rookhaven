param([switch]$SkipFlagOffBaseline,[switch]$NativeOnly,[switch]$AccessFixes,[switch]$AdditionalRegressionsOnly,
 [string]$ServerRoot='', [string]$ServerExecutable='')
# All writes target an owned cold database copy, copied runtime, and probe profile.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$clientRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverRoot=if ($ServerRoot) {[IO.Path]::GetFullPath($ServerRoot)} else {[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven'))}
$localRoot=Join-Path $clientRoot 'out/local-server'
$sourceDb=Join-Path $localRoot 'passives-db'
$sourceConfig=Join-Path $localRoot 'passives-runtime/config.lua'
$dbBin=Join-Path $localRoot 'mariadb-11.4.9-winx64/bin'
$sourceExe=Join-Path $serverRoot 'build/local-passives/tfs.exe'
if ($ServerExecutable) {$sourceExe=[IO.Path]::GetFullPath($ServerExecutable)}
$package=Join-Path $clientRoot 'out/install/x64-LocalPassives'
$runRoot=Join-Path $clientRoot ('out/five-fixes-native-qa/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$PID)
$runtime=Join-Path $runRoot 'runtime'
$dbData=Join-Path $runRoot 'database'
$profile=[IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Rookhaven Client/Rookhaven-LocalPassives-Probe'))
$profileParent=[IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Rookhaven Client'))
$profileBackup=Join-Path $runRoot 'profile-before'
$ownedServer=$null
$ownedDb=$null
$profileExisted=Test-Path -LiteralPath $profile
$profileCaptured=$false
$mysqlPwdBefore=[Environment]::GetEnvironmentVariable('MYSQL_PWD','Process')
$report=[ordered]@{status='RUNNING';scope='Owned cold-copy DB33308 and copied loopback runtime7174/7175';runRoot=$runRoot;gates=@();serverProcesses=@();databaseProcess=$null;originalDatabaseUnchanged=$false;originalRuntimeConfigUnchanged=$false;probeProfileRestored=$false;ownedProcessesStopped=$false}
function Digest-Tree([string]$Root) {
 $rows=@(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object FullName | ForEach-Object {
  $_.FullName.Substring($Root.Length)+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
 })
 return $rows -join "`n"
}
function Assert-OwnedPath([string]$Path,[string]$Root) {
 $p=[IO.Path]::GetFullPath($Path);$r=[IO.Path]::GetFullPath($Root).TrimEnd('\')
 if (-not $p.StartsWith($r+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Owned path escaped its workspace boundary.'}
}
function Stop-Owned($Process,[string]$ExpectedPath) {
 if (-not $Process) {return}
 $Process.Refresh()
 if (-not $Process.HasExited) {
  $actual=Get-Process -Id $Process.Id -ErrorAction Stop
  if (-not [string]::Equals($actual.Path,[IO.Path]::GetFullPath($ExpectedPath),[StringComparison]::OrdinalIgnoreCase)) {throw 'Owned process identity changed; refusing to stop it.'}
  Stop-Process -Id $actual.Id
  if (-not $Process.WaitForExit(10000)) {throw 'Owned process failed to exit.'}
 }
}
function Sql([string]$Query) {
 $result=@(& (Join-Path $dbBin 'mariadb.exe') --no-defaults --host=127.0.0.1 --port=33308 "--user=$sqlUser" --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Query")
 if ($LASTEXITCODE) {throw 'Owned clone fixture SQL failed.'}
 return $result
}
function Register-Xml([string]$Relative,[string]$End,[string]$Value) {
 $path=Join-Path $runtime $Relative;$xml=[IO.File]::ReadAllText($path)
 if (-not $xml.Contains($End)) {throw 'Runtime XML registration target missing.'}
 [IO.File]::WriteAllText($path,$xml.Replace($End,$Value+$End),[Text.UTF8Encoding]::new($false))
}
function Start-OwnedServer([string]$Phase) {
 foreach ($port in @(7174,7175)) {if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {throw 'Test server port already occupied.'}}
 $script:ownedServer=Start-Process (Join-Path $runtime 'tfs.exe') -WorkingDirectory $runtime -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot ($Phase+'-server-stdout.log')) -RedirectStandardError (Join-Path $runRoot ($Phase+'-server-stderr.log'))
 $script:report.serverProcesses+=@{pid=$script:ownedServer.Id;phase=$Phase;path=(Join-Path $runtime 'tfs.exe')}
 $deadline=(Get-Date).AddSeconds(35)
 do {
  $script:ownedServer.Refresh();if ($script:ownedServer.HasExited) {throw "Owned server exited during $Phase; inspect saved logs."}
  $connections=@(Get-NetTCPConnection -LocalPort 7175 -State Listen -ErrorAction SilentlyContinue)
  if ($connections.Count) {
   if (@($connections|Where-Object {$_.OwningProcess -ne $script:ownedServer.Id -or $_.LocalAddress -ne '127.0.0.1'}).Count) {throw 'Test listener identity/address differs.'}
   return
  }
  if ((Get-Date)-gt $deadline) {throw 'Owned test server startup timed out.'}
  Start-Sleep -Milliseconds 250
 }while($true)
}
function Probe([string]$Script,[string]$Marker,[int]$Timeout) {
 Write-Host "FIVE_FIXES_QA running $Script"
 $log=Join-Path $runRoot ($Script.Replace('.lua','')+'.log')
 if ($Marker.EndsWith('enabled=false')) {$log=Join-Path $runRoot 'passives-baseline-disabled.log'}
 & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script $Script -Success $Marker -TimeoutSeconds $Timeout -ExitReceiptPath ($log+'.exit.json') *> $log
 if ($LASTEXITCODE) {throw "Native probe failed: $Script; inspect $log"}
 $receipt=Get-Content -LiteralPath ($log+'.exit.json') -Raw | ConvertFrom-Json
 $content=[IO.File]::ReadAllText($log)
 if ($receipt.clientExit -ne 0 -or -not $content.Contains($Marker) -or $content -match 'FIVE_FIXES_NATIVE_FAILED|PASSIVES_\w+_FAILED|(?m)^(ERROR|FATAL)') {throw "Native probe evidence failed: $Script; inspect $log"}
 $script:report.gates+=@{script=$Script;marker=$Marker;clientExit=$receipt.clientExit;log=$log}
 Write-Host "FIVE_FIXES_QA PASS $Marker"
}
try {
 foreach ($port in @(33308,7174,7175)) {if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {throw 'A required loopback test port is already occupied.'}}
 if (Get-CimInstance Win32_Process -Filter "Name='mariadbd.exe'" | Where-Object {$_.CommandLine -like "*$sourceDb*"}) {throw 'Original fixture database must be stopped for a consistent cold copy.'}
 if (Get-Process RookhavenClient -ErrorAction SilentlyContinue) {throw 'Close existing native clients before preserving the dedicated probe profile.'}
 foreach ($required in @($sourceDb,$sourceConfig,$sourceExe,(Join-Path $dbBin 'mariadbd.exe'),(Join-Path $package 'RookhavenClient.exe'))) {if (-not (Test-Path -LiteralPath $required)) {throw 'Required existing local QA dependency missing.'}}
 Assert-OwnedPath $runRoot (Join-Path $clientRoot 'out')
 New-Item -ItemType Directory -Path $runRoot,$runtime -Force | Out-Null
 $databaseBefore=Digest-Tree $sourceDb
 $configBefore=(Get-FileHash -LiteralPath $sourceConfig -Algorithm SHA256).Hash
 $profileBefore=if ($profileExisted) {Digest-Tree $profile} else {''}
 if ($profileExisted) {Copy-Item -LiteralPath $profile -Destination $profileBackup -Recurse}
 $profileCaptured=$true
 Copy-Item -LiteralPath $sourceDb -Destination $dbData -Recurse
 Copy-Item -LiteralPath (Join-Path $serverRoot 'data') -Destination $runtime -Recurse
 Copy-Item -LiteralPath $sourceConfig -Destination (Join-Path $runtime 'config.lua')
 foreach ($file in @('global.lua','schema.sql','key.pem')) {if (Test-Path -LiteralPath (Join-Path $serverRoot $file)) {Copy-Item -LiteralPath (Join-Path $serverRoot $file) -Destination $runtime}}
 Copy-Item -LiteralPath $sourceExe -Destination (Join-Path $runtime 'tfs.exe')
 Get-ChildItem -LiteralPath (Split-Path $sourceExe -Parent) -Filter '*.dll' | Copy-Item -Destination $runtime
 Copy-Item -LiteralPath (Join-Path $package 'checksum_expected.txt') -Destination (Join-Path $runtime 'data/checksum_expected.txt') -Force
 $config=[IO.File]::ReadAllText((Join-Path $runtime 'config.lua'))
 foreach ($expected in @('ip = "127.0.0.1"','bindOnlyGlobalAddress = true','loginProtocolPort = 7174','gameProtocolPort = 7175','mysqlHost = "127.0.0.1"','mysqlPort = 33308','mysqlDatabase = "rookhaven_passives_test"','serverName = "Rookhaven Local Passives Test"','passiveTestEnabled = true')) {if (-not $config.Contains($expected)) {throw 'Existing isolated fixture config does not match required scope.'}}
 $userMatch=[regex]::Match($config,'(?m)^mysqlUser\s*=\s*"([^"]+)"')
 $passwordMatch=[regex]::Match($config,'(?m)^mysqlPass\s*=\s*"([^"]+)"')
 if (-not $userMatch.Success -or -not $passwordMatch.Success) {throw 'Existing local test SQL credentials missing.'}
 $sqlUser=$userMatch.Groups[1].Value
 [Environment]::SetEnvironmentVariable('MYSQL_PWD',$passwordMatch.Groups[1].Value,'Process')
 Register-Xml 'data/XML/groups.xml' '</groups>' '<group id="7" name="five fixes normal combat admin" access="1" maxdepotitems="0" maxvipentries="200"><flags><flag isalwayspremium="1" /></flags></group>'
 foreach ($name in @('passiveqa.lua','passive_baseline.lua')) {Copy-Item -LiteralPath (Join-Path $serverRoot ('tools/passives-fixture/'+$name)) -Destination (Join-Path $runtime ('data/talkactions/scripts/'+$name))}
 Register-Xml 'data/talkactions/talkactions.xml' '</talkactions>' '<talkaction words="/passiveqa" separator=" " script="passiveqa.lua" /><talkaction words="/passivebaseline" separator=" " script="passive_baseline.lua" />'
 if ($AdditionalRegressionsOnly) {
  Copy-Item -LiteralPath (Join-Path $serverRoot 'tools/passives-fixture/passive_lifecycle.lua') -Destination (Join-Path $runtime 'data/talkactions/scripts/passive_lifecycle.lua')
  Register-Xml 'data/talkactions/talkactions.xml' '</talkactions>' '<talkaction words="/passivelifecycle" separator=" " script="passive_lifecycle.lua" />'
 }
 foreach ($dummy in @('passive_test_dummy.xml','passive_bleed_budget_dummy.xml','passive_bleed_immune_dummy.xml')) {Copy-Item -LiteralPath (Join-Path $serverRoot ('tools/passives-fixture/'+$dummy)) -Destination (Join-Path $runtime ('data/monster/monsters/'+$dummy))}
 Register-Xml 'data/monster/monsters.xml' '</monsters>' '<monster name="Passive Test Dummy" file="monsters/passive_test_dummy.xml" /><monster name="Passive Bleed Budget Dummy" file="monsters/passive_bleed_budget_dummy.xml" /><monster name="Passive Bleed Immune Dummy" file="monsters/passive_bleed_immune_dummy.xml" />'
 Copy-Item -LiteralPath (Join-Path $serverRoot 'tools/five-fixes-native-fixture.lua') -Destination (Join-Path $runtime 'data/scripts/five-fixes-native.lua')
 if ($AccessFixes) {Copy-Item -LiteralPath (Join-Path $serverRoot 'tools/access-fixes-native-fixture.lua') -Destination (Join-Path $runtime 'data/scripts/access-fixes-native.lua')}
 $ownedDb=Start-Process (Join-Path $dbBin 'mariadbd.exe') -ArgumentList '--no-defaults',"--datadir=$dbData",'--bind-address=127.0.0.1','--port=33308','--skip-name-resolve',"--pid-file=$dbData/five-fixes.pid",'--console' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot 'database-stdout.log') -RedirectStandardError (Join-Path $runRoot 'database-stderr.log')
 $report.databaseProcess=@{pid=$ownedDb.Id;path=(Join-Path $dbBin 'mariadbd.exe');datadir=$dbData}
 $deadline=(Get-Date).AddSeconds(25)
 do {
  $ownedDb.Refresh();if ($ownedDb.HasExited) {throw 'Owned cold-copy database exited; inspect saved logs.'}
  $listeners=@(Get-NetTCPConnection -LocalPort 33308 -State Listen -ErrorAction SilentlyContinue)
  if ($listeners.Count) {if (@($listeners|Where-Object {$_.OwningProcess -ne $ownedDb.Id -or $_.LocalAddress -ne '127.0.0.1'}).Count) {throw 'Database listener identity/address differs.'};break}
  if ((Get-Date)-gt $deadline) {throw 'Owned database startup timed out.'};Start-Sleep -Milliseconds 250
 }while($true)
 $identity=@(Sql 'SELECT id,name,group_id,account_id FROM players WHERE id=9001')
 if ($identity.Count -ne 1 -or $identity[0] -notmatch '^9001\tPassive Tester\t\d+\t9001$') {throw 'Owned disposable GUID9001 fixture identity differs.'}
 # Reset only the cloned, disposable GUID9001; the original inventory is untouched.
 Sql 'DELETE FROM player_items WHERE player_id=9001; DELETE FROM player_passives WHERE player_id=9001; UPDATE players SET group_id=7,health=735,healthmax=735,mana=390,manamax=390,conditions=NULL,posx=32097,posy=32219,posz=7,ps_mode=0,balance=0 WHERE id=9001;' | Out-Null
 Sql 'UPDATE accounts SET type=6 WHERE id=9001;' | Out-Null
 if ($AccessFixes) {
  # The disposable baseline has the parent table but no container-listing table.
  # Supply that existing store contract only in this owned database copy.
  Sql 'CREATE TABLE IF NOT EXISTS personal_store_container_items (item_code INT NOT NULL,itemid INT NOT NULL,count INT NOT NULL,attributes BLOB,INDEX (item_code)); DELETE FROM personal_store_container_items WHERE item_code IN (SELECT item_code FROM personal_store_items WHERE seller_guid=9001); DELETE FROM personal_store_items WHERE seller_guid=9001;' | Out-Null
 }
 Start-OwnedServer 'enabled'
 if ($AdditionalRegressionsOnly) {
  Probe 'passives-normal-guard.lua' 'PASSIVES_NORMAL_GUARD_OK' 125
  Probe 'passives-lifecycle.lua' 'PASSIVES_LIFECYCLE_OK' 125
  Probe 'passives-all-trees-contract.lua' 'PASSIVES_ALL_TREES_CONTRACT_OK' 125
 } else {
  Probe 'five-fixes-native.lua' 'FIVE_FIXES_NATIVE_OK' 85
  if ($AccessFixes) {Probe 'access-fixes-native.lua' 'ACCESS_FIXES_NATIVE_OK' 110}
 }
 if (-not $NativeOnly -and -not $AdditionalRegressionsOnly) {
  Probe 'passives-baseline.lua' 'PASSIVES_BASELINE_OK enabled=true' 125
  Probe 'passives-delayed.lua' 'PASSIVES_DELAYED_OK' 75
 }
 if (-not $NativeOnly -and -not $AdditionalRegressionsOnly -and -not $SkipFlagOffBaseline) {
  Stop-Owned $ownedServer (Join-Path $runtime 'tfs.exe');$ownedServer=$null
  [IO.File]::WriteAllText((Join-Path $runtime 'config.lua'),$config.Replace('passiveTestEnabled = true','passiveTestEnabled = false'),[Text.UTF8Encoding]::new($false))
  Start-OwnedServer 'disabled'
  Probe 'passives-baseline.lua' 'PASSIVES_BASELINE_OK enabled=false' 125
 }
 $report.status='PASS'
}catch {
 $report.status='FAILED';$report.error=$_.Exception.Message
 Write-Host 'FIVE_FIXES_QA FAILED; inspect the retained owned run directory.'
 throw
}finally {
 $cleanupErrors=@()
 try {Stop-Owned $ownedServer (Join-Path $runtime 'tfs.exe')}catch {$cleanupErrors+='Owned server stop: '+$_.Exception.Message}
 try {Stop-Owned $ownedDb (Join-Path $dbBin 'mariadbd.exe')}catch {$cleanupErrors+='Owned database stop: '+$_.Exception.Message}
 try {[Environment]::SetEnvironmentVariable('MYSQL_PWD',$mysqlPwdBefore,'Process')}catch {$cleanupErrors+='Process environment restore failed.'}
 try {
  if ($profileCaptured) {
   Assert-OwnedPath $profile $profileParent
   if (Test-Path -LiteralPath $profile) {Remove-Item -LiteralPath $profile -Recurse -Force}
   if ($profileExisted) {Copy-Item -LiteralPath $profileBackup -Destination $profile -Recurse}
   $report.probeProfileRestored=if ($profileExisted) {(Digest-Tree $profile)-ceq $profileBefore} else {-not (Test-Path -LiteralPath $profile)}
  }
 }catch {$cleanupErrors+='Dedicated probe profile restore: '+$_.Exception.Message}
 try {if (Test-Path variable:databaseBefore) {$report.originalDatabaseUnchanged=(Digest-Tree $sourceDb)-ceq $databaseBefore}}catch {$cleanupErrors+='Original database verification failed.'}
 try {if (Test-Path variable:configBefore) {$report.originalRuntimeConfigUnchanged=(Get-FileHash -LiteralPath $sourceConfig -Algorithm SHA256).Hash -ceq $configBefore}}catch {$cleanupErrors+='Original runtime config verification failed.'}
 try {
  $serverStopped=$true;$dbStopped=$true
  if ($ownedServer) {$ownedServer.Refresh();$serverStopped=$ownedServer.HasExited}
  if ($ownedDb) {$ownedDb.Refresh();$dbStopped=$ownedDb.HasExited}
  $report.ownedProcessesStopped=$serverStopped -and $dbStopped -and -not (Get-NetTCPConnection -LocalPort 33308,7174,7175 -State Listen -ErrorAction SilentlyContinue)
 }catch {$cleanupErrors+='Owned process/listener verification failed.'}
 if ($report.status -eq 'PASS' -and (-not $report.originalDatabaseUnchanged -or -not $report.originalRuntimeConfigUnchanged -or -not $report.probeProfileRestored -or -not $report.ownedProcessesStopped)) {$cleanupErrors+='A mandatory preservation or shutdown invariant failed.'}
 if ($cleanupErrors.Count) {$report.status='FAILED';$report.cleanupErrors=$cleanupErrors}
 if (Test-Path -LiteralPath $runRoot) {[IO.File]::WriteAllText((Join-Path $runRoot 'report.json'),($report|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))}
 Write-Host 'FIVE_FIXES_QA evidence:' $runRoot
 if ($cleanupErrors.Count) {throw 'Owned QA cleanup/preservation failed; inspect saved report.'}
}
