extends ProfilyModule
## System information panel. Port of G_AdvancedData
## (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Static lines are filled once; dynamic lines refresh at 5 Hz (the update
## rate serialized in the original Graphy prefab).
## The PanelContainer root auto-sizes to the longest line (the original
## resized its background to the widest text + padding). Text alignment
## follows the anchored side, like the original.

const UPDATE_INTERVAL := 0.2

var _accumulated := 0.0
var _max_texture_size := 0

@onready var _cpu_label: Label = %CpuLabel
@onready var _ram_label: Label = %RamLabel
@onready var _gpu_label: Label = %GpuLabel
@onready var _api_label: Label = %ApiLabel
@onready var _vram_label: Label = %VramLabel
@onready var _screen_label: Label = %ScreenLabel
@onready var _window_label: Label = %WindowLabel
@onready var _os_label: Label = %OsLabel
@onready var _godot_label: Label = %GodotLabel
@onready var _xr_label: Label = %XrLabel


func _process(_delta: float) -> void:
	_accumulated += _manager.unscaled_delta
	if _accumulated <= UPDATE_INTERVAL:
		return
	_accumulated = 0.0
	_update_dynamic_lines()


func update_parameters() -> void:
	# The panel is tinted via self_modulate (children are unaffected);
	# a fully transparent tint doubles as the "no background" mode.
	self_modulate = _manager.background_color if _manager.background else Color(0, 0, 0, 0)
	_apply_state()


## Text lines align towards the anchored corner (port of SetPosition's
## TextAnchor adjustment in the original).
func set_alignment_for_position(module_position: ProfilyTypes.ModulePosition) -> void:
	var alignment := HORIZONTAL_ALIGNMENT_LEFT
	if module_position in [
		ProfilyTypes.ModulePosition.TOP_RIGHT, ProfilyTypes.ModulePosition.BOTTOM_RIGHT,
	]:
		alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in _all_labels():
		label.horizontal_alignment = alignment


func _on_init() -> void:
	_fill_static_lines()
	_update_dynamic_lines()


func _initial_state() -> ProfilyTypes.ModuleState:
	return _manager.advanced_module_state


func _apply_state() -> void:
	if _manager == null:
		return # Not initialized yet; init() re-applies the state.
	# FULL/TEXT/BASIC all show the whole panel; BACKGROUND/OFF hide it
	# (parity with the original, which has no graph in this module).
	var active := _module_state in [
		ProfilyTypes.ModuleState.FULL,
		ProfilyTypes.ModuleState.TEXT,
		ProfilyTypes.ModuleState.BASIC,
	]
	visible = active
	set_process(active)


func _fill_static_lines() -> void:
	_cpu_label.text = "CPU: %s [%d cores]" % [OS.get_processor_name(), OS.get_processor_count()]

	var memory_info := OS.get_memory_info()
	var physical_mb := int(memory_info.get("physical", 0)) / 1048576
	_ram_label.text = "RAM: %d MB" % physical_mb

	var adapter_vendor := RenderingServer.get_video_adapter_vendor()
	var gpu := RenderingServer.get_video_adapter_name()
	if not adapter_vendor.is_empty() and not gpu.begins_with(adapter_vendor):
		gpu = "%s %s" % [adapter_vendor, gpu]
	_gpu_label.text = "GPU: %s" % gpu

	_api_label.text = "Graphics API: %s (%s, %s)" % [
		RenderingServer.get_video_adapter_api_version(),
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(),
	]

	# RenderingDevice is null on the Compatibility renderer.
	var rendering_device := RenderingServer.get_rendering_device()
	if rendering_device != null:
		_max_texture_size = rendering_device.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D)

	_os_label.text = "OS: %s %s" % [OS.get_distribution_name(), OS.get_version()]

	var version_info := Engine.get_version_info()
	_godot_label.text = "Godot: %s" % version_info.get("string", "?")

	_update_xr_line()


func _update_dynamic_lines() -> void:
	var vram_mb := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	if _max_texture_size > 0:
		_vram_label.text = "VRAM used: %d MB. Max texture size: %dpx" % [vram_mb, _max_texture_size]
	else:
		_vram_label.text = "VRAM used: %d MB" % vram_mb

	if DisplayServer.get_name() == "headless":
		_screen_label.text = "Screen: n/a (headless)"
		_window_label.text = "Window: n/a (headless)"
		return

	var screen_size := DisplayServer.screen_get_size()
	var refresh_rate := DisplayServer.screen_get_refresh_rate()
	var refresh_text := "%.0f" % refresh_rate if refresh_rate > 0.0 else "?"
	_screen_label.text = "Screen: %dx%d@%sHz [%ddpi]" % [
		screen_size.x, screen_size.y, refresh_text, DisplayServer.screen_get_dpi(),
	]

	var window_size := DisplayServer.window_get_size()
	_window_label.text = "Window: %dx%d" % [window_size.x, window_size.y]


func _update_xr_line() -> void:
	var xr_interface := XRServer.primary_interface
	if xr_interface == null:
		_xr_label.visible = false
		return
	_xr_label.visible = true
	var target_size := xr_interface.get_render_target_size()
	_xr_label.text = "XR: %s (%dx%d per eye)" % [xr_interface.name, target_size.x, target_size.y]


func _all_labels() -> Array[Label]:
	return [
		_cpu_label, _ram_label, _gpu_label, _api_label, _vram_label,
		_screen_label, _window_label, _os_label, _godot_label, _xr_label,
	]
