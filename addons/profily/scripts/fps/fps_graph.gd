extends ColorRect
## FPS graph. Port of G_FpsGraph (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Every frame the sample window shifts left by one, the new FPS enters at the
## right, and everything is normalized by a slowly decaying peak (the graph's
## dynamic Y ceiling): the peak follows new maxima instantly but only decays
## by 1 per frame, so the scale never jumps.

const FpsMonitor := preload("fps_monitor.gd")
const GraphShaderController := preload("../graph_shader_controller.gd")

var _manager: ProfilyManager
var _monitor: FpsMonitor
var _controller := GraphShaderController.new()
var _fps_array := PackedInt32Array()
var _resolution := 150
var _highest_fps := 0


func _process(_delta: float) -> void:
	var fps := roundi(_monitor.current_fps)

	# Shift the window left; track the maximum while at it.
	var current_max := fps
	for i in _resolution - 1:
		var value := _fps_array[i + 1]
		_fps_array[i] = value
		current_max = maxi(current_max, value)
	_fps_array[_resolution - 1] = fps

	# Decaying peak (exact port of the original's m_highestFps update).
	if _highest_fps < 1 or _highest_fps <= current_max:
		_highest_fps = current_max
	else:
		_highest_fps -= 1
	_highest_fps = maxi(_highest_fps, 1)

	var inv := 1.0 / float(_highest_fps)
	for i in _resolution:
		_controller.shader_values[i] = float(_fps_array[i]) * inv
	_controller.update_points()

	_controller.average = _monitor.average_fps * inv
	_controller.update_average()
	_controller.good_threshold = float(_manager.good_fps_threshold) * inv
	_controller.caution_threshold = float(_manager.caution_fps_threshold) * inv
	_controller.update_thresholds()


func init(manager: ProfilyManager, monitor: FpsMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	_controller.initialize(self, _manager.effective_mode(), _manager.effective_graph_backend())
	_controller.good_color = _manager.good_fps_color
	_controller.caution_color = _manager.caution_fps_color
	_controller.critical_color = _manager.critical_fps_color
	_controller.update_colors()
	_resolution = clampi(_manager.fps_graph_resolution, 10, _controller.array_max_size)
	_fps_array.resize(_resolution)
	_fps_array.fill(0)
	_controller.set_resolution(_resolution)
