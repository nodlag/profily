class_name ProfilyDebugCondition
extends RefCounted
## One condition of a debug packet: VARIABLE COMPARER VALUE
## (e.g. FPS < 25). Port of GraphyDebugger.DebugCondition
## (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.

var variable: ProfilyDebugger.DebugVariable = ProfilyDebugger.DebugVariable.FPS
var comparer: ProfilyDebugger.DebugComparer = ProfilyDebugger.DebugComparer.LESS_THAN
var value := 0.0


## Convenience factory:
## ProfilyDebugCondition.of(Var.FPS, Comparer.LESS_THAN, 25.0)
static func of(
	p_variable: ProfilyDebugger.DebugVariable,
	p_comparer: ProfilyDebugger.DebugComparer,
	p_value: float,
) -> ProfilyDebugCondition:
	var condition := ProfilyDebugCondition.new()
	condition.variable = p_variable
	condition.comparer = p_comparer
	condition.value = p_value
	return condition
