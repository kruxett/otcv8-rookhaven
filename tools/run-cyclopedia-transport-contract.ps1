param(
    [string]$LuaJit = 'C:\vcpkg-client\installed\x64-windows-static\tools\luajit\luajit.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$clientRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $clientRoot 'modules\game_cyclopedia\game_cyclopedia.lua'
$testPath = Join-Path $PSScriptRoot 'tests\cyclopedia-transport-contract.lua'
foreach ($requiredPath in @($LuaJit, $sourcePath, $testPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required contract input missing: $requiredPath"
    }
}

# The test reads fresh source and supplies only isolated protocol/clock/events.
# It starts no native game client, server, network connection or profile helper.
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$output = @(& $LuaJit $testPath $sourcePath 2>&1)
$testExitCode = $LASTEXITCODE
foreach ($line in $output) { Write-Output $line }
if ($testExitCode -ne 0) { throw "Cyclopedia transport source contract failed (exit $testExitCode)." }
if (-not ($output -match '^CYCLOPEDIA_TRANSPORT_CONTRACT_OK checks=20 pureSource=true native=false$')) {
    throw 'Cyclopedia transport source contract did not emit its success marker.'
}
if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $sourceHash) {
    throw 'Cyclopedia source changed during its contract check; rerun against a stable source.'
}
Write-Output "CYCLOPEDIA_TRANSPORT_SOURCE_SHA256 $sourceHash"
