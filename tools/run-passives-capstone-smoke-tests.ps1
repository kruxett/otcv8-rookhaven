param()
$ErrorActionPreference='Stop'
$clientRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverExe=[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$logs=Join-Path $clientRoot 'out/passives-capstone-smoke-tests'
$runtimeConfig=[IO.File]::ReadAllText((Join-Path $clientRoot 'out/local-server/passives-runtime/config.lua'))
foreach($pattern in @('(?m)^ip = "127\.0\.0\.1"','(?m)^mysqlPort = 33308','(?m)^mysqlDatabase = "rookhaven_passives_test"','(?m)^passiveTestEnabled = true')){
 if($runtimeConfig -notmatch $pattern){throw 'Expected owned loopback runtime required.'}
}
$server=@(Get-Process tfs -ErrorAction Stop|Where-Object Path -eq $serverExe)
if($server.Count -ne 1){throw 'Exactly one owned server must already be running.'}
New-Item -ItemType Directory -Path $logs -Force|Out-Null
$cases=@{
 reaver=@('berserker','bloodletting','bloodguard')
 blademaster=@('duelist','riposte','bladestorm')
 earthshaker=@('aftershock','stoneguard','stonebond')
 marksman=@('deadeye','skirmisher','quarry')
 arcanist=@('conduit','resonance','spellweaver')
 lifekeeper=@('renewal','aegis','concord')
}
$samples=@()
$watch=[Diagnostics.Stopwatch]::StartNew()
Push-Location $clientRoot
try{
 foreach($tree in @('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper')){
  foreach($cap in $cases[$tree]){
   $server[0].Refresh()
   if($server[0].HasExited){throw 'Owned server exited during capstone smoke test.'}
   $before=$server[0].TotalProcessorTime.TotalSeconds
   & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script passives-capstones.lua -Tree $tree -Cap $cap -Success ('PASSIVES_CAPSTONE_OK '+$tree+' '+$cap) -TimeoutSeconds 195 *> (Join-Path $logs ($tree+'-'+$cap+'.log'))
   $server[0].Refresh()
   if($server[0].HasExited){throw 'Owned server exited during capstone smoke test.'}
   $samples+=[pscustomobject]@{tree=$tree;capstone=$cap;elapsedSeconds=[Math]::Round($watch.Elapsed.TotalSeconds,2);cpuSeconds=[Math]::Round($server[0].TotalProcessorTime.TotalSeconds-$before,3);privateBytes=$server[0].PrivateMemorySize64;workingSetBytes=$server[0].WorkingSet64}
   Write-Host ('PASSIVES_CAPSTONE_SMOKE_CASE_OK '+$tree+' '+$cap)
  }
 }
 $samples|ConvertTo-Json -Depth 4|Set-Content (Join-Path $logs 'server-samples.json') -Encoding utf8
 Write-Host ('PASSIVES_CAPSTONE_SMOKE_SUITE_OK cases=18 elapsed='+[Math]::Round($watch.Elapsed.TotalSeconds,1))
}finally{
 $samples|ConvertTo-Json -Depth 4|Set-Content (Join-Path $logs 'server-samples.json') -Encoding utf8
 Pop-Location
}
