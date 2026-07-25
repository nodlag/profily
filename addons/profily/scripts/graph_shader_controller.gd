extends RefCounted
## Bridge between the module graph scripts and the graph rendering backend.
## Port of G_GraphShader (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Deviation from the original: Unity uploads partial arrays over a
## pre-initialized 512-float array; here [member shader_values] is ALWAYS kept
## at the full compiled array size (zero padded) and uploaded whole, because
## Godot requires uniform arrays to be set with their declared size.
## The material is created per instance in code, so graphs can never
## accidentally share a material (a real hazard with .tscn-embedded ones).
##
## Godot-only addition: the CANVAS backend draws the same plot on the CPU as
## one canvas triangle batch, with no ShaderMaterial involved. It exists for
## drivers that mis-bind custom canvas materials (Godot 4.7's Metal driver on
## iOS 26 binds a 160-byte canvas_data buffer to shaders expecting 272).
## It must stay visually equivalent to graph_full.gdshader — edit both
## together. The only accepted difference: the horizontal edge fade is
## interpolated per vertex instead of per pixel, so a column straddling the
## 3% fade boundary deviates by at most one column width.

const ARRAY_MAX_SIZE_FULL := 512
const ARRAY_MAX_SIZE_LIGHT := 128

const SHADER_FULL: Shader = preload("../shaders/graph_full.gdshader")
const SHADER_LIGHT: Shader = preload("../shaders/graph_light.gdshader")

## Bar height, edge fade width and fill gradient strength, as in the shader
## (normalized units).
const BAR_THICKNESS := 0.02
const EDGE_FADE := 0.03
const FILL_GRADIENT := 0.3

var array_max_size := ARRAY_MAX_SIZE_LIGHT

## Normalized 0..1 graph points (index 0 = oldest, drawn left to right).
## Values below 0 (e.g. the audio module's -1 gaps) render as transparent.
var shader_values := PackedFloat32Array()

var image: ColorRect

var average := 0.0
var good_threshold := 0.0
var caution_threshold := 0.0
var good_color := Color.WHITE
var caution_color := Color.WHITE
var critical_color := Color.WHITE

var _material: ShaderMaterial
var _backend := ProfilyTypes.GraphBackend.SHADER
var _resolution := ARRAY_MAX_SIZE_LIGHT
var _original_color := Color.WHITE

# Geometry buffers reused across CANVAS redraws.
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


## Creates the per-instance material (SHADER backend) or hooks the CPU drawer
## (CANVAS backend) and uploads the initial state. AUTO must be resolved by
## the manager before reaching here; it falls back to SHADER defensively.
func initialize(
	p_image: ColorRect,
	mode: ProfilyTypes.Mode,
	backend := ProfilyTypes.GraphBackend.SHADER,
) -> void:
	if image != p_image:
		_original_color = p_image.color
	if image != null and image.draw.is_connected(_on_image_draw):
		image.draw.disconnect(_on_image_draw)
	image = p_image
	_backend = ProfilyTypes.GraphBackend.SHADER \
			if backend == ProfilyTypes.GraphBackend.AUTO else backend
	var is_full := mode == ProfilyTypes.Mode.FULL
	array_max_size = ARRAY_MAX_SIZE_FULL if is_full else ARRAY_MAX_SIZE_LIGHT
	_resolution = clampi(_resolution, 10, array_max_size)
	shader_values.resize(array_max_size)
	shader_values.fill(0.0)
	if _backend == ProfilyTypes.GraphBackend.CANVAS:
		_material = null
		image.material = null
		# The rect must not paint itself: everything is drawn in _on_image_draw.
		image.color = Color(0.0, 0.0, 0.0, 0.0)
		image.draw.connect(_on_image_draw)
	else:
		image.color = _original_color
		_material = ShaderMaterial.new()
		_material.shader = SHADER_FULL if is_full else SHADER_LIGHT
		image.material = _material
	update_points()
	update_average()
	update_thresholds()
	update_colors()


## Sets how many points the graph actually reads (the visual resolution).
func set_resolution(resolution: int) -> void:
	_resolution = clampi(resolution, 10, array_max_size)
	if _backend == ProfilyTypes.GraphBackend.CANVAS:
		image.queue_redraw()
	else:
		_material.set_shader_parameter("graph_values_length", _resolution)


func update_points() -> void:
	if _backend == ProfilyTypes.GraphBackend.CANVAS:
		image.queue_redraw()
	else:
		_material.set_shader_parameter("graph_values", shader_values)


func update_average() -> void:
	if _backend == ProfilyTypes.GraphBackend.CANVAS:
		image.queue_redraw()
	else:
		_material.set_shader_parameter("average", average)


func update_thresholds() -> void:
	if _backend == ProfilyTypes.GraphBackend.CANVAS:
		image.queue_redraw()
	else:
		_material.set_shader_parameter("good_threshold", good_threshold)
		_material.set_shader_parameter("caution_threshold", caution_threshold)


func update_colors() -> void:
	if _backend == ProfilyTypes.GraphBackend.CANVAS:
		image.queue_redraw()
	else:
		_material.set_shader_parameter("good_color", good_color)
		_material.set_shader_parameter("caution_color", caution_color)
		_material.set_shader_parameter("critical_color", critical_color)


# --- CANVAS backend ---

## Mirrors graph_full.gdshader: per-column threshold coloring, a solid head
## with a fading fill below it, then the average/threshold bars on top.
func _on_image_draw() -> void:
	var size := image.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_points.clear()
	_colors.clear()
	_indices.clear()
	var increment := 1.0 / (float(_resolution) - 1.0)
	var head_height := increment * 4.0
	for i: int in _resolution:
		var value := shader_values[i]
		if value <= 0.0:
			continue
		var base := critical_color
		if value > good_threshold:
			base = good_color
		elif value > caution_threshold:
			base = caution_color
		var x0 := float(i) / float(_resolution)
		var x1 := float(i + 1) / float(_resolution)
		var fade0 := _edge_fade(x0)
		var fade1 := _edge_fade(x1)
		var head_base := maxf(value - head_height, 0.0)
		if head_base > 0.0:
			var top_alpha := base.a * FILL_GRADIENT * head_base / value
			_add_quad(size, x0, x1, 0.0, head_base, base, 0.0, top_alpha, fade0, fade1)
		_add_quad(
			size, x0, x1, head_base, minf(value, 1.0), base, base.a, base.a, fade0, fade1
		)
	_add_bar(size, average, Color.WHITE)
	_add_bar(size, caution_threshold, caution_color)
	_add_bar(size, good_threshold, good_color)
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		image.get_canvas_item(), _indices, _points, _colors
	)


## Horizontal alpha fade at the graph sides, as in the shader.
func _edge_fade(x: float) -> float:
	if x < EDGE_FADE:
		return x / EDGE_FADE
	if x > 1.0 - EDGE_FADE:
		return (1.0 - x) / EDGE_FADE
	return 1.0


## Quad in normalized coordinates (y up, like the shader). Alphas are given
## for the bottom/top edges and multiplied by the left/right edge fades.
func _add_quad(
	size: Vector2,
	x0: float,
	x1: float,
	y_bottom: float,
	y_top: float,
	base: Color,
	bottom_alpha: float,
	top_alpha: float,
	fade0: float,
	fade1: float,
) -> void:
	var index := _points.size()
	var px0 := x0 * size.x
	var px1 := x1 * size.x
	var py_bottom := (1.0 - y_bottom) * size.y
	var py_top := (1.0 - y_top) * size.y
	_points.push_back(Vector2(px0, py_bottom))
	_points.push_back(Vector2(px1, py_bottom))
	_points.push_back(Vector2(px1, py_top))
	_points.push_back(Vector2(px0, py_top))
	_colors.push_back(Color(base, bottom_alpha * fade0))
	_colors.push_back(Color(base, bottom_alpha * fade1))
	_colors.push_back(Color(base, top_alpha * fade1))
	_colors.push_back(Color(base, top_alpha * fade0))
	_indices.push_back(index)
	_indices.push_back(index + 1)
	_indices.push_back(index + 2)
	_indices.push_back(index)
	_indices.push_back(index + 2)
	_indices.push_back(index + 3)


## Full-width horizontal bar whose top edge sits at [param top] (normalized),
## split in three so the vertex fade matches the shader's edge fade exactly.
func _add_bar(size: Vector2, top: float, color: Color) -> void:
	if top <= 0.0:
		return
	var y_top := minf(top, 1.0)
	var y_bottom := maxf(top - BAR_THICKNESS, 0.0)
	if y_top <= y_bottom:
		return
	var alpha := color.a
	_add_quad(size, 0.0, EDGE_FADE, y_bottom, y_top, color, alpha, alpha, 0.0, 1.0)
	_add_quad(
		size, EDGE_FADE, 1.0 - EDGE_FADE, y_bottom, y_top, color, alpha, alpha, 1.0, 1.0
	)
	_add_quad(size, 1.0 - EDGE_FADE, 1.0, y_bottom, y_top, color, alpha, alpha, 1.0, 0.0)
