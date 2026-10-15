param([ValidateSet('inventory','flow','store','lifecycle','wire','competition','all')][string]$Suite='inventory',
 [string]$ServerRoot='', [string]$ServerExecutable='', [string]$PackageDirectory='')
# All writes target an owned cold database copy, copied runtime, and probe profile.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$clientRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverRoot=if ($ServerRoot) {[IO.Path]::GetFullPath($ServerRoot)} else {[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven'))}
$localRoot=Join-Path $clientRoot 'out/local-server'
$sourceDb=Join-Path $localRoot 'passives-db'
$sourceConfig=Join-Path $localRoot 'passives-runtime/config.lua'
$dbBin=Join-Path $localRoot 'mariadb-11.4.9-winx64/bin'
$sourceExe=Join-Path $serverRoot 'build/server-validation/tfs.exe'
if ($ServerExecutable) {$sourceExe=[IO.Path]::GetFullPath($ServerExecutable)}
$package=Join-Path $clientRoot 'out/install/server-validation-QA'
if ($PackageDirectory) {$package=[IO.Path]::GetFullPath($PackageDirectory)}
$runRoot=Join-Path $clientRoot ('out/server-validation-native-qa/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$PID)
$runtime=Join-Path $runRoot 'runtime'
$dbData=Join-Path $runRoot 'database'
$profile=[IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Rookhaven Client/Rookhaven-LocalPassives-Probe'))
$profileParent=[IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Rookhaven Client'))
$profileBackup=Join-Path $runRoot 'profile-before'
$peerProfile=Join-Path $profileParent 'Rookhaven-LocalPassives-Probe-Peer'
$peerProfileBackup=Join-Path $runRoot 'peer-profile-before'
$peerProfileExisted=Test-Path -LiteralPath $peerProfile
$peerProfileCaptured=$false
$ownedPeer=$null
$peerExecutable=''
$ownedServer=$null
$ownedDb=$null
$ownedProxy=$null
$proxyStopFile=''
$proxyPython=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
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
function Read-SharedText([string]$Path) {
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
 $reader=[IO.StreamReader]::new($stream)
 try {return $reader.ReadToEnd()} finally {$reader.Dispose();$stream.Dispose()}
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
function Probe([string]$Script,[string]$Marker,[int]$Timeout,[string]$Cap='berserker',[string]$Preamble='') {
 Write-Host "SERVER_VALIDATION_QA running $Script"
 $probeSourceSha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$Script)) -Algorithm SHA256).Hash
 $log=Join-Path $runRoot ($Script.Replace('.lua','')+'.log')
 if ($Cap -ne 'berserker') {$log=Join-Path $runRoot ($Script.Replace('.lua','')+'-'+$Cap+'.log')}
 if ($Marker.EndsWith('enabled=false')) {$log=Join-Path $runRoot 'passives-baseline-disabled.log'}
 & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -PackageDirectory $package -Script $Script -Success $Marker -TimeoutSeconds $Timeout -Cap $Cap -ProbePreamble $Preamble -ExitReceiptPath ($log+'.exit.json') *> $log
 if ($LASTEXITCODE) {throw "Native probe failed: $Script; inspect $log"}
 $receipt=Get-Content -LiteralPath ($log+'.exit.json') -Raw | ConvertFrom-Json
 $content=[IO.File]::ReadAllText($log)
 if ($receipt.clientExit -ne 0 -or -not $content.Contains($Marker) -or $content -match 'SERVER_VALIDATION_\w+_FAILED|PASSIVES_\w+_FAILED|(?m)^(ERROR|FATAL)') {throw "Native probe evidence failed: $Script; inspect $log"}
 $script:report.gates+=@{script=$Script;marker=$Marker;clientExit=$receipt.clientExit;log=$log;probeSourceSha256=$probeSourceSha256;clientBinarySha256=(Get-FileHash -LiteralPath (Join-Path $package 'RookhavenClient.exe') -Algorithm SHA256).Hash;clientArchiveSha256=(Get-FileHash -LiteralPath (Join-Path $package 'data.zip') -Algorithm SHA256).Hash}
 Write-Host "SERVER_VALIDATION_QA PASS $Marker"
}
function Stop-OwnedProxy {
 if (-not $script:ownedProxy) {return}
 $script:ownedProxy.Refresh()
 if (-not $script:ownedProxy.HasExited) {
  Assert-OwnedPath $script:proxyStopFile $runRoot
  [IO.File]::WriteAllText($script:proxyStopFile,'stop',[Text.UTF8Encoding]::new($false))
  if (-not $script:ownedProxy.WaitForExit(10000)) {
   Stop-Owned $script:ownedProxy $proxyPython
   throw 'Owned latency proxy did not shut down after its stop signal.'
  }
 }
 if ($script:ownedProxy.ExitCode -ne 0) {throw 'Owned latency proxy exited unsuccessfully.'}
 $script:ownedProxy=$null
}
function Store-Competition {
 $scriptName='server-validation-store-competition.lua'
 $script:peerExecutable=Join-Path $clientRoot 'out/server-validation-store-competition-peer/RookhavenClient.exe'
 & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -PackageDirectory $package -Script $scriptName -Peer -Cap store_compete_peer -PrepareOnly | Out-Null
 $peerOut=Join-Path $runRoot 'competition-peer-stdout.log'
 $peerErr=Join-Path $runRoot 'competition-peer-stderr.log'
 $script:ownedPeer=Start-Process $peerExecutable -ArgumentList '--local-passives','--local-passives-peer','--test' -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $peerOut -RedirectStandardError $peerErr
 $null=$script:ownedPeer.Handle
 Probe $scriptName 'STORE_VALIDATION_COMPETITION_OK role=primary' 60 'store_compete_primary'
 if (-not $script:ownedPeer.WaitForExit(10000)) {throw 'Second real buyer did not finish.'}
 $peerText=[IO.File]::ReadAllText($peerOut)+[IO.File]::ReadAllText($peerErr)
 if ($script:ownedPeer.ExitCode -ne 0 -or -not $peerText.Contains('STORE_VALIDATION_COMPETITION_OK role=peer') -or $peerText -match '(?m)^(ERROR|FATAL)|STORE_VALIDATION_COMPETITION_FAILED') {throw 'Second real buyer failed; inspect competition-peer logs.'}
 $script:report.gates+=@{script=$scriptName;role='peer';clientExit=$script:ownedPeer.ExitCode;log=$peerOut}
 Write-Host 'SERVER_VALIDATION_QA PASS two real buyers / one stock'
}
function Flow-Calibrations {
 if (-not (Test-Path -LiteralPath $proxyPython)) {throw 'Bundled Python required for owned latency calibration.'}
 $script:report.latencyProfiles=@()
 foreach ($phase in @(@{name='flow_zero';rtt=0;jitter=0},@{name='flow_medium';rtt=150;jitter=20},@{name='flow_high';rtt=500;jitter=50})) {
  if (Get-NetTCPConnection -LocalPort 7176 -State Listen -ErrorAction SilentlyContinue) {throw 'Owned proxy port already occupied.'}
  $proxyReport=Join-Path $runRoot ($phase.name+'-wire-metrics.json')
  $proxyOutput=Join-Path $runRoot ($phase.name+'-proxy-stdout.log')
  $script:proxyStopFile=Join-Path $runRoot ($phase.name+'-proxy.stop')
  $proxyArguments=@(('"'+(Join-Path $PSScriptRoot 'tests/loopback-latency-proxy.py')+'"'),
   '--rtt-ms',$phase.rtt,'--jitter-ms',$phase.jitter,'--server-key',('"'+(Join-Path $runtime 'key.pem')+'"'),
   '--report',('"'+$proxyReport+'"'),'--stop-file',('"'+$script:proxyStopFile+'"'),'--duration','180')
  $script:ownedProxy=Start-Process $proxyPython -ArgumentList $proxyArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $proxyOutput -RedirectStandardError (Join-Path $runRoot ($phase.name+'-proxy-stderr.log'))
  $deadline=(Get-Date).AddSeconds(10)
  do {
   $script:ownedProxy.Refresh();if ($script:ownedProxy.HasExited) {throw 'Owned proxy exited before readiness.'}
   $listener=@(Get-NetTCPConnection -LocalPort 7176 -State Listen -ErrorAction SilentlyContinue)
   if ($listener.Count) {
    if (@($listener|Where-Object {$_.OwningProcess -ne $script:ownedProxy.Id -or $_.LocalAddress -ne '127.0.0.1'}).Count) {throw 'Proxy listener identity/address differs.'}
    if ((Test-Path -LiteralPath $proxyOutput) -and (Read-SharedText $proxyOutput).Contains('LOOPBACK_LATENCY_PROXY_READY')) {break}
   }
   if ((Get-Date)-gt $deadline) {throw 'Owned proxy readiness timed out.'}
   Start-Sleep -Milliseconds 100
  }while($true)
  Probe 'server-validation-flow.lua' 'SERVER_VALIDATION_FLOW_CLIENT_OK' 150 $phase.name ("SERVER_VALIDATION_PROXY=true; SERVER_VALIDATION_RTT="+$phase.rtt)
  $deadline=(Get-Date).AddSeconds(8)
  do {
   $metrics=Get-Content -LiteralPath $proxyReport -Raw | ConvertFrom-Json
   if ($metrics.connections -eq 3 -and $metrics.closed -eq 3) {break}
   if ((Get-Date)-gt $deadline) {throw 'Proxy did not observe all three native session closures.'}
   Start-Sleep -Milliseconds 100
  }while($true)
  Stop-OwnedProxy
  $metrics=Get-Content -LiteralPath $proxyReport -Raw | ConvertFrom-Json
  if (@($metrics.errors).Count -or $metrics.frames -eq 0) {throw 'Proxy capture/shape validation failed; inspect wire metrics.'}
  foreach ($opcode in @('64','82','96','A1','A2','A8','D3')) {
   if ($metrics.byOpcodeAction.PSObject.Properties.Name -notcontains $opcode) {throw "Expected native emitter absent from calibration: $opcode"}
  }
  $script:report.latencyProfiles+=@{name=$phase.name;rttMs=$phase.rtt;jitterMs=$phase.jitter;wireReport=$proxyReport;metrics=$metrics}
 }
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
 if ($Suite -in @('store','competition','all')) {
  $peerProfileBefore=if ($peerProfileExisted) {Digest-Tree $peerProfile} else {''}
  if ($peerProfileExisted) {Copy-Item -LiteralPath $peerProfile -Destination $peerProfileBackup -Recurse}
  $peerProfileCaptured=$true
 }
 Copy-Item -LiteralPath $sourceDb -Destination $dbData -Recurse
 Copy-Item -LiteralPath (Join-Path $serverRoot 'data') -Destination $runtime -Recurse
 Copy-Item -LiteralPath $sourceConfig -Destination (Join-Path $runtime 'config.lua')
 foreach ($file in @('global.lua','schema.sql','key.pem')) {if (Test-Path -LiteralPath (Join-Path $serverRoot $file)) {Copy-Item -LiteralPath (Join-Path $serverRoot $file) -Destination $runtime}}
 Copy-Item -LiteralPath $sourceExe -Destination (Join-Path $runtime 'tfs.exe')
 if (Test-Path -LiteralPath (Join-Path (Split-Path $sourceExe -Parent) 'tfs.pdb')) {Copy-Item -LiteralPath (Join-Path (Split-Path $sourceExe -Parent) 'tfs.pdb') -Destination $runtime}
 $report.serverBinarySha256=(Get-FileHash -LiteralPath $sourceExe -Algorithm SHA256).Hash
 $report.clientBinarySha256=(Get-FileHash -LiteralPath (Join-Path $package 'RookhavenClient.exe') -Algorithm SHA256).Hash
 $report.clientArchiveSha256=(Get-FileHash -LiteralPath (Join-Path $package 'data.zip') -Algorithm SHA256).Hash
 Get-ChildItem -LiteralPath (Split-Path $sourceExe -Parent) -Filter '*.dll' | Copy-Item -Destination $runtime
 Copy-Item -LiteralPath (Join-Path $package 'checksum_expected.txt') -Destination (Join-Path $runtime 'data/checksum_expected.txt') -Force
 $config=[IO.File]::ReadAllText((Join-Path $runtime 'config.lua'))
 foreach ($expected in @('ip = "127.0.0.1"','bindOnlyGlobalAddress = true','loginProtocolPort = 7174','gameProtocolPort = 7175','mysqlHost = "127.0.0.1"','mysqlPort = 33308','mysqlDatabase = "rookhaven_passives_test"','serverName = "Rookhaven Local Passives Test"','passiveTestEnabled = true')) {if (-not $config.Contains($expected)) {throw 'Existing isolated fixture config does not match required scope.'}}
 $userMatch=[regex]::Match($config,'(?m)^mysqlUser\s*=\s*"([^"]+)"')
 $passwordMatch=[regex]::Match($config,'(?m)^mysqlPass\s*=\s*"([^"]+)"')
 if (-not $userMatch.Success -or -not $passwordMatch.Success) {throw 'Existing local test SQL credentials missing.'}
 $sqlUser=$userMatch.Groups[1].Value
 [Environment]::SetEnvironmentVariable('MYSQL_PWD',$passwordMatch.Groups[1].Value,'Process')
 Register-Xml 'data/XML/groups.xml' '</groups>' '<group id="7" name="validation normal combat admin" access="1" maxdepotitems="0" maxvipentries="200"><flags><flag isalwayspremium="1" /></flags></group>'
 foreach ($fixture in @('inventory','flow','store')) {
  $source=Join-Path $serverRoot ('tools/server-validation-'+$fixture+'-fixture.lua')
  if (Test-Path -LiteralPath $source) {Copy-Item -LiteralPath $source -Destination (Join-Path $runtime ('data/scripts/server-validation-'+$fixture+'.lua'))}
 }
 if ($Suite -eq 'lifecycle' -or $Suite -eq 'all') {
  foreach ($name in @('passiveqa.lua','passive_lifecycle.lua')) {
   Copy-Item -LiteralPath (Join-Path $serverRoot ('tools/passives-fixture/'+$name)) -Destination (Join-Path $runtime ('data/talkactions/scripts/'+$name))
  }
  Register-Xml 'data/talkactions/talkactions.xml' '</talkactions>' '<talkaction words="/passiveqa" separator=" " script="passiveqa.lua" /><talkaction words="/passivelifecycle" separator=" " script="passive_lifecycle.lua" />'
 }
 $ownedDb=Start-Process (Join-Path $dbBin 'mariadbd.exe') -ArgumentList '--no-defaults',"--datadir=$dbData",'--bind-address=127.0.0.1','--port=33308','--skip-name-resolve',"--pid-file=$dbData/server-validation.pid",'--console' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot 'database-stdout.log') -RedirectStandardError (Join-Path $runRoot 'database-stderr.log')
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
 if ($Suite -in @('store','competition','all')) {
  $peer=@(Sql 'SELECT id,name,account_id FROM players WHERE id=9002')
  if ($peer.Count -ne 1 -or $peer[0] -notmatch '^9002\tPassive Peer\t9002$') {throw 'Owned disposable GUID9002 identity differs.'}
  Sql 'DELETE FROM player_items WHERE player_id=9002; DELETE FROM player_passives WHERE player_id=9002; UPDATE players SET group_id=1,health=735,healthmax=735,mana=390,manamax=390,conditions=NULL,posx=32098,posy=32219,posz=7,ps_mode=0,balance=0 WHERE id=9002;' | Out-Null
  if (@(Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='personal_store_container_items'")[0] -eq '1') {
   Sql 'DELETE FROM personal_store_container_items WHERE item_code IN (SELECT item_code FROM personal_store_items WHERE seller_guid IN (9001,9002));' | Out-Null
  }
  Sql 'DELETE FROM personal_store_items WHERE seller_guid IN (9001,9002);' | Out-Null
  if (@(Sql 'SELECT COUNT(*) FROM players WHERE id=90103')[0] -ne '0' -or @(Sql "SELECT COUNT(*) FROM accounts WHERE id=90103 OR name='storebuyer'")[0] -ne '0') {throw 'Competition fixture needs unused cloned account/player90103.'}
  Sql @'
INSERT INTO accounts (id,name,password,type,premium_ends_at,email,creation) VALUES (90103,'storebuyer',SHA1('storebuyer'),1,0,'',0);
CREATE TEMPORARY TABLE validation_buyer_seed LIKE players;
INSERT INTO validation_buyer_seed SELECT * FROM players WHERE id=9001;
UPDATE validation_buyer_seed SET id=90103,name='Store Buyer',account_id=90103,group_id=1,posx=32099,ps_mode=0,balance=0;
INSERT INTO players SELECT * FROM validation_buyer_seed;
DROP TEMPORARY TABLE validation_buyer_seed;
'@ | Out-Null
 }
 Start-OwnedServer 'enabled'
 if ($Suite -eq 'wire' -or $Suite -eq 'all') {
  $wireLog=Join-Path $runRoot 'wire-login-framing.log'
  $wireReport=Join-Path $runRoot 'wire-login-framing.json'
  & $proxyPython (Join-Path $PSScriptRoot 'tests/client-login-integrity.py') --runtime $runtime --output $wireReport --ingress *> $wireLog
  if ($LASTEXITCODE) {throw "Native login/framing failed; inspect $wireLog"}
  $report.gates+=@{script='client-login-integrity.py --ingress';log=$wireLog;report=$wireReport}
  Write-Host 'SERVER_VALIDATION_QA PASS native login/framing'
 }
 if ($Suite -eq 'inventory' -or $Suite -eq 'all') {Probe 'server-validation-inventory.lua' 'SERVER_VALIDATION_INVENTORY_CLIENT_OK' 100}
 if ($Suite -eq 'flow' -or $Suite -eq 'all') {Flow-Calibrations}
 if ($Suite -eq 'lifecycle' -or $Suite -eq 'all') {Probe 'passives-lifecycle.lua' 'PASSIVES_LIFECYCLE_OK' 150}
 if ($Suite -in @('store','all')) {
  Probe 'server-validation-store.lua' 'STORE_VALIDATION_NATIVE_OK' 150
  Probe 'server-validation-store.lua' 'STORE_VALIDATION_CRASH_READY' 60 'store_crash'
  if (-not $ownedServer.WaitForExit(10000) -or $ownedServer.ExitCode -ne 86) {throw 'Expected owned crash boundary exit86 did not occur.'}
  $ownedServer=$null
  Start-OwnedServer 'after-store-crash'
  Probe 'server-validation-store.lua' 'STORE_VALIDATION_CRASH_RECOVERY_OK' 60 'store_verify_crash'
 }
 if ($Suite -in @('store','competition','all')) {Store-Competition}
 $ownedServer.Refresh()
 if ($ownedServer.HasExited) {throw "Owned server exited unexpectedly after probes (exit=$($ownedServer.ExitCode))."}
 foreach ($diagnostics in Get-ChildItem -LiteralPath $runRoot -Filter '*-server-stderr.log') {
  if ((Read-SharedText $diagnostics.FullName) -match 'ERROR: AddressSanitizer|runtime error:') {throw 'Native sanitizer diagnostic; inspect saved server stderr.'}
 }
 $report.status='PASS'
}catch {
 $report.status='FAILED';$report.error=$_.Exception.Message
 Write-Host 'SERVER_VALIDATION_QA FAILED; inspect the retained owned run directory.'
 throw
}finally {
 $cleanupErrors=@()
 if ($ownedServer) {$ownedServer.Refresh();$report.serverExitBeforeCleanup=if ($ownedServer.HasExited) {$ownedServer.ExitCode} else {$null}}
 try {Stop-Owned $ownedPeer $peerExecutable}catch {$cleanupErrors+='Owned peer stop: '+$_.Exception.Message}
 try {Stop-OwnedProxy}catch {$cleanupErrors+='Owned proxy stop: '+$_.Exception.Message}
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
 try {
  if ($peerProfileCaptured) {
   Assert-OwnedPath $peerProfile $profileParent
   if (Test-Path -LiteralPath $peerProfile) {Remove-Item -LiteralPath $peerProfile -Recurse -Force}
   if ($peerProfileExisted) {Copy-Item -LiteralPath $peerProfileBackup -Destination $peerProfile -Recurse}
   $report.peerProfileRestored=if ($peerProfileExisted) {(Digest-Tree $peerProfile)-ceq $peerProfileBefore} else {-not (Test-Path -LiteralPath $peerProfile)}
   if (-not $report.peerProfileRestored) {$cleanupErrors+='Peer profile restoration failed.'}
  }
 }catch {$cleanupErrors+='Peer profile restore: '+$_.Exception.Message}
 try {if (Test-Path variable:databaseBefore) {$report.originalDatabaseUnchanged=(Digest-Tree $sourceDb)-ceq $databaseBefore}}catch {$cleanupErrors+='Original database verification failed.'}
 try {if (Test-Path variable:configBefore) {$report.originalRuntimeConfigUnchanged=(Get-FileHash -LiteralPath $sourceConfig -Algorithm SHA256).Hash -ceq $configBefore}}catch {$cleanupErrors+='Original runtime config verification failed.'}
 try {
  $serverStopped=$true;$dbStopped=$true
  if ($ownedServer) {$ownedServer.Refresh();$serverStopped=$ownedServer.HasExited}
  if ($ownedDb) {$ownedDb.Refresh();$dbStopped=$ownedDb.HasExited}
  $report.ownedProcessesStopped=$serverStopped -and $dbStopped -and -not (Get-NetTCPConnection -LocalPort 33308,7174,7175,7176 -State Listen -ErrorAction SilentlyContinue)
 }catch {$cleanupErrors+='Owned process/listener verification failed.'}
 if ($report.status -eq 'PASS' -and (-not $report.originalDatabaseUnchanged -or -not $report.originalRuntimeConfigUnchanged -or -not $report.probeProfileRestored -or -not $report.ownedProcessesStopped)) {$cleanupErrors+='A mandatory preservation or shutdown invariant failed.'}
 if ($cleanupErrors.Count) {$report.status='FAILED';$report.cleanupErrors=$cleanupErrors}
 if (Test-Path -LiteralPath $runRoot) {[IO.File]::WriteAllText((Join-Path $runRoot 'report.json'),($report|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))}
 Write-Host 'SERVER_VALIDATION_QA evidence:' $runRoot
 if ($cleanupErrors.Count) {throw 'Owned QA cleanup/preservation failed; inspect saved report.'}
}
