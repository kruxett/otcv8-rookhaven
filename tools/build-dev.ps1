param(
    [string]$VcpkgRoot = 'C:\vcpkg-client',
    [string]$VcpkgInstalledDirectory = '',
    [string]$VisualStudioPath = '',
    [ValidateRange(1, 64)]
    [int]$Jobs = 8,
    [string]$BuildDirectory = '',
    [string]$InstallDirectory = '',
    [string]$DefaultServerEndpoint = 'testserver2.rookhaven-ot.com:7173:860',
    [string]$ServerRsaPublicKeyFile = '',
    [switch]$QaClient,
    [switch]$BuildOnly,
    [string]$Python = 'C:/Users/marcu/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $ServerRsaPublicKeyFile) {
    if ($QaClient) {
        & $Python (Join-Path $PSScriptRoot 'prepare-local-rsa.py') | Out-Null
        if ($LASTEXITCODE) { throw 'Private loopback RSA fixture preparation failed.' }
        $ServerRsaPublicKeyFile = Join-Path $projectRoot 'out/local-server/auth/public-modulus.txt'
    } else { $ServerRsaPublicKeyFile = Join-Path $PSScriptRoot 'keys/dev-rsa.txt' }
}
$toolchain = Join-Path $VcpkgRoot 'scripts\buildsystems\vcpkg.cmake'
if (-not $VcpkgInstalledDirectory) { $VcpkgInstalledDirectory = Join-Path $VcpkgRoot 'installed' }
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
function Invoke-DevCMake([string[]]$Arguments, [string]$Failure) {
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $cmake @Arguments
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($code -ne 0) { throw "$Failure (exit $code)." }
}
Get-Command ninja -ErrorAction Stop | Out-Null
$buildDir = Join-Path $projectRoot 'out\build\x64-DevRelease'
$installDir = Join-Path $projectRoot 'out\install\x64-DevRelease'
if ($BuildDirectory) { $buildDir = [IO.Path]::GetFullPath($BuildDirectory) }
if ($InstallDirectory) { $installDir = [IO.Path]::GetFullPath($InstallDirectory) }
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
    "-DVCPKG_INSTALLED_DIR=$VcpkgInstalledDirectory",
    "-DVCPKG_OVERLAY_TRIPLETS=$tripletDir",
    '-DVCPKG_BUILD_TYPE=release',
    "-DDEFAULT_SERVER_ENDPOINT=$DefaultServerEndpoint",
    "-DSERVER_RSA_PUBLIC_KEY_FILE=$ServerRsaPublicKeyFile",
    '-DUPDATER_CHANNEL=dev',
    '-DGENERATE_LEGACY_BUILD_CHECKSUMS=OFF',
    "-DROOKHAVEN_QA_CLIENT=$($QaClient.IsPresent.ToString().ToUpperInvariant())",
    "-DPython3_EXECUTABLE=$Python",
    "-DCMAKE_INSTALL_PREFIX=$installDir"
)
Invoke-DevCMake $configureArgs 'DEV configure failed'
Invoke-DevCMake @('--build',$buildDir,'--parallel',"$Jobs") 'DEV build failed'
if ($BuildOnly) { Write-Host "DEV native build: $(Join-Path $buildDir 'RookhavenClient.exe')"; return }
# POST_BUILD does not run when only Lua/UI resources changed. Refresh the staging
# resources and bytecode explicitly so every DEV package contains current sources.
foreach ($resourceDir in @('data', 'modules', 'layouts')) {
    $stagingPath = [IO.Path]::GetFullPath((Join-Path $buildDir $resourceDir))
    if (-not $stagingPath.StartsWith([IO.Path]::GetFullPath($buildDir).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $stagingPath.StartsWith([IO.Path]::GetFullPath((Join-Path $projectRoot $resourceDir)), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe resource staging path: $stagingPath"
    }
    if (Test-Path -LiteralPath $stagingPath) { Remove-Item -LiteralPath $stagingPath -Recurse -Force }
    Invoke-DevCMake @('-E','copy_directory',(Join-Path $projectRoot $resourceDir),(Join-Path $buildDir $resourceDir)) "DEV resource copy failed: $resourceDir"
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'init.lua') -Destination (Join-Path $buildDir 'init.lua') -Force
$compilerEntry = Select-String -LiteralPath (Join-Path $buildDir 'CMakeCache.txt') -Pattern '^LUAC_EXECUTABLE:FILEPATH=(.+)$'
if (-not $compilerEntry) { throw 'DEV Lua bytecode compiler is missing from CMake cache.' }
$luaCompiler = $compilerEntry.Matches[0].Groups[1].Value
Invoke-DevCMake @("-DROOT_DIR=$buildDir","-DLUAC_EXECUTABLE=$luaCompiler",'-P',(Join-Path $PSScriptRoot 'luac_compile.cmake')) 'DEV bytecode compilation failed'
Invoke-DevCMake @('--install',$buildDir) 'DEV install failed'
if (-not $QaClient) {
    $manifest = Get-Content -LiteralPath (Join-Path $buildDir 'generated/rookhaven_resources.json') -Raw | ConvertFrom-Json
    $binaryHash = (Get-FileHash -LiteralPath (Join-Path $installDir 'RookhavenClient.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    @($manifest.fingerprint, $binaryHash) | Set-Content -LiteralPath (Join-Path $installDir 'client_integrity_expected.txt') -Encoding ascii
}
Write-Host "DEV client: $(Join-Path $installDir 'RookhavenClient.exe')"
