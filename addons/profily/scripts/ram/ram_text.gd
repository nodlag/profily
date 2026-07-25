extends Control
## RAM text block. Port of G_RamText (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.

const RamMonitor := preload("ram_monitor.gd")

var _manager: ProfilyManager
var _monitor: RamMonitor
var _update_rate := 3
var _accumulated := 0.0

@onready var _allocated_label: Label = %AllocatedLabel
@onready var _reserved_label: Label = %ReservedLabel
@onready var _vram_label: Label = %VramLabel


func _process(_delta: float) -> void:
	_accumulated += _manager.unscaled_delta
	if _accumulated <= 1.0 / float(_update_rate):
		return
	_accumulated = 0.0

	# Integer MiB, like the original's (int) cast.
	if _monitor.ram_available:
		_allocated_label.text = "%d MB — Static" % int(_monitor.allocated_ram)
		_reserved_label.text = "%d MB — Static peak" % int(_monitor.reserved_ram)
	else:
		_allocated_label.text = "n/a (release) — Static"
		_reserved_label.text = "n/a (release) — Static peak"
	_vram_label.text = "%d MB — VRAM" % int(_monitor.vram)


func init(manager: ProfilyManager, monitor: RamMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	_update_rate = _manager.ram_text_update_rate
	_allocated_label.add_theme_color_override("font_color", _manager.allocated_ram_color)
	_reserved_label.add_theme_color_override("font_color", _manager.reserved_ram_color)
	_vram_label.add_theme_color_override("font_color", _manager.vram_color)
