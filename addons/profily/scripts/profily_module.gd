class_name ProfilyModule
extends Control
## Base class of every Profily module: shared visibility state machine and
## init/hot-reload plumbing (the common core of the original G_*Manager
## classes plus the IMovable/IModifiableState interfaces).
## Deriving from it also lets users build custom modules that plug into the
## manager's state and preset handling.
##
## Port of Graphy (Unity, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.

var _manager: ProfilyManager
var _module_state: ProfilyTypes.ModuleState = ProfilyTypes.ModuleState.FULL
var _previous_state: ProfilyTypes.ModuleState = ProfilyTypes.ModuleState.FULL


## Called once by the manager; wires children, applies parameters and the
## initial state read from the manager's configuration.
func init(manager: ProfilyManager) -> void:
	_manager = manager
	_on_init()
	update_parameters()
	set_state(_initial_state(), true)


## Virtual: re-reads every parameter from the manager (hot-reload path).
## Overrides must end by refreshing the state via _apply_state().
func update_parameters() -> void:
	_apply_state()


func set_state(state: ProfilyTypes.ModuleState, silent := false) -> void:
	if not silent:
		_previous_state = _module_state
	_module_state = state
	_apply_state()


## Reverts to the state active before the last non-silent set_state()
## (used by Profily.enable() after a disable()).
func restore_previous_state() -> void:
	set_state(_previous_state)


func current_state() -> ProfilyTypes.ModuleState:
	return _module_state


## Virtual: the module's live data collector, or null if it has none.
func monitor() -> Node:
	return null


## Height this module occupies in the stacked group for its current state:
## 0 when hidden (OFF/BACKGROUND), the full rect height otherwise. Modules
## with compact TEXT/BASIC layouts override it with their background height
## so the stack leaves no holes.
func effective_height() -> float:
	match _module_state:
		ProfilyTypes.ModuleState.OFF, ProfilyTypes.ModuleState.BACKGROUND:
			return 0.0
		_:
			return size.y


## Width the module's visible content occupies in its current state. Used to
## anchor right-side corners against the content instead of the full rect
## (e.g. the FPS BASIC box is narrower than the module).
func effective_width() -> float:
	return size.x


## Virtual: text alignment adjustment when the module changes corner
## (only the advanced module cares).
func set_alignment_for_position(_module_position: ProfilyTypes.ModulePosition) -> void:
	pass


## Virtual: one-time child wiring, run before the first update_parameters().
func _on_init() -> void:
	pass


## Virtual: the configured startup state for this module.
func _initial_state() -> ProfilyTypes.ModuleState:
	return ProfilyTypes.ModuleState.FULL


## Virtual: applies _module_state to the scene (visibility, processing...).
func _apply_state() -> void:
	pass
