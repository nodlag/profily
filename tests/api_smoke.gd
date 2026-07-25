extends SceneTree
## Headless API smoke test for Profily: presets, toggles, live data getters
## and the debugger packet lifecycle. Run with:
##   godot --headless --path . -s tests/api_smoke.gd
## Exits 0 on success.
## (c) 2026 Javier Garrido (nodlag), MIT.

var _errors := 0


func _init() -> void:
	_run()


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   %s" % what)
	else:
		push_error("  FAIL %s" % what)
		_errors += 1


func _run() -> void:
	await process_frame

	# Use the autoload if present (normal run), otherwise instance the scene
	# (godot -s does not load autoloads in every configuration).
	var profily: ProfilyManager = root.get_node_or_null("Profily")
	if profily == null:
		profily = (load("res://addons/profily/profily.tscn") as PackedScene).instantiate()
		root.add_child(profily)
		await process_frame
	_check(profily != null, "Profily manager available")

	# --- Presets: all 12 apply without errors and report via signal ---
	var reported: Array = []
	var on_preset := func(preset: ProfilyTypes.ModulePreset) -> void: reported.append(preset)
	profily.preset_changed.connect(on_preset)
	for preset: int in ProfilyTypes.ModulePreset.values():
		profily.set_preset(preset as ProfilyTypes.ModulePreset)
	_check(reported.size() == 12, "12 presets applied and signalled")
	_check(profily.current_preset() == ProfilyTypes.ModulePreset.FPS_BASIC_ADVANCED_FULL,
			"preset pointer on the last preset")
	profily.toggle_modes()
	_check(profily.current_preset() == ProfilyTypes.ModulePreset.FPS_BASIC,
			"toggle_modes wraps from last preset to 0")
	profily.preset_changed.disconnect(on_preset)

	# --- Active toggling restores previous states ---
	profily.set_module_mode(ProfilyTypes.ModuleType.RAM, ProfilyTypes.ModuleState.TEXT)
	profily.disable()
	_check(not profily.is_active, "disable() flips is_active")
	_check(not profily.visible, "disable() hides the canvas layer")
	profily.enable()
	_check(profily.is_active and profily.visible, "enable() restores visibility")

	# --- Live data getters respond (values may legitimately be 0 headless) ---
	await create_timer(0.8).timeout # Let the FPS warmup elapse.
	_check(profily.current_fps >= 0.0, "current_fps readable (%.0f)" % profily.current_fps)
	_check(profily.vram >= 0.0, "vram readable (%.1f MB)" % profily.vram)
	_check(profily.max_db <= 0.0, "max_db readable (%.0f dB)" % profily.max_db)
	_check(profily.spectrum.size() > 0, "spectrum array populated (%d bars)" % profily.spectrum.size())

	# --- Debugger: packet fires once, runs the callback, removes itself ---
	var fired: Array = []
	var conditions: Array[ProfilyDebugCondition] = [
		ProfilyDebugCondition.of(
			ProfilyDebugger.DebugVariable.FPS,
			ProfilyDebugger.DebugComparer.EQUALS_OR_GREATER_THAN,
			0.0
		),
	]
	var packet := profily.debugger.add_new_debug_packet(
		42, conditions,
		ProfilyDebugger.ConditionEvaluation.ALL_CONDITIONS_MUST_BE_MET,
		true, 0.1, 0.1,
		"api_smoke packet",
		ProfilyDebugger.MessageType.LOG,
		false, "profily_screenshot", false,
		func() -> void: fired.append(true)
	)
	_check(profily.debugger.get_first_packet_with_id(42) == packet, "packet registered and findable")
	await create_timer(0.5).timeout
	_check(not fired.is_empty(), "packet condition fired the callback")
	_check(profily.debugger.get_first_packet_with_id(42) == null, "execute_once removed the packet")

	# --- Singleton guard: a second scene instance must remove itself ---
	_check(ProfilyManager.instance == profily, "static instance points at the live manager")
	var duplicate: ProfilyManager = (load("res://addons/profily/profily.tscn") as PackedScene).instantiate()
	root.add_child(duplicate)
	await process_frame
	await process_frame
	_check(not is_instance_valid(duplicate), "duplicate scene instance removed itself")
	_check(ProfilyManager.instance == profily, "original instance survives the duplicate")

	# --- Debugger: recurring packet re-fires and can be removed by id ---
	var recurring_fired: Array = []
	profily.debugger.add_new_debug_packet(
		7, conditions.duplicate(),
		ProfilyDebugger.ConditionEvaluation.ONLY_ONE_CONDITION_HAS_TO_BE_MET,
		false, 0.1, 0.1,
		"", ProfilyDebugger.MessageType.LOG,
		false, "profily_screenshot", false,
		func() -> void: recurring_fired.append(true)
	)
	await create_timer(0.6).timeout
	_check(recurring_fired.size() >= 2, "recurring packet re-fired (%d times)" % recurring_fired.size())
	profily.debugger.remove_all_packets_with_id(7)
	_check(profily.debugger.get_first_packet_with_id(7) == null, "remove_all_packets_with_id")

	# --- Scene-drop mode: profily.tscn works standalone, no autoload needed ---
	profily.free() # Remove the current manager (autoload or manual instance).
	await process_frame
	_check(ProfilyManager.instance == null, "static instance cleared on exit")
	var scene_copy: ProfilyManager = (load("res://addons/profily/profily.tscn") as PackedScene).instantiate()
	var scene_ready: Array = []
	scene_copy.initialized.connect(func() -> void: scene_ready.append(true))
	root.add_child(scene_copy)
	await process_frame
	_check(not scene_ready.is_empty(), "scene-dropped instance initializes standalone")
	_check(ProfilyManager.instance == scene_copy, "scene-dropped instance becomes the singleton")
	_check(scene_copy.is_active, "scene-dropped instance is active")

	# --- Inspector-configured values survive ready (Unity-style workflow) ---
	scene_copy.free()
	await process_frame
	var configured: ProfilyManager = \
			(load("res://addons/profily/profily.tscn") as PackedScene).instantiate()
	# Simulate scene-serialized Inspector overrides (assigned before add_child,
	# exactly like the scene loader applies exported properties).
	configured.good_fps_threshold = 90
	configured.fps_module_state = ProfilyTypes.ModuleState.TEXT
	root.add_child(configured)
	await process_frame
	_check(configured.good_fps_threshold == 90,
			"inspector value survives ready (no profily/* keys registered)")
	_check(configured.fps_module_state == ProfilyTypes.ModuleState.TEXT,
			"inspector module state applied on init")
	configured.settings_source = ProfilyTypes.SettingsSource.INSPECTOR
	_check(configured.settings_source == ProfilyTypes.SettingsSource.INSPECTOR,
			"settings_source switch exposed")

	print("[api_smoke] %s" % ("OK" if _errors == 0 else "FAILED (%d errors)" % _errors))
	quit(_errors)
