param()
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$runtimeConfig = Join-Path $clientRoot 'out/local-server/passives-runtime/config.lua'
$probeRunner = Join-Path $PSScriptRoot 'run-passives-probe.ps1'
$logs = Join-Path $clientRoot 'out/passives-ward-party-tests'
$config = [IO.File]::ReadAllText($runtimeConfig)
foreach ($pattern in @('(?m)^\s*ip\s*=\s*"127\.0\.0\.1"\s*$','(?m)^\s*gameProtocolPort\s*=\s*7175\s*$','(?m)^\s*mysqlPort\s*=\s*33308\s*$','(?m)^\s*mysqlDatabase\s*=\s*"rookhaven_passives_test"\s*$','(?m)^\s*passiveTestEnabled\s*=\s*true\s*$')) {
    if ($config -notmatch $pattern) { throw 'Runtime is not the expected isolated loopback passive fixture.' }
}
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$peer = $null
$peerExe = $null
function Read-SharedLog([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $stream = $null
        $reader = $null
        try {
            $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $reader = [IO.StreamReader]::new($stream)
            return $reader.ReadToEnd()
        } catch [IO.IOException] {
            $code = $_.Exception.HResult -band 0xffff
            if ($code -notin @(32, 33) -or $attempt -eq 4) { throw }
            Start-Sleep -Milliseconds 50
        } finally {
            if ($reader) { $reader.Dispose() }
            elseif ($stream) { $stream.Dispose() }
        }
    }
}
Push-Location $clientRoot
try {
    $prepared = @(& $probeRunner -Script 'passives-ward-party-peer.lua' -Peer -PrepareOnly)
    $peerPath = [IO.Path]::GetFullPath([string]$prepared[-1])
    $expected = [IO.Path]::GetFullPath((Join-Path $clientRoot 'out/passives-ward-party-peer-peer'))
    if ($peerPath -ne $expected) { throw 'Unexpected ward peer preparation path.' }
    $peerExe = Join-Path $peerPath 'RookhavenClient.exe'
    $stdout = Join-Path $logs 'peer-stdout.log'
    $stderr = Join-Path $logs 'peer-stderr.log'
    $peer = Start-Process $peerExe -ArgumentList '--local-passives','--local-passives-peer','--test' `
        -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $peer.Handle
    $deadline = (Get-Date).AddSeconds(25)
    do {
        $peer.Refresh()
        $text = (Read-SharedLog $stdout) + (Read-SharedLog $stderr)
        if ($text -match 'PASSIVES_WARD_PEER_FAILED|(?m)^(ERROR|FATAL)') { throw 'Ward peer failed before ready.' }
        if ($text -match 'PASSIVES_WARD_PEER_READY') { break }
        if ($peer.HasExited -or (Get-Date) -gt $deadline) { throw 'Ward peer readiness timeout.' }
        Start-Sleep -Milliseconds 200
    } while ($true)
    Start-Sleep -Seconds 6
    & $probeRunner -Script 'passives-ward-party.lua' -Success 'PASSIVES_WARD_PARTY_OK' -TimeoutSeconds 235 `
        *> (Join-Path $logs 'main.log')
    if ($LASTEXITCODE) { throw 'Actual two-client ward party probe failed.' }
    if (-not $peer.WaitForExit(10000)) { throw 'Ward peer did not finish after successful party probe.' }
    $peerText = (Read-SharedLog $stdout) + (Read-SharedLog $stderr)
    if ($peerText -notmatch 'PASSIVES_WARD_PEER_OK' -or $peerText -match 'PASSIVES_WARD_PEER_FAILED|(?m)^(ERROR|FATAL)') { throw 'Ward peer did not confirm its actual casts and cleanup.' }
    Write-Output 'PASSIVES_WARD_PARTY_RUNNER_OK'
} finally {
    if ($peer) {
        $peer.Refresh()
        if (-not $peer.HasExited) {
            $actual = Get-Process -Id $peer.Id -ErrorAction Stop
            if ($actual.Path -ne $peerExe -or $actual.StartTime -ne $peer.StartTime) { throw 'Ward peer ownership mismatch; refusing cleanup.' }
            Stop-Process -Id $peer.Id
            $null = $peer.WaitForExit(10000)
        }
    }
    Pop-Location
}
