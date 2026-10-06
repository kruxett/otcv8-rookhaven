param()
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$dbData = [IO.Path]::GetFullPath((Join-Path $clientRoot 'out/local-server/passives-db'))
$logs = Join-Path $clientRoot 'out/passives-route-refund-tests'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
function Stop-OwnedServer {
 foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
  Stop-Process -Id $owned.Id
  if (-not $owned.WaitForExit(10000)) { throw 'Owned server did not exit.' }
 }
}
function Sql([string]$Query) {
 $rows = & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Query"
 if ($LASTEXITCODE) { throw 'Disposable route-refund query failed.' }
 return $rows
}
function Start-Owned([string]$Label) {
 & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs ($Label + '-start.log'))
}
function Probe([string]$Phase) {
 & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'passives-route-refund.lua' -Cap $Phase -Success ('PASSIVES_ROUTE_REFUND_OK ' + $Phase) -TimeoutSeconds 55 *> (Join-Path $logs ($Phase + '.log'))
}
function Assert-Ledger([string]$Ranks) {
 $actual = [string](Sql "SELECT CONCAT(class_id,'|',earned_points,'|',respec_count,'|',ranks) FROM player_passives WHERE player_id=9007")
 if ($actual -ne ('blademaster|16|2|' + $Ranks)) { throw 'Route-refund ledger differs from expected class/points/count/ranks.' }
 if ([string](Sql 'SELECT balance FROM players WHERE id=9007') -ne '12345') { throw 'Route refund charged or changed bank gold.' }
 foreach ($hex in $script:savedSpellHex) {
  if ([int](Sql ("SELECT COUNT(*) FROM player_spells WHERE player_id=9007 AND HEX(name)='" + $hex + "'")) -lt 1) { throw 'Route refund lost a saved learned spell.' }
 }
 if ([int](Sql "SELECT COUNT(*) FROM player_spells WHERE player_id=9007 AND name IN ('Focused Thrust','Flurry')") -ne 2) { throw 'Route refund changed starter entitlements.' }
}
$captured = $false
Push-Location $clientRoot
try {
 # Never infer isolation only from a filename: verify the connected DB and its datadir.
 $identity = [string](Sql "SELECT CONCAT(DATABASE(),'|',@@port,'|',@@datadir)")
 $parts = $identity.Split('|')
 if ($parts.Length -ne 3 -or $parts[0] -ne 'rookhaven_passives_test' -or $parts[1] -ne '33308') { throw 'Refusing unexpected DB/schema/port.' }
 # Batch SQL escapes backslashes; normalize those before resolving the actual directory.
 $actualData = [IO.Path]::GetFullPath($parts[2].Replace('\\','\')).TrimEnd('\','/')
 if ($actualData -ne $dbData.TrimEnd('\','/')) { throw 'Refusing DB outside owned passive datadir.' }
 Stop-OwnedServer
 if ([int](Sql "SELECT COUNT(*) FROM players WHERE id=9007 AND name='Starter Blademaster' AND account_id=9007 AND group_id=1 AND vocation=3 AND level=40 AND healthmax=735") -ne 1) { throw 'Expected ordinary disposable GUID9007 fixture required.' }
 $saved = [string](Sql "SELECT JSON_OBJECT('class_id',class_id,'earned_points',earned_points,'respec_count',respec_count,'ranks',ranks) FROM player_passives WHERE player_id=9007")
 if (-not $saved) { throw 'Run Blademaster starter suite first; no chosen permanent fixture.' }
 $original = $saved | ConvertFrom-Json
 if ($original.class_id -ne 'blademaster' -or $original.ranks -notmatch '^[0-5](,[0-5]){16}$|^[0-5](,[0-5]){28}$') { throw 'Unexpected fixture ledger.' }
 $balance = [string](Sql 'SELECT balance FROM players WHERE id=9007')
 if ($balance -notmatch '^\d+$') { throw 'Invalid fixture balance.' }
 $script:savedSpellHex = @(Sql 'SELECT HEX(name) FROM player_spells WHERE player_id=9007 ORDER BY name')
 foreach ($hex in $script:savedSpellHex) { if ($hex -notmatch '^([0-9A-F]{2})+$') { throw 'Invalid fixture spell snapshot.' } }
 [IO.File]::WriteAllText((Join-Path $logs 'original-fixture.json'), (@{guid=9007;ledger=$original;balance=$balance;spellHex=$script:savedSpellHex} | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
 $captured = $true
 $zero = ((1..29 | ForEach-Object { '0' }) -join ',')
 $suffix = ',' + ((1..12 | ForEach-Object { '0' }) -join ',')
 $oldG = '0,0,0,0,3,1,3,1,0,0,2,2,0,3,0,0,1'
 $oldC = '5,1,3,1,0,0,0,0,3,2,0,0,0,0,0,0,1'
 $normalized = '3,1,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0'
 $proof = Get-Content -LiteralPath (Join-Path $clientRoot 'out/passives-connected/catalog-proof.json') -Raw | ConvertFrom-Json
 $witness = @($proof.trees | Where-Object id -eq 'blademaster')[0].witnesses | Where-Object cap -eq 'cap_bladestorm' | Select-Object -First 1
 if (-not $witness -or $witness.spent -ne 16) { throw 'Run the independent connected catalog proof first.' }
 $keys = @('minor_precision','minor_critical','minor_power','minor_efficiency','minor_vitality','minor_resilience','minor_recovery','minor_focus','major_precision','major_pressure','major_guard','major_recovery','major_tactical','major_steady','cap_duelist','cap_riposte','cap_bladestorm','path_broad_stroke','path_deliberate_cut','path_blood_return','path_hewing_rhythm','path_battle_sustenance','path_iron_rhythm','mid_sweeping_form','mid_true_aim','mid_focused_edge','mid_measured_breath','mid_stout_heart','mid_braced_guard')
 $newRanks = ($keys | ForEach-Object { $value = $witness.ranks.PSObject.Properties[$_]; if ($value) { [string]$value.Value } else { '0' } }) -join ','
 Sql "UPDATE player_passives SET ranks='$oldG',earned_points=16,respec_count=2 WHERE player_id=9007 AND class_id='blademaster'; UPDATE players SET balance=12345 WHERE id=9007;" | Out-Null
 Start-Owned 'refund'; Probe 'refund'; Assert-Ledger $zero
 Stop-OwnedServer
 Sql "UPDATE player_passives SET ranks='$oldC' WHERE player_id=9007 AND class_id='blademaster'" | Out-Null
 Start-Owned 'refund_current'; Probe 'refund_current'; Assert-Ledger $zero
 Stop-OwnedServer
 Sql "UPDATE player_passives SET ranks='$normalized' WHERE player_id=9007 AND class_id='blademaster'" | Out-Null
 Start-Owned 'normalize'; Probe 'normalize'; Assert-Ledger ($normalized + $suffix)
 Stop-OwnedServer
 Sql "UPDATE player_passives SET ranks='$newRanks' WHERE player_id=9007 AND class_id='blademaster'" | Out-Null
 Start-Owned 'retain'; Probe 'retain'; Assert-Ledger $newRanks
 Stop-OwnedServer
 # Invalid 17-field data must fail both historical validators, never be refunded.
 $corrupt = '0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,1'
 Sql "UPDATE player_passives SET ranks='$corrupt' WHERE player_id=9007 AND class_id='blademaster'" | Out-Null
 Start-Owned 'corrupt'; Probe 'corrupt'; Assert-Ledger $corrupt
 Stop-OwnedServer
 # Even a previously legal legacy cap must NOT get legacy fallback in a 29-field row.
 $corrupt29 = $oldC + $suffix
 Sql "UPDATE player_passives SET ranks='$corrupt29' WHERE player_id=9007 AND class_id='blademaster'" | Out-Null
 Start-Owned 'corrupt_new'; Probe 'corrupt_new'; Assert-Ledger $corrupt29
 $serverLog = Get-Content -LiteralPath (Join-Path $clientRoot 'out/local-server/passives-runtime/server-stdout.log') -Raw
 if ($serverLog -notmatch '\[Passives\] Permanent restore failed for GUID 9007: Saved permanent class data is invalid\.') { throw 'Expected invalid new-ledger native rejection missing.' }
 if ([int](Sql 'SELECT COUNT(*) FROM players_online WHERE player_id=9007') -ne 0) { throw 'Corrupt fixture remains online.' }
 Write-Output 'PASSIVES_ROUTE_REFUND_SUITE_OK six migration cases: historical/current legacy cap refunds; valid17 normalization; valid29 retain; invalid17/29 rejection; idempotent relog; unchanged bank/class/points/count/spells.'
} finally {
 if ($captured) {
  Stop-OwnedServer
  $restore = "UPDATE player_passives SET class_id='blademaster',earned_points=$($original.earned_points),respec_count=$($original.respec_count),ranks='$($original.ranks)' WHERE player_id=9007; UPDATE players SET balance=$balance WHERE id=9007; DELETE FROM player_spells WHERE player_id=9007;"
  foreach ($hex in $script:savedSpellHex) { $restore += "INSERT INTO player_spells(player_id,name) VALUES(9007,CONVERT(UNHEX('$hex') USING utf8mb4));" }
  Sql $restore | Out-Null
  Start-Owned 'restored'
 }
 Pop-Location
}
