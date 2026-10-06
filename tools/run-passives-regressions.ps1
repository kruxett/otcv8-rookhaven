param([switch]$Build)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$runtimeConfig = Join-Path $clientRoot 'out/local-server/passives-runtime/config.lua'
$logs = Join-Path $clientRoot 'out/passives-regressions'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
Push-Location $clientRoot
try {
    if ($Build) {
        Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe | Stop-Process
        & (Join-Path $PSScriptRoot 'build-local-passives.ps1') -Jobs 8 *> (Join-Path $logs 'build.log')
        if ($LASTEXITCODE) { throw 'Local client/server build failed.' }
    }
    & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'start.log')
    if ($LASTEXITCODE) { throw 'Local test startup failed.' }
    $configBytes = [IO.File]::ReadAllBytes($runtimeConfig)
    function Run-Regression([string]$Script,[string]$Marker,[string]$Log) {
        & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script $Script -Success $Marker -TimeoutSeconds 125 *> (Join-Path $logs $Log)
        if ($LASTEXITCODE) { throw "Regression failed: $Script. See $logs/$Log." }
        Write-Host "PASS $Script ($Log)"
    }
    try {
        Run-Regression 'passives-normal-guard.lua' 'PASSIVES_NORMAL_GUARD_OK' 'normal-module-guard.log'
        Run-Regression 'passives-lifecycle.lua' 'PASSIVES_LIFECYCLE_OK' 'lifecycle.log'
        Run-Regression 'passives-baseline.lua' 'PASSIVES_BASELINE_OK enabled=true' 'baseline-enabled.log'
        Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe | Stop-Process
        $config = [IO.File]::ReadAllText($runtimeConfig)
        if (-not $config.Contains('passiveTestEnabled = true')) { throw 'Expected owned runtime flag missing.' }
        [IO.File]::WriteAllText($runtimeConfig,$config.Replace('passiveTestEnabled = true','passiveTestEnabled = false'),[Text.UTF8Encoding]::new($false))
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') *> (Join-Path $logs 'disabled-start.log')
        if ($LASTEXITCODE) { throw 'Disabled-mode startup failed.' }
        Run-Regression 'passives-baseline.lua' 'PASSIVES_BASELINE_OK enabled=false' 'baseline-disabled.log'
    } finally {
        Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe | Stop-Process
        [IO.File]::WriteAllBytes($runtimeConfig,$configBytes)
        & (Join-Path $PSScriptRoot 'start-local-passives.ps1') -Refresh *> (Join-Path $logs 'restored-start.log')
        if ($LASTEXITCODE) { throw 'Source-default runtime restoration failed.' }
    }
    Run-Regression 'passives-all-trees-contract.lua' 'PASSIVES_ALL_TREES_CONTRACT_OK' 'six-trees-contract.log'
    Write-Host 'PASS regression gates. Local server restored; source balance untouched. Logs:' $logs
} finally { Pop-Location }