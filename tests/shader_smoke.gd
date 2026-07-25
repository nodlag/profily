extends SceneTree
## Headless smoke test for the graph shader infrastructure (F1).
## Run with:
##   godot --headless --path . -s tests/shader_smoke.gd
## Exits with 0 on success, >0 on failure.
## (c) 2026 Javier Garrido (nodlag), MIT.

const GraphShaderController := preload("res://addons/profily/scripts/graph_shader_controller.gd")


func _init() -> void:
	var errors := 0

	for path: String in [
		"res://addons/profily/shaders/graph_full.gdshader",
		"res://addons/profily/shaders/graph_light.gdshader",
	]:
		var shader: Shader = load(path)
		if shader == null:
			push_error("Failed to load shader: %s" % path)
			errors += 1

	# Feed a sine wave through the controller and read the uniform back.
	var color_rect := ColorRect.new()
	var controller := GraphShaderController.new()
	controller.initialize(color_rect, ProfilyTypes.Mode.FULL)
	controller.set_resolution(150)
	for i in 150:
		controller.shader_values[i] = 0.5 + 0.5 * sin(float(i) * 0.2)
	controller.average = 0.5
	controller.good_threshold = 0.6
	controller.caution_threshold = 0.3
	controller.update_points()
	controller.update_average()
	controller.update_thresholds()
	controller.update_colors()

	var material := color_rect.material as ShaderMaterial
	if material == null:
		push_error("Controller did not assign a ShaderMaterial")
		errors += 1
	else:
		var values: PackedFloat32Array = material.get_shader_parameter("graph_values")
		if values.size() != GraphShaderController.ARRAY_MAX_SIZE_FULL:
			push_error("graph_values size mismatch: %d" % values.size())
			errors += 1
		var length: int = material.get_shader_parameter("graph_values_length")
		if length != 150:
			push_error("graph_values_length mismatch: %d" % length)
			errors += 1

	# LIGHT mode must cap the array at 128 entries.
	var light_rect := ColorRect.new()
	var light_controller := GraphShaderController.new()
	light_controller.initialize(light_rect, ProfilyTypes.Mode.LIGHT)
	light_controller.set_resolution(300)
	var light_material := light_rect.material as ShaderMaterial
	var light_length: int = light_material.get_shader_parameter("graph_values_length")
	if light_length != GraphShaderController.ARRAY_MAX_SIZE_LIGHT:
		push_error("LIGHT resolution not capped at 128: %d" % light_length)
		errors += 1

	# CANVAS backend: no material; the plot becomes one canvas triangle batch.
	var canvas_rect := ColorRect.new()
	canvas_rect.size = Vector2(300.0, 88.0)
	var canvas_controller := GraphShaderController.new()
	canvas_controller.initialize(
		canvas_rect, ProfilyTypes.Mode.FULL, ProfilyTypes.GraphBackend.CANVAS
	)
	canvas_controller.set_resolution(150)
	canvas_controller.average = 0.5
	canvas_controller.good_threshold = 0.6
	canvas_controller.caution_threshold = 0.3
	if canvas_rect.material != null:
		push_error("CANVAS backend must not assign a material")
		errors += 1
	if canvas_rect.color.a != 0.0:
		push_error("CANVAS backend must make the ColorRect transparent")
		errors += 1

	# All points at 0 (or the audio -1 gaps) draw nothing but the three bars,
	# each split in three quads (4 points / 6 indices per quad).
	canvas_controller._on_image_draw()
	if canvas_controller._points.size() != 36 or canvas_controller._indices.size() != 54:
		push_error("CANVAS bars geometry mismatch: %d points, %d indices" % [
			canvas_controller._points.size(), canvas_controller._indices.size()])
		errors += 1

	# A single visible column adds its fill gradient + head quads.
	canvas_controller.shader_values[50] = 0.8
	canvas_controller._on_image_draw()
	if canvas_controller._points.size() != 44 or canvas_controller._indices.size() != 66:
		push_error("CANVAS column geometry mismatch: %d points, %d indices" % [
			canvas_controller._points.size(), canvas_controller._indices.size()])
		errors += 1

	# Re-initializing back to SHADER must restore the material path cleanly.
	canvas_controller.initialize(canvas_rect, ProfilyTypes.Mode.FULL)
	if canvas_rect.material == null:
		push_error("SHADER re-init did not restore the material")
		errors += 1
	if canvas_rect.draw.is_connected(canvas_controller._on_image_draw):
		push_error("SHADER re-init left the draw signal connected")
		errors += 1
	if canvas_rect.color != Color.WHITE:
		push_error("SHADER re-init did not restore the ColorRect color")
		errors += 1

	color_rect.free()
	light_rect.free()
	canvas_rect.free()
	print("[shader_smoke] %s" % ("OK" if errors == 0 else "FAILED (%d errors)" % errors))
	quit(errors)
