param()
$ErrorActionPreference='Stop'
$clientRoot=Split-Path $PSScriptRoot -Parent
$serverExe=[IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$runtime=Join-Path $clientRoot 'out/local-server/passives-runtime'
$cfgPath=Join-Path $runtime 'data/lib/passives/config.lua'
$logs=Join-Path $clientRoot 'out/passives-middle-crit-tests'
function Stop-Owned {foreach($p in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)){Stop-Process -Id $p.Id;if(-not $p.WaitForExit(10000)){throw 'Owned test server did not stop'}}}
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$bytes=$null
Push-Location $clientRoot
try {
 $runtimeConfig=[IO.File]::ReadAllText((Join-Path $runtime 'config.lua'))
 foreach($pattern in @('(?m)^ip = "127\.0\.0\.1"','(?m)^mysqlPort = 33308','(?m)^mysqlDatabase = "rookhaven_passives_test"','(?m)^passiveTestEnabled = true')){if($runtimeConfig -notmatch $pattern){throw 'Expected loopback fixture required'}}
 Stop-Owned
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'source-start.log')
 Stop-Owned
 $bytes=[IO.File]::ReadAllBytes($cfgPath)
 $source=[IO.File]::ReadAllText($cfgPath)
 foreach($literal in @('minorPrecisionBps=50','majorPrecisionBps=100','midPrecisionBps=20')){if(-not $source.Contains($literal)){throw 'Unexpected shipped chance configuration'}}
 $test=$source.Replace('minorPrecisionBps=50','minorPrecisionBps=0').Replace('majorPrecisionBps=100','majorPrecisionBps=0').Replace('midPrecisionBps=20','midPrecisionBps=10000')
 [IO.File]::WriteAllText($cfgPath,$test,[Text.UTF8Encoding]::new($false))
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'deterministic-start.log')
 & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script passives-middle-crit.lua -Success PASSIVES_MIDDLE_CRIT_OK -TimeoutSeconds 90 *> (Join-Path $logs 'native.log')
 Write-Output 'PASSIVES_MIDDLE_CRIT_SUITE_OK temporary100percentNewMinorOnly=true shipped20bpsUntouched=true'
} finally {
 Stop-Owned
 if($bytes){[IO.File]::WriteAllBytes($cfgPath,$bytes)}
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'restored-start.log')
 if($bytes -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($cfgPath)) -ne [Convert]::ToBase64String($bytes)){throw 'Source passive configuration did not restore exactly'}
 Pop-Location
}
