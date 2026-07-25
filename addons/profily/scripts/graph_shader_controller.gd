extends RefCounted
## Bridge between the module graph scripts and the graph shader material.
## Port of G_GraphShader (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Deviation from the original: Unity uploads partial arrays over a
## pre-initialized 512-float array; here [member shader_values] is ALWAYS kept
## at the full compiled array size (zero padded) and uploaded whole, because
## Godot requires uniform arrays to be set with their declared size.
## The material is created per instance in code, so graphs can never
## accidentally share a material (a real hazard with .tscn-embedded ones).

const ARRAY_MAX_SIZE_FULL := 512
const ARRAY_MAX_SIZE_LIGHT := 128

const SHADER_FULL: Shader = preload("../shaders/graph_full.gdshader")
const SHADER_LIGHT: Shader = preload("../shaders/graph_light.gdshader")

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


## Creates the per-instance material and uploads the initial state.
func initialize(p_image: ColorRect, mode: ProfilyTypes.Mode) -> void:
	image = p_image
	var is_full := mode == ProfilyTypes.Mode.FULL
	array_max_size = ARRAY_MAX_SIZE_FULL if is_full else ARRAY_MAX_SIZE_LIGHT
	shader_values.resize(array_max_size)
	shader_values.fill(0.0)
	_material = ShaderMaterial.new()
	_material.shader = SHADER_FULL if is_full else SHADER_LIGHT
	image.material = _material
	update_points()
	update_average()
	update_thresholds()
	update_colors()


## Sets how many points the shader actually reads (the visual resolution).
func set_resolution(resolution: int) -> void:
	_material.set_shader_parameter("graph_values_length", clampi(resolution, 10, array_max_size))


func update_points() -> void:
	_material.set_shader_parameter("graph_values", shader_values)


func update_average() -> void:
	_material.set_shader_parameter("average", average)


func update_thresholds() -> void:
	_material.set_shader_parameter("good_threshold", good_threshold)
	_material.set_shader_parameter("caution_threshold", caution_threshold)


func update_colors() -> void:
	_material.set_shader_parameter("good_color", good_color)
	_material.set_shader_parameter("caution_color", caution_color)
	_material.set_shader_parameter("critical_color", critical_color)
