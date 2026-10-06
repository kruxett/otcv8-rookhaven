param([string[]]$Trees=@('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'))
$ErrorActionPreference='Stop'
$clientRoot=Split-Path $PSScriptRoot -Parent
$serverExe=[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli=Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$dbData=[IO.Path]::GetFullPath((Join-Path $clientRoot 'out/local-server/passives-db'))
$passiveConfig=Join-Path $clientRoot 'out/local-server/passives-runtime/data/lib/passives/config.lua'
$logs=Join-Path $clientRoot 'out/passives-route-effects-tests'
$all=@('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper')
foreach($tree in $Trees){if($tree -notin $all){throw 'Unknown isolated class'}}
New-Item -ItemType Directory -Path $logs -Force | Out-Null
function Stop-Owned {
 foreach($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)){
  Stop-Process -Id $owned.Id
  if(-not $owned.WaitForExit(10000)){throw 'Owned passive server did not exit'}
 }
}
function Sql([string]$query){
 $rows=& $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$query"
 if($LASTEXITCODE){throw 'Isolated route-effect SQL failed'}
 return $rows
}
$captured=$false;$saved=@{};$configBytes=$null
Push-Location $clientRoot
try {
 $identity=([string](Sql "SELECT CONCAT(DATABASE(),'|',@@port,'|',@@datadir)")).Split('|')
 if($identity.Length -ne 3 -or $identity[0] -ne 'rookhaven_passives_test' -or $identity[1] -ne '33308' -or [IO.Path]::GetFullPath($identity[2].Replace('\\','\')).TrimEnd('\','/') -ne $dbData.TrimEnd('\','/')){throw 'Refusing unexpected route-effect DB/datadir'}
 Stop-Owned
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'source-start.log')
 Stop-Owned
 $configBytes=[IO.File]::ReadAllBytes($passiveConfig)
 foreach($tree in $Trees){
  $guid=9006+[array]::IndexOf($all,$tree)
  if([int](Sql "SELECT COUNT(*) FROM players WHERE id=$guid AND account_id=$guid AND group_id=1 AND vocation=3 AND level=40 AND healthmax=735") -ne 1){throw 'Expected ordinary L40 fixture required'}
  $row=[string](Sql "SELECT JSON_OBJECT('class_id',class_id,'earned_points',earned_points,'respec_count',respec_count,'ranks',ranks) FROM player_passives WHERE player_id=$guid")
  if(-not $row){throw 'Run all starter-spell tests before route effects'}
  $ledger=$row|ConvertFrom-Json
  if($ledger.class_id -ne $tree -or $ledger.ranks -notmatch '^[0-5](,[0-5]){28}$'){throw 'Expected valid chosen29-node fixture'}
  $saved[[string]$guid]=@{ledger=$ledger;bank=[string](Sql "SELECT balance FROM players WHERE id=$guid")}
 }
 [IO.File]::WriteAllText((Join-Path $logs 'original-ledgers.json'),($saved|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
 $captured=$true
 $zero=((1..29|ForEach-Object{'0'})-join ',')
 foreach($guid in $saved.Keys){Sql "UPDATE player_passives SET earned_points=16,respec_count=0,ranks='$zero' WHERE player_id=$guid; UPDATE players SET health=735,mana=390,conditions='',posx=32097,posy=32219,posz=7 WHERE id=$guid"|Out-Null}
 $config=[IO.File]::ReadAllText($passiveConfig)
 if(-not $config.Contains('respecCosts={0,1000,2000,4000,8000}')){throw 'Unexpected source respec costs'}
 [IO.File]::WriteAllText($passiveConfig,$config.Replace('respecCosts={0,1000,2000,4000,8000}','respecCosts={0}'),[Text.UTF8Encoding]::new($false))
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'free-respec-start.log')
 foreach($tree in $Trees){
  & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-route-effects.lua' -Tree $tree -Success ('PASSIVES_ROUTE_EFFECTS_OK '+$tree) -TimeoutSeconds 365 *> (Join-Path $logs ($tree+'.log'))
  Write-Output ('PASS native route effects '+$tree)
  Start-Sleep -Seconds 6
 }
 Write-Output ('PASSIVES_ROUTE_EFFECTS_SUITE_OK classes='+$Trees.Count+' newNodes='+($Trees.Count*12)+' shippedEffectValues=true temporaryFreeFixtureRespecOnly=true')
} finally {
 Stop-Owned
 if($configBytes){[IO.File]::WriteAllBytes($passiveConfig,$configBytes)}
 if($captured){foreach($guid in $saved.Keys){$old=$saved[$guid];$ledger=$old.ledger;Sql "UPDATE player_passives SET class_id='$($ledger.class_id)',earned_points=$($ledger.earned_points),respec_count=$($ledger.respec_count),ranks='$($ledger.ranks)' WHERE player_id=$guid; UPDATE players SET balance=$($old.bank),health=735,mana=390,conditions='' WHERE id=$guid"|Out-Null}}
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'restored-start.log')
 Pop-Location
}
