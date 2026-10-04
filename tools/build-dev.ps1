param(
    [string]$VcpkgRoot = 'C:\vcpkg-client',
    [string]$VisualStudioPath = '',
    [ValidateRange(1, 64)]
    [int]$Jobs = 8
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$toolchain = Join-Path $VcpkgRoot 'scripts\buildsystems\vcpkg.cmake'
if (-not (Test-Path -LiteralPath $toolchain)) {
    throw "Client vcpkg is missing at $VcpkgRoot."
}

if (-not (Get-Command cl -ErrorAction SilentlyContinue) -or $env:VSCMD_ARG_TGT_ARCH -ne 'x64') {
    if (-not $VisualStudioPath) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path -LiteralPath $vswhere) {
            $VisualStudioPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        }
    }
    if (-not $VisualStudioPath) {
        throw 'No Visual Studio C++ build tools found. Specify -VisualStudioPath.'
    }
    Import-Module (Join-Path $VisualStudioPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $VisualStudioPath -DevCmdArguments '-arch=x64 -host_arch=x64' -SkipAutomaticLocation
}

$cmake = (Get-Command cmake -ErrorAction Stop).Source
Get-Command ninja -ErrorAction Stop | Out-Null
$buildDir = Join-Path $projectRoot 'out\build\x64-DevRelease'
$installDir = Join-Path $projectRoot 'out\install\x64-DevRelease'
$tripletDir = Join-Path $projectRoot 'out\vcpkg-triplets'
New-Item -ItemType Directory -Path $tripletDir -Force | Out-Null
@'
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_BUILD_TYPE release)
'@ | Set-Content -LiteralPath (Join-Path $tripletDir 'x64-windows-static.cmake') -Encoding ascii

$env:VCPKG_MAX_CONCURRENCY = "$Jobs"
$configureArgs = @(
    '-S', $projectRoot, '-B', $buildDir, '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
    '-DUSE_STATIC_LIBS=ON',
    '-DVCPKG_TARGET_TRIPLET=x64-windows-static',
    '-DVCPKG_HOST_TRIPLET=x64-windows-static',
    "-DVCPKG_INSTALLED_DIR=$(Join-Path $VcpkgRoot 'installed')",
    "-DVCPKG_OVERLAY_TRIPLETS=$tripletDir",
    '-DVCPKG_BUILD_TYPE=release',
    '-DDEFAULT_SERVER_ENDPOINT=testserver2.rookhaven-ot.com:7173:860',
    '-DUPDATER_CHANNEL=dev',
    "-DCMAKE_INSTALL_PREFIX=$installDir"
)
& $cmake @configureArgs
if ($LASTEXITCODE -ne 0) { throw 'DEV configure failed.' }
& $cmake --build $buildDir --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw 'DEV build failed.' }
& $cmake --install $buildDir
if ($LASTEXITCODE -ne 0) { throw 'DEV install failed.' }
Write-Host "DEV client: $(Join-Path $installDir 'RookhavenClient.exe')"
