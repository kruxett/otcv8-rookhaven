param([ValidateSet('all','reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper')]
      [string]$Tree='all')
$ErrorActionPreference='Stop'
$clientRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$evidence=Join-Path $clientRoot 'out/cyclopedia-passives-native-suite'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$trees=@($Tree)
if ($Tree -eq 'all') { $trees=@('reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper') }
foreach ($class in $trees) {
    # Login and game each open a TCP connection. Ban::acceptConnection resets
    # its burst count after >5 seconds; keep fixture runs outside that burst.
    Start-Sleep -Seconds 6
    $logPath=Join-Path $evidence "$class.log"
    & (Join-Path $PSScriptRoot 'run-passives-probe.ps1') -Script 'cyclopedia-passives-native.lua' `
        -Success 'CYCLOPEDIA_PASSIVES_NATIVE_COMPLETE' -Tree $class -TimeoutSeconds 55 `
        -ExitReceiptPath (Join-Path $evidence "$class-exit.json") *> $logPath
    if ($LASTEXITCODE) { throw "Native Cyclopedia check failed for $class. See $logPath" }
    $log=[IO.File]::ReadAllText($logPath)
    if ($log -notmatch 'CYCLOPEDIA_PASSIVES_NATIVE_UI_OK' -or
        $log -notmatch '(?m)^CYCLOPEDIA_PASSIVES_NATIVE_SCREENSHOT_DIRECTORY (.+)$') {
        throw "Native UI evidence absent for $class. See $logPath"
    }
    $imageRoot=$Matches[1].Trim()
    foreach ($view in @('stats','talents')) {
        foreach ($size in @('1280x800','800x600')) {
            $name="cyclopedia-native-$class-$view-$size.png"
            Copy-Item -LiteralPath (Join-Path $imageRoot $name) -Destination (Join-Path $evidence $name) -Force
        }
    }
    Write-Host "PASS native Cyclopedia $class (read-only; both views and sizes)"
}
