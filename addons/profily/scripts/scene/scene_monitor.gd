extends Node
## Scene/render stats collector. Godot-specific module with no Graphy
## equivalent: it surfaces Performance monitors Unity never exposed.
## (c) 2026 Javier Garrido (nodlag), MIT.

var draw_calls := 0.0
var objects_in_frame := 0.0
var primitives_in_frame := 0.0
var node_count := 0.0
## Debug builds only; 0 in release exports.
var orphan_node_count := 0.0
var physics_2d_active := 0.0
var physics_3d_active := 0.0


func _process(_delta: float) -> void:
	draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	objects_in_frame = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	primitives_in_frame = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	orphan_node_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	physics_2d_active = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	physics_3d_active = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
