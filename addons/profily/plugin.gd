@tool
extends EditorPlugin
## Profily editor plugin: registers the project settings and the autoload.
##
## Profily is a Godot port of Graphy (MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.

const AUTOLOAD_NAME := "Profily"
const AUTOLOAD_PATH := "res://addons/profily/profily.tscn"


func _enter_tree() -> void:
	# Idempotent: makes sure the settings exist even if the plugin was already
	# enabled (e.g. after updating the addon).
	ProfilySettings.register_all()


func _enable_plugin() -> void:
	ProfilySettings.register_all()
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	ProjectSettings.save()


func _disable_plugin() -> void:
	# The profily/* settings are kept on purpose: they are user configuration
	# and re-enabling the plugin picks them up unchanged.
	remove_autoload_singleton(AUTOLOAD_NAME)
