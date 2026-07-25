extends ColorRect
## Draw calls graph (Godot-specific module). Monochrome series normalized by
## the window maximum, in the style of the RAM graphs.
## (c) 2026 Javier Garrido (nodlag), MIT.

const GraphShaderController := preload("../graph_shader_controller.gd")
const SceneMonitor := preload("scene_monitor.gd")

var _manager: ProfilyManager
var _monitor: SceneMonitor
var _controller := GraphShaderController.new()
var _values := PackedFloat32Array()
var _resolution := 150


func _process(_delta: float) -> void:
	var new_value := _monitor.draw_calls
	var window_max := maxf(1.0, new_value)
	for i in _resolution - 1:
		var value := _values[i + 1]
		_values[i] = value
		window_max = maxf(window_max, value)
	_values[_resolution - 1] = new_value

	var inv := 1.0 / window_max
	for i in _resolution:
		_controller.shader_values[i] = _values[i] * inv
	_controller.update_points()


func init(manager: ProfilyManager, monitor: SceneMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	_controller.initialize(self, _manager.effective_mode(), _manager.effective_graph_backend())
	_controller.good_color = _manager.scene_graph_color
	_controller.caution_color = _manager.scene_graph_color
	_controller.critical_color = _manager.scene_graph_color
	_controller.update_colors()
	_resolution = clampi(_manager.scene_graph_resolution, 10, _controller.array_max_size)
	_values.resize(_resolution)
	_values.fill(0.0)
	_controller.set_resolution(_resolution)
