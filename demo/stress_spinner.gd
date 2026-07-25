extends Node3D
## Ring of spinning boxes: generates draw calls, primitives and node churn so
## the Profily SCENE and RAM modules have something to show in the demo.
## (c) 2026 Javier Garrido (nodlag), MIT.

@export var box_count := 60:
	set(value):
		box_count = maxi(0, value)
		if is_inside_tree():
			_rebuild()

var _boxes: Array[MeshInstance3D] = []
var _mesh := BoxMesh.new()


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	rotate_y(delta * 0.5)


func _rebuild() -> void:
	while _boxes.size() > box_count:
		var removed: MeshInstance3D = _boxes.pop_back()
		removed.queue_free()
	while _boxes.size() < box_count:
		var box := MeshInstance3D.new()
		box.mesh = _mesh
		box.scale = Vector3.ONE * 0.35
		add_child(box)
		_boxes.append(box)
	for i in _boxes.size():
		var angle := TAU * float(i) / float(maxi(1, _boxes.size()))
		var radius := 2.5 + 1.5 * fmod(float(i) * 0.37, 1.0)
		var height := -1.5 + 3.0 * fmod(float(i) * 0.61, 1.0)
		_boxes[i].position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
