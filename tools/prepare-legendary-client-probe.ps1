param(
    [string]$PackageDirectory = '',
    [switch]$PrepareOnly,
    [int]$TimeoutSeconds = 120,
    [string]$ExitReceiptPath = ''
)
$ErrorActionPreference = 'Stop'
$taskClientRoot = Split-Path $PSScriptRoot -Parent
$taskPackage = if ($PackageDirectory) { [IO.Path]::GetFullPath($PackageDirectory) } else {
    Join-Path $taskClientRoot 'out/install/x64-LocalPassives'
}
$taskPreparation = & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') `
    -Script 'legendary-client-native.lua' -PrepareOnly -PackageDirectory $taskPackage
$taskProbe = [IO.Path]::GetFullPath([string]($taskPreparation | Select-Object -Last 1))
$taskExpectedProbe = [IO.Path]::GetFullPath((Join-Path $taskClientRoot 'out/legendary-client-native'))
if ($taskProbe -ne $taskExpectedProbe) { throw 'Unexpected owned legendary probe directory.' }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$taskZip = [IO.Compression.ZipFile]::Open((Join-Path $taskProbe 'data.zip'), [IO.Compression.ZipArchiveMode]::Update)
try {
    $taskSources = @{
        'legendary-overlay-source.txt' = 'modules/game_inventory/legendary_overlay.lua'
        'legendary-forgotten-source.txt' = 'modules/game_lava_smelt/forgotten_works.lua'
        'legendary-lava-source.txt' = 'modules/game_lava_smelt/lava_smelt.lua'
        'legendary-forge-layout.txt' = 'modules/game_lava_smelt/lava_smelt.otui'
    }
    foreach ($taskEntry in $taskSources.GetEnumerator()) {
        $taskPrevious = $taskZip.GetEntry($taskEntry.Key)
        if ($taskPrevious) { $taskPrevious.Delete() }
        $taskWriter = [IO.StreamWriter]::new($taskZip.CreateEntry($taskEntry.Key).Open(), [Text.UTF8Encoding]::new($false))
        try { $taskWriter.Write([IO.File]::ReadAllText((Join-Path $taskClientRoot $taskEntry.Value))) }
        finally { $taskWriter.Dispose() }
    }
} finally { $taskZip.Dispose() }
if ($PrepareOnly) { Write-Output $taskProbe; return }
# Root owns serial isolation of this disposable local test profile. This helper
# touches no existing user profile, DEV login, server, account or character.
$taskProcess = Start-Process (Join-Path $taskProbe 'RookhavenClient.exe') `
    -ArgumentList @('--local-passives', '--test') -WorkingDirectory $taskClientRoot `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskProbe 'stdout.txt') `
    -RedirectStandardError (Join-Path $taskProbe 'stderr.txt')
$null = $taskProcess.Handle
if (-not $taskProcess.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $taskProcess.Id
    throw 'Owned legendary native UI probe timed out.'
}
$taskProcess.Refresh()
if ($ExitReceiptPath) {
    $taskReceipt = @{clientExit = $taskProcess.ExitCode; processId = $taskProcess.Id; renderingOnly = $true; serverProof = $false}
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($ExitReceiptPath), ($taskReceipt | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}
$taskLog = [IO.File]::ReadAllText((Join-Path $taskProbe 'stdout.txt')) + [IO.File]::ReadAllText((Join-Path $taskProbe 'stderr.txt'))
Write-Output $taskLog
if ($taskProcess.ExitCode -ne 0 -or $taskLog -notmatch 'LEGENDARY_CLIENT_NATIVE_OK' `
    -or $taskLog -match '(?m)^(ERROR|FATAL)|LEGENDARY_CLIENT_NATIVE_FAILED') {
    throw "Owned legendary native UI probe failed (exit=$($taskProcess.ExitCode)); see $taskProbe logs."
}
