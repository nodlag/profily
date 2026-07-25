extends Control
## RAM graphs (three overlaid monochrome series). Port of G_RamGraph
## (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Deliberate deviation: the original normalizes all series by the max of the
## "reserved" window; here VRAM can exceed the static peak, so the ceiling is
## the max across the three windows instead.

const GraphShaderController := preload("../graph_shader_controller.gd")
const RamMonitor := preload("ram_monitor.gd")

var _manager: ProfilyManager
var _monitor: RamMonitor
var _allocated := GraphShaderController.new()
var _reserved := GraphShaderController.new()
var _vram := GraphShaderController.new()
var _allocated_values := PackedFloat32Array()
var _reserved_values := PackedFloat32Array()
var _vram_values := PackedFloat32Array()
var _resolution := 150

@onready var _allocated_rect: ColorRect = %GraphAllocated
@onready var _reserved_rect: ColorRect = %GraphReserved
@onready var _vram_rect: ColorRect = %GraphVram


func _process(_delta: float) -> void:
	var highest := 1.0
	highest = maxf(highest, _shift_in(_allocated_values, _monitor.allocated_ram))
	highest = maxf(highest, _shift_in(_reserved_values, _monitor.reserved_ram))
	highest = maxf(highest, _shift_in(_vram_values, _monitor.vram))

	_upload(_allocated, _allocated_values, highest)
	_upload(_reserved, _reserved_values, highest)
	_upload(_vram, _vram_values, highest)


func init(manager: ProfilyManager, monitor: RamMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	var mode := _manager.effective_mode()
	var backend := _manager.effective_graph_backend()
	_allocated.initialize(_allocated_rect, mode, backend)
	_reserved.initialize(_reserved_rect, mode, backend)
	_vram.initialize(_vram_rect, mode, backend)
	# Monochrome series: every threshold color is the series color and the
	# thresholds stay at 0 (no threshold/average bars, parity with Graphy).
	_set_series_color(_allocated, _manager.allocated_ram_color)
	_set_series_color(_reserved, _manager.reserved_ram_color)
	_set_series_color(_vram, _manager.vram_color)
	_resolution = clampi(_manager.ram_graph_resolution, 10, _allocated.array_max_size)
	_allocated_values.resize(_resolution)
	_allocated_values.fill(0.0)
	_reserved_values.resize(_resolution)
	_reserved_values.fill(0.0)
	_vram_values.resize(_resolution)
	_vram_values.fill(0.0)
	_allocated.set_resolution(_resolution)
	_reserved.set_resolution(_resolution)
	_vram.set_resolution(_resolution)
	# In release builds the static memory series are meaningless (always 0).
	var ram_ok := _monitor.ram_available
	_allocated_rect.visible = ram_ok
	_reserved_rect.visible = ram_ok


## Shifts the window left, inserts the new value and returns the window max.
func _shift_in(values: PackedFloat32Array, new_value: float) -> float:
	var window_max := new_value
	for i in _resolution - 1:
		var value := values[i + 1]
		values[i] = value
		window_max = maxf(window_max, value)
	values[_resolution - 1] = new_value
	return window_max


func _upload(controller: GraphShaderController, values: PackedFloat32Array, highest: float) -> void:
	var inv := 1.0 / highest
	for i in _resolution:
		controller.shader_values[i] = values[i] * inv
	controller.update_points()


func _set_series_color(controller: GraphShaderController, color: Color) -> void:
	controller.good_color = color
	controller.caution_color = color
	controller.critical_color = color
	controller.update_colors()
