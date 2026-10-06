param()
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$runtime = [IO.Path]::GetFullPath((Join-Path $clientRoot 'out/local-server/passives-runtime'))
$itemsPath = Join-Path $runtime 'data/items/items.xml'
$logs = Join-Path $clientRoot 'out/passives-finite-field-tests'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
function Stop-OwnedServer {
 foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
  Stop-Process -Id $owned.Id
  if (-not $owned.WaitForExit(10000)) { throw 'Owned server did not exit.' }
 }
}
$original = $null
Push-Location $clientRoot
try {
 # Source-clean disposable runtime includes the newest fixture; its existing
 # startup helper fences loopback ports7174/7175 and DB33308.
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'prepare.log')
 Stop-OwnedServer
 $config = [IO.File]::ReadAllText((Join-Path $runtime 'config.lua'))
 if ($config -notmatch 'mysqlPort\s*=\s*33308\b' -or $config -notmatch 'mysqlDatabase\s*=\s*"rookhaven_passives_test"' -or $config -notmatch 'ip\s*=\s*"127\.0\.0\.1"') { throw 'Refusing non-isolated runtime.' }
 $original = [IO.File]::ReadAllBytes($itemsPath)
 [IO.File]::WriteAllBytes((Join-Path $logs 'items.original.xml'),$original)
 $text = [IO.File]::ReadAllText($itemsPath)
 $regex = [regex]::new('<item\s+id="1494"[^>]*>.*?</item>', [Text.RegularExpressions.RegexOptions]::Singleline)
 $match = $regex.Match($text)
 if (-not $match.Success -or -not $match.Value.Contains('<attribute key="field" value="fire" />')) { throw 'Expected empty diagnostic-capable1494 field missing.' }
 $replacement = $match.Value.Replace('<attribute key="field" value="fire" />','<attribute key="field" value="physical" />')
 $changed = $text.Substring(0,$match.Index) + $replacement + $text.Substring($match.Index+$match.Length)
 [IO.File]::WriteAllText($itemsPath,$changed,[Text.UTF8Encoding]::new($false))
 # No -Refresh here: restarting preserves the deliberately temporary runtime XML.
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'diagnostic-start.log')
 & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-finite-field.lua' -Success 'PASSIVES_FINITE_FIELD_OK' -TimeoutSeconds 40 *> (Join-Path $logs 'field.log')
 Write-Output 'PASSIVES_FINITE_FIELD_SUITE_OK finite and legacy real-MagicField behavior.'
} finally {
 if ($null -ne $original) {
  Stop-OwnedServer
  [IO.File]::WriteAllBytes($itemsPath,$original)
  $restored = [IO.File]::ReadAllBytes($itemsPath)
  if ([Convert]::ToBase64String($restored) -ne [Convert]::ToBase64String($original)) { throw 'Runtime field XML exact-byte restoration failed.' }
  & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'restored-start.log')
 }
 Pop-Location
}
