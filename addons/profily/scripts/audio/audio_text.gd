extends Control
## Audio text block (dB readout). Port of G_AudioText
## (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.

const AudioMonitor := preload("audio_monitor.gd")

var _manager: ProfilyManager
var _monitor: AudioMonitor
var _update_rate := 3
var _accumulated := 0.0

@onready var _db_label: Label = %DbLabel


func _process(_delta: float) -> void:
	_accumulated += _manager.unscaled_delta
	if _accumulated <= 1.0 / float(_update_rate):
		return
	_accumulated = 0.0
	_db_label.text = "%d dB" % clampi(roundi(_monitor.max_db), -80, 0)


func init(manager: ProfilyManager, monitor: AudioMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	_update_rate = _manager.audio_text_update_rate
