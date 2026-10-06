param()
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$serverExe = [IO.Path]::GetFullPath((Join-Path $clientRoot '../Rookhaven/build/local-passives/tfs.exe'))
$dbCli = Join-Path $clientRoot 'out/local-server/mariadb-11.4.9-winx64/bin/mariadb.exe'
$runtimeConfig = Join-Path $clientRoot 'out/local-server/passives-runtime/config.lua'
$logs = Join-Path $clientRoot 'out/class-spells-synergy-tests'
$probeRunner = Join-Path $PSScriptRoot 'run-passives-probe.ps1'
$serverRunner = Join-Path $PSScriptRoot 'start-local-passives.ps1'

function Stop-OwnedServer {
    foreach ($owned in @(Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe)) {
        Stop-Process -Id $owned.Id
        if (-not $owned.WaitForExit(10000)) { throw 'Owned isolated server did not exit.' }
    }
}
function Invoke-FixtureSql([string]$Sql) {
    $rows = & $dbCli --host=127.0.0.1 --port=33308 --user=root --password=LocalPassiveFixtureOnly `
        --database=rookhaven_passives_test --batch --skip-column-names "--execute=$Sql"
    if ($LASTEXITCODE) { throw 'Isolated class-spell synergy fixture SQL failed.' }
    return $rows
}
function Assert-IsolatedFixture {
    foreach ($path in @($dbCli, $serverExe, $runtimeConfig, $probeRunner, $serverRunner)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required local fixture file missing: $path" }
    }
    $config = [IO.File]::ReadAllText($runtimeConfig)
    foreach ($pattern in @(
        '(?m)^\s*ip\s*=\s*"127\.0\.0\.1"\s*$',
        '(?m)^\s*bindOnlyGlobalAddress\s*=\s*true\s*$',
        '(?m)^\s*loginProtocolPort\s*=\s*7174\s*$',
        '(?m)^\s*gameProtocolPort\s*=\s*7175\s*$',
        '(?m)^\s*mysqlHost\s*=\s*"127\.0\.0\.1"\s*$',
        '(?m)^\s*mysqlPort\s*=\s*33308\s*$',
        '(?m)^\s*mysqlDatabase\s*=\s*"rookhaven_passives_test"\s*$',
        '(?m)^\s*serverName\s*=\s*"Rookhaven Local Passives Test"\s*$',
        '(?m)^\s*passiveTestEnabled\s*=\s*true\s*$'
    )) {
        if ($config -notmatch $pattern) { throw 'Runtime is not the expected isolated loopback passive fixture.' }
    }
    if ([string](Invoke-FixtureSql "SELECT CONCAT(@@port,':',DATABASE())") -ne '33308:rookhaven_passives_test') {
        throw 'Database identity does not match the isolated fixture.'
    }
    $query = @'
SELECT COUNT(*) FROM players p JOIN accounts a ON a.id=p.account_id JOIN player_passives t ON t.player_id=p.id
WHERE p.group_id=1 AND p.vocation=3 AND p.level=40 AND p.healthmax=735 AND p.manamax=390 AND
((p.id=9011 AND p.name='Starter Lifekeeper' AND a.name='classlifekeeper' AND t.class_id='lifekeeper') OR
 (p.id=9006 AND p.name='Starter Reaver' AND a.name='classreaver' AND t.class_id='reaver'));
'@
    if ([int](Invoke-FixtureSql $query) -ne 2) {
        throw 'Run the six-class starter suite first: ordinary GUID9006 Reaver and GUID9011 Lifekeeper are required.'
    }
}
function Reset-HealerFixture {
    if (Get-Process tfs -ErrorAction SilentlyContinue | Where-Object Path -eq $serverExe) {
        throw 'Stop the owned server before seeding the two disposable fixture players.'
    }
    # Only the Lifekeeper ledger changes. The Reaver peer keeps its chosen class.
    $sql = @'
START TRANSACTION;
UPDATE player_passives SET earned_points=16,respec_count=0,ranks='0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0' WHERE player_id=9011 AND class_id='lifekeeper';
UPDATE players SET group_id=1,health=735,mana=390,conditions='',ps_mode=0,ps_name='',posx=32097,posy=32219,posz=7 WHERE id IN (9006,9011);
COMMIT;
'@
    Invoke-FixtureSql $sql | Out-Null
}
function Stop-OwnedPeer($Peer, [string]$ExpectedPath) {
    if (-not $Peer) { return }
    $Peer.Refresh()
    if ($Peer.HasExited) { return }
    $actual = Get-Process -Id $Peer.Id -ErrorAction Stop
    if ($actual.Path -ne $ExpectedPath -or $actual.StartTime -ne $Peer.StartTime) {
        throw 'Peer cleanup ownership check failed; refusing to stop a different process.'
    }
    Stop-Process -Id $Peer.Id
    if (-not $Peer.WaitForExit(10000)) { throw 'Owned synergy peer did not exit.' }
}

Push-Location $clientRoot
try {
    Assert-IsolatedFixture
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    foreach ($cap in @('renewal','aegis','concord')) {
        $peer = $null
        $peerExe = $null
        try {
            Stop-OwnedServer
            Reset-HealerFixture
            & $serverRunner -Refresh *> (Join-Path $logs ($cap + '-server.log'))
            if ($LASTEXITCODE) { throw "Isolated server startup failed: $cap" }

            $prepared = @(& $probeRunner -Script 'class-spells-peer.lua' -Peer -PrepareOnly)
            $peerPath = [string]$prepared[-1]
            $peerExe = [IO.Path]::GetFullPath((Join-Path $peerPath 'RookhavenClient.exe'))
            $expectedDirectory = [IO.Path]::GetFullPath((Join-Path $clientRoot 'out/class-spells-peer-peer'))
            if ([IO.Path]::GetFullPath($peerPath) -ne $expectedDirectory -or -not (Test-Path -LiteralPath $peerExe -PathType Leaf)) {
                throw 'Peer preparation returned an unexpected executable path.'
            }
            $peerStdout = Join-Path $logs ($cap + '-peer-stdout.log')
            $peerStderr = Join-Path $logs ($cap + '-peer-stderr.log')
            $peer = Start-Process $peerExe -ArgumentList '--local-passives','--local-passives-peer','--test' `
                -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru `
                -RedirectStandardOutput $peerStdout -RedirectStandardError $peerStderr
            $null = $peer.Handle
            $deadline = (Get-Date).AddSeconds(25)
            do {
                $peer.Refresh()
                $text = if (Test-Path -LiteralPath $peerStdout) { Get-Content -LiteralPath $peerStdout -Raw } else { '' }
                if ($text -match 'CLASS_SPELL_PEER_FAILED|(?m)^(ERROR|FATAL)') { throw "Synergy peer failed: $cap" }
                if ($text -match 'CLASS_SPELL_PEER_READY') { break }
                if ($peer.HasExited -or (Get-Date) -gt $deadline) { throw "Ordinary peer did not become ready: $cap" }
                Start-Sleep -Milliseconds 200
            } while ($true)

            Start-Sleep -Seconds 6 # Both account/game sockets obey the existing IP throttle.
            & $probeRunner -Script 'class-spells-synergy.lua' -Tree lifekeeper -Cap $cap `
                -Success ("CLASS_SPELLS_SYNERGY_OK " + $cap) -TimeoutSeconds 125 `
                *> (Join-Path $logs ($cap + '-main.log'))
            if ($LASTEXITCODE) { throw "Ordinary-party synergy probe failed: $cap" }
            $peer.Refresh()
            $peerOutput = [string](Get-Content -LiteralPath $peerStdout -Raw) + [string](Get-Content -LiteralPath $peerStderr -Raw)
            if ($peer.HasExited -or $peerOutput -match 'CLASS_SPELL_PEER_FAILED|(?m)^(ERROR|FATAL)') {
                throw "Party peer ended or failed during the actual synergy probe: $cap"
            }
            Write-Host "PASS class-spell real-party synergy $cap"
        } finally {
            Stop-OwnedPeer $peer $peerExe
        }
    }
    Write-Host 'Local party synergy suite complete. Owned server remains running. Logs:' $logs
} finally {
    Pop-Location
}
