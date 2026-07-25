extends ProfilyModule
## RAM module root: visibility state machine and background switching.
## Port of G_RamManager (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
## TEXT and BASIC are identical in this module (parity with the original).

const RamGraph := preload("ram_graph.gd")
const RamMonitor := preload("ram_monitor.gd")
const RamText := preload("ram_text.gd")

@onready var _monitor: RamMonitor = %Monitor
@onready var _bg_full: Panel = %BackgroundFull
@onready var _bg_text: Panel = %BackgroundText
@onready var _graph: RamGraph = %GraphArea
@onready var _text: RamText = %Text


func monitor() -> Node:
	return _monitor


func effective_height() -> float:
	match _module_state:
		ProfilyTypes.ModuleState.TEXT, ProfilyTypes.ModuleState.BASIC:
			return _bg_text.size.y
		_:
			return super()


func update_parameters() -> void:
	_text.update_parameters()
	_graph.update_parameters()
	for bg: Panel in [_bg_full, _bg_text]:
		bg.self_modulate = _manager.background_color
	_apply_state()


func _on_init() -> void:
	_text.init(_manager, _monitor)
	_graph.init(_manager, _monitor)


func _initial_state() -> ProfilyTypes.ModuleState:
	return _manager.ram_module_state


func _apply_state() -> void:
	if _manager == null:
		return # Not initialized yet; init() re-applies the state.
	var state := _module_state
	visible = state != ProfilyTypes.ModuleState.OFF \
			and state != ProfilyTypes.ModuleState.BACKGROUND
	var show_graph := state == ProfilyTypes.ModuleState.FULL
	var show_text := state in [
		ProfilyTypes.ModuleState.FULL,
		ProfilyTypes.ModuleState.TEXT,
		ProfilyTypes.ModuleState.BASIC,
	]

	_graph.visible = show_graph
	_text.visible = show_text

	var show_background := _manager.background
	_bg_full.visible = show_background and state == ProfilyTypes.ModuleState.FULL
	_bg_text.visible = show_background and state in [
		ProfilyTypes.ModuleState.TEXT, ProfilyTypes.ModuleState.BASIC,
	]

	var collect := state != ProfilyTypes.ModuleState.OFF
	_monitor.set_process(collect)
	_graph.set_process(show_graph)
	_text.set_process(show_text)
