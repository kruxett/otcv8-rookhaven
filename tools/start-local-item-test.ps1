param([switch]$Stop)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path (Split-Path $clientRoot -Parent) 'Rookhaven'
$localRoot = Join-Path $clientRoot 'out/local-server'
$databaseExe = Join-Path $localRoot 'mariadb-11.4.9-winx64/bin/mariadbd.exe'
$serverExe = Join-Path $serverRoot 'build/local-item-test/tfs.exe'
$databaseExe = [IO.Path]::GetFullPath($databaseExe)
$serverExe = [IO.Path]::GetFullPath($serverExe)
$targets = @($databaseExe, $serverExe)
if ($Stop) {
    Get-Process mariadbd,tfs -ErrorAction SilentlyContinue | Where-Object { $_.Path -in $targets } | Stop-Process
    Write-Host 'Local item test server and database stopped.'
    exit
}
if (-not (Test-Path $databaseExe) -or -not (Test-Path $serverExe)) {
    throw 'Local test binaries are missing. See README: Local item proof.'
}
$config = Get-Content (Join-Path $serverRoot 'config.lua') -Raw
if ($config -notmatch 'ip\s*=\s*"127\.0\.0\.1"' -or $config -notmatch 'mysqlPort\s*=\s*33307' -or $config -notmatch 'serverName\s*=\s*"Rookhaven Local Item Test"') {
    throw 'This launcher requires the isolated local test configuration.'
}
$running = Get-Process mariadbd,tfs -ErrorAction SilentlyContinue
if (-not ($running | Where-Object Path -eq $databaseExe)) {
    Start-Process $databaseExe -ArgumentList '--no-defaults',"--datadir=$localRoot/db",'--bind-address=127.0.0.1','--port=33307','--skip-name-resolve','--console' -WindowStyle Hidden -RedirectStandardOutput "$localRoot/db-stdout.log" -RedirectStandardError "$localRoot/db-stderr.log" | Out-Null
}
$deadline = (Get-Date).AddSeconds(20)
while (-not (Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 33307 -State Listen -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) { throw 'Local database did not start.' }
    Start-Sleep -Milliseconds 200
}
if (-not ($running | Where-Object Path -eq $serverExe)) {
    Start-Process $serverExe -WorkingDirectory $serverRoot -WindowStyle Hidden -RedirectStandardOutput "$localRoot/server-stdout.log" -RedirectStandardError "$localRoot/server-stderr.log" | Out-Null
}
$deadline = (Get-Date).AddSeconds(20)
while (-not (Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 7175 -State Listen -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) { throw 'Local game server did not start.' }
    Start-Sleep -Milliseconds 200
}
Write-Host 'Local server ready: login 127.0.0.1:7174, game 7175, database 33307.'
Write-Host 'Test account: itemtest / itemtest; character: Item Tester.'
