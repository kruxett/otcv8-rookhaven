# Lua Bytecode Compilation Script for OTClient V8
# This script compiles all Lua files to bytecode (.luac) for security
# Purpose: Make it harder for players to tamper with client files

param(
    [string]$LuaCompilerPath = "lua",  # Path to lua or luac compiler
    [string]$DataPath = ".\data",
    [string]$ModulesPath = ".\modules"
)

function Get-LuaCompiler {
    # Try to find lua compiler
    $paths = @(
        "luac",                          # Windows (needs to be in PATH)
        "C:\Program Files\Lua\lua.exe",
        "C:\Program Files (x86)\Lua\lua.exe",
        (which luac 2>$null),
        (Get-Command luac -ErrorAction SilentlyContinue).Source
    )
    
    foreach ($path in $paths) {
        if ($path -and (Test-Path $path)) {
            Write-Host "Found Lua compiler at: $path" -ForegroundColor Green
            return $path
        }
    }
    
    Write-Host "ERROR: Lua compiler not found. Please install Lua or set LuaCompilerPath parameter." -ForegroundColor Red
    return $null
}

function Compile-LuaFile {
    param(
        [string]$SourceFile,
        [string]$CompilerPath
    )
    
    $outputFile = $SourceFile -replace '\.lua$', '.luac'
    
    try {
        # Compile Lua to bytecode
        & $CompilerPath -o $outputFile $SourceFile 2>&1 | Out-Null
        
        if (Test-Path $outputFile) {
            Write-Host "✓ Compiled: $(Split-Path $SourceFile -Leaf)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ Failed: $(Split-Path $SourceFile -Leaf)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ Error compiling $(Split-Path $SourceFile -Leaf): $_" -ForegroundColor Red
        return $false
    }
}

# Main script
Write-Host "=== OTClient V8 Lua to Bytecode Compiler ===" -ForegroundColor Cyan
Write-Host ""

# Find compiler
$compiler = Get-LuaCompiler
if (-not $compiler) {
    Write-Host ""
    Write-Host "INSTALLATION INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "1. Download Lua from: https://www.lua.org/download.html"
    Write-Host "2. Extract and add to PATH, or specify path with -LuaCompilerPath parameter"
    Write-Host "3. Run this script again"
    exit 1
}

Write-Host ""
Write-Host "Starting compilation..." -ForegroundColor Cyan

$successCount = 0
$failCount = 0

# Compile Lua files in modules directory
if (Test-Path $ModulesPath) {
    Write-Host ""
    Write-Host "Compiling modules..." -ForegroundColor Yellow
    $luaFiles = Get-ChildItem -Path $ModulesPath -Recurse -Filter "*.lua"
    
    foreach ($file in $luaFiles) {
        if (Compile-LuaFile -SourceFile $file.FullName -CompilerPath $compiler) {
            $successCount++
        } else {
            $failCount++
        }
    }
}

# Compile Lua files in data directory
if (Test-Path $DataPath) {
    Write-Host ""
    Write-Host "Compiling data files..." -ForegroundColor Yellow
    $luaFiles = Get-ChildItem -Path $DataPath -Recurse -Filter "*.lua"
    
    foreach ($file in $luaFiles) {
        if (Compile-LuaFile -SourceFile $file.FullName -CompilerPath $compiler) {
            $successCount++
        } else {
            $failCount++
        }
    }
}

Write-Host ""
Write-Host "=== Compilation Complete ===" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Delete all .lua files from modules/ and data/ (keep .luac files)"
Write-Host "2. Rebuild data.zip with only .luac bytecode files"
Write-Host "3. Rebuild the client"
Write-Host "4. Login and capture the new checksum hash"
Write-Host "5. Update checksum_expected.txt on server with new hash"
