param([switch]$ResumeFailedStartup,[switch]$FinalAttempt)
# Run only after the root orchestrator freezes/builds the server and stops its
# ordinary local fixture server. This helper NEVER uses a deployed database.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($ResumeFailedStartup -and $FinalAttempt) { throw 'A final independent proof cannot resume the retained first attempt.' }
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverRoot = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven'))
$localRoot = [IO.Path]::GetFullPath((Join-Path $clientRoot 'out/local-server'))
$proofDirectory = if ($FinalAttempt) { 'out/passives-dev-database-final' } else { 'out/passives-dev-database' }
$runtimeDirectory = if ($FinalAttempt) { 'passives-db-upgrade-final-runtime' } else { 'passives-db-upgrade-runtime' }
$proofRoot = [IO.Path]::GetFullPath((Join-Path $clientRoot $proofDirectory))
$runtime = [IO.Path]::GetFullPath((Join-Path $localRoot $runtimeDirectory))
$expectedData = [IO.Path]::GetFullPath((Join-Path $localRoot 'passives-db'))
$dbBin = Join-Path $localRoot 'mariadb-11.4.9-winx64/bin'
$dbCli = Join-Path $dbBin 'mariadb.exe'
$dumpCli = Join-Path $dbBin 'mariadb-dump.exe'
$sourceExe = [IO.Path]::GetFullPath((Join-Path $serverRoot 'build/local-passives/tfs.exe'))
$proofExe = [IO.Path]::GetFullPath((Join-Path $runtime 'tfs.exe'))
$sourceDb = 'rookhaven_passives_test'
$upgradeDb = if ($FinalAttempt) { 'rookhaven_passives_upgrade_final' } else { 'rookhaven_passives_upgrade_test' }
$restoreDb = if ($FinalAttempt) { 'rookhaven_passives_restore_final' } else { 'rookhaven_passives_restore_test' }
if (($upgradeDb + '|' + $restoreDb) -cnotin @('rookhaven_passives_upgrade_test|rookhaven_passives_restore_test','rookhaven_passives_upgrade_final|rookhaven_passives_restore_final')) { throw 'Unknown proof clone identities.' }
$dbArgs = @('--no-defaults', '--host=127.0.0.1', '--port=33308', '--user=root', '--password=LocalPassiveFixtureOnly')
$controlStatements = @(
    ('CREATE DATABASE `' + $upgradeDb + '` CHARACTER SET utf8mb4'),
    ("GRANT ALL PRIVILEGES ON ``$upgradeDb``.* TO 'rooktest'@'127.0.0.1'"),
    ('CREATE DATABASE `' + $restoreDb + '` CHARACTER SET utf8mb4')
)
$ownedProcess = $null
$writeReport = $false
$stage = 'preflight'
$report = [ordered]@{ status='RUNNING'; sourceDatabase=$sourceDb; upgradeDatabase=$upgradeDb; restoreDatabase=$restoreDb; datadir=$expectedData; scope='Disposable DB33308 only; automatic native server migration and complete pre-upgrade dump/restore rehearsal'; stages=@() }
function Stage([string]$Name) {
    $script:stage = $Name
    $script:report.stages += $Name
    Write-Host "PASSIVES_DEV_DATABASE stage=$Name"
}
function Sql([ValidateSet('SourceRead','Upgrade','Restore','CloneControl')][string]$Role, [string]$Query) {
    $database = switch ($Role) {
        'SourceRead' { $script:sourceDb }
        'Upgrade' { $script:upgradeDb }
        'Restore' { $script:restoreDb }
        'CloneControl' { '' }
    }
    if ($Role -eq 'SourceRead' -and ($Query -notmatch '^\s*(SELECT|SHOW|CHECKSUM)\b' -or $Query.Contains(';'))) { throw 'Source database is strictly read-only in this proof.' }
    if ($Role -eq 'CloneControl' -and $Query -cnotin $script:controlStatements) { throw 'Only the three exact proof-clone control statements are authorized.' }
    if ($Role -in @('Upgrade','Restore') -and $Query -match '(?i)\b(?:CREATE|DROP|ALTER)\s+DATABASE\b|\bUSE\s+|\bGRANT\s+') { throw 'Clone statements cannot change database scope or grants.' }
    if ($Role -in @('Upgrade','Restore') -and $Query -match '(?i)`?rookhaven_passives_test`?\s*\.') { throw 'Clone SQL must not refer to the source database.' }
    $argsForQuery = $script:dbArgs + @('--batch','--skip-column-names')
    if ($database) { $argsForQuery += "--database=$database" }
    $output = @(& $script:dbCli @argsForQuery "--execute=$Query")
    if ($LASTEXITCODE) { throw "Proof SQL failed (role=$Role, stage=$script:stage)." }
    return $output
}
function Scalar([ValidateSet('SourceRead','Upgrade','Restore','CloneControl')][string]$Role,[string]$Query) {
    $rows = @(Sql $Role $Query)
    if ($rows.Count -ne 1) { throw "Expected one row (role=$Role, stage=$script:stage)." }
    return [string]$rows[0]
}
function Normalize-Path([string]$Path) { return [IO.Path]::GetFullPath($Path.Replace('/','\')).TrimEnd('\') }
function Table-Checksums([ValidateSet('SourceRead','Upgrade','Restore')][string]$Role) {
    $database = switch ($Role) { 'SourceRead' {$script:sourceDb} 'Upgrade' {$script:upgradeDb} 'Restore' {$script:restoreDb} }
    $tables = @(Sql $Role "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$database' AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME")
    if (-not $tables.Count) { throw "No base tables in proof database $database." }
    $sums = [ordered]@{}
    foreach ($table in $tables) {
        if ($table -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw 'Unexpected table identifier; refusing interpolated SQL.' }
        $row = Scalar $Role "CHECKSUM TABLE ``$table`` EXTENDED"
        $parts = $row -split "`t"
        if ($parts.Count -ne 2 -or $parts[1] -notmatch '^\d+$') { throw "No measured CHECKSUM TABLE result for $table." }
        $sums[[string]$table] = [string]$parts[1]
    }
    return $sums
}
function Assert-Checksums($Before,$After,[string[]]$Exceptions=@(),[string[]]$Added=@()) {
    $beforeKeys = @($Before.Keys | Where-Object { $_ -cnotin $Exceptions } | Sort-Object)
    $afterKeys = @($After.Keys | Where-Object { $_ -cnotin $Exceptions -and $_ -cnotin $Added } | Sort-Object)
    if (($beforeKeys -join '|') -cne ($afterKeys -join '|')) { throw 'Ordinary base-table set changed.' }
    foreach ($table in $beforeKeys) { if ([string]$Before[$table] -cne [string]$After[$table]) { throw "Ordinary table checksum changed: $table." } }
    foreach ($table in $Added) { if (-not $After.Contains($table)) { throw "Expected added proof table missing: $table." } }
}
function Dump([ValidateSet('SourceRead','Upgrade')][string]$Role,[string]$Path) {
    $database = if ($Role -eq 'SourceRead') {$script:sourceDb} else {$script:upgradeDb}
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($script:proofRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Dump path escaped the owned ignored proof directory.' }
    & $script:dumpCli @script:dbArgs --single-transaction --skip-lock-tables --routines --events --triggers --hex-blob --skip-comments "--result-file=$fullPath" $database
    if ($LASTEXITCODE) { throw "Disposable database dump failed at $script:stage." }
    if ((Get-Item -LiteralPath $fullPath).Length -le 0) { throw 'Empty proof dump.' }
    # Dumps without --databases must not select another schema during import.
    $dumpText = [IO.File]::ReadAllText($fullPath)
    if ($dumpText -match '(?im)^\s*(?:CREATE|DROP|ALTER)\s+DATABASE\b|^\s*USE\s+' -or $dumpText -match '(?i)`?rookhaven_passives_test`?\s*\.') { throw 'Generated proof dump crosses the database boundary.' }
}
function Import-Dump([ValidateSet('Upgrade','Restore')][string]$Role,[string]$Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($script:proofRoot + '\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($fullPath) -cnotin @('source-clone.sql','pre-upgrade.sql')) { throw 'Unrecognized import artifact.' }
    if ($fullPath.Contains(' ') -or $fullPath.Contains(';') -or $fullPath.Contains("'")) { throw 'This fixed local proof requires a simple SOURCE path.' }
    Sql $Role ('SOURCE ' + $fullPath.Replace('\','/')) | Out-Null
}
function Stop-ProofServer {
    if (-not $script:ownedProcess) { return }
    $script:ownedProcess.Refresh()
    if (-not $script:ownedProcess.HasExited) {
        $actual = Get-Process -Id $script:ownedProcess.Id -ErrorAction Stop
        if (-not [string]::Equals($actual.Path,$script:proofExe,[StringComparison]::OrdinalIgnoreCase)) { throw 'Proof process identity changed; refusing to stop it.' }
        Stop-Process -Id $actual.Id
        if (-not $script:ownedProcess.WaitForExit(10000)) { throw 'Proof server did not stop.' }
    }
    $script:ownedProcess = $null
}
function Start-ProofServer([string]$Run) {
    foreach ($port in @(7176,7177)) { if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw "Another process owns proof port $port." } }
    $stdout = Join-Path $script:proofRoot "$Run-server-stdout.log"
    $stderr = Join-Path $script:proofRoot "$Run-server-stderr.log"
    $script:ownedProcess = Start-Process -FilePath $script:proofExe -WorkingDirectory $script:runtime -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $deadline = (Get-Date).AddSeconds(30)
    do {
        $script:ownedProcess.Refresh()
        if ($script:ownedProcess.HasExited) { throw "Proof server exited during $Run; inspect $stdout and $stderr." }
        # bindOnlyGlobalAddress=false listens on wildcard addresses. Ownership
        # of the game port is the readiness condition, independent of address.
        $listener = @(Get-NetTCPConnection -LocalPort 7177 -State Listen -ErrorAction SilentlyContinue)
        if ($listener.Count) {
            if (@($listener | Where-Object OwningProcess -ne $script:ownedProcess.Id).Count) { throw 'Proof game listener belongs to a different process.' }
            return
        }
        if ((Get-Date) -gt $deadline) { throw "Proof server startup timeout during $Run." }
        Start-Sleep -Milliseconds 250
    } while ($true)
}
function Proof-Config {
    $configText = @'
ip = "127.0.0.1"
bindOnlyGlobalAddress = false
loginProtocolPort = 7176
gameProtocolPort = 7177
statusProtocolPort = 7176
mysqlHost = "127.0.0.1"
mysqlPort = 33308
mysqlUser = "rooktest"
mysqlPass = "LocalItemProofOnly"
mysqlDatabase = "rookhaven_passives_upgrade_test"
mapName = "rookalmost"
serverName = "Rookhaven Passive Migration Proof"
worldType = "no-pvp"
passivesEnabled = true
passiveTestEnabled = false
enforceClientChecksums = true
startupDatabaseOptimization = false
classicEquipmentSlots = true
'@
    return $configText.Replace('mysqlDatabase = "rookhaven_passives_upgrade_test"',('mysqlDatabase = "' + $script:upgradeDb + '"'))
}
function Read-Checksums($Object) {
    $out = [ordered]@{}
    foreach ($property in $Object.PSObject.Properties) {
        if ($property.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or [string]$property.Value -notmatch '^\d+$') { throw 'Invalid retained checksum evidence.' }
        $out[$property.Name] = [string]$property.Value
    }
    if (-not $out.Count) { throw 'Retained checksum evidence is empty.' }
    return $out
}
try {
    foreach ($required in @($dbCli,$dumpCli,$sourceExe,(Join-Path $serverRoot 'data/global.lua'),(Join-Path $serverRoot 'schema.sql'),(Join-Path $serverRoot 'key.pem'))) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Missing local proof input: $required." }
    }
    if (@(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $sourceExe }).Count) { throw 'Stop the owned ordinary local fixture server before dumping its fixture.' }
    if (@(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $proofExe }).Count) { throw 'The owned proof server is still running; reconcile its previous run first.' }
    $actualData = Normalize-Path (Scalar SourceRead 'SELECT @@datadir')
    if (-not [string]::Equals($actualData,(Normalize-Path $expectedData),[StringComparison]::OrdinalIgnoreCase)) { throw 'DB33308 datadir does not match the owned disposable passive fixture.' }
    if ([int](Scalar SourceRead 'SELECT COUNT(*) FROM players_online') -ne 0) { throw 'Source fixture has online rows; finish fixture cleanup before cloning.' }
    if ($ResumeFailedStartup) {
        Stage 'reconcile-retained-first-start'
        $retainedPath = Join-Path $proofRoot 'report.json'
        $failedPath = Join-Path $proofRoot 'report-listener-failure.json'
        $preDump = Join-Path $proofRoot 'pre-upgrade.sql'
        foreach ($required in @($retainedPath,$preDump,$proofExe,(Join-Path $runtime 'config.lua'),(Join-Path $proofRoot 'first-server-stdout.log'))) {
            if (-not (Test-Path -LiteralPath $required)) { throw "Missing retained proof input: $required." }
        }
        if (Test-Path -LiteralPath $failedPath) { throw 'The exact listener-failure resume has already been attempted; reconcile its later evidence manually.' }
        $retained = [IO.File]::ReadAllText($retainedPath) | ConvertFrom-Json
        if ($retained.status -cne 'FAILED' -or $retained.failedStage -cne 'automatic-migration-first-start' -or $retained.error -cne 'Proof server startup timeout during first.') { throw 'Resume is restricted to the reconciled wildcard-listener timeout.' }
        if ($retained.sourceDatabase -cne $sourceDb -or $retained.upgradeDatabase -cne $upgradeDb -or $retained.restoreDatabase -cne $restoreDb -or -not [string]::Equals((Normalize-Path $retained.datadir),(Normalize-Path $expectedData),[StringComparison]::OrdinalIgnoreCase)) { throw 'Retained proof identities do not match the owned fixture.' }
        if ($retained.PSObject.Properties['cleanupError']) { throw 'Prior cleanup was not confirmed; refusing automated resume.' }
        if ((Get-FileHash -LiteralPath $preDump -Algorithm SHA256).Hash -cne $retained.preUpgradeDumpSha256) { throw 'The full pre-upgrade dump changed after the failed attempt.' }
        if ((Get-FileHash -LiteralPath $proofExe -Algorithm SHA256).Hash -cne $retained.serverExeSha256 -or (Get-FileHash -LiteralPath $sourceExe -Algorithm SHA256).Hash -cne $retained.serverExeSha256) { throw 'Retained proof binary or frozen source binary changed.' }
        if ([IO.File]::ReadAllText((Join-Path $runtime 'config.lua')).Trim() -cne (Proof-Config).Trim()) { throw 'Retained proof runtime configuration changed.' }
        foreach ($relative in @('data/global.lua','data/migrations/30.lua','data/lib/passives/test.lua','data/lib/passives/config.lua','data/lib/passives/routes.lua','data/lib/class_spells/class_spells.lua','data/lib/class_spells/config.lua','data/npc/scripts/The Nameless.lua','schema.sql','key.pem')) {
            if ((Get-FileHash -LiteralPath (Join-Path $runtime $relative) -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath (Join-Path $serverRoot $relative) -Algorithm SHA256).Hash) { throw "Retained runtime input changed: $relative." }
        }
        foreach ($dll in @(Get-ChildItem -LiteralPath (Split-Path $sourceExe -Parent) -Filter '*.dll' -File)) {
            if ((Get-FileHash -LiteralPath (Join-Path $runtime $dll.Name) -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $dll.FullName -Algorithm SHA256).Hash) { throw 'Retained runtime dependency changed.' }
        }
        $sourceBefore = Read-Checksums $retained.sourceBefore
        $preUpgrade = Read-Checksums $retained.preUpgrade
        $sourceVersion = [string]$retained.sourceVersion
        Assert-Checksums $sourceBefore (Table-Checksums SourceRead)
        if ((Scalar SourceRead "SELECT value FROM server_config WHERE config='db_version'") -cne $sourceVersion) { throw 'Source fixture version changed after the first attempt.' }
        if ([int](Scalar SourceRead "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$upgradeDb'") -ne 1 -or [int](Scalar SourceRead "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$restoreDb'") -ne 0) { throw 'Expected upgraded-only clone state is missing.' }
        if ((Scalar Upgrade "SELECT value FROM server_config WHERE config='db_version'") -cne '31' -or [int](Scalar Upgrade 'SELECT COUNT(*) FROM player_passives') -ne 0) { throw 'First startup was not reconciled as an empty version31 passive ledger.' }
        Assert-Checksums $preUpgrade (Table-Checksums Upgrade) @('server_config') @('player_passives')
        $retainedLog = [IO.File]::ReadAllText((Join-Path $proofRoot 'first-server-stdout.log'))
        if (-not $retainedLog.Contains('Updating database to version 31 (permanent passive classes)') -or -not $retainedLog.Contains('Rookhaven Passive Migration Proof Server Online!')) { throw 'First native migration and online state were not both recorded.' }
        # Preserve the original failure verbatim only after every read-only
        # reconciliation gate passed. No clone is dropped, reimported or reset.
        Copy-Item -LiteralPath $retainedPath -Destination $failedPath
        $writeReport = $true
        $report.stages = @($retained.stages) + @('reconcile-retained-first-start')
        $report.sourceVersion = $sourceVersion
        $report.sourceBefore = $sourceBefore
        $report.preUpgrade = $preUpgrade
        $report.preUpgradeDumpSha256 = $retained.preUpgradeDumpSha256
        $report.serverExeSha256 = $retained.serverExeSha256
        $report.recoveredRunnerListenerError = $retained.error
        $report.priorFailedReport = 'report-listener-failure.json'
    } else {
    if (Test-Path -LiteralPath $proofRoot) { throw 'Proof directory already exists; inspect retained artifacts before another attempt.' }
    if (Test-Path -LiteralPath $runtime) { throw 'Proof runtime already exists; inspect it before another attempt.' }
    if ([int](Scalar SourceRead "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME IN ('$upgradeDb','$restoreDb')") -ne 0) { throw 'A proof clone already exists; refusing to overwrite it.' }
    New-Item -ItemType Directory -Path $proofRoot,$runtime | Out-Null
    $writeReport = $true
    Stage 'source-full-dump'
    $sourceBefore = Table-Checksums SourceRead
    $sourceVersion = Scalar SourceRead "SELECT value FROM server_config WHERE config='db_version'"
    $sourceDump = Join-Path $proofRoot 'source-clone.sql'
    Dump SourceRead $sourceDump
    Stage 'prepare-pre30-clone'
    Sql CloneControl $controlStatements[0] | Out-Null
    Sql CloneControl $controlStatements[1] | Out-Null
    Import-Dump Upgrade $sourceDump
    Sql Upgrade 'SET FOREIGN_KEY_CHECKS=0; DROP TABLE IF EXISTS `player_passives`; SET FOREIGN_KEY_CHECKS=1; UPDATE `server_config` SET `value`=30 WHERE `config`=''db_version''' | Out-Null
    if ((Scalar Upgrade "SELECT value FROM server_config WHERE config='db_version'") -cne '30') { throw 'Pre-upgrade clone is not at version30.' }
    if ([int](Scalar Upgrade "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$upgradeDb' AND TABLE_NAME='player_passives'") -ne 0) { throw 'Pre-upgrade clone still has a passive ledger.' }
    $preUpgrade = Table-Checksums Upgrade
    $preDump = Join-Path $proofRoot 'pre-upgrade.sql'
    Dump Upgrade $preDump
    $report.sourceVersion = $sourceVersion
    $report.sourceBefore = $sourceBefore
    $report.preUpgrade = $preUpgrade
    $report.preUpgradeDumpSha256 = (Get-FileHash -LiteralPath $preDump -Algorithm SHA256).Hash
    Stage 'isolated-runtime'
    Copy-Item -LiteralPath $sourceExe -Destination $proofExe
    foreach ($dll in @(Get-ChildItem -LiteralPath (Split-Path $sourceExe -Parent) -Filter '*.dll' -File)) { Copy-Item -LiteralPath $dll.FullName -Destination $runtime }
    Copy-Item -LiteralPath (Join-Path $serverRoot 'data') -Destination $runtime -Recurse
    # The native loader uses data/global.lua, already copied with data above.
    foreach ($name in @('schema.sql','key.pem')) { Copy-Item -LiteralPath (Join-Path $serverRoot $name) -Destination $runtime }
    $config = Proof-Config
    [IO.File]::WriteAllText((Join-Path $runtime 'config.lua'),$config,[Text.UTF8Encoding]::new($false))
    $report.serverExeSha256 = (Get-FileHash -LiteralPath $proofExe -Algorithm SHA256).Hash
    Stage 'automatic-migration-first-start'
    Start-ProofServer 'first'
    Stop-ProofServer
    }
    if ((Scalar Upgrade "SELECT value FROM server_config WHERE config='db_version'") -cne '31') { throw 'Automatic migration did not advance30 to31.' }
    $defaultRanks = (Scalar Upgrade "SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$upgradeDb' AND TABLE_NAME='player_passives' AND COLUMN_NAME='ranks'").Trim("'")
    if ($defaultRanks -notmatch '^0(,0){28}$') { throw 'Automatic table default is not29 zero ranks.' }
    if ((Scalar Upgrade "SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$upgradeDb' AND TABLE_NAME='player_passives' AND COLUMN_NAME='ranks'") -cne 'varchar(128)') { throw 'Passive rank storage width differs from its contract.' }
    $fk = Scalar Upgrade "SELECT CONCAT(REFERENCED_TABLE_NAME,':',DELETE_RULE) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA='$upgradeDb' AND TABLE_NAME='player_passives'"
    if ($fk -cne 'players:CASCADE') { throw 'Passive ledger foreign key differs from its contract.' }
    $firstSums = Table-Checksums Upgrade
    Assert-Checksums $preUpgrade $firstSums @('server_config') @('player_passives')
    $firstLog = [IO.File]::ReadAllText((Join-Path $proofRoot 'first-server-stdout.log'))
    if (-not $firstLog.Contains('Updating database to version 31 (permanent passive classes)')) { throw 'Missing actual startup migration log evidence.' }
    $report.upgradedVersion = 31
    $report.rankDefault = $defaultRanks
    $report.foreignKey = $fk
    $report.afterFirstStartup = $firstSums
    Stage 'idempotent-second-start'
    Start-ProofServer 'second'
    Stop-ProofServer
    $secondSums = Table-Checksums Upgrade
    Assert-Checksums $firstSums $secondSums
    $secondLog = [IO.File]::ReadAllText((Join-Path $proofRoot 'second-server-stdout.log'))
    if ($secondLog.Contains('Updating database to version 31 (permanent passive classes)')) { throw 'Second startup repeated the applied migration.' }
    $report.afterSecondStartup = $secondSums
    Stage 'full-pre30-restore'
    Sql CloneControl $controlStatements[2] | Out-Null
    Import-Dump Restore $preDump
    $restoredSums = Table-Checksums Restore
    Assert-Checksums $preUpgrade $restoredSums
    if ((Scalar Restore "SELECT value FROM server_config WHERE config='db_version'") -cne '30') { throw 'Restored full dump did not retain version30.' }
    if ([int](Scalar Restore "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$restoreDb' AND TABLE_NAME='player_passives'") -ne 0) { throw 'Restored pre30 dump unexpectedly has a passive ledger.' }
    $report.restoredVersion = 30
    $report.afterRestore = $restoredSums
    Stage 'source-unchanged'
    $sourceAfter = Table-Checksums SourceRead
    Assert-Checksums $sourceBefore $sourceAfter
    if ((Scalar SourceRead "SELECT value FROM server_config WHERE config='db_version'") -cne $sourceVersion) { throw 'Read-only source version changed.' }
    $report.sourceAfter = $sourceAfter
    $report.tableCounts = [ordered]@{ source=$sourceBefore.Count; preUpgrade=$preUpgrade.Count; afterFirstStartup=$firstSums.Count; afterSecondStartup=$secondSums.Count; restored=$restoredSums.Count; ordinaryCompared=($preUpgrade.Count - 1) }
    $report.status = 'PASS'
    $report.measured = @('Real automatic startup30-to31 migration','Ordinary base-table checksums unchanged','29-rank default and player FK cascade','Complete second-startup checksum idempotence','Full pre30 dump restored to a separate disposable database','Every restored base-table checksum and version30/no-ledger match','Original fixture checksums/version unchanged')
    Write-Host "PASSIVES_DEV_DATABASE_OK ordinaryTables=$($preUpgrade.Count - 1) restoreTables=$($restoredSums.Count)"
} catch {
    $report.status = 'FAILED'
    $report.failedStage = $stage
    $report.error = $_.Exception.Message
    throw
} finally {
    $stopFailure = $null
    try { Stop-ProofServer } catch {
        $stopFailure = $_
        $report.status = 'FAILED'
        $report.cleanupError = $_.Exception.Message
    }
    if ($writeReport -and (Test-Path -LiteralPath $proofRoot)) { [IO.File]::WriteAllText((Join-Path $proofRoot 'report.json'),($report | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false)) }
    if ($stopFailure) { throw $stopFailure }
}
