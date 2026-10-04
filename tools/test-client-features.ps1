param()
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path (Split-Path $clientRoot -Parent) 'Rookhaven'
$config = Get-Content -LiteralPath (Join-Path $serverRoot 'config.lua') -Raw
if ($config -notmatch 'ip\s*=\s*"127\.0\.0\.1"' -or $config -notmatch 'mysqlPort\s*=\s*33307' -or
    $config -notmatch 'serverName\s*=\s*"Rookhaven Local Item Test"') {
    throw 'Feature tests require the isolated local item-test server configuration.'
}
$serverExe = [IO.Path]::GetFullPath((Join-Path $serverRoot 'build/local-item-test/tfs.exe'))
$databaseCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
function Invoke-FixtureSql([string]$Sql) {
    $result = & $databaseCli --host=127.0.0.1 --port=33307 --user=rooktest --password=LocalItemProofOnly --database=rookhaven_item_test --batch --skip-column-names --execute=$Sql
    if ($LASTEXITCODE -ne 0) { throw 'Local fixture SQL failed.' }
    return $result
}
function Stop-FixtureServer {
    Get-Process tfs -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $serverExe } | Stop-Process
}
$testDir = Join-Path $clientRoot 'out/feature-integration-test'
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Copy-Item -Path (Join-Path $clientRoot 'out/install/x64-DevRelease/*') -Destination $testDir -Recurse -Force
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open((Join-Path $testDir 'data.zip'), [IO.Compression.ZipArchiveMode]::Update)
try {
    $entry = $archive.GetEntry('init.luac')
    $stream = $entry.Open()
    $buffer = [IO.MemoryStream]::new()
    try { $stream.CopyTo($buffer); $bytes = $buffer.ToArray() }
    finally { $stream.Dispose(); $buffer.Dispose() }
    $entry.Delete()
    $entry = $archive.CreateEntry('startup_original.luac')
    $stream = $entry.Open()
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    $contents = @{
        'init.lua' = "DEFAULT_SERVER_ENDPOINT='127.0.0.1:7174:860'`nfunction T() assert(loadstring(g_resources.readFileContents('/feature-test.txt')))() end`nreturn dofile('/startup_original.lua')"
        'test.lua' = 'T()'
        'feature-test.txt' = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tests/client-features.lua') -Raw)
        'dev-startup-test-config.otml' = "window-size: 1500 900`nwindow-maximized: false`nautoReconnect: false`nshowGuildNames: false`n"
    }
    foreach ($item in $contents.GetEnumerator()) {
        $entry = $archive.GetEntry($item.Key)
        if ($entry) { $entry.Delete() }
        $entry = $archive.CreateEntry($item.Key)
        $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write($item.Value) } finally { $writer.Dispose() }
    }
} finally { $archive.Dispose() }

$xmlPath = Join-Path $serverRoot 'data/talkactions/talkactions.xml'
$originalXml = [IO.File]::ReadAllBytes($xmlPath)
$originalAccountType = [int](Invoke-FixtureSql 'SELECT type FROM accounts WHERE id=1;')
$seeded = $false
try {
    if ([int](Invoke-FixtureSql 'SELECT COUNT(*) FROM guild_membership WHERE player_id=1;') -ne 0) {
        throw 'The local fixture player already has a guild. Remove that fixture membership before this test.'
    }
    Stop-FixtureServer
    $seeded = $true
    Invoke-FixtureSql "UPDATE accounts SET type=6 WHERE id=1 AND name='itemtest'; INSERT INTO guilds(id,name,ownerid,creationdata) VALUES(9001,'Feature Testers',1,0); INSERT INTO guild_ranks(id,guild_id,name,level) VALUES(9001,9001,'Leader',3); INSERT INTO guild_membership(player_id,guild_id,rank_id,nick) VALUES(1,9001,9001,'');" | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tests/live-feature-probe.lua') -Destination (Join-Path $serverRoot 'build/local-item-test/live-feature-probe.lua') -Force
    $xml = [Text.Encoding]::UTF8.GetString($originalXml).Replace('</talkactions>', '<talkaction words="/featureprobe" separator=" " script="../../../build/local-item-test/live-feature-probe.lua" /></talkactions>')
    [IO.File]::WriteAllText($xmlPath, $xml, [Text.UTF8Encoding]::new($false))
    & (Join-Path $PSScriptRoot 'start-local-item-test.ps1')
    $env:ROOKHAVEN_SMOKE_HASH = (Get-FileHash -LiteralPath (Join-Path $testDir 'data.zip') -Algorithm SHA256).Hash
    $process = Start-Process -FilePath (Join-Path $testDir 'RookhavenClient.exe') -ArgumentList '--test' -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $testDir 'stdout.txt') -RedirectStandardError (Join-Path $testDir 'stderr.txt')
    $null = $process.Handle
    if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id; throw 'Feature client test timed out.' }
    $process.Refresh()
    $stdout = Get-Content -LiteralPath (Join-Path $testDir 'stdout.txt') -Raw
    $stderr = Get-Content -LiteralPath (Join-Path $testDir 'stderr.txt') -Raw
    $stdout
    $stderr
    if ($process.ExitCode -ne 0 -or $stdout -notmatch 'CLIENT_FEATURES_OK' -or ($stdout + $stderr) -match '(?m)^(ERROR|FATAL)') {
        throw 'Feature integration test failed. See out/feature-integration-test logs.'
    }
} finally {
    foreach ($logName in @('server-stdout.log', 'server-stderr.log')) {
        Copy-Item -LiteralPath (Join-Path $clientRoot "out/local-server/$logName") -Destination $testDir -Force -ErrorAction SilentlyContinue
    }
    Stop-FixtureServer
    [IO.File]::WriteAllBytes($xmlPath, $originalXml)
    if ($seeded) {
        Invoke-FixtureSql "UPDATE accounts SET type=$originalAccountType WHERE id=1 AND name='itemtest'; DELETE FROM guild_membership WHERE player_id=1 AND guild_id=9001; DELETE FROM guilds WHERE id=9001 AND ownerid=1;" | Out-Null
    }
    & (Join-Path $PSScriptRoot 'start-local-item-test.ps1')
}
