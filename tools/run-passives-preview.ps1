param([string]$Script = 'passives-ui-preview.lua')
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path (Split-Path $clientRoot -Parent) 'Rookhaven'
$package = Join-Path $clientRoot 'out/install/x64-LocalPassives'
$preview = Join-Path $clientRoot 'out/passives-preview'
New-Item -ItemType Directory -Path $preview -Force | Out-Null
Copy-Item -Path (Join-Path $package '*') -Destination $preview -Recurse -Force
$luajit = 'C:/vcpkg-client/installed/x64-windows-static/tools/luajit/luajit.exe'
$treePath = (Join-Path $preview 'tree.json').Replace('\','/')
$treesPath = (Join-Path $preview 'trees.json').Replace('\','/')
# Export presentation data offline; native startup configuration is verified by
# the live server gates, not by this screenshot-only preview.
$export = "Game={configurePassiveClasses=function() return true end}; dofile('data/lib/core/json.lua'); dofile('data/lib/passives/test.lua'); local f=assert(io.open('$treePath','w')); f:write(json.encode(PassiveTest.tree)); f:close(); local a=assert(io.open('$treesPath','w')); a:write(json.encode(PassiveTest.trees or {reaver=PassiveTest.tree})); a:close()"
Push-Location $serverRoot
try { & $luajit -e $export; if ($LASTEXITCODE) { throw 'Could not export the server tree.' } }
finally { Pop-Location }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open((Join-Path $preview 'data.zip'), [IO.Compression.ZipArchiveMode]::Update)
try {
    $original = $zip.GetEntry('init.luac')
    $memory = [IO.MemoryStream]::new()
    $reader = $original.Open()
    try { $reader.CopyTo($memory); $bytes = $memory.ToArray() } finally { $reader.Dispose(); $memory.Dispose() }
    $original.Delete()
    $destination = $zip.CreateEntry('startup_original.luac').Open()
    try { $destination.Write($bytes, 0, $bytes.Length) } finally { $destination.Dispose() }
    $entries = @{
        'init.lua' = "function T() assert(loadstring(g_resources.readFileContents('/passives-preview-test.txt')))() end`nreturn dofile('/startup_original.lua')"
        'test.lua' = 'T()'
        'passives-preview-test.txt' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('tests/' + $Script)))
        'passives-preview-tree.txt' = [IO.File]::ReadAllText((Join-Path $preview 'tree.json'))
        'passives-preview-trees.txt' = [IO.File]::ReadAllText((Join-Path $preview 'trees.json'))
    }
    foreach ($entry in $entries.GetEnumerator()) {
        $old = $zip.GetEntry($entry.Key); if ($old) { $old.Delete() }
        $writer = [IO.StreamWriter]::new($zip.CreateEntry($entry.Key).Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
    }
} finally { $zip.Dispose() }
$process = Start-Process (Join-Path $preview 'RookhavenClient.exe') -ArgumentList '--local-passives','--test' `
    -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $preview 'stdout.txt') -RedirectStandardError (Join-Path $preview 'stderr.txt')
$null = $process.Handle
if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id; throw 'Native preview timed out.' }
$log = [IO.File]::ReadAllText((Join-Path $preview 'stdout.txt')) + [IO.File]::ReadAllText((Join-Path $preview 'stderr.txt'))
Write-Output $log
if ($log -notmatch 'PASSIVES_NATIVE_PREVIEW_OK' -or $log -match '(?m)^(ERROR|FATAL)|PASSIVES_PREVIEW_FAILED') {
    throw 'Native passive UI preview failed.'
}
Write-Host 'Screenshot: AppData/Roaming/Rookhaven Client/Rookhaven-LocalPassives-Probe/passives-preview-retro.png'
