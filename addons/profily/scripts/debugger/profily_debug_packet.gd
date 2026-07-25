class_name ProfilyDebugPacket
extends RefCounted
## A set of conditions with timed gates and the actions to run when they are
## met. Port of GraphyDebugger.DebugPacket (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
## The UnityEvent of the original is replaced by the [signal executed] signal
## plus the [member callbacks] list.

## Emitted right after this packet's actions run.
signal executed

var active := true
## Free-form identifier to look packets up through the debugger API.
var id := 0
## When true (default) the packet removes itself after executing once.
var execute_once := true
## Seconds to wait before the first evaluation (avoids firing on loading
## hiccups, same default as the original).
var init_sleep_time := 2.0
## Seconds between re-evaluations when execute_once is false.
var execute_sleep_time := 2.0
var condition_evaluation: ProfilyDebugger.ConditionEvaluation = \
		ProfilyDebugger.ConditionEvaluation.ALL_CONDITIONS_MUST_BE_MET
var conditions: Array[ProfilyDebugCondition] = []

# --- Actions ---
var message := ""
var message_type: ProfilyDebugger.MessageType = ProfilyDebugger.MessageType.LOG
var take_screenshot := false
var screenshot_file_name := "profily_screenshot"
## Pauses execution: engine breakpoint if a debugger session is attached,
## otherwise pauses the scene tree.
var debug_break := false
var callbacks: Array[Callable] = []

var _time_passed := 0.0
var _can_be_checked := false
var _has_executed := false


## Advances the temporal gate (port of DebugPacket.Update).
func update(delta: float) -> void:
	if _can_be_checked:
		return
	_time_passed += delta
	var wait := execute_sleep_time if _has_executed else init_sleep_time
	if _time_passed >= wait:
		_can_be_checked = true


func can_be_checked() -> bool:
	return _can_be_checked


## Re-arms the temporal gate after executing (port of DebugPacket.Executed).
func mark_executed() -> void:
	_has_executed = true
	_can_be_checked = false
	_time_passed = 0.0
