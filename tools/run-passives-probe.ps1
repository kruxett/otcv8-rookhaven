param(
    [string]$Script = 'passives-contract.lua',
    [string]$Success = 'PASSIVES_CONTRACT_OK',
    [int]$TimeoutSeconds = 100,
    [ValidateSet('all','ward')][string]$Phase = 'all',
    [ValidateSet('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper')][string]$Tree = 'reaver',
    [ValidatePattern('^[a-z_]+$')][string]$Cap = 'berserker',
    [switch]$Party,
    [switch]$Peer,
    [switch]$PrepareOnly,
    [string]$PackageDirectory = '',
    [switch]$NormalDev,
    [string]$ExitReceiptPath = ''
)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$name = [IO.Path]::GetFileNameWithoutExtension($Script)
$package = Join-Path $clientRoot 'out/install/x64-LocalPassives'
if ($PackageDirectory) { $package = [IO.Path]::GetFullPath($PackageDirectory) }
$probe = Join-Path $clientRoot ('out/' + $name + $(if ($Peer) { '-peer' }))
New-Item -ItemType Directory -Path $probe -Force | Out-Null
Copy-Item -Path (Join-Path $package '*') -Destination $probe -Recurse -Force
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open((Join-Path $probe 'data.zip'), [IO.Compression.ZipArchiveMode]::Update)
try {
    $original = $zip.GetEntry('init.luac')
    $memory = [IO.MemoryStream]::new()
    $reader = $original.Open()
    try { $reader.CopyTo($memory); $bytes = $memory.ToArray() } finally { $reader.Dispose(); $memory.Dispose() }
    $original.Delete()
    $destination = $zip.CreateEntry('startup_original.luac').Open()
    try { $destination.Write($bytes, 0, $bytes.Length) } finally { $destination.Dispose() }
    $entries = @{
        'init.lua' = "function T() assert(loadstring(g_resources.readFileContents('/passives-probe.txt')))() end`nreturn dofile('/startup_original.lua')"
        'test.lua' = 'T()'
        'passives-probe.txt' = "PASSIVES_COMBAT_PHASE='$Phase'`nPASSIVES_PROBE_TREE='$Tree'`nPASSIVES_PROBE_CAP='$Cap'`nPASSIVES_PROBE_PARTY=$($Party.IsPresent.ToString().ToLowerInvariant())`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('tests/' + $Script)))
    }
    if ($NormalDev) {
        # Only the disposable probe scripts the updater response. The unchanged
        # release endpoint/version/channel are asserted before modules load.
        $devVersion = [regex]::Match([IO.File]::ReadAllText((Join-Path $clientRoot 'init.lua')), 'local\s+DEV_APP_VERSION\s*=\s*(\d+)')
        if (-not $devVersion.Success) { throw 'Source DEV version is missing.' }
        $entries['init.lua'] = @'
function T() assert(loadstring(g_resources.readFileContents('/passives-probe.txt')))() end
local ensureModuleLoaded = g_modules.ensureModuleLoaded
g_modules.ensureModuleLoaded = function(name)
  ensureModuleLoaded(name)
  if name == 'updater' then
    local postJSON = HTTP.postJSON
    HTTP.postJSON = function(url, request, callback)
      HTTP.postJSON = postJSON
      assert(url == 'http://updater2.rookhaven-ot.com/api/updater', 'Normal DEV updater URL changed')
      assert(request.args.dev == true and request.version == @@DEV_VERSION@@, 'Normal DEV updater channel/version changed')
      print('PASSIVES_DEV_UPDATER_REQUEST_OK version=' .. request.version .. ' dev=true response=scripted')
      scheduleEvent(function() callback({upToDate=true}, nil) end, 10)
      return 0
    end
  end
end
return dofile('/startup_original.lua')
'@
        $entries['init.lua'] = $entries['init.lua'].Replace('@@DEV_VERSION@@', $devVersion.Groups[1].Value)
    }
    foreach ($entry in $entries.GetEnumerator()) {
        $old = $zip.GetEntry($entry.Key); if ($old) { $old.Delete() }
        $writer = [IO.StreamWriter]::new($zip.CreateEntry($entry.Key).Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
    }
} finally { $zip.Dispose() }
if ($PrepareOnly) { Write-Output $probe; exit }
$arguments = @('--local-passives','--test')
if ($NormalDev) { $arguments = @('--test') }
if ($Peer) { $arguments += '--local-passives-peer' }
$process = Start-Process (Join-Path $probe 'RookhavenClient.exe') -ArgumentList $arguments `
    -WorkingDirectory $clientRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $probe 'stdout.txt') -RedirectStandardError (Join-Path $probe 'stderr.txt')
$null = $process.Handle
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { Stop-Process -Id $process.Id; throw "Native probe timed out: $name" }
$process.Refresh()
if ($ExitReceiptPath) {
    $exitReceipt = @{ clientExit = $process.ExitCode; processId = $process.Id } | ConvertTo-Json
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($ExitReceiptPath), $exitReceipt, [Text.UTF8Encoding]::new($false))
}
$log = [IO.File]::ReadAllText((Join-Path $probe 'stdout.txt')) + [IO.File]::ReadAllText((Join-Path $probe 'stderr.txt'))
Write-Output $log
if ($process.ExitCode -ne 0 -or $log -notmatch [regex]::Escape($Success) -or $log -match '(?m)^(ERROR|FATAL)|PASSIVES_\w+_FAILED') {
    throw "Native probe failed: $name (exit=$($process.ExitCode)). See $probe logs."
}
