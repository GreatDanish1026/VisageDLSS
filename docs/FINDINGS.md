# VisageDLSS findings

Visage (SadSquare Studio), Steam 594330, build 6062332. Exe
`Visage\Binaries\Win64\Visage-Win64-Shipping.exe` (55,492,096 bytes, PE timestamp 0x5ffb673f, no
`.bind` section: not encrypted). **UE 4.24** (`++UE4+Release-4.24`). Paks v8, index not encrypted.

The code comes from StrayDLSS (UE 4.27, DX11 and DX12; not public); only what differs or was
checked for Visage is here.

## Renderer

`DefaultEngine.ini` (pakchunk0): `TargetedRHIs=PCD3D_SM5` / `PCD3D_SM4` only, no `r.RayTracing`,
`r.DefaultFeature.AntiAliasing=2` (TAA), `r.BasePassOutputsVelocity=False`. So DirectX 11, no ray
tracing; the add-on stays off when started with `-dx12` (untested, nothing registered).

## Console variables

Same layout as UE 4.25 (checked offline on the exe): IConsoleManager singleton RVA 0x3221c90,
FindConsoleVariable +0xb0 (1695 call sites), CallAllConsoleVariableSinks +0x50,
IConsoleVariable::Set +0x80 with SetBy 0x09000000 (console, 42 sites) / 0x08000000 (code, 29).
`cvars.hpp` and the game-thread hook work unchanged. At start the present thread reads
r.ScreenPercentage 80 (set by scalability: sg.ResolutionQuality=80), but the game thread reads 100
once the game is running (the game's own video settings), and the game renders at 100%.

## TAA (frame capture 2026-11-24, 3840x2160, DX11)

Post-processing order: Diaphragm DOF (cs5dc5e832 setup, **cs93596adb DOF temporal pass**,
gather/recombine, cs661a104b writes scene colour), then the TAA:

- **csc01cd60e** (100%): t0 exposure 1x1 rgba32f, t1 scene colour rgba16f, t2 depth r32g8x24,
  t3 velocity rg16unorm, t4 history rgba16f, u0 output rgba16f; b0 pass parameters (4096-byte
  buffer), b1 View.
- **cs878314a0** (TAAU, below 100% with r.TemporalAA.Upsampling=1): same bindings, colour at render
  size, output at 4K.

UE 4.24's TAA declares **t0-t4** and u0: UE 4.25+ adds a stencil input (history at t5), which is
what StrayDLSS's register check required, so 0.0.1 never found it. `CodeTaaSrvCount` accepts both
(5 or 6 inputs, history = the last). The DOF temporal pass and two TAAU-time DOF passes
(csfea5d786, cs0cb4a1a0) have the same registers; requiring colour, depth and velocity at one size
rules them out (logged as "TAA-shaped ... not taken"). A shader is ruled out only after 30
mismatching frames: a camera cut binds a 1x1 velocity.

## View uniform buffer

At b1. The run-time layout search (`FindViewLayout`, UE 4.25's order) found exactly UE 4.25's
offsets: ViewToClip jitter row 480, ClipToPrevClip 1952, TemporalAAJitter 2016, ViewRectMin 2064,
ViewSizeAndInvSize 2080.

## Tests

- 0.0.1 (2026-11-24): loaded, cvars and hook fine, DLSS never ran (TAA not recognised). Capture
  above.
- 0.0.2 (2026-11-24): csc01cd60e taken 2.7 s after start, View found, NGX D3D11 ready, DLAA
  3840x2160 from the first frame (jitter 0.125, 0.375 px); F9 and overlay toggles; Quality: TAAU
  cs878314a0 taken, DLSS 2561x1441 -> 3840x2160. No frame kept by the game's TAA, clean exit. User:
  looks good.
- 1.0.0: on by default in DLAA, DX11 only, ships the add-on and nvngx_dlss.dll alone.
