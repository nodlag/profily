extends Node
## RAM data collector. Port of G_RamMonitor (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Godot mapping (the original used Unity's Profiler API):
##  - allocated -> Performance.MEMORY_STATIC (current static memory)
##  - reserved  -> Performance.MEMORY_STATIC_MAX (peak static memory)
##  - Mono (no GDScript equivalent) is replaced by VRAM
##    (Performance.RENDER_VIDEO_MEM_USED), a Godot-specific extra.

const BYTES_TO_MB := 1.0 / 1048576.0

## Current static memory, in MiB.
var allocated_ram := 0.0
## Peak static memory, in MiB.
var reserved_ram := 0.0
## Video memory in use (textures + buffers), in MiB.
var vram := 0.0

## MEMORY_STATIC/_MAX only report in debug builds; release exports return 0,
## so those two series are hidden and their labels show "n/a".
var ram_available := OS.is_debug_build()

var _release_warned := false


func _process(_delta: float) -> void:
	allocated_ram = Performance.get_monitor(Performance.MEMORY_STATIC) * BYTES_TO_MB
	reserved_ram = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) * BYTES_TO_MB
	vram = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * BYTES_TO_MB
	if not ram_available and not _release_warned:
		_release_warned = true
		push_warning("[Profily] Static memory monitors return 0 in release builds; the RAM module only shows VRAM.")
