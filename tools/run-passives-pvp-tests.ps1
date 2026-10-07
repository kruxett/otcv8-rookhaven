param([switch]$PrepareClasses,[string]$PackageDirectory='')
$ErrorActionPreference='Stop'
$clientRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverExe=[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$localRoot=Join-Path $clientRoot 'out/local-server'
$dbCli=Join-Path $localRoot 'mariadb-11.4.9-winx64/bin/mariadb.exe'
$dbExe=[IO.Path]::GetFullPath((Join-Path $localRoot 'mariadb-11.4.9-winx64/bin/mariadbd.exe'))
$dbData=[IO.Path]::GetFullPath((Join-Path $localRoot 'passives-db'))
$runtimeConfig=Join-Path $localRoot 'passives-runtime/config.lua'
$probe=Join-Path $PSScriptRoot 'run-passives-probe.ps1'
$start=Join-Path $PSScriptRoot 'start-local-passives.ps1'
$logs=Join-Path $clientRoot ('out/passives-pvp-tests-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
$originalConfig=$null;$peer=$null;$peerExe=$null;$nativeProofComplete=$false
New-Item -ItemType Directory -Path $logs -Force|Out-Null
function Read-GrowingLog([string]$Path) {
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete))
 $reader=$null
 try {
  $reader=[IO.StreamReader]::new($stream,[Text.UTF8Encoding]::new($false),$true)
  return $reader.ReadToEnd()
 } finally {
  if($null-ne$reader){$reader.Dispose()}else{$stream.Dispose()}
 }
}
function Stop-OwnedServer {
 foreach($owned in @(Get-Process tfs -ErrorAction SilentlyContinue|Where-Object Path -eq $serverExe)){
  Stop-Process -Id $owned.Id
  if(-not $owned.WaitForExit(10000)){throw 'Owned loopback test server did not exit.'}
 }
}
function Sql([string]$Text){
 $rows=& $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Text"
 if($LASTEXITCODE){throw 'Isolated PvP fixture SQL failed.'}
 return $rows
}
function Assert-Isolated {
 foreach($file in @($serverExe,$dbCli,$dbExe,$runtimeConfig,$probe,$start)){if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw 'Required local fixture file missing.'}}
 $config=[IO.File]::ReadAllText($runtimeConfig)
 foreach($line in @('ip = "127.0.0.1"','bindOnlyGlobalAddress = true','loginProtocolPort = 7174','gameProtocolPort = 7175','mysqlHost = "127.0.0.1"','mysqlPort = 33308','mysqlDatabase = "rookhaven_passives_test"','serverName = "Rookhaven Local Passives Test"','passiveTestEnabled = true','passiveAdminEnabled = false')){
  if($config -notmatch ('(?m)^'+[regex]::Escape($line)+'\s*$')){throw 'Runtime is not the bounded isolated PvP fixture.'}
 }
 $listeners=@(Get-NetTCPConnection -LocalPort 33308 -State Listen -ErrorAction SilentlyContinue)
 if($listeners.Count-ne1-or$listeners[0].LocalAddress-ne'127.0.0.1'){throw 'Database must bind exclusively to loopback33308.'}
 $database=Get-CimInstance Win32_Process -Filter "ProcessId=$($listeners[0].OwningProcess)"
 if(-not$database-or$database.ExecutablePath-ne$dbExe-or$database.CommandLine-notlike"*$dbData*"){throw 'Database executable/data-directory identity mismatch.'}
 $identity=@(Sql @'
SELECT CONCAT(DATABASE(),'|',@@port,'|',COUNT(*)) FROM players p JOIN accounts a ON a.id=p.account_id JOIN player_passives t ON t.player_id=p.id WHERE p.group_id=1 AND a.type=1 AND p.vocation=3 AND p.level=40 AND p.healthmax=735 AND p.manamax=390 AND ((p.id=9006 AND p.name='Starter Reaver' AND a.id=9006 AND a.name='classreaver' AND t.class_id='reaver') OR(p.id=9007 AND p.name='Starter Blademaster' AND a.id=9007 AND a.name='classblademaster' AND t.class_id='blademaster'));
'@)
 if($identity.Count-ne1-or$identity[0]-ne'rookhaven_passives_test|33308|2'){throw 'Expected two ordinary disposable class fixtures missing; use -PrepareClasses.'}
}
function Stop-OwnedPeer {
 if(-not$peer){return};$peer.Refresh();if($peer.HasExited){return}
 $actual=Get-Process -Id $peer.Id -ErrorAction Stop
 if($actual.Path-ne$peerExe-or$actual.StartTime-ne$peer.StartTime){throw 'Peer cleanup process ownership mismatch.'}
 Stop-Process -Id $peer.Id
 if(-not$peer.WaitForExit(10000)){throw 'Owned peer did not stop.'}
}
Push-Location $clientRoot
try{
 $packageParameters=@{};if($PackageDirectory){$packageParameters.PackageDirectory=$PackageDirectory}
 if($PrepareClasses){
  & (Join-Path $PSScriptRoot 'run-class-spells-tests.ps1') -Trees reaver,blademaster @packageParameters *> (Join-Path $logs 'prepare-classes.log')
  if($LASTEXITCODE){throw 'Fresh ordinary class preparation failed.'}
 }
 Stop-OwnedServer
 & $start -Refresh *> (Join-Path $logs 'prepare-runtime.log')
 Assert-Isolated
 Stop-OwnedServer
 $originalConfig=[IO.File]::ReadAllBytes($runtimeConfig)
 [IO.File]::WriteAllBytes((Join-Path $logs 'config.original.lua'),$originalConfig)
 $text=[Text.UTF8Encoding]::new($false).GetString($originalConfig)
 if([regex]::Matches($text,'(?m)^worldType\s*=\s*"no-pvp"\s*$').Count-ne1){throw 'Expected exactly one original no-PvP runtime setting.'}
 $changed=[regex]::Replace($text,'(?m)^worldType\s*=\s*"no-pvp"\s*$','worldType = "pvp"')
 [IO.File]::WriteAllText($runtimeConfig,$changed,[Text.UTF8Encoding]::new($false))
 & $start *> (Join-Path $logs 'pvp-start.log')
 Assert-Isolated
 $prepared=@(& $probe -Script 'passives-pvp-peer.lua' -Peer -PrepareOnly @packageParameters)
 $peerPath=[IO.Path]::GetFullPath([string]$prepared[-1])
 if($peerPath-ne[IO.Path]::GetFullPath((Join-Path $clientRoot 'out/passives-pvp-peer-peer'))){throw 'Peer preparation returned unexpected path.'}
 $peerExe=Join-Path $peerPath 'RookhavenClient.exe'
 $peerOut=Join-Path $logs 'peer-stdout.log';$peerErr=Join-Path $logs 'peer-stderr.log'
 $peer=Start-Process $peerExe -ArgumentList '--local-passives','--local-passives-peer','--test' -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $peerOut -RedirectStandardError $peerErr
 $null=$peer.Handle
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 do{
  $peer.Refresh();$output=if(Test-Path -LiteralPath $peerOut){Read-GrowingLog $peerOut}else{''}
  if($output-match'PASSIVES_PVP_PEER_FAILED|(?m)^(ERROR|FATAL)'){throw 'Ordinary native peer failed.'}
  if($output.Contains('PASSIVES_PVP_PEER_READY')){break}
  if($peer.HasExited-or[DateTime]::UtcNow-gt$deadline){throw 'Ordinary native peer did not become ready.'}
  Start-Sleep -Milliseconds 200
 }while($true)
 Start-Sleep -Seconds 6 # Preserve existing account/game IP connection throttle.
 $receiptPath=Join-Path $logs 'source-exit.json';$mainLog=Join-Path $logs 'source.log';$started=[DateTime]::UtcNow
 & $probe -Script 'passives-pvp.lua' -Success 'PASSIVES_PVP_OK' -TimeoutSeconds 270 -ExitReceiptPath $receiptPath @packageParameters *> $mainLog
 if(-not(Test-Path -LiteralPath $receiptPath)-or(Get-Item -LiteralPath $receiptPath).LastWriteTimeUtc-lt$started){throw 'Missing fresh source native exit receipt.'}
 $receipt=[IO.File]::ReadAllText($receiptPath)|ConvertFrom-Json
 if($receipt.clientExit-ne0){throw 'Ordinary PvP source did not exit0.'}
 $main=[IO.File]::ReadAllText($mainLog)
 $required=@('PASSIVES_PVP_NATURAL_OK','PASSIVES_PVP_CAP_BUDGET_OK','PASSIVES_PVP_EXPIRY_OK','PASSIVES_PVP_CURE_OK','PASSIVES_PVP_PZ_TICK_OK','PASSIVES_PVP_PARTY_OK','PASSIVES_PVP_VICTIM_LOGOUT_OK','PASSIVES_PVP_OWNER_LOGOUT_OK','PASSIVES_PVP_DEATH_OK','PASSIVES_PVP_OK')
 $required+=@('no-wound','own-wound','foreign-legacy-finite','own-legacy-finite','legacy-infinite','party-normal-engine-policy')|ForEach-Object{'PASSIVES_PVP_REND_OK '+$_}
 $required+=@('secure','nopvp','pztarget','pzcaster','self')|ForEach-Object{'PASSIVES_PVP_FORBIDDEN_OK '+$_}
 foreach($marker in $required){if(-not$main.Contains($marker)){throw ('Missing actual native PvP evidence: '+$marker)}}
 if($main-match'PASSIVES_PVP_(FAILED|FIXTURE_FAILED)|(?m)^(ERROR|FATAL)'){throw 'Native PvP assertions failed.'}
 if(-not$peer.WaitForExit(10000)){throw 'Peer did not complete its normal final logout.'}
 $peer.Refresh();$peerLog=(Read-GrowingLog $peerOut)+(Read-GrowingLog $peerErr)
 if($peer.ExitCode-ne0-or$peerLog-match'PASSIVES_PVP_PEER_FAILED|(?m)^(ERROR|FATAL)'){throw 'Native peer failed or did not exit0.'}
 foreach($marker in @('PASSIVES_PVP_PEER_NATIVE_DEATH_OK','PASSIVES_PVP_PEER_SOURCE_LOGOUT_OK','PASSIVES_PVP_PEER_OK')){if(-not$peerLog.Contains($marker)){throw ('Missing peer native lifecycle evidence: '+$marker)}}
 $nativeProofComplete=$true
 [IO.File]::WriteAllText((Join-Path $logs 'result.json'),(@{passed=$false;nativeProofComplete=$true;sourceClientExit=$receipt.clientExit;peerClientExit=$peer.ExitCode;ordinaryPlayers=@(9006,9007);expectedMarkers=$required;naturalActivation=$true;syntheticPendingMarkerCases=@('cap','expiry','cure','lifecycle');sameObjectArenaRespawn='unmeasured';foreignSpecialOwnerSameTargetIsolation='unmeasured';configRestored=$false}|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
}finally{
 try { Stop-OwnedPeer } finally {
  try {
   if($null-ne$originalConfig){
    Stop-OwnedServer
    [IO.File]::WriteAllBytes($runtimeConfig,$originalConfig)
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($runtimeConfig))-ne[Convert]::ToBase64String($originalConfig)){throw 'Runtime PvP config exact-byte restoration failed.'}
    & $start *> (Join-Path $logs 'restored-start.log')
    $restoredListeners=@(Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 7174,7175 -State Listen -ErrorAction SilentlyContinue)
    if($restoredListeners.Count-ne2-or@($restoredListeners.OwningProcess|Select-Object -Unique).Count-ne1){throw 'Restored test-server listeners were not freshly owned by one process.'}
    $restoredServer=Get-Process -Id $restoredListeners[0].OwningProcess -ErrorAction Stop
    if($restoredServer.Path-ne$serverExe){throw 'Restored server listener executable identity mismatch.'}
    $resultPath=Join-Path $logs 'result.json'
    if(Test-Path -LiteralPath $resultPath){
     $result=[IO.File]::ReadAllText($resultPath)|ConvertFrom-Json
     $result.configRestored=$true
     $result|Add-Member -NotePropertyName restoredServerProcessId -NotePropertyValue $restoredServer.Id
     $result|Add-Member -NotePropertyName serverRestored -NotePropertyValue $true
     [IO.File]::WriteAllText($resultPath,($result|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
    }
   }
  } finally { Pop-Location }
 }
}
if(-not $nativeProofComplete){throw 'Native PvP proof did not complete.'}
$resultPath=Join-Path $logs 'result.json'
$result=[IO.File]::ReadAllText($resultPath)|ConvertFrom-Json
if(-not $result.configRestored){throw 'Native PvP proof completed without exact runtime restoration.'}
$result.passed=$true
[IO.File]::WriteAllText($resultPath,($result|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Host ('PASSIVES_PVP_SUITE_OK sourceExit=0 peerExit=0 configRestored=true logs='+$logs)
