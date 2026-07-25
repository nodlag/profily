extends Control
## Scene stats text block (Godot-specific module).
## (c) 2026 Javier Garrido (nodlag), MIT.

const SceneMonitor := preload("scene_monitor.gd")

var _manager: ProfilyManager
var _monitor: SceneMonitor
var _update_rate := 3
var _accumulated := 0.0

@onready var _draw_calls_label: Label = %DrawCallsLabel
@onready var _objects_label: Label = %ObjectsLabel
@onready var _nodes_label: Label = %NodesLabel
@onready var _physics_label: Label = %PhysicsLabel


func _process(_delta: float) -> void:
	_accumulated += _manager.unscaled_delta
	if _accumulated <= 1.0 / float(_update_rate):
		return
	_accumulated = 0.0

	_draw_calls_label.text = "Draw calls %d" % int(_monitor.draw_calls)
	_objects_label.text = "Objects %d · Prims %s" % [
		int(_monitor.objects_in_frame), _compact(int(_monitor.primitives_in_frame)),
	]
	_nodes_label.text = "Nodes %d · Orphans %d" % [
		int(_monitor.node_count), int(_monitor.orphan_node_count),
	]
	_physics_label.text = "Phys 2D %d · 3D %d" % [
		int(_monitor.physics_2d_active), int(_monitor.physics_3d_active),
	]


func init(manager: ProfilyManager, monitor: SceneMonitor) -> void:
	_manager = manager
	_monitor = monitor
	update_parameters()


func update_parameters() -> void:
	_update_rate = _manager.scene_text_update_rate
	_draw_calls_label.add_theme_color_override("font_color", _manager.scene_graph_color)


## Compacts large counts (primitives easily reach millions): 1234567 -> 1.2M.
func _compact(value: int) -> String:
	if value >= 1_000_000:
		return "%.1fM" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.0fK" % (float(value) / 1_000.0)
	return str(value)
