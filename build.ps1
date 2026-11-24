# Builds bin\VisageDLSS.addon64 with MSVC (Visual Studio 2022+ with C++ tools).
# MSVC is required: ReShade is built with it, and MinGW returns API structs differently.
# Usage: .\build.ps1 [-Install] [-Package] [-GameBin <folder of Visage-Win64-Shipping.exe>]
#   -Install  copies the add-on and nvngx_dlss.dll next to the game's exe (game closed).
#   -Package  makes bin\release\VisageDLSS-<version>.zip: the add-on and nvngx_dlss.dll, README,
#             LICENSE, THIRD_PARTY_NOTICES and the DLSS licence.
# nvngx_dlss.dll (DLSS 310.9.16) comes from third_party\streamline\bin\x64: bin\x64 of NVIDIA's
# Streamline SDK release 2.14.16 (github.com/NVIDIA-RTX/Streamline/releases). Visage is DirectX 11
# only, so the Streamline and AMD FSR runtimes that StrayDLSS ships aren't needed or shipped; the
# build still compiles StrayDLSS's DX12 sources (never registered in Visage). The DLL isn't in this
# repository.
param(
    [switch]$Install,
    [switch]$Package,
    [string]$GameBin = "E:\SteamLibrary\steamapps\common\Visage\Visage\Binaries\Win64"
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$exe = "Visage-Win64-Shipping.exe"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
# vcvars64.bat runs vswhere by name; PATH entries with parentheses in odd places (a Steam tool's
# folder) break cmd's parsing of vcvars, so only the Windows folders are kept for the build.
$env:PATH = "$(Split-Path $vswhere);$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\WindowsPowerShell\v1.0"
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw "Visual Studio with the C++ x64 tools not found." }
$vcvars = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"

$obj = "$root\bin\obj"
New-Item -ItemType Directory -Force $obj | Out-Null
$addon = "$root\bin\VisageDLSS.addon64"

# ReShade add-on headers in third_party\reshade match ReShade 6.8.0.
$cmd = @(
    "call `"$vcvars`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kMotionCs /Fh `"$obj\motion_cs.h`" `"$root\src\motion.hlsl`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kTintCs /Fh `"$obj\tint_cs.h`" `"$root\src\tint.hlsl`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kComposeCs /Fh `"$obj\compose_cs.h`" `"$root\src\compose.hlsl`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kUiAlphaCs /Fh `"$obj\ui_alpha_cs.h`" `"$root\src\ui_alpha.hlsl`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kHudComposeCs /Fh `"$obj\hud_compose_cs.h`" `"$root\src\hud_compose.hlsl`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kGuideCs /Fh `"$obj\guide_cs.h`" `"$root\src\guide.hlsl`" >nul",
    "fxc /nologo /T cs_5_1 /E main /O3 /Vn kGuideViewCs /Fh `"$obj\guide_view_cs.h`" `"$root\src\guide_view.hlsl`" >nul",
    "fxc /nologo /T cs_5_0 /E main /O3 /Vn kMotion11Cs /Fh `"$obj\motion11_cs.h`" `"$root\src\motion11.hlsl`" >nul",
    ("cl /nologo /std:c++17 /O2 /EHsc /MT /W3 /D_CRT_SECURE_NO_WARNINGS /DNOMINMAX " +
     "/I `"$obj`" /I `"$root\third_party\imgui`" /I`"$root\third_party\reshade\include`" /I `"$root\third_party\dlss\include`" /I `"$root\third_party\streamline\include`" " +
     "/I `"$root\third_party\fidelityfx\api\include`" /I `"$root\third_party\fidelityfx\upscalers\include`" /I `"$root\third_party\fidelityfx\framegeneration\include`" " +
     "/Fo`"$obj\\`" `"$root\src\main.cpp`" `"$root\third_party\reshade\utils\descriptor_tracking.cpp`" `"$root\src\upscaler.cpp`" `"$root\src\dlss.cpp`" `"$root\src\fsr.cpp`" `"$root\src\fsrfg.cpp`" `"$root\src\framegen.cpp`" `"$root\src\probe11.cpp`" `"$root\src\upscaler11.cpp`" `"$root\src\dlss11.cpp`" user32.lib advapi32.lib ole32.lib d3d11.lib d3d12.lib dxgi.lib `"$root\third_party\dlss\lib\nvsdk_ngx_s.lib`" " +
     "/link /DLL /OUT:`"$addon`" /PDB:`"$obj\VisageDLSS.pdb`" /DEBUG")
) -join " && "
cmd /c $cmd
if ($LASTEXITCODE) { throw "build failed" }
Write-Host "Built $addon"

# NVIDIA's DLSS runtime, signed, next to the exe.
$sl = "$root\third_party\streamline\bin\x64"
if (($Install -or $Package) -and -not (Test-Path "$sl\nvngx_dlss.dll")) { throw "nvngx_dlss.dll not found in $sl (unzip NVIDIA's Streamline 2.14.16 release there)" }

# Lays out the add-on and DLSS as they go in the game's Win64 folder.
function Copy-Runtime([string]$dest) {
    Copy-Item $addon $dest -Force
    Copy-Item "$sl\nvngx_dlss.dll" $dest -Force
}

if ($Install) {
    if (-not (Test-Path "$GameBin\$exe")) { throw "$exe not found in $GameBin (pass -GameBin)" }
    if (Get-Process ([IO.Path]::GetFileNameWithoutExtension($exe)) -ErrorAction SilentlyContinue) { throw "Close the game first." }
    Copy-Runtime $GameBin
    Write-Host "Installed to $GameBin"
}

if ($Package) {
    $version = [regex]::Match((Get-Content "$root\src\version.h" -Raw), 'RD_VERSION "([^"]+)"').Groups[1].Value
    $name = "VisageDLSS-$version"
    $stage = "$root\bin\release\$name"
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force "$stage\licenses" | Out-Null
    # The add-on and nvngx_dlss.dll go next to the game's shipping exe.
    Copy-Runtime $stage
    Copy-Item "$root\README.md", "$root\LICENSE", "$root\THIRD_PARTY_NOTICES.txt" $stage
    Copy-Item "$root\third_party\streamline\licenses\nvngx_dlss.license.txt" "$stage\licenses\NVIDIA-DLSS-LICENSE.txt"
    $zip = "$root\bin\release\$name.zip"
    if (Test-Path $zip) { Remove-Item -Force $zip }
    # Zip with forward-slash entry names (Compress-Archive in PowerShell 5.1 writes backslashes,
    # which some unzip tools mishandle: streamline\x.dll ended up as a file name).
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem $stage -Recurse -File | ForEach-Object {
            $entry = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entry,
                [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $archive.Dispose() }
    Write-Host "Packaged $zip"
    Get-ChildItem $stage -Recurse -File | ForEach-Object {
        "{0,-40} {1,-14} {2,12:N0}" -f $_.FullName.Substring($stage.Length + 1), $_.VersionInfo.FileVersion, $_.Length
    }
}
