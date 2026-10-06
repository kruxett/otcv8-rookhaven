param([ValidateRange(10,20)][int]$ObservationSeconds=15)
# Negative startup gates only. Run after all client probes have exited: this stops
# the owned local TFS and restores its exact runtime files before restarting it.
# No source game data, direct SQL, builds, or production processes are changed.
# Restoring through the normal start helper retains its existing idempotent local fixture setup.
$ErrorActionPreference='Stop'
$clientRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$runtime=[IO.Path]::GetFullPath((Join-Path $clientRoot 'out/local-server/passives-runtime'))
$serverExe=[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$configPath=Join-Path $runtime 'config.lua'
$balancePath=Join-Path $runtime 'data/lib/class_spells/config.lua'
$xmlPath=Join-Path $runtime 'data/spells/spells.xml'
$startScript=Join-Path $PSScriptRoot 'start-local-passives.ps1'
$logRoot=Join-Path $clientRoot ('out/class-spells-startup/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$ports=@(7174,7175)
$originals=@{}
$utf8=[Text.UTF8Encoding]::new($false)
$didStop=$false
function Owned-Servers {
 @(Get-Process -Name tfs -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $serverExe })
}
function Listeners {
 @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort })
}
function Stop-OwnedServer {
 foreach($process in @(Owned-Servers)) {
  Stop-Process -Id $process.Id -ErrorAction Stop
  if(-not $process.WaitForExit(10000)){throw 'Owned local TFS did not exit within ten seconds.'}
 }
 $deadline=[DateTime]::UtcNow.AddSeconds(3)
 while(@(Listeners).Count -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
 if(@(Listeners).Count){throw 'Test ports remain occupied after stopping the owned TFS; refusing to continue.'}
}
function Restore-ExactFiles {
 foreach($path in $originals.Keys){[IO.File]::WriteAllBytes($path,$originals[$path])}
}
function Read-Log([string]$path) {
 if(-not (Test-Path -LiteralPath $path)){return ''}
 try {return (Get-Content -LiteralPath $path -Raw -ErrorAction Stop)}catch [IO.IOException]{return ''}
}
function Run-BadStartup([string]$case,[string]$causePattern) {
 $outPath=Join-Path $logRoot ($case+'-stdout.log')
 $errPath=Join-Path $logRoot ($case+'-stderr.log')
 $process=Start-Process -FilePath $serverExe -ArgumentList '--config=config.lua' -WorkingDirectory $runtime -WindowStyle Hidden -RedirectStandardOutput $outPath -RedirectStandardError $errPath -PassThru
 $deadline=[DateTime]::UtcNow.AddSeconds($ObservationSeconds)
 $observedFatal=$false
 try {
  while([DateTime]::UtcNow -lt $deadline) {
   if(@(Listeners).Count){throw "Bad startup '$case' reached a test listening port."}
   $text=(Read-Log $outPath)+"`n"+(Read-Log $errPath)
   if($text -match 'Invalid permanent class starter configuration:' -and $text -match $causePattern){$observedFatal=$true}
   $process.Refresh()
   if($process.HasExited){break}
   Start-Sleep -Milliseconds 150
  }
  # startupErrorMessage can wait for getchar on Windows. Being alive is fine only
  # with the exact fatal/cause evidence and no listening ports throughout the window.
  if(@(Listeners).Count){throw "Bad startup '$case' opened a test port."}
  $text=(Read-Log $outPath)+"`n"+(Read-Log $errPath)
  if($text -match 'Invalid permanent class starter configuration:' -and $text -match $causePattern){$observedFatal=$true}
  if(-not $observedFatal){throw "Bad startup '$case' did not produce the expected fatal/cause evidence. See $outPath and $errPath."}
  Write-Host "PASS bad startup ${case}: exact fatal logged; ports 7174/7175 remained closed."
 } finally {
  $process.Refresh()
  if(-not $process.HasExited){Stop-Process -Id $process.Id -ErrorAction Stop;if(-not $process.WaitForExit(10000)){throw "Could not stop failed startup '$case'."}}
 }
}
foreach($path in @($serverExe,$configPath,$balancePath,$xmlPath,$startScript)){
 if(-not (Test-Path -LiteralPath $path)){throw "Missing local startup-test dependency: $path"}
}
# Resolve and verify all writable targets before mutation; only the three explicitly
# named files under this owned runtime may be temporarily changed.
foreach($path in @($configPath,$balancePath,$xmlPath)){
 $absolute=[IO.Path]::GetFullPath($path)
 if(-not $absolute.StartsWith($runtime+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Startup-test target escapes the owned runtime.'}
 $originals[$path]=[IO.File]::ReadAllBytes($path)
}
$config=[IO.File]::ReadAllText($configPath)
foreach($required in @('(?m)^ip\s*=\s*"127\.0\.0\.1"\s*$','(?m)^bindOnlyGlobalAddress\s*=\s*true\s*$','(?m)^serverName\s*=\s*"Rookhaven Local Passives Test"\s*$','(?m)^passiveTestEnabled\s*=\s*true\s*$','(?m)^loginProtocolPort\s*=\s*7174\s*$','(?m)^gameProtocolPort\s*=\s*7175\s*$','(?m)^mysqlDatabase\s*=\s*"rookhaven_passives_test"\s*$','(?m)^mysqlPort\s*=\s*33308\s*$')){
 if($config -notmatch $required){throw 'Unexpected local runtime configuration; refusing startup mutations.'}
}
$ownedIds=@(Owned-Servers | ForEach-Object Id)
foreach($listener in @(Listeners)){if($ownedIds -notcontains $listener.OwningProcess){throw 'A test port belongs to another process; refusing to stop or replace it.'}}
if(-not (Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 33308 -State Listen -ErrorAction SilentlyContinue)){throw 'The existing isolated database must be running before this test; this helper does not provision it.'}
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
try {
 $didStop=$true
 Stop-OwnedServer
 Restore-ExactFiles
 $balance=[IO.File]::ReadAllText($balancePath)
 $taskManaMatches=[regex]::Matches($balance,"name='Cleaving Arc'[^\r\n]*?mana=(?<mana>\d+),")
 if($taskManaMatches.Count -ne 1 -or [int]$taskManaMatches[0].Groups['mana'].Value -le 0){throw 'Expected exactly one positive configured Cleaving Arc mana definition.'}
 $invalidManaDefinition=[regex]::Replace($taskManaMatches[0].Value,'mana=\d+,','mana=0,')
 $balance=$balance.Remove($taskManaMatches[0].Index,$taskManaMatches[0].Length).Insert($taskManaMatches[0].Index,$invalidManaDefinition)
 [IO.File]::WriteAllText($balancePath,$balance,$utf8)
 Run-BadStartup 'invalid-mana' 'Invalid starter tuning: Cleaving Arc\.mana'
 Restore-ExactFiles
 $xml=[IO.File]::ReadAllText($xmlPath)
 if(([regex]::Matches($xml,'script="class_spells/cleaving_arc.lua"')).Count -ne 1){throw 'Expected one Cleaving Arc wrapper registration.'}
 $xml=$xml.Replace('script="class_spells/cleaving_arc.lua"','script="class_spells/does_not_exist_startup_gate.lua"')
 [IO.File]::WriteAllText($xmlPath,$xml,$utf8)
 Run-BadStartup 'missing-wrapper' 'Permanent class starter must be registered exactly once: Cleaving Arc'
} finally {
 # No -Refresh: preserve every original byte, including any local balance that
 # preceded this helper, rather than replacing it from source defaults.
 $taskStopError=$null
 if($didStop){try {Stop-OwnedServer}catch {$taskStopError=$_}}
 Restore-ExactFiles
 foreach($path in $originals.Keys){
  if([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ne [Convert]::ToBase64String($originals[$path])){throw "Exact runtime restoration failed: $path"}
 }
 if($taskStopError){throw $taskStopError}
 if($didStop){
  & $startScript *> (Join-Path $logRoot 'restored-start.log')
  if($LASTEXITCODE){throw 'Owned runtime restart failed after exact file restoration.'}
  $deadline=[DateTime]::UtcNow.AddSeconds(25)
  do {
   $listeners=@(Listeners)
   $ready=($listeners.LocalPort -contains 7174) -and ($listeners.LocalPort -contains 7175)
   if($ready){break}
   if([DateTime]::UtcNow -gt $deadline){throw 'Restored server did not return both test listening ports.'}
   Start-Sleep -Milliseconds 150
  }while($true)
 }
}
Write-Host "CLASS_SPELL_STARTUP_OK exact-files-restored ports=7174,7175 logs=$logRoot"
