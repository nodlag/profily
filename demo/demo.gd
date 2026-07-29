extends Node3D
## Profily demo and testing scene.
## (c) 2026 Javier Garrido (nodlag), MIT.
##
## The Music node streams a generated chord (three sines with slow amplitude
## LFOs) so the audio module has a live spectrum without bundling any audio
## asset. Skipped in headless runs (Dummy audio driver).
## The UI panel exercises the whole Profily API: presets, per-module states,
## corners, node/orphan spawning and a CPU burner to drop real FPS.

const TONE_FREQS: Array[float] = [220.0, 440.0, 880.0]
const TONE_LFO_SPEEDS: Array[float] = [0.7, 1.3, 2.9]
const SPAWN_BATCH := 500
const STORE_URL := "https://store.godotengine.org/asset/javier-garrido/profily/"

@onready var _camera: Camera3D = $Camera3D
@onready var _music: AudioStreamPlayer = $Music

@onready var _toggle_preset_button: Button = %TogglePresetButton
@onready var _toggle_active_button: Button = %ToggleActiveButton
@onready var _position_option: OptionButton = %PositionOption
@onready var _module_option: OptionButton = %ModuleOption
@onready var _state_option: OptionButton = %StateOption
@onready var _spawn_button: Button = %SpawnButton
@onready var _free_button: Button = %FreeButton
@onready var _orphan_button: Button = %OrphanButton
@onready var _burn_slider: HSlider = %BurnSlider
@onready var _packet_button: Button = %PacketButton
@onready var _rate_button: Button = %RateButton
@onready var _status_label: Label = %StatusLabel

## Typed access to the manager: works identically whether Profily runs as the
## plugin autoload or as a scene-dropped instance.
var _profily: ProfilyManager

var _playback: AudioStreamGeneratorPlayback
var _phases := PackedFloat32Array([0.0, 0.0, 0.0])
var _lfo_time := 0.0
var _spawned: Node
var _orphans: Array[Node] = []


func _ready() -> void:
	_profily = ProfilyManager.instance
	_camera.look_at_from_position(Vector3(0.0, 3.0, 9.0), Vector3.ZERO)
	if DisplayServer.get_name() != "headless":
		_music.play()
		_playback = _music.get_stream_playback()
	if _profily != null:
		_setup_ui()
	else:
		_status_label.text = "No Profily found: enable the plugin or drop profily.tscn into this scene."
		push_warning("[ProfilyDemo] No Profily instance/autoload found; the demo UI is inert.")
	print("[ProfilyDemo] ready — Profily manager active: %s" % is_instance_valid(_profily))


func _exit_tree() -> void:
	# Release the generator playback (otherwise it is reported as a leaked
	# instance on quit) and the intentional orphans.
	_music.stop()
	_playback = null
	for orphan: Node in _orphans:
		orphan.free()
	_orphans.clear()


func _process(_delta: float) -> void:
	_fill_music_buffer()
	_burn_cpu()


func _setup_ui() -> void:
	for corner: String in ["Top Right", "Top Left", "Bottom Right", "Bottom Left", "Free"]:
		_position_option.add_item(corner)
	for module: String in ["FPS", "RAM", "AUDIO", "ADVANCED", "SCENE"]:
		_module_option.add_item(module)
	for state: String in ["Full", "Text", "Basic", "Background", "Off"]:
		_state_option.add_item(state)

	_toggle_preset_button.pressed.connect(func() -> void: _profily.toggle_modes())
	_toggle_active_button.pressed.connect(func() -> void: _profily.toggle_active())
	_position_option.item_selected.connect(func(index: int) -> void:
		_profily.graph_modules_position = index as ProfilyTypes.ModulePosition)
	_state_option.item_selected.connect(_apply_module_state)
	_module_option.item_selected.connect(func(_index: int) -> void: _sync_state_option())
	_spawn_button.pressed.connect(_spawn_nodes)
	_free_button.pressed.connect(_free_spawned)
	_orphan_button.pressed.connect(_create_orphan)
	_packet_button.pressed.connect(_add_debug_packet)
	_rate_button.pressed.connect(_open_store_page)

	_profily.preset_changed.connect(func(preset: ProfilyTypes.ModulePreset) -> void:
		_status_label.text = "Preset: %s" % ProfilyTypes.ModulePreset.keys()[preset])
	_profily.active_toggled.connect(func(active: bool) -> void:
		_status_label.text = "Profily %s" % ("enabled" if active else "disabled"))
	_sync_state_option()


func _apply_module_state(state_index: int) -> void:
	var module := _module_option.selected as ProfilyTypes.ModuleType
	_profily.set_module_mode(module, state_index as ProfilyTypes.ModuleState)


func _sync_state_option() -> void:
	# Reflect the selected module's current state in the state dropdown.
	var states := {
		ProfilyTypes.ModuleType.FPS: _profily.fps_module_state,
		ProfilyTypes.ModuleType.RAM: _profily.ram_module_state,
		ProfilyTypes.ModuleType.AUDIO: _profily.audio_module_state,
		ProfilyTypes.ModuleType.ADVANCED: _profily.advanced_module_state,
		ProfilyTypes.ModuleType.SCENE: _profily.scene_module_state,
	}
	_state_option.selected = states[_module_option.selected as ProfilyTypes.ModuleType]


func _spawn_nodes() -> void:
	if _spawned == null:
		_spawned = Node.new()
		_spawned.name = "Spawned"
		add_child(_spawned)
	for i in SPAWN_BATCH:
		_spawned.add_child(Node3D.new())
	_status_label.text = "Spawned nodes: %d" % _spawned.get_child_count()


func _free_spawned() -> void:
	if _spawned != null:
		_spawned.queue_free()
		_spawned = null
		_status_label.text = "Spawned nodes freed"


func _create_orphan() -> void:
	# Orphan on purpose: raises OBJECT_ORPHAN_NODE_COUNT in the SCENE module.
	# Freed in _exit_tree so the engine does not report leaks on quit.
	_orphans.append(Node.new())
	_status_label.text = "Orphans: %d" % _orphans.size()


func _add_debug_packet() -> void:
	# Fires once when FPS drops below 25 (raise the CPU burn slider to test):
	# warning in the output + screenshot in user://.
	var conditions: Array[ProfilyDebugCondition] = [
		ProfilyDebugCondition.of(
			ProfilyDebugger.DebugVariable.FPS,
			ProfilyDebugger.DebugComparer.LESS_THAN,
			25.0
		),
	]
	var packet: ProfilyDebugPacket = _profily.debugger.add_new_debug_packet(
		1, conditions,
		ProfilyDebugger.ConditionEvaluation.ALL_CONDITIONS_MUST_BE_MET,
		true, 2.0, 2.0,
		"FPS dropped below 25!",
		ProfilyDebugger.MessageType.WARNING,
		true
	)
	packet.executed.connect(func() -> void:
		_status_label.text = "Debug packet fired! (see output & user://)")
	_status_label.text = "Packet armed: FPS<25 → warn+screenshot"


func _open_store_page() -> void:
	OS.shell_open(STORE_URL)
	_status_label.text = "Thanks! Opening the Asset Store…"


func _burn_cpu() -> void:
	var burn_ms := _burn_slider.value
	if burn_ms <= 0.0:
		return
	var end := Time.get_ticks_usec() + int(burn_ms * 1000.0)
	while Time.get_ticks_usec() < end:
		pass # Busy-wait: drops real FPS to test thresholds and the debugger.


func _fill_music_buffer() -> void:
	if _playback == null:
		return
	var generator := _music.stream as AudioStreamGenerator
	var mix_rate := generator.mix_rate
	var frames := _playback.get_frames_available()
	for _frame in frames:
		var sample := 0.0
		for k in TONE_FREQS.size():
			_phases[k] = fmod(_phases[k] + TONE_FREQS[k] / mix_rate, 1.0)
			var amplitude := 0.18 + 0.14 * sin(TAU * TONE_LFO_SPEEDS[k] * _lfo_time)
			sample += sin(TAU * _phases[k]) * amplitude
		_lfo_time += 1.0 / mix_rate
		_playback.push_frame(Vector2(sample, sample))
