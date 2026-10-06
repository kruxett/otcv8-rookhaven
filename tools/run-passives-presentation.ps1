param([switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$basePackage = Join-Path $clientRoot 'out/install/x64-LocalPassives'
$presentationPackage = Join-Path $clientRoot 'out/passives-presentation'
$catalogPath = Join-Path $clientRoot 'out/passives-preview/trees.json'
foreach ($required in @((Join-Path $basePackage 'data.zip'), (Join-Path $basePackage 'RookhavenClient.exe'), $catalogPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required offline artifact missing: $required" }
}
New-Item -ItemType Directory -Path $presentationPackage -Force | Out-Null
Copy-Item -Path (Join-Path $basePackage '*') -Destination $presentationPackage -Recurse -Force
$baseHash = (Get-FileHash -LiteralPath (Join-Path $basePackage 'data.zip') -Algorithm SHA256).Hash
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
function Get-PresentationEntryHash($entry) {
    $hash = [Security.Cryptography.SHA256]::Create()
    $stream = $entry.Open()
    try { return [BitConverter]::ToString($hash.ComputeHash($stream)) } finally { $stream.Dispose(); $hash.Dispose() }
}
$archivePath = Join-Path $presentationPackage 'data.zip'
$archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Update)
try {
    # Keep every encrypted module entry. Only the disposable startup is wrapped.
    $moduleEntries = @($archive.Entries | Where-Object { $_.FullName -like 'modules/*' } | ForEach-Object { $_.FullName })
    $moduleHashes = @{}
    foreach ($name in $moduleEntries) { $moduleHashes[$name] = Get-PresentationEntryHash ($archive.GetEntry($name)) }
    $original = $archive.GetEntry('init.luac')
    if (-not $original) { throw 'Base package init.luac missing.' }
    $memory = [IO.MemoryStream]::new()
    $reader = $original.Open()
    try { $reader.CopyTo($memory); $startup = $memory.ToArray() } finally { $reader.Dispose(); $memory.Dispose() }
    $original.Delete()
    $destination = $archive.CreateEntry('startup_original.luac').Open()
    try { $destination.Write($startup, 0, $startup.Length) } finally { $destination.Dispose() }
    $entries = @{
        'init.lua' = "function T() assert(loadstring(g_resources.readFileContents('/passives-presentation-test.txt')))() end`nreturn dofile('/startup_original.lua')"
        'test.lua' = 'T()'
        'passives-presentation-test.txt' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'tests/passives-presentation.lua'))
        'passives-presentation-source.txt' = [IO.File]::ReadAllText((Join-Path $clientRoot 'modules/game_passives/passives.lua'))
        'passives-presentation-layout.txt' = [IO.File]::ReadAllText((Join-Path $clientRoot 'modules/game_passives/passives.otui'))
        'passives-presentation-trees.txt' = [IO.File]::ReadAllText($catalogPath)
    }
    foreach ($entry in $entries.GetEnumerator()) {
        $existing = $archive.GetEntry($entry.Key)
        if ($existing) { $existing.Delete() }
        $writer = [IO.StreamWriter]::new($archive.CreateEntry($entry.Key).Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
    }
    foreach ($name in $moduleEntries) {
        $module = $archive.GetEntry($name)
        if (-not $module -or (Get-PresentationEntryHash $module) -ne $moduleHashes[$name]) { throw "Packaged module changed: $name" }
    }
} finally { $archive.Dispose() }
if ((Get-FileHash -LiteralPath (Join-Path $basePackage 'data.zip') -Algorithm SHA256).Hash -ne $baseHash) {
    throw 'Base package changed while preparing presentation gate.'
}
$manifest = [ordered]@{
    scope = 'Offline native presentation only'; basePackage = $basePackage; baseZipSha256 = $baseHash
    sourceSha256 = (Get-FileHash -LiteralPath (Join-Path $clientRoot 'modules/game_passives/passives.lua') -Algorithm SHA256).Hash
    uiSha256 = (Get-FileHash -LiteralPath (Join-Path $clientRoot 'modules/game_passives/passives.otui') -Algorithm SHA256).Hash
    encryptedModulesPreserved = $true; preservedModuleCount = $moduleEntries.Count; serverCalls = $false; sharedSourceModifiedDuringHarness = $false
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $presentationPackage 'presentation-manifest.json') -Encoding UTF8
if ($PrepareOnly) { Write-Host "Prepared $presentationPackage"; return }
$process = Start-Process (Join-Path $presentationPackage 'RookhavenClient.exe') -ArgumentList '--local-passives','--test' `
    -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $presentationPackage 'stdout.txt') -RedirectStandardError (Join-Path $presentationPackage 'stderr.txt')
$null = $process.Handle
if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id; throw 'Native presentation gate timed out.' }
$log = [IO.File]::ReadAllText((Join-Path $presentationPackage 'stdout.txt')) + [IO.File]::ReadAllText((Join-Path $presentationPackage 'stderr.txt'))
[IO.File]::WriteAllText((Join-Path $presentationPackage 'run.log'), $log, [Text.UTF8Encoding]::new($false))
Write-Output $log
if ($log -notmatch 'PASSIVES_PRESENTATION_OK' -or $log -match '(?m)^(ERROR|FATAL)|PASSIVES_PRESENTATION_FAILED') {
    throw 'Native passive presentation regression failed.'
}
if ((Get-FileHash -LiteralPath (Join-Path $basePackage 'data.zip') -Algorithm SHA256).Hash -ne $baseHash) {
    throw 'Base package changed during native presentation gate.'
}
if ($log -match '(?m)^PASSIVES_PRESENTATION_SCREENSHOT_DIRECTORY (.+)$') {
    $screenshotDirectory = $Matches[1].Trim()
    $imagesDirectory = Join-Path $presentationPackage 'images'
    New-Item -ItemType Directory -Path $imagesDirectory -Force | Out-Null
    foreach ($name in @('passives-presentation-reaver-1280x800.png', 'passives-presentation-reaver-800x600.png')) {
        $imagePath = Join-Path $screenshotDirectory $name
        if (Test-Path -LiteralPath $imagePath) { Copy-Item -LiteralPath $imagePath -Destination (Join-Path $imagesDirectory $name) -Force }
    }
}
Write-Host "Presentation evidence: $(Join-Path $presentationPackage 'run.log')"
