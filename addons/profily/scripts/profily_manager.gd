class_name ProfilyManager
extends CanvasLayer
## Profily — FPS/RAM/audio/system/scene stats monitor for Godot 4.6+.
##
## Port of "Graphy - Ultimate Stats Monitor" (Unity, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
## This node coordinates the modules and exposes the public API. It works in
## two ways, like the original's prefab did:
##  - As the `Profily` autoload the plugin registers when enabled.
##  - Dropping addons/profily/profily.tscn into any scene (no plugin needed);
##    access it through [member ProfilyManager.instance].
## The first instance to enter the tree wins; extra copies remove themselves
## (port of the original G_Singleton behaviour).
## Every configuration property hot-reloads its module when assigned.

signal initialized
signal active_toggled(active: bool)
signal preset_changed(preset: ProfilyTypes.ModulePreset)
signal module_state_changed(module: ProfilyTypes.ModuleType, state: ProfilyTypes.ModuleState)

# Aliases of the shared enums, so user code can write Profily.ModuleState.FULL
# just like the original exposed GraphyManager.ModuleState.
const Mode := ProfilyTypes.Mode
const ModuleType := ProfilyTypes.ModuleType
const ModuleState := ProfilyTypes.ModuleState
const ModulePosition := ProfilyTypes.ModulePosition
const ModulePreset := ProfilyTypes.ModulePreset
const GraphBackend := ProfilyTypes.GraphBackend

const AudioMonitor := preload("audio/audio_monitor.gd")
const SafeArea := preload("safe_area.gd")

## Side margin from the corner (the baked |x| of the original prefab).
const SIDE_MARGIN := 10.0

## Stacking order of the corner-shared module group.
const GROUP_ORDER: Array[ProfilyTypes.ModuleType] = [
	ModuleType.FPS, ModuleType.RAM, ModuleType.AUDIO, ModuleType.SCENE,
]

## Vertical gap between stacked modules (the original prefab used 6-8 px).
const MODULE_SPACING := 8.0

## States applied to [FPS, RAM, AUDIO, ADVANCED] by each preset (the exact 12
## combos of the original; SCENE keeps its own state on purpose).
const _PRESET_STATES: Dictionary = {
	ModulePreset.FPS_BASIC:
		[ModuleState.BASIC, ModuleState.OFF, ModuleState.OFF, ModuleState.OFF],
	ModulePreset.FPS_TEXT:
		[ModuleState.TEXT, ModuleState.OFF, ModuleState.OFF, ModuleState.OFF],
	ModulePreset.FPS_FULL:
		[ModuleState.FULL, ModuleState.OFF, ModuleState.OFF, ModuleState.OFF],
	ModulePreset.FPS_TEXT_RAM_TEXT:
		[ModuleState.TEXT, ModuleState.TEXT, ModuleState.OFF, ModuleState.OFF],
	ModulePreset.FPS_FULL_RAM_TEXT:
		[ModuleState.FULL, ModuleState.TEXT, ModuleState.OFF, ModuleState.OFF],
	ModulePreset.FPS_FULL_RAM_FULL:
		[ModuleState.FULL, ModuleState.FULL, ModuleState.OFF, ModuleState.OFF],
	ModulePreset.FPS_TEXT_RAM_TEXT_AUDIO_TEXT:
		[ModuleState.TEXT, ModuleState.TEXT, ModuleState.TEXT, ModuleState.OFF],
	ModulePreset.FPS_FULL_RAM_TEXT_AUDIO_TEXT:
		[ModuleState.FULL, ModuleState.TEXT, ModuleState.TEXT, ModuleState.OFF],
	ModulePreset.FPS_FULL_RAM_FULL_AUDIO_TEXT:
		[ModuleState.FULL, ModuleState.FULL, ModuleState.TEXT, ModuleState.OFF],
	ModulePreset.FPS_FULL_RAM_FULL_AUDIO_FULL:
		[ModuleState.FULL, ModuleState.FULL, ModuleState.FULL, ModuleState.OFF],
	ModulePreset.FPS_FULL_RAM_FULL_AUDIO_FULL_ADVANCED_FULL:
		[ModuleState.FULL, ModuleState.FULL, ModuleState.FULL, ModuleState.FULL],
	ModulePreset.FPS_BASIC_ADVANCED_FULL:
		[ModuleState.BASIC, ModuleState.OFF, ModuleState.OFF, ModuleState.FULL],
}

## The live ProfilyManager (equivalent of GraphyManager.Instance in the
## original). Works both with the autoload and with a scene-dropped instance:
## `ProfilyManager.instance.current_fps`.
static var instance: ProfilyManager = null

# --- Configuration ---
# Editable per instance in the Inspector (parity with the original
# GraphyManager custom editor) and hot-reloadable at runtime through the
# same properties. With settings_source = PROJECT_SETTINGS, any profily/*
# key present in Project Settings (the plugin registers them all when
# enabled) overrides the Inspector values on ready.

## Where the configuration is read from when Profily enters the tree.
## PROJECT_SETTINGS: profily/* keys override the Inspector values when they
## exist (the plugin/autoload flow; without the plugin the Inspector values
## still apply). INSPECTOR: only the values serialized in the scene are used.
@export var settings_source := ProfilyTypes.SettingsSource.PROJECT_SETTINGS

@export_group("General")
## Show Profily as soon as it enters the tree (the hotkey toggles it later).
@export var enabled_on_startup := true
## FULL allows graphs of up to 512 points; LIGHT caps them at 128 for GPUs
## with tight uniform limits (parity with Graphy's Standard/Mobile shaders).
@export var profily_mode: ProfilyTypes.Mode = ProfilyTypes.Mode.FULL:
	set(value):
		profily_mode = value
		_refresh_all_modules()
## How graphs are drawn. AUTO uses the CPU CANVAS fallback on iOS with the
## Metal driver (whose custom canvas materials are broken in Godot 4.7) and
## the Graphy-parity SHADER path everywhere else.
@export var graph_backend: ProfilyTypes.GraphBackend = ProfilyTypes.GraphBackend.AUTO:
	set(value):
		graph_backend = value
		_refresh_all_modules()
@export var background := true:
	set(value):
		background = value
		_refresh_all_modules()
@export var background_color := Color(0.0, 0.0, 0.0, 0.333333):
	set(value):
		background_color = value
		_refresh_all_modules()
## CanvasLayer index the overlay renders on (128 = above almost everything).
@export_range(1, 128) var canvas_layer := 128:
	set(value):
		canvas_layer = value
		layer = value
## Global UI scale (0.66 matches the original's CanvasScaler setup).
@export_range(0.2, 3.0, 0.01) var ui_scale := 0.66:
	set(value):
		ui_scale = maxf(0.05, value)
		_update_layout()
## Corner shared by the stacked FPS/RAM/AUDIO/SCENE group.
@export var graph_modules_position := ProfilyTypes.ModulePosition.TOP_RIGHT:
	set(value):
		graph_modules_position = value
		_reposition_all()
@export var graph_modules_offset := Vector2.ZERO:
	set(value):
		graph_modules_offset = value
		_reposition_all()

@export_group("Hotkeys")
@export var hotkeys_enabled := true
## Rotates through the 12 module presets (Ctrl+G by default).
@export var toggle_mode_key: Key = KEY_G
@export var toggle_mode_ctrl := true
@export var toggle_mode_alt := false
## Shows/hides Profily entirely (Ctrl+H by default).
@export var toggle_active_key: Key = KEY_H
@export var toggle_active_ctrl := true
@export var toggle_active_alt := false

@export_group("FPS")
@export var fps_module_state := ProfilyTypes.ModuleState.FULL:
	set(value):
		fps_module_state = value
		set_module_mode(ProfilyTypes.ModuleType.FPS, value)
## At or above this FPS the readings use the "good" color.
@export_range(1, 300) var good_fps_threshold := 60:
	set(value):
		good_fps_threshold = maxi(1, value)
		_refresh_module(ProfilyTypes.ModuleType.FPS)
@export var good_fps_color := Color(0.2083, 0.6792, 0.6219):
	set(value):
		good_fps_color = value
		_refresh_module(ProfilyTypes.ModuleType.FPS)
## At or above this FPS (and below the good threshold) the readings use the
## "caution" color; below it they use the "critical" color.
@export_range(1, 300) var caution_fps_threshold := 30:
	set(value):
		caution_fps_threshold = maxi(1, value)
		_refresh_module(ProfilyTypes.ModuleType.FPS)
@export var caution_fps_color := Color(0.9137, 0.7686, 0.4157):
	set(value):
		caution_fps_color = value
		_refresh_module(ProfilyTypes.ModuleType.FPS)
@export var critical_fps_color := Color(0.9059, 0.4353, 0.3176):
	set(value):
		critical_fps_color = value
		_refresh_module(ProfilyTypes.ModuleType.FPS)
## Points shown by the graph (LIGHT mode caps it at 128).
@export_range(10, 300) var fps_graph_resolution := 150:
	set(value):
		fps_graph_resolution = clampi(value, 10, 300)
		_refresh_module(ProfilyTypes.ModuleType.FPS)
## Text refreshes per second.
@export_range(1, 60) var fps_text_update_rate := 3:
	set(value):
		fps_text_update_rate = clampi(value, 1, 60)
		_refresh_module(ProfilyTypes.ModuleType.FPS)

@export_group("RAM")
@export var ram_module_state := ProfilyTypes.ModuleState.FULL:
	set(value):
		ram_module_state = value
		set_module_mode(ProfilyTypes.ModuleType.RAM, value)
@export var allocated_ram_color := Color(0.9451, 0.3569, 0.7098):
	set(value):
		allocated_ram_color = value
		_refresh_module(ProfilyTypes.ModuleType.RAM)
@export var reserved_ram_color := Color(0.9961, 0.8941, 0.251):
	set(value):
		reserved_ram_color = value
		_refresh_module(ProfilyTypes.ModuleType.RAM)
@export var vram_color := Color(0.0, 0.7333, 0.9765):
	set(value):
		vram_color = value
		_refresh_module(ProfilyTypes.ModuleType.RAM)
@export_range(10, 300) var ram_graph_resolution := 150:
	set(value):
		ram_graph_resolution = clampi(value, 10, 300)
		_refresh_module(ProfilyTypes.ModuleType.RAM)
@export_range(1, 60) var ram_text_update_rate := 3:
	set(value):
		ram_text_update_rate = clampi(value, 1, 60)
		_refresh_module(ProfilyTypes.ModuleType.RAM)

@export_group("Audio")
@export var audio_module_state := ProfilyTypes.ModuleState.FULL:
	set(value):
		audio_module_state = value
		set_module_mode(ProfilyTypes.ModuleType.AUDIO, value)
## Bus the spectrum analyzer is attached to while the module is active.
@export var audio_bus_name := "Master":
	set(value):
		audio_bus_name = value
		_refresh_module(ProfilyTypes.ModuleType.AUDIO)
@export var audio_graph_color := Color.WHITE:
	set(value):
		audio_graph_color = value
		_refresh_module(ProfilyTypes.ModuleType.AUDIO)
## Spectrum bars (multiples of 3 look best with the gap effect).
@export_range(10, 300) var audio_graph_resolution := 81:
	set(value):
		audio_graph_resolution = clampi(value, 10, 300)
		_refresh_module(ProfilyTypes.ModuleType.AUDIO)
## FFT size of the spectrum analyzer.
@export_enum("256:256", "512:512", "1024:1024", "2048:2048", "4096:4096")
var audio_spectrum_size := 512:
	set(value):
		audio_spectrum_size = value
		_refresh_module(ProfilyTypes.ModuleType.AUDIO)
@export_range(1, 60) var audio_text_update_rate := 3:
	set(value):
		audio_text_update_rate = clampi(value, 1, 60)
		_refresh_module(ProfilyTypes.ModuleType.AUDIO)

@export_group("Advanced")
@export var advanced_module_state := ProfilyTypes.ModuleState.FULL:
	set(value):
		advanced_module_state = value
		set_module_mode(ProfilyTypes.ModuleType.ADVANCED, value)
## The advanced panel anchors independently from the graph modules group.
@export var advanced_module_position := ProfilyTypes.ModulePosition.BOTTOM_LEFT:
	set(value):
		advanced_module_position = value
		_reposition_all()
@export var advanced_module_offset := Vector2.ZERO:
	set(value):
		advanced_module_offset = value
		_reposition_all()

@export_group("Scene (Godot extra)")
## Godot-specific module (draw calls, objects, nodes, physics); OFF by
## default so the out-of-the-box look matches the original Graphy.
@export var scene_module_state := ProfilyTypes.ModuleState.OFF:
	set(value):
		scene_module_state = value
		set_module_mode(ProfilyTypes.ModuleType.SCENE, value)
@export var scene_graph_color := Color(1.0, 0.65, 0.25):
	set(value):
		scene_graph_color = value
		_refresh_module(ProfilyTypes.ModuleType.SCENE)
@export_range(10, 300) var scene_graph_resolution := 150:
	set(value):
		scene_graph_resolution = clampi(value, 10, 300)
		_refresh_module(ProfilyTypes.ModuleType.SCENE)
@export_range(1, 60) var scene_text_update_rate := 3:
	set(value):
		scene_text_update_rate = clampi(value, 1, 60)
		_refresh_module(ProfilyTypes.ModuleType.SCENE)

@export_group("Debugger")
@export var debugger_enabled := true:
	set(value):
		debugger_enabled = value
		if _ready_done and debugger != null:
			debugger.set_process(value)

## False while disabled via toggle_active()/disable() (Ctrl+H).
var is_active := true

## Unscaled seconds of the last frame, measured with ticks so that neither
## Engine.time_scale nor tree pauses distort Profily's update cadence.
## The manager processes before its children, so modules can read it directly.
var unscaled_delta := 0.0

# --- Live data (read-only, mirroring the original GraphyManager getters) ---

var current_fps: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.FPS, &"current_fps")
var average_fps: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.FPS, &"average_fps")
var one_percent_fps: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.FPS, &"one_percent_fps")
var zero1_percent_fps: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.FPS, &"zero1_percent_fps")
var allocated_ram: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.RAM, &"allocated_ram")
var reserved_ram: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.RAM, &"reserved_ram")
var vram: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.RAM, &"vram")
var max_db: float:
	get:
		var audio_monitor := _audio_monitor()
		return audio_monitor.max_db if audio_monitor != null else -80.0
var spectrum: PackedFloat32Array:
	get:
		var audio_monitor := _audio_monitor()
		return audio_monitor.spectrum if audio_monitor != null else PackedFloat32Array()
var draw_calls: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.SCENE, &"draw_calls")
var node_count: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.SCENE, &"node_count")
var orphan_node_count: float:
	get: return _monitor_float(ProfilyTypes.ModuleType.SCENE, &"orphan_node_count")

var _module_preset: ProfilyTypes.ModulePreset = ProfilyTypes.ModulePreset.FPS_BASIC_ADVANCED_FULL
var _mode_degraded_warned := false
var _backend_fallback_warned := false
var _ready_done := false
var _is_duplicate := false
var _last_ticks_usec := 0
var _has_last_ticks := false

## The condition-based alert system (Profily.debugger.add_new_debug_packet…).
@onready var debugger: ProfilyDebugger = get_node_or_null("Debugger")

@onready var _safe_area: SafeArea = $SafeArea

# Modules are resolved leniently: during phased development (and if a user
# deletes a module they don't want) everything else keeps working.
@onready var _modules: Dictionary = {
	ProfilyTypes.ModuleType.FPS: get_node_or_null("SafeArea/FpsModule"),
	ProfilyTypes.ModuleType.RAM: get_node_or_null("SafeArea/RamModule"),
	ProfilyTypes.ModuleType.AUDIO: get_node_or_null("SafeArea/AudioModule"),
	ProfilyTypes.ModuleType.ADVANCED: get_node_or_null("SafeArea/AdvancedModule"),
	ProfilyTypes.ModuleType.SCENE: get_node_or_null("SafeArea/SceneModule"),
}


func _enter_tree() -> void:
	# Singleton guard (port of G_Singleton): if a Profily already lives in the
	# tree — e.g. the plugin autoload plus a scene-dropped copy — the newcomer
	# removes itself so there is never a double overlay or a second audio
	# analyzer on the bus.
	if instance != null and instance != self:
		_is_duplicate = true
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		push_warning("[Profily] Another Profily instance is already active; removing this one.")
		queue_free()
		return
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if _is_duplicate:
		return
	if settings_source == ProfilyTypes.SettingsSource.PROJECT_SETTINGS:
		_load_settings()
	layer = canvas_layer
	get_viewport().size_changed.connect(_update_layout)
	_init_modules()
	if debugger != null:
		debugger.init(self)
	_ready_done = true
	_update_layout()
	if not enabled_on_startup:
		disable()
	initialized.emit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _has_last_ticks and now > _last_ticks_usec:
		unscaled_delta = float(now - _last_ticks_usec) / 1_000_000.0
	_has_last_ticks = true
	_last_ticks_usec = now


func _input(event: InputEvent) -> void:
	if not hotkeys_enabled:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# The event is intentionally not consumed (parity with the original).
	# While disabled, only the show/hide hotkey responds.
	if is_active and _matches_hotkey(key, toggle_mode_key, toggle_mode_ctrl, toggle_mode_alt):
		toggle_modes()
	elif _matches_hotkey(key, toggle_active_key, toggle_active_ctrl, toggle_active_alt):
		toggle_active()


# --- Public API ---

## Sets the presentation state of one module (port of SetModuleMode).
func set_module_mode(module_type: ProfilyTypes.ModuleType, state: ProfilyTypes.ModuleState) -> void:
	if not _ready_done:
		return # During _load_settings the state setters only store the value.
	var module: ProfilyModule = _modules.get(module_type)
	if module == null:
		return
	module.set_state(state)
	# Re-stack: hidden or compacted modules must not leave holes behind.
	_reposition_all()
	module_state_changed.emit(module_type, state)


## Moves the FPS/RAM/AUDIO/SCENE stacked group, or the ADVANCED module, to a
## corner (port of SetModulePosition: graph modules share their position).
func set_module_position(
	module_type: ProfilyTypes.ModuleType,
	module_position: ProfilyTypes.ModulePosition,
) -> void:
	if module_type == ProfilyTypes.ModuleType.ADVANCED:
		advanced_module_position = module_position
	else:
		graph_modules_position = module_position


## Applies one of the 12 original preset combos to FPS/RAM/AUDIO/ADVANCED.
func set_preset(preset: ProfilyTypes.ModulePreset) -> void:
	if not _PRESET_STATES.has(preset):
		return
	_module_preset = preset
	var states: Array = _PRESET_STATES[preset]
	set_module_mode(ProfilyTypes.ModuleType.FPS, int(states[0]) as ProfilyTypes.ModuleState)
	set_module_mode(ProfilyTypes.ModuleType.RAM, int(states[1]) as ProfilyTypes.ModuleState)
	set_module_mode(ProfilyTypes.ModuleType.AUDIO, int(states[2]) as ProfilyTypes.ModuleState)
	set_module_mode(ProfilyTypes.ModuleType.ADVANCED, int(states[3]) as ProfilyTypes.ModuleState)
	preset_changed.emit(preset)


func current_preset() -> ProfilyTypes.ModulePreset:
	return _module_preset


## Advances to the next preset, wrapping around (the Ctrl+G hotkey action).
## The pointer starts at the last preset, so the first toggle lands on 0.
func toggle_modes() -> void:
	var next := (int(_module_preset) + 1) % _PRESET_STATES.size()
	set_preset(next as ProfilyTypes.ModulePreset)


## Hides Profily entirely and stops every monitor (port of Disable).
func disable() -> void:
	if not is_active:
		return
	is_active = false
	for module_type: ProfilyTypes.ModuleType in _modules:
		var module: ProfilyModule = _modules[module_type]
		if module != null:
			module.set_state(ProfilyTypes.ModuleState.OFF)
	visible = false
	active_toggled.emit(false)


## Restores every module to its state previous to disable() (port of Enable).
func enable() -> void:
	if is_active:
		return
	is_active = true
	visible = true
	for module_type: ProfilyTypes.ModuleType in _modules:
		var module: ProfilyModule = _modules[module_type]
		if module != null:
			module.restore_previous_state()
	_reposition_all()
	active_toggled.emit(true)


## The Ctrl+H hotkey action.
func toggle_active() -> void:
	if is_active:
		disable()
	else:
		enable()


## Convenience shortcut for Profily.debugger.add_packet().
func add_debug_packet(packet: ProfilyDebugPacket) -> void:
	if debugger != null:
		debugger.add_packet(packet)


## The mode graphs must compile for: FULL degrades to LIGHT on mobile/web
## compatibility renderers, whose uniform limits the 512-float array can
## exceed (same remedy the original Graphy documents for its Mobile shader).
func effective_mode() -> ProfilyTypes.Mode:
	if profily_mode == ProfilyTypes.Mode.FULL \
			and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
			and (OS.has_feature("mobile") or OS.has_feature("web")):
		if not _mode_degraded_warned:
			_mode_degraded_warned = true
			push_warning("[Profily] FULL mode degraded to LIGHT (compatibility renderer on mobile/web).")
		return ProfilyTypes.Mode.LIGHT
	return profily_mode


## The backend graphs must draw with. AUTO degrades to the CPU CANVAS drawer
## on iOS with the Metal driver, where Godot 4.7 mis-binds the canvas_data
## uniform buffer of custom canvas materials (160 bytes bound vs 272
## expected), corrupting every draw that uses a ShaderMaterial.
func effective_graph_backend() -> ProfilyTypes.GraphBackend:
	if graph_backend != ProfilyTypes.GraphBackend.AUTO:
		return graph_backend
	if OS.has_feature("ios") \
			and RenderingServer.get_current_rendering_driver_name().begins_with("metal"):
		if not _backend_fallback_warned:
			_backend_fallback_warned = true
			push_warning("[Profily] Graphs drawn with the CPU canvas fallback (iOS Metal driver).")
		return ProfilyTypes.GraphBackend.CANVAS
	return ProfilyTypes.GraphBackend.SHADER


# --- Internals ---

## Applies every profily/* key present in ProjectSettings. Keys that were
## never registered (plugin not enabled) keep the Inspector/scene values,
## which are passed as the fallback.
func _load_settings() -> void:
	enabled_on_startup = ProfilySettings.value_or(
		"profily/general/enabled_on_startup", enabled_on_startup)
	profily_mode = ProfilySettings.value_or(
		"profily/general/mode", profily_mode) as ProfilyTypes.Mode
	graph_backend = ProfilySettings.value_or(
		"profily/general/graph_backend", graph_backend) as ProfilyTypes.GraphBackend
	background = ProfilySettings.value_or("profily/general/background", background)
	background_color = ProfilySettings.value_or(
		"profily/general/background_color", background_color)
	canvas_layer = ProfilySettings.value_or("profily/general/canvas_layer", canvas_layer)
	ui_scale = ProfilySettings.value_or("profily/general/ui_scale", ui_scale)
	graph_modules_position = ProfilySettings.value_or(
		"profily/general/graph_modules_position", graph_modules_position
	) as ProfilyTypes.ModulePosition
	graph_modules_offset = ProfilySettings.value_or(
		"profily/general/graph_modules_offset", graph_modules_offset)

	hotkeys_enabled = ProfilySettings.value_or("profily/hotkeys/enabled", hotkeys_enabled)
	toggle_mode_key = ProfilySettings.value_or(
		"profily/hotkeys/toggle_mode_key", toggle_mode_key) as Key
	toggle_mode_ctrl = ProfilySettings.value_or("profily/hotkeys/toggle_mode_ctrl", toggle_mode_ctrl)
	toggle_mode_alt = ProfilySettings.value_or("profily/hotkeys/toggle_mode_alt", toggle_mode_alt)
	toggle_active_key = ProfilySettings.value_or(
		"profily/hotkeys/toggle_active_key", toggle_active_key) as Key
	toggle_active_ctrl = ProfilySettings.value_or(
		"profily/hotkeys/toggle_active_ctrl", toggle_active_ctrl)
	toggle_active_alt = ProfilySettings.value_or(
		"profily/hotkeys/toggle_active_alt", toggle_active_alt)

	fps_module_state = ProfilySettings.value_or(
		"profily/fps/module_state", fps_module_state) as ProfilyTypes.ModuleState
	good_fps_threshold = ProfilySettings.value_or("profily/fps/good_threshold", good_fps_threshold)
	caution_fps_threshold = ProfilySettings.value_or(
		"profily/fps/caution_threshold", caution_fps_threshold)
	good_fps_color = ProfilySettings.value_or("profily/fps/good_color", good_fps_color)
	caution_fps_color = ProfilySettings.value_or("profily/fps/caution_color", caution_fps_color)
	critical_fps_color = ProfilySettings.value_or("profily/fps/critical_color", critical_fps_color)
	fps_graph_resolution = ProfilySettings.value_or(
		"profily/fps/graph_resolution", fps_graph_resolution)
	fps_text_update_rate = ProfilySettings.value_or(
		"profily/fps/text_update_rate", fps_text_update_rate)

	ram_module_state = ProfilySettings.value_or(
		"profily/ram/module_state", ram_module_state) as ProfilyTypes.ModuleState
	allocated_ram_color = ProfilySettings.value_or(
		"profily/ram/allocated_color", allocated_ram_color)
	reserved_ram_color = ProfilySettings.value_or("profily/ram/reserved_color", reserved_ram_color)
	vram_color = ProfilySettings.value_or("profily/ram/vram_color", vram_color)
	ram_graph_resolution = ProfilySettings.value_or(
		"profily/ram/graph_resolution", ram_graph_resolution)
	ram_text_update_rate = ProfilySettings.value_or(
		"profily/ram/text_update_rate", ram_text_update_rate)

	audio_module_state = ProfilySettings.value_or(
		"profily/audio/module_state", audio_module_state) as ProfilyTypes.ModuleState
	audio_bus_name = ProfilySettings.value_or("profily/audio/bus_name", audio_bus_name)
	audio_graph_color = ProfilySettings.value_or("profily/audio/graph_color", audio_graph_color)
	audio_graph_resolution = ProfilySettings.value_or(
		"profily/audio/graph_resolution", audio_graph_resolution)
	audio_spectrum_size = ProfilySettings.value_or(
		"profily/audio/spectrum_size", audio_spectrum_size)
	audio_text_update_rate = ProfilySettings.value_or(
		"profily/audio/text_update_rate", audio_text_update_rate)

	advanced_module_state = ProfilySettings.value_or(
		"profily/advanced/module_state", advanced_module_state) as ProfilyTypes.ModuleState
	advanced_module_position = ProfilySettings.value_or(
		"profily/advanced/module_position", advanced_module_position
	) as ProfilyTypes.ModulePosition
	advanced_module_offset = ProfilySettings.value_or(
		"profily/advanced/module_offset", advanced_module_offset)

	scene_module_state = ProfilySettings.value_or(
		"profily/scene/module_state", scene_module_state) as ProfilyTypes.ModuleState
	scene_graph_color = ProfilySettings.value_or("profily/scene/graph_color", scene_graph_color)
	scene_graph_resolution = ProfilySettings.value_or(
		"profily/scene/graph_resolution", scene_graph_resolution)
	scene_text_update_rate = ProfilySettings.value_or(
		"profily/scene/text_update_rate", scene_text_update_rate)

	debugger_enabled = ProfilySettings.value_or("profily/debugger/enabled", debugger_enabled)


func _init_modules() -> void:
	for module_type: ProfilyTypes.ModuleType in _modules:
		var module: ProfilyModule = _modules[module_type]
		if module == null:
			continue
		module.init(self)
	var advanced: ProfilyModule = _modules.get(ProfilyTypes.ModuleType.ADVANCED)
	if advanced != null:
		# The advanced panel auto-sizes to its longest line; re-anchor it
		# whenever that happens.
		advanced.resized.connect(_reposition_all)


## Reads a float property from a module's monitor, tolerating missing modules.
func _monitor_float(module_type: ProfilyTypes.ModuleType, property: StringName) -> float:
	var module: ProfilyModule = _modules.get(module_type)
	if module == null:
		return 0.0
	var module_monitor := module.monitor()
	if module_monitor == null:
		return 0.0
	return float(module_monitor.get(property))


func _audio_monitor() -> AudioMonitor:
	var module: ProfilyModule = _modules.get(ProfilyTypes.ModuleType.AUDIO)
	if module == null:
		return null
	return module.monitor() as AudioMonitor


func _matches_hotkey(key: InputEventKey, keycode: Key, needs_ctrl: bool, needs_alt: bool) -> bool:
	return key.keycode == keycode \
			and key.ctrl_pressed == needs_ctrl \
			and key.alt_pressed == needs_alt


## Hot-reload plumbing: re-applies every parameter of one module.
func _refresh_module(module_type: ProfilyTypes.ModuleType) -> void:
	if not _ready_done:
		return
	var module: ProfilyModule = _modules.get(module_type)
	if module != null:
		module.update_parameters()


func _refresh_all_modules() -> void:
	if not _ready_done:
		return
	for module_type: ProfilyTypes.ModuleType in _modules:
		var module: ProfilyModule = _modules[module_type]
		if module != null:
			module.update_parameters()


# --- Layout ---

## Recomputes scale, safe area and positions. Single compensation point for
## the Unity CanvasScaler equivalent: the whole CanvasLayer is scaled and the
## SafeArea grows by the inverse ratio.
func _update_layout() -> void:
	if not _ready_done:
		return
	scale = Vector2(ui_scale, ui_scale)
	var canvas_size := get_viewport().get_visible_rect().size / ui_scale
	_safe_area.apply(canvas_size)
	_reposition_all()


func _reposition_all() -> void:
	if not _ready_done:
		return
	# Dynamic stacking (deviation from the original's baked offsets): each
	# visible module contributes its state-dependent height, so hidden or
	# compacted (TEXT/BASIC) modules leave no holes in the stack.
	var stack_y := SIDE_MARGIN + graph_modules_offset.y
	for module_type: ProfilyTypes.ModuleType in GROUP_ORDER:
		var module: ProfilyModule = _modules.get(module_type)
		if module == null:
			continue
		var height := module.effective_height()
		if height <= 0.0:
			continue
		var offset := Vector2(SIDE_MARGIN + graph_modules_offset.x, stack_y)
		_position_module(module, graph_modules_position, offset, height)
		stack_y += height + MODULE_SPACING
	var advanced: ProfilyModule = _modules.get(ProfilyTypes.ModuleType.ADVANCED)
	if advanced != null:
		var offset := Vector2(SIDE_MARGIN, SIDE_MARGIN) + advanced_module_offset
		_position_module(advanced, advanced_module_position, offset, advanced.size.y)
		advanced.set_alignment_for_position(advanced_module_position)


## Port of G_*Manager.SetPosition(): anchors the module to a corner of the
## safe area, mirroring the offset per side. In bottom corners the mirror
## uses the state's effective height so the visible part hugs the stack.
## FREE keeps the current position.
func _position_module(
	module: ProfilyModule,
	module_position: ProfilyTypes.ModulePosition,
	offset: Vector2,
	height: float,
) -> void:
	var safe_size := _safe_area.size
	# Right-side corners anchor against the visible content width, so compact
	# states (like the FPS BASIC box) hug the margin without dead space.
	var width := module.effective_width()
	match module_position:
		ProfilyTypes.ModulePosition.TOP_RIGHT:
			module.position = Vector2(safe_size.x - width - offset.x, offset.y)
		ProfilyTypes.ModulePosition.TOP_LEFT:
			module.position = Vector2(offset.x, offset.y)
		ProfilyTypes.ModulePosition.BOTTOM_RIGHT:
			module.position = Vector2(
				safe_size.x - width - offset.x,
				safe_size.y - height - offset.y
			)
		ProfilyTypes.ModulePosition.BOTTOM_LEFT:
			module.position = Vector2(offset.x, safe_size.y - height - offset.y)
		ProfilyTypes.ModulePosition.FREE:
			pass
