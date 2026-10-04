param([switch]$Interactive)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'out'
$testDir = Join-Path $outputDir 'item-integration-test'
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Copy-Item -Path (Join-Path $outputDir 'install/x64-DevRelease/*') -Destination $testDir -Recurse -Force
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open((Join-Path $testDir 'data.zip'), [System.IO.Compression.ZipArchiveMode]::Update)
try {
    $init = $archive.GetEntry('init.luac')
    $stream = $init.Open()
    $buffer = [System.IO.MemoryStream]::new()
    try { $stream.CopyTo($buffer); $initBytes = $buffer.ToArray() }
    finally { $stream.Dispose(); $buffer.Dispose() }
    $init.Delete()
    $newInit = $archive.CreateEntry('startup_original.luac')
    $stream = $newInit.Open()
    try { $stream.Write($initBytes, 0, $initBytes.Length) } finally { $stream.Dispose() }
    foreach ($name in @('test.lua', 'test.luac')) {
        $entry = $archive.GetEntry($name)
        if ($entry) { $entry.Delete() }
    }
    $entries = @{
        'init.lua' = "DEFAULT_SERVER_ENDPOINT='127.0.0.1:7174:860'`nfunction T() assert(loadstring(g_resources.readFileContents('/dev-startup-test.txt')))() end`nreturn dofile('/startup_original.lua')"
        'test.lua' = 'T()'
        'item-proof-checksum-paths.txt' = ((Get-Content C:/GitRepos/kruxett/Rookhaven/data/checksum_expected.txt | Where-Object { $_ -match '^/' } | ForEach-Object { ($_ -split '=')[0] }) -join "`n")
        'dev-startup-test.txt' = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'item-proof/client-test.lua') -Raw)
        'dev-startup-test-config.otml' = "window-size: 1500 900`nwindow-maximized: false`nautoReconnect: false`n"
    }
    foreach ($item in $entries.GetEnumerator()) {
        $entry = $archive.CreateEntry($item.Key)
        $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
        try { $writer.Write($item.Value) } finally { $writer.Dispose() }
    }
} finally { $archive.Dispose() }
$env:ROOKHAVEN_SMOKE_HASH = (Get-FileHash -LiteralPath (Join-Path $testDir 'data.zip') -Algorithm SHA256).Hash
$env:ROOKHAVEN_SMOKE_SCREENSHOT = '/dev-startup-test-layout.png'
$env:ROOKHAVEN_ITEM_INTERACTIVE = if ($Interactive) { '1' } else { '0' }
$process = Start-Process -FilePath (Join-Path $testDir 'RookhavenClient.exe') -ArgumentList '--test' -WorkingDirectory $projectRoot -WindowStyle $(if ($Interactive) { 'Normal' } else { 'Hidden' }) -PassThru -RedirectStandardOutput (Join-Path $testDir 'stdout.txt') -RedirectStandardError (Join-Path $testDir 'stderr.txt')
if ($Interactive) {
    Write-Host "Local client PID=$($process.Id). Account: itemtest / itemtest."
    exit
}
$null = $process.Handle
if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id; throw 'DEV startup test timed out' }
$process.Refresh()
"ExitCode=$($process.ExitCode)"
$stdout = Get-Content -LiteralPath (Join-Path $testDir 'stdout.txt') -Raw
$stderr = Get-Content -LiteralPath (Join-Path $testDir 'stderr.txt') -Raw
$stdout
$stderr
if ($process.ExitCode -ne 0 -or $stdout -notmatch 'ITEM_INTEGRATION_OK' -or ($stdout + $stderr) -match '(?m)^(ERROR|FATAL)') {
    throw 'Local item integration test failed'
}

