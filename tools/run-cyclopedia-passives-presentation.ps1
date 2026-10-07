param([switch]$PrepareOnly, [switch]$NoScreenshots)
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
& (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'cyclopedia-passives-presentation.lua' -PrepareOnly
if ($LASTEXITCODE) { throw 'Cyclopedia presentation preparation failed.' }
$probe = Join-Path $clientRoot 'out/cyclopedia-passives-presentation'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open((Join-Path $probe 'data.zip'), [IO.Compression.ZipArchiveMode]::Update)
try {
    $entries = @{
        'cyclopedia-character-source.txt' = 'modules/game_cyclopedia/tab/character/character.lua'
        'cyclopedia-character-layout.txt' = 'modules/game_cyclopedia/tab/character/character.otui'
    }
    foreach ($entry in $entries.GetEnumerator()) {
        $old = $zip.GetEntry($entry.Key)
        if ($old) { $old.Delete() }
        $writer = [IO.StreamWriter]::new($zip.CreateEntry($entry.Key).Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write([IO.File]::ReadAllText((Join-Path $clientRoot $entry.Value))) } finally { $writer.Dispose() }
    }
    if ($NoScreenshots) {
        $entry = $zip.GetEntry('passives-probe.txt')
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $source = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $entry.Delete()
        $writer = [IO.StreamWriter]::new($zip.CreateEntry('passives-probe.txt').Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write("CYCLOPEDIA_PASSIVES_SCREENSHOTS=false`n" + $source) } finally { $writer.Dispose() }
    }
} finally { $zip.Dispose() }
if ($PrepareOnly) { Write-Output $probe; return }
$process = Start-Process (Join-Path $probe 'RookhavenClient.exe') -ArgumentList '--local-passives','--test' `
    -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $probe 'stdout.txt') -RedirectStandardError (Join-Path $probe 'stderr.txt')
$null = $process.Handle
if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id; throw 'Cyclopedia presentation probe timed out.' }
$log = [IO.File]::ReadAllText((Join-Path $probe 'stdout.txt')) + [IO.File]::ReadAllText((Join-Path $probe 'stderr.txt'))
Write-Output $log
if ($process.ExitCode -ne 0 -or $log -notmatch 'CYCLOPEDIA_PASSIVES_PRESENTATION_OK' -or $log -match '(?m)^(ERROR|FATAL)|CYCLOPEDIA_PASSIVES_FAILED') {
    throw "Native Cyclopedia presentation failed (exit=$($process.ExitCode))."
}
if (-not $NoScreenshots -and $log -match '(?m)^CYCLOPEDIA_PASSIVES_SCREENSHOT_DIRECTORY (.+)$') {
    $imageRoot = $Matches[1].Trim()
    foreach ($name in @('cyclopedia-passives-1280x800.png','cyclopedia-passives-800x640.png')) {
        Copy-Item -LiteralPath (Join-Path $imageRoot $name) -Destination (Join-Path $probe $name) -Force
    }
}
