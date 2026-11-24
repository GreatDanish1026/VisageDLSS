# VisageDLSS 1.0.0

ReShade add-on for **Visage** (SadSquare Studio, Unreal Engine 4.24, DirectX 11) that replaces the
game's TAA anti-aliasing with **NVIDIA DLSS**: **DLAA** at native resolution by default, or DLSS
upscaling from Quality to Ultra Performance. The game has no DLSS of its own.

Needs an NVIDIA RTX graphics card and ReShade 6.8 or later with add-on support.

## What it does

- **DLSS** (F9 to switch on and off, on by default): DLSS Super Resolution 310.9.16 in place of the
  game's TAA. Motion vectors are computed by the add-on from the depth buffer and the camera, plus
  the engine's own motion of moving objects.
- **DLSS mode**: Native / DLAA (default), Quality, Balanced, Performance or Ultra Performance, or
  "Game's resolution scale" (DLSS at whatever resolution scale the game uses). The upscaling modes
  set the engine's screen percentage while DLSS is on and give the game's value back when it's off.
- **DLSS model**: Automatic (default: K, M at Performance, L at Ultra Performance, as NVIDIA
  recommends), or K, J, L or M at every resolution, or NVIDIA's default. A DLSS override for the
  game in the NVIDIA App takes precedence.

Camera cuts keep the game's own TAA for that frame (the engine has no motion data then). The
game's depth of field has a temporal pass of its own; it's left alone. The game's own HDR output
works with the add-on (DLSS runs before tone mapping).

The overlay (ReShade's Add-ons tab, VisageDLSS) shows DLSS on/off, DLSS mode and DLSS model, with
the render and output size. Settings are saved in `ReShade.ini` under `[VisageDLSS]`.

## Install

1. Install ReShade 6.8 or later with full add-on support for `Visage-Win64-Shipping.exe`, in
   `Visage\Visage\Binaries\Win64` (DirectX 10/11/12).
2. Copy `VisageDLSS.addon64` and `nvngx_dlss.dll` from the release zip into that folder (the
   licence files can go along).
3. Start the game as usual (no launch option; the add-on stays off with `-dx12`). DLAA is on from
   the start. Open ReShade (Home key), Add-ons tab, VisageDLSS, to pick another DLSS mode or press
   F9 to compare with the game's TAA.

The zip includes NVIDIA's DLSS 310.9.16 runtime, signed by NVIDIA. Its licence is in `licenses`,
and attribution is in `THIRD_PARTY_NOTICES.txt`. To uninstall, delete the two files.

Tested with Steam build 6062332 at 3840x2160 (game HDR on) on an NVIDIA RTX 5080: DLAA and Quality,
switched live, and F9 on and off. Balanced, Performance and Ultra Performance use the same path but
weren't run with DLSS on. Log:
`VisageDLSS.log` next to the game's exe.

## Build

`.\build.ps1` (Visual Studio 2022 C++ tools, Windows SDK for `fxc`). `nvngx_dlss.dll` isn't in the
repository: unzip `bin\x64` of NVIDIA's Streamline 2.14.16 release into
`third_party\streamline\bin\x64`. `.\build.ps1 -Install` copies the add-on and `nvngx_dlss.dll` into
the game folder (game closed); `.\build.ps1 -Package` makes the release zip in `bin\release`.

## How it works

Built from the DirectX 11 part of StrayDLSS 1.2.2 (UE 4.27). `docs/FINDINGS.md` has the Visage
details: the TAA passes (found by their declared registers and bindings), the View uniform buffer
offsets (the same as in UE 4.25-4.27) and the test results. DLSS runs through NGX's Direct3D 11
interface at the TAA dispatch (`src/upscaler11.cpp`, `src/dlss11.cpp`), with the game's compute
bindings saved and put back, and the game's dispatch skipped. `ReShade.ini` `[VisageDLSS]
Dx11Capture=1` turns on a frame capture (F10, `VisageDLSS-DX11-frame-N.txt`), for finding the TAA
again after a game update. `tools/mdunwind.py` reads the stack of a crash dump.

StrayDLSS's DirectX 12 code (FSR, frame generation, Ray Reconstruction) is still in the source but
never runs in Visage, which ships DirectX 11 shaders only.
