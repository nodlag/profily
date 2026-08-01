# Parity Audit — Profily vs. Graphy 3.0.5

- **Audited:** 2026-07-25, Profily 1.0.0 (pre-release), against Graphy —
  Ultimate Stats Monitor v3.0.5 (Unity, MIT © 2018 Martín Pane).
- **Scope:** every runtime C# file, both shaders and the serialized prefab
  defaults of the original, compared against the GDScript port in
  `addons/profily/` — formula by formula, constant by constant.
- **Method:** seven independent review passes (graph shader + CPU plumbing,
  FPS, RAM, audio, manager/presets/hotkeys/singleton, debugger, advanced
  module + prefab defaults). Every flagged difference was re-verified against
  both sources before landing in this document. Runtime behavior was
  additionally exercised with the headless test suite (`tests/`) and
  screenshot probes in both Forward+ and Compatibility renderers.

A note on defaults: Graphy's effective defaults are the ones serialized in
`Prefab/[Graphy].prefab`, which override the C# field initializers (e.g. the
shipped FPS palette is teal/amber/coral, not the green/yellow/red found in
`GraphyManager.cs`). All default comparisons below are against the prefab.

## Verdict

Functional parity confirmed.

- The 12-preset table matches Unity's `SetPreset` switch in **all 48 cells**
  (12 presets × 4 modules), including the initial preset pointer (11 — the
  first toggle lands on preset 0) and the `% 12` wrap.
- The graph fragment shader is **step-for-step identical**: threshold color
  selection, gradient fill (`value − y > increment·4` →
  `alpha ·= y·0.3/value`), top cutoff, 0.02-wide average/threshold bars, 3%
  edge fades, and bit-identical premultiplied blending.
- Every serialized prefab default is **byte-comparable** in the port
  (thresholds 60/30, colors to 3 decimals, graph resolutions 150/150/81, text
  update rates 3/s, spectrum size 512, positions TOP_RIGHT / BOTTOM_LEFT,
  background (0, 0, 0, 0.333), UI scale 0.66, hotkeys Ctrl+G / Ctrl+H), and
  the port's two default sources (`profily_settings.gd` and the `@export`
  initializers) agree with each other field by field.

Three gaps found by the audit were fixed on the spot; the remaining
differences are deliberate and cataloged below.

## Fixed as a result of this audit

1. **Audio silence floor.** `lin_to_db_clamped()` in `audio_monitor.gd` used
   a `1e-7` epsilon (= −140 dB), so absolute silence rendered every
   spectrum/peak bar at 12.5% height where Unity renders 0. The epsilon is
   now `1e-8` (= exactly −160 dB, which normalizes to 0).
2. **Advanced panel refresh rate.** The dynamic lines (VRAM used, screen,
   window) refreshed at 1 Hz — the `G_AdvancedData.cs` code default — but the
   shipped prefab serializes `m_updateRate: 5`. `UPDATE_INTERVAL` is now
   0.2 s (5 Hz).
3. **`render_mode unshaded`.** The original shader declares `Lighting Off`;
   both Godot shaders now declare `unshaded` as well, so a `Light2D` whose
   layer range covers the overlay's CanvasLayer can never tint the graphs.

## Accepted differences

Observable behavior that intentionally differs from Graphy 3.0.5 — usually
because the original behavior was buggy, inconsistent, or un-Godot-like.
(The high-level adaptations — VRAM series, SCENE module, bus-peak dB, FPS
warmup, dynamic re-stacking, `keep_alive`, LIGHT auto-degradation — are
user-facing and live in the README's *Differences* section; the list below
covers the finer-grained deltas found by this audit.)

- **CANVAS graph backend (Godot-only).** `graph_shader_controller.gd` can
  draw the plot on the CPU as one canvas triangle batch instead of a
  ShaderMaterial, replicating `graph_full.gdshader` (threshold coloring,
  fill gradient, average/threshold bars, edge fade). It exists because
  Godot 4.7's Metal driver on iOS 26 mis-binds the `canvas_data` uniform
  buffer of custom canvas materials (160 bytes bound vs 272 expected),
  corrupting those draws and any drawn after them. `graph_backend = AUTO`
  (default) selects it only on iOS with the Metal driver. Known visual
  delta: the horizontal edge fade interpolates per vertex, so a column
  straddling the 3% fade boundary deviates by at most one column width.
  Graphy has no equivalent (Unity's UI material path was never broken).
- **Graph traces clear on hot-reload.** Changing a graph parameter at runtime
  (color, update rate, background…) rebuilds the FPS/RAM/SCENE graph buffers
  from zero; the trace refills within ~2.5 s at 60 fps / 150 points. Unity
  preserved the trace when the resolution was unchanged.
- **Hotkeys while hidden.** With Profily hidden (Ctrl+H), only the show/hide
  hotkey responds. Unity also processes the preset hotkey while hidden, which
  corrupts its own state (modules reappear while `m_active` stays false, and
  the next enable restores OFF — a blank overlay that reads as active).
- **Exact modifier matching.** A hotkey fires only when its key is pressed
  with exactly the configured Ctrl/Alt state. In Unity, extra modifiers do
  not block a hotkey (Ctrl+Alt+G triggers a Ctrl+G binding) and the modifier
  may be pressed after the main key.
- **Round instead of truncate.** Unity truncates fractional values via
  integer casts when displaying AVG / 1% low, when sampling graph points and
  on the dB readout; the port rounds. Displayed values can read one unit
  higher than Unity's about half the time, and a value just under a threshold
  can be colored by the other side of it. The port is internally consistent
  (text and graph agree); the original was not (its FPS monitor rounds while
  its FPS graph truncates).
- **Empty-condition debug packets never fire.** In Unity, a packet with zero
  conditions in ALL mode (the default) fires unconditionally (`0 >= 0`).
- **`AUDIO_DB` debugger fallback.** With no audio module available the
  variable reads −80 dB (silence floor); Unity returns 0 (full scale), which
  would trip any `> −x` condition.
- **Runtime property writes preserve module states.** Setting e.g.
  `background` or `profily_mode` at runtime keeps whatever states a
  preset/hotkey applied; Unity snaps every module back to its
  Inspector-serialized state.
- **Advanced module content.** The VRAM line shows VRAM *used* (Godot exposes
  no total-VRAM API) instead of Unity's total graphics memory; refresh-rate
  Hz and dpi live on the Screen line rather than the Window line; the XR line
  is computed once at init; the line order differs; there is no shader-level
  or device-type field (no Godot equivalent). Added lines: Godot version,
  rendering method/driver, adapter vendor.
- **No in-graph watermarks.** The faint "fps" / "audio" captions Unity
  renders inside the FULL graphs are not reproduced.
- **Config ranges.** Text update rates accept 1–60/s (Unity: 1–200); the
  spectrum size is restricted to Godot's analyzer FFT enum (256–4096, with a
  512 fallback) instead of any power of two in 64–8192.
- **`spectrum` API shape.** The manager exposes the displayed, dB-normalized
  bars (default 81); Unity exposed the raw linear FFT bins.

## Upstream Graphy 3.0.5 bugs fixed in the port

Found while auditing; the port deliberately does the right thing in each
case:

1. **The FPS graph's average line never renders in Unity** —
   `AverageFPS / m_highestFps` is integer division, pinning the line to the
   bottom of the graph. The port divides in float; the white average line
   actually works.
2. **The FPS average is biased low while the ring buffer fills** (the
   original writes from index 1 and averages a stale zero slot), and the 1%
   low divides by a fixed 10 even when fewer samples exist. The port is exact
   from the first sample.
3. **BASIC state leaks the "0.1%" label in Unity** — it is missing from the
   prefab's `m_nonBasicTextGameObjects`, so it floats outside the compact
   background. The port hides it.
4. **LIGHT mode breaks above 128 points in Unity** — it uploads a capped
   128-float array but tells the shader the configured length, so the shader
   reads out of bounds. The port clamps the resolution to the compiled array
   size.
5. **`Ram_Reserved` and `Ram_Mono` debugger variables both return allocated
   RAM in Unity.** The port maps every variable to its real source (and
   renames `Fps_Min`/`Fps_Max` to `FPS_1_PERCENT`/`FPS_01_PERCENT` — what
   they actually measure).
6. **`RemoveFirstDebugPacketWithId` / `AddCallbackToFirstDebugPacketWithId`
   throw in Unity** when the id does not exist (LINQ `.First()`); the port
   returns null / no-ops.
7. **The shader reads one slot past the values array at `x = 1.0` in Unity**;
   the port clamps the sample index.

## Not ported (and why)

| Original | Reason |
|---|---|
| `m_keepAlive` / `DontDestroyOnLoad` | A Godot autoload already persists across scene changes. |
| `G_IntString` / `G_FloatString` allocation-free caches | Formatting at ≤3 updates/s is noise in GDScript; the per-frame hot path stays purely numeric. |
| `FFTWindow` selection (Blackman) | Godot's `AudioEffectSpectrumAnalyzer` exposes no window function. |
| `PixelSnap`, `_MainTex` sprite path in the shader | The graph sprite is a pure-white 2×2 texture — an identity multiply; a plain `ColorRect` is equivalent. Pixel snap was never enabled at runtime. |
| `[Graphy] VR.prefab` (world-space canvas variant) | No direct Godot equivalent; the advanced module reports the XR render-target size instead. |
| Custom editor scripts (`GraphyManagerEditor`, `GraphyDebuggerEditor`, `GraphyMenuItem`, `GraphyEditorStyle`) | Replaced by the `@export_group` inspector layout (same group order as Unity's custom inspector), the EditorPlugin (autoload + Project Settings registration) and code-only debug packets. |
| Inspector-authored debug packet list | Packets are created through the runtime API (`add_new_debug_packet()` / `ProfilyDebugCondition.of()`); nothing is serialized. |
| `OnApplicationFocus` parameter refresh | Nothing in the port is invalidated by focus loss. |
| SafeArea per-axis opt-outs (`m_conformX/Y`) | The port always conforms both axes. |
| Northwest-Bold brand font | Proprietary license; the runtime UI only ever used Roboto. |

## Verified parity highlights

**Shader / graph plumbing** — uniform set, defaults (thresholds 0.5/0.25,
white colors, average 0), array sizes 512 (full) / 128 (light), the full
fragment algorithm in the same order with the same strict comparisons,
per-instance material creation, full-array uploads with a length uniform,
resolution clamped to 10..array size.

**FPS** — 1024-sample ring; current FPS = `round(1 / unscaled_delta)`; AVG =
window mean; 1% low = mean of the worst samples of the sorted window (10 at
full buffer; the sorted mirror is maintained incrementally per sample instead
of re-sorting a copy each frame like the original — the order and every
derived value are identical); 0.1% low = the single worst; text at 3 Hz showing its
own interval average and `%.1f` ms; per-label threshold coloring (the fps and
ms labels colored by the interval fps, AVG/1%/0.1% by their own values);
graph shift-left with a decaying ceiling (instant rise, −1/frame decay,
floor 1) normalizing points, average and thresholds; BASIC keeps only the
big number + caption.

**RAM** — three overlaid monochrome series in MB (`bytes / 1048576`),
integer-MB labels at 3 Hz colored per series, thresholds/average disabled,
TEXT ≡ BASIC, monitor keeps sampling in BACKGROUND and stops in OFF. VRAM
replaces Mono (see README); normalization uses the max of the three windows
(VRAM can exceed the static peak — Unity normalized all series by the
reserved max).

**Audio** — 81 bars over the same Nyquist span (`mix_rate/2 · 486/512`);
gap shaping identical (`(i+1) % 3 == 0 && i > 1` → the triple's average
written to bars *i* and *i−1*, bar *i−2* = −1 → transparent gap through the
same shader cutoff); normalization `(clamp(20·log10 x, −160, 0) + 160) /
160`; peak-hold decay `peak − peak·delta·2` in the linear domain; peaks
layer at 50% alpha (the prefab's tint); dB readout clamped −80..0 at 3 Hz.

**Manager** — enums identical in names, order and values; 12-preset table
48/48; preset pointer starts at `FPS_BASIC_ADVANCED_FULL` (11) so the first
toggle lands on preset 0; hotkeys Ctrl+G / Ctrl+H without consuming input;
corner math (TOP_RIGHT mirrors X, BOTTOM_* mirror Y, FREE untouched; the
advanced module positioned independently with per-corner text alignment);
the singleton keeps the original instance and frees the newcomer;
enable/disable restores each module's previous state; background flag and
color propagate to every module; `enabled_on_startup` semantics.

**Debugger** — comparers `<, <=, ≈, >=, >` in Unity's order; ALL/ANY
evaluation; packet defaults (active, execute-once, init/execute sleep 2 s);
timing gates (arm after the init sleep, re-arm after the execute sleep when
not once); execute-once packets removed the same frame they fire; screenshot
saved as `name_timestamp.png`; public API name-for-name
(`add_new_debug_packet`, `get/remove_first/all_packets_with_id`,
`add_callback_to_*`).

## File coverage

| Graphy (Ref) | Profily | Result |
|---|---|---|
| Runtime/GraphyManager.cs | scripts/profily_manager.gd, profily_types.gd, profily_settings.gd | parity + documented adaptations |
| Runtime/GraphyDebugger.cs | scripts/debugger/profily_debugger.gd, profily_debug_packet.gd, profily_debug_condition.gd | parity + bug fixes 5–6 |
| Runtime/Fps/G_FpsManager.cs | scripts/fps/fps_manager.gd | parity |
| Runtime/Fps/G_FpsMonitor.cs | scripts/fps/fps_monitor.gd | parity + bug fix 2 |
| Runtime/Fps/G_FpsText.cs | scripts/fps/fps_text.gd | parity (round vs truncate) |
| Runtime/Fps/G_FpsGraph.cs | scripts/fps/fps_graph.gd | parity + bug fixes 1, 4 |
| Runtime/Ram/G_RamManager.cs | scripts/ram/ram_manager.gd | parity |
| Runtime/Ram/G_RamMonitor.cs | scripts/ram/ram_monitor.gd | adapted (VRAM series, release fallback) |
| Runtime/Ram/G_RamText.cs | scripts/ram/ram_text.gd | parity |
| Runtime/Ram/G_RamGraph.cs | scripts/ram/ram_graph.gd | parity (normalization per VRAM adaptation) |
| Runtime/Audio/G_AudioManager.cs | scripts/audio/audio_manager.gd | parity |
| Runtime/Audio/G_AudioMonitor.cs | scripts/audio/audio_monitor.gd | adapted (bus analyzer + peak dB) |
| Runtime/Audio/G_AudioText.cs | scripts/audio/audio_text.gd | parity (round vs truncate) |
| Runtime/Audio/G_AudioGraph.cs | scripts/audio/audio_graph.gd | parity |
| Runtime/Advanced/G_AdvancedData.cs | scripts/advanced/advanced_module.gd | parity + Godot data sources |
| Runtime/Shader/G_GraphShader.cs | scripts/graph_shader_controller.gd | parity + CANVAS fallback backend |
| Runtime/Graph/G_Graph.cs | folded into the *_graph.gd scripts | structural only |
| Shaders/GraphStandard.shader | shaders/graph_full.gdshader | parity + bug fix 7 |
| Shaders/GraphMobile.shader | shaders/graph_light.gdshader | parity |
| Runtime/UI/G_SafeArea.cs | scripts/safe_area.gd | parity (event-driven refresh) |
| Runtime/UI/IMovable.cs, IModifiableState.cs | scripts/profily_module.gd virtuals | parity |
| Runtime/Util/G_Singleton.cs | duplicate guard in profily_manager.gd | parity (same survivor + warning) |
| Runtime/Util/G_ExtensionMethods.cs | not needed (direct `visible` writes) | n/a |
| Runtime/Util/G_Intstring.cs, G_FloatString.cs | not ported | see *Not ported* |
| Editor/*.cs (4 files) | plugin.gd + @export groups | see *Not ported* |
| Prefab/[Graphy].prefab | profily.tscn + defaults in settings/@exports | parity (defaults table) |
| Prefab/Internal/*.prefab (4 modules) | scenes/*.tscn | parity (sizes 330×172.6 / 166.3 / 102.5, auto-width advanced) |
| Prefab/[Graphy] VR.prefab | not ported | see *Not ported* |
| — | scripts/scene/* + scenes/scene_module.tscn | Godot-only addition (see README) |

---

Original **Graphy**: MIT © 2018 [Martín Pane](https://github.com/Tayx94/graphy).
**Profily** (Godot port): MIT © 2026 Javier Garrido (nodlag).
