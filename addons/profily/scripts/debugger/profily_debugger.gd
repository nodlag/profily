class_name ProfilyDebugger
extends Node
## Condition-based alert system. Port of GraphyDebugger
## (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Watches live Profily values and, when a packet's conditions hold, runs its
## actions: log/warning/error message, screenshot, break and callbacks.
## Fixes a bug in the original where RAM_RESERVED and RAM_MONO both read the
## allocated value, and renames Fps_Min/Fps_Max to what they really are
## (the 1% and 0.1% lows). DRAW_CALLS and NODE_COUNT are Godot extras.

signal packet_executed(packet: ProfilyDebugPacket)

enum DebugVariable {
	FPS,
	FPS_AVG,
	FPS_1_PERCENT, ## The original's misnamed "Fps_Min".
	FPS_01_PERCENT, ## The original's misnamed "Fps_Max".
	RAM_ALLOCATED,
	RAM_RESERVED,
	RAM_VRAM,
	AUDIO_DB,
	DRAW_CALLS,
	NODE_COUNT,
}

enum DebugComparer {
	LESS_THAN,
	EQUALS_OR_LESS_THAN,
	EQUALS,
	EQUALS_OR_GREATER_THAN,
	GREATER_THAN,
}

enum ConditionEvaluation {
	ALL_CONDITIONS_MUST_BE_MET,
	ONLY_ONE_CONDITION_HAS_TO_BE_MET,
}

enum MessageType { LOG, WARNING, ERROR }

var _manager: ProfilyManager
var _packets: Array[ProfilyDebugPacket] = []


func init(manager: ProfilyManager) -> void:
	_manager = manager
	set_process(manager.debugger_enabled)


func _process(delta: float) -> void:
	if _manager == null:
		return
	var finished: Array[ProfilyDebugPacket] = []
	for packet: ProfilyDebugPacket in _packets:
		if packet == null or not packet.active:
			continue
		packet.update(delta)
		if not packet.can_be_checked():
			continue
		if _conditions_met(packet):
			_execute(packet)
			if packet.execute_once:
				finished.append(packet)
	for packet: ProfilyDebugPacket in finished:
		_packets.erase(packet)


# --- Public API (port of the AddNewDebugPacket/Get/Remove family) ---

func add_packet(packet: ProfilyDebugPacket) -> void:
	_packets.append(packet)


## Builds, registers and returns a packet. A single method with defaults
## replaces the original's overloads.
func add_new_debug_packet(
	id: int,
	conditions: Array[ProfilyDebugCondition],
	condition_evaluation: ConditionEvaluation = ConditionEvaluation.ALL_CONDITIONS_MUST_BE_MET,
	execute_once := true,
	init_sleep_time := 2.0,
	execute_sleep_time := 2.0,
	message := "",
	message_type: MessageType = MessageType.LOG,
	take_screenshot := false,
	screenshot_file_name := "profily_screenshot",
	debug_break := false,
	callback := Callable(),
) -> ProfilyDebugPacket:
	var packet := ProfilyDebugPacket.new()
	packet.id = id
	packet.conditions = conditions
	packet.condition_evaluation = condition_evaluation
	packet.execute_once = execute_once
	packet.init_sleep_time = init_sleep_time
	packet.execute_sleep_time = execute_sleep_time
	packet.message = message
	packet.message_type = message_type
	packet.take_screenshot = take_screenshot
	packet.screenshot_file_name = screenshot_file_name
	packet.debug_break = debug_break
	if callback.is_valid():
		packet.callbacks.append(callback)
	add_packet(packet)
	return packet


func get_first_packet_with_id(packet_id: int) -> ProfilyDebugPacket:
	for packet: ProfilyDebugPacket in _packets:
		if packet.id == packet_id:
			return packet
	return null


func get_all_packets_with_id(packet_id: int) -> Array[ProfilyDebugPacket]:
	var result: Array[ProfilyDebugPacket] = []
	for packet: ProfilyDebugPacket in _packets:
		if packet.id == packet_id:
			result.append(packet)
	return result


func remove_first_packet_with_id(packet_id: int) -> void:
	var packet := get_first_packet_with_id(packet_id)
	if packet != null:
		_packets.erase(packet)


func remove_all_packets_with_id(packet_id: int) -> void:
	for packet: ProfilyDebugPacket in get_all_packets_with_id(packet_id):
		_packets.erase(packet)


func add_callback_to_first_packet_with_id(callback: Callable, packet_id: int) -> void:
	var packet := get_first_packet_with_id(packet_id)
	if packet != null:
		packet.callbacks.append(callback)


func add_callback_to_all_packets_with_id(callback: Callable, packet_id: int) -> void:
	for packet: ProfilyDebugPacket in get_all_packets_with_id(packet_id):
		packet.callbacks.append(callback)


func packet_count() -> int:
	return _packets.size()


# --- Internals ---

func _conditions_met(packet: ProfilyDebugPacket) -> bool:
	if packet.conditions.is_empty():
		return false
	match packet.condition_evaluation:
		ConditionEvaluation.ALL_CONDITIONS_MUST_BE_MET:
			for condition: ProfilyDebugCondition in packet.conditions:
				if not _condition_met(condition):
					return false
			return true
		ConditionEvaluation.ONLY_ONE_CONDITION_HAS_TO_BE_MET:
			for condition: ProfilyDebugCondition in packet.conditions:
				if _condition_met(condition):
					return true
			return false
	return false


func _condition_met(condition: ProfilyDebugCondition) -> bool:
	var current := _value_of(condition.variable)
	match condition.comparer:
		DebugComparer.LESS_THAN:
			return current < condition.value
		DebugComparer.EQUALS_OR_LESS_THAN:
			return current <= condition.value
		DebugComparer.EQUALS:
			return is_equal_approx(current, condition.value)
		DebugComparer.EQUALS_OR_GREATER_THAN:
			return current >= condition.value
		DebugComparer.GREATER_THAN:
			return current > condition.value
	return false


func _value_of(variable: DebugVariable) -> float:
	match variable:
		DebugVariable.FPS:
			return _manager.current_fps
		DebugVariable.FPS_AVG:
			return _manager.average_fps
		DebugVariable.FPS_1_PERCENT:
			return _manager.one_percent_fps
		DebugVariable.FPS_01_PERCENT:
			return _manager.zero1_percent_fps
		DebugVariable.RAM_ALLOCATED:
			return _manager.allocated_ram
		DebugVariable.RAM_RESERVED:
			return _manager.reserved_ram
		DebugVariable.RAM_VRAM:
			return _manager.vram
		DebugVariable.AUDIO_DB:
			return _manager.max_db
		DebugVariable.DRAW_CALLS:
			return _manager.draw_calls
		DebugVariable.NODE_COUNT:
			return _manager.node_count
	return 0.0


func _execute(packet: ProfilyDebugPacket) -> void:
	packet.mark_executed()
	if not packet.message.is_empty():
		var text := "[Profily] %s: %s" % [
			Time.get_datetime_string_from_system(), packet.message,
		]
		match packet.message_type:
			MessageType.LOG:
				print(text)
			MessageType.WARNING:
				push_warning(text)
			MessageType.ERROR:
				push_error(text)
	if packet.take_screenshot:
		_take_screenshot(packet.screenshot_file_name)
	if packet.debug_break:
		_debug_break()
	for callback: Callable in packet.callbacks:
		if callback.is_valid():
			callback.call()
	packet.executed.emit()
	packet_executed.emit(packet)


func _take_screenshot(base_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("[Profily] Screenshot skipped (headless run).")
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://%s_%s.png" % [base_name, stamp]
	image.save_png(path)
	print("[Profily] Screenshot saved: %s" % ProjectSettings.globalize_path(path))


## Equivalent of Unity's Debug.Break(): engine breakpoint with a debugger
## attached; otherwise pauses the tree (Profily keeps running thanks to
## PROCESS_MODE_ALWAYS).
func _debug_break() -> void:
	if EngineDebugger.is_active():
		breakpoint
	else:
		get_tree().paused = true
		push_warning("[Profily] debug_break: scene tree paused (no debugger attached).")
