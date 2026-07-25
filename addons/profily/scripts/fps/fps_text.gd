extends Control
## FPS text block. Port of G_FpsText (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## The big FPS number is intentionally independent from the monitor's
## CurrentFPS: it averages its own accumulation interval (frames / elapsed),
## updated text_update_rate times per second, exactly like the original.

const FpsMonitor := preload("fps_monitor.gd")

var _manager: ProfilyManager
var _monitor: FpsMonitor
var _update_rate := 3
var _accumulated := 0.0
var _frames := 0

@onready var _fps_label: Label = %FpsLabel
@onready var _ms_label: Label = %MsLabel
@onready var _avg_label: Label = %AvgLabel
@onready var _one_percent_label: Label = %OnePercentLabel
@onready var _zero1_percent_label: Label = %Zero1PercentLabel


func _process(_delta: float) -> void:
	_accumulated += _monitor.unscaled_delta
	_frames += 1
	if _accumulated <= 1.0 / float(_update_rate):
		return

	var fps := float(_frames) / _accumulated
	var ms := _accumulated / float(_frames) * 1000.0
	_accumulated = 0.0
	_frames = 0

	_fps_label.text = "%d" % roundi(fps)
	_ms_label.text = "%.1f ms" % ms
	_apply_fps_color(_fps_label, fps)
	_apply_fps_color(_ms_label, fps)

	var avg := _monitor.average_fps
	var one_percent := _monitor.one_percent_fps
	var zero1_percent := _monitor.zero1_percent_fps
	_avg_label.text = "AVG %d" % roundi(avg)
	_one_percent_label.text = "1%% %d" % roundi(one_percent)
	_zero1_percent_label.text = "0.1%% %d" % roundi(zero1_percent)
	# Each stat is colored by its own value (parity with the original).
	_apply_fps_color(_avg_label, avg)
	_apply_fps_color(_one_percent_label, one_percent)
	_apply_fps_color(_zero1_percent_label, zero1_percent)


func init(manager: ProfilyManager, monitor: FpsMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	_update_rate = _manager.fps_text_update_rate


func _apply_fps_color(label: Label, fps: float) -> void:
	var rounded := roundi(fps)
	var color := _manager.critical_fps_color
	if rounded >= _manager.good_fps_threshold:
		color = _manager.good_fps_color
	elif rounded >= _manager.caution_fps_threshold:
		color = _manager.caution_fps_color
	label.add_theme_color_override("font_color", color)
