param([int]$Jobs = 8, [switch]$ClientOnly, [switch]$ServerOnly,
    [string]$Python = 'C:/Users/marcu/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
$ErrorActionPreference = 'Stop'
if ($ClientOnly -and $ServerOnly) { throw 'Choose ClientOnly or ServerOnly.' }
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path (Split-Path $clientRoot -Parent) 'Rookhaven'
$packageDir = Join-Path $clientRoot 'out/install/x64-LocalPassives'
if (-not $ServerOnly) {
    & (Join-Path $PSScriptRoot 'build-dev.ps1') -Jobs $Jobs `
        -BuildDirectory (Join-Path $clientRoot 'out/build/x64-LocalPassives') `
        -InstallDirectory $packageDir -DefaultServerEndpoint '127.0.0.1:7174:860'
    if ($LASTEXITCODE) { throw 'Local client build failed.' }
    $launcher = '@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'start "" "%~dp0RookhavenClient.exe" --local-passives' + "`r`n"
    [IO.File]::WriteAllText((Join-Path $packageDir 'Start Local Passives.cmd'), $launcher, [Text.Encoding]::ASCII)
    [IO.File]::WriteAllText((Join-Path $packageDir 'Start Second Local Client.cmd'),
        $launcher.Replace('--local-passives', '--local-passives --local-passives-peer'), [Text.Encoding]::ASCII)
    if (-not (Test-Path -LiteralPath $Python)) { throw 'Specify -Python with a Python 3 executable.' }
    & $Python (Join-Path $PSScriptRoot 'passives/package-checksums.py') `
        (Join-Path $packageDir 'data.zip') (Join-Path $packageDir 'checksum_expected.txt')
    if ($LASTEXITCODE) { throw 'Local final-package checksum generation failed.' }
}
if (-not $ClientOnly) {
    & (Join-Path $PSScriptRoot 'build-server-local.ps1') -Jobs $Jobs `
        -BuildDirectory (Join-Path $serverRoot 'build/local-passives')
    if ($LASTEXITCODE) { throw 'Local server build failed.' }
}
Write-Host "Local retro client: $packageDir"
Write-Host 'Start server: tools/start-local-passives.ps1 -Refresh'
