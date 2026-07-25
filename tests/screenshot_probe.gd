extends Node
## Visual verification probe: waits a few frames, captures the viewport to a
## PNG and quits. Run windowed (not headless):
##   PROFILY_PROBE_OUT=/path/out.png godot --path . res://tests/screenshot_probe.tscn
## Optional env vars:
##   PROFILY_PROBE_FRAMES  frames to wait before capturing (default 90).
##   PROFILY_PROBE_SETUP   expression evaluated on this node at frame 5,
##                         e.g. "Profily.set_module_mode(0, 2)".
## (c) 2026 Javier Garrido (nodlag), MIT.

var _frames := 0
var _capture_at := 90


func _ready() -> void:
	var frames_env := OS.get_environment("PROFILY_PROBE_FRAMES")
	if not frames_env.is_empty():
		_capture_at = maxi(10, int(frames_env))


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		_run_setup()
	if _frames >= _capture_at:
		set_process(false)
		_capture()


func _run_setup() -> void:
	var setup := OS.get_environment("PROFILY_PROBE_SETUP")
	if setup.is_empty():
		return
	# Several ';'-separated expressions are evaluated on the live manager,
	# whichever way it was created (autoload or scene instance).
	var profily := ProfilyManager.instance
	if profily == null:
		push_error("[probe] No Profily manager found")
		return
	for statement: String in setup.split(";", false):
		var expression := Expression.new()
		if expression.parse(statement.strip_edges()) != OK:
			push_error("[probe] setup parse error: %s" % expression.get_error_text())
			continue
		expression.execute([], profily)
		if expression.has_execute_failed():
			push_error("[probe] setup failed: %s" % expression.get_error_text())


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("PROFILY_PROBE_OUT")
	if out.is_empty():
		out = "user://profily_probe.png"
	var image := get_viewport().get_texture().get_image()
	image.save_png(out)
	print("[probe] saved %s" % out)
	get_tree().quit()
