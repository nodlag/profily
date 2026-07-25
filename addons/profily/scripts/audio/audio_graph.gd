extends Control
## Audio spectrum graphs (current + peak-hold). Port of G_AudioGraph
## (Graphy, MIT (c) 2018 Martin Pane), including the readability gap effect:
## every third bar the triple is averaged into two bars and the first one is
## set to -1, which the shader renders as a transparent gap.
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.

const AudioMonitor := preload("audio_monitor.gd")
const GraphShaderController := preload("../graph_shader_controller.gd")

var _manager: ProfilyManager
var _monitor: AudioMonitor
var _spectrum := GraphShaderController.new()
var _peaks := GraphShaderController.new()
var _resolution := 81

@onready var _spectrum_rect: ColorRect = %GraphSpectrum
@onready var _peaks_rect: ColorRect = %GraphPeaks


func _process(_delta: float) -> void:
	var bars := _monitor.spectrum
	var peak_bars := _monitor.spectrum_peaks
	if bars.size() < _resolution or peak_bars.size() < _resolution:
		return
	_upload_with_gaps(_spectrum, bars)
	_upload_with_gaps(_peaks, peak_bars)


func init(manager: ProfilyManager, monitor: AudioMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	var mode := _manager.effective_mode()
	var backend := _manager.effective_graph_backend()
	_spectrum.initialize(_spectrum_rect, mode, backend)
	_peaks.initialize(_peaks_rect, mode, backend)
	_set_series_color(_spectrum, _manager.audio_graph_color)
	# The peak-hold layer is drawn behind at half opacity so the live bars
	# stay readable (the original used a second, dimmer material).
	var peaks_color := _manager.audio_graph_color
	peaks_color.a *= 0.5
	_set_series_color(_peaks, peaks_color)
	_resolution = clampi(_manager.audio_graph_resolution, 10, _spectrum.array_max_size)
	_spectrum.set_resolution(_resolution)
	_peaks.set_resolution(_resolution)


func _upload_with_gaps(controller: GraphShaderController, values: PackedFloat32Array) -> void:
	for i in _resolution:
		controller.shader_values[i] = values[i]
		# Gap effect, same condition as the original: on every (i+1) % 3 == 0
		# bar past the first pair, average the triple and open a gap.
		if (i + 1) % 3 == 0 and i > 1:
			var average := (
				controller.shader_values[i]
				+ controller.shader_values[i - 1]
				+ controller.shader_values[i - 2]
			) / 3.0
			controller.shader_values[i] = average
			controller.shader_values[i - 1] = average
			controller.shader_values[i - 2] = -1.0
	controller.update_points()


func _set_series_color(controller: GraphShaderController, color: Color) -> void:
	controller.good_color = color
	controller.caution_color = color
	controller.critical_color = color
	controller.update_colors()
