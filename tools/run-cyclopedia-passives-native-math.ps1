param([string]$ServerRoot = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Rookhaven'))
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$ServerRoot = [IO.Path]::GetFullPath($ServerRoot)
$nativeSource = [IO.File]::ReadAllText((Join-Path $ServerRoot 'src/passives.cpp'))
$rngSource = [IO.File]::ReadAllText((Join-Path $ServerRoot 'src/tools.cpp'))
$combatSource = [IO.File]::ReadAllText((Join-Path $ServerRoot 'src/combat.cpp'))
$probability = [regex]::Matches($nativeSource, '(?ms)^double legacyCriticalProbability\(uint16_t threshold\) \{.*?^\}')
$roll = [regex]::Matches($rngSource, '(?ms)^int32_t normal_random\(int32_t minNumber, int32_t maxNumber\)\r?\n\{.*?^\}')
if ($probability.Count -ne 1 -or $roll.Count -ne 1) { throw 'Cannot extract unique actual native probability/RNG functions.' }
if ($combatSource -notmatch 'normal_random\(1, 100\) <= chance') { throw 'Legacy combat critical roll changed; review this check.' }
$output = Join-Path $clientRoot 'out/cyclopedia-passives-math'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$sourcePath = Join-Path $output 'critical-probability.cpp'
$source = @'
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <iomanip>
#include <random>
std::mt19937& getRandomGenerator() { static std::mt19937 rng(10085); return rng; }
'@ + "`n" + $probability[0].Value + "`n" + $roll[0].Value + "`n" + @'
int main() {
 struct Case { uint16_t threshold; double expected; };
 const Case cases[]={{0,0},{10,3.027955566444207},{49,46.113537260417054},
  {50,50},{51,53.88646273958293},{100,100},{65535,100}};
 for(const auto& c:cases) if(std::abs(legacyCriticalProbability(c.threshold)-c.expected)>1e-9) {
  std::cerr << "Critical CDF boundary failed: " << c.threshold << '\n';return 1;
 }
 const double gear=legacyCriticalProbability(10),passive=2.5,combined=gear+(100-gear)*passive/100;
 if(std::abs(combined-5.452256677283102)>1e-9) {std::cerr<<"Independent roll composition failed\n";return 2;}
 // Execute the actual tools.cpp float RNG/mapping rather than a copied model.
 uint32_t counts[101]={};const uint32_t samples=1000000;
 for(uint32_t n=0;n<samples;++n) {const auto value=normal_random(1,100);if(value<1||value>100)return 3;++counts[value];}
 uint32_t accepted=0;
 for(uint16_t threshold=1;threshold<=100;++threshold) {
  accepted+=counts[threshold];const double actual=100.0*accepted/samples;
  if(std::abs(actual-legacyCriticalProbability(threshold))>.15) {
   std::cerr<<"Actual source RNG disagrees at "<<threshold<<": "<<actual<<'\n';return 4;
  }
 }
 std::cout<<std::setprecision(12)<<"CYCLOPEDIA_CRITICAL_MATH_OK threshold10="<<gear
  <<" passive="<<passive<<" combined="<<combined<<" sourceRngSamples="<<samples<<" boundaries=0,49,50,51,100,65535\n";
}
'@
[IO.File]::WriteAllText($sourcePath, $source, [Text.UTF8Encoding]::new($false))
Import-Module 'C:/BuildTools/Common7/Tools/Microsoft.VisualStudio.DevShell.dll'
Enter-VsDevShell -VsInstallPath 'C:/BuildTools' -DevCmdArguments '-arch=x64 -host_arch=x64' -SkipAutomaticLocation | Out-Null
$executable = Join-Path $output 'critical-probability.exe'
$object = Join-Path $output 'critical-probability.obj'
& cl.exe /std:c++17 /EHsc /nologo /O2 "/Fe:$executable" "/Fo:$object" $sourcePath
if ($LASTEXITCODE) { throw 'Standalone actual-source probability build failed.' }
& $executable
if ($LASTEXITCODE) { throw 'Standalone actual-source probability check failed.' }
