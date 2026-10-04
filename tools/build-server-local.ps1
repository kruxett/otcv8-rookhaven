param([string]$VcpkgRoot = 'C:/vcpkg-server', [int]$Jobs = 8)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path (Split-Path $clientRoot -Parent) 'Rookhaven'
$buildDir = Join-Path $serverRoot 'build/local-item-test'
$include = Join-Path $VcpkgRoot 'installed/x64-windows/include'
Import-Module C:/BuildTools/Common7/Tools/Microsoft.VisualStudio.DevShell.dll
Enter-VsDevShell -VsInstallPath C:/BuildTools -DevCmdArguments '-arch=x64 -host_arch=x64' -SkipAutomaticLocation
cmake -S $serverRoot -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows "-DVCPKG_INSTALLED_DIR=$VcpkgRoot/installed" -DVCPKG_MANIFEST_MODE=OFF -DSKIP_GIT=ON "-DMYSQL_INCLUDE_DIR=$include/mariadb" "-DLUA_INCLUDE_DIR=$include/luajit" "-DLUA_LIBRARY=$VcpkgRoot/installed/x64-windows/lib/lua51.lib"
if ($LASTEXITCODE) { throw 'Local server configure failed.' }
cmake --build $buildDir --parallel $Jobs
if ($LASTEXITCODE) { throw 'Local server build failed.' }
Copy-Item "$VcpkgRoot/installed/x64-windows/bin/*.dll" $buildDir -Force
Write-Host "Local server: $buildDir/tfs.exe"
