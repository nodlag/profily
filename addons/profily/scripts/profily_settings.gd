@tool
class_name ProfilySettings
extends RefCounted
## Registration and reading of Profily's ProjectSettings entries.
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Defaults replicate the ones serialized in the original Graphy prefab
## (which take precedence over its C# code defaults). The plugin calls
## [method register_all] when enabled; at runtime the manager reads each key
## through [method value], which works even if the plugin never registered
## anything (e.g. autoload added by hand) thanks to the default fallback.

const SETTINGS: Dictionary = {
	# --- General ---
	"profily/general/enabled_on_startup": {"type": TYPE_BOOL, "default": true},
	"profily/general/mode": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Full,Light",
	},
	"profily/general/graph_backend": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto,Shader,Canvas",
	},
	"profily/general/background": {"type": TYPE_BOOL, "default": true},
	"profily/general/background_color": {"type": TYPE_COLOR, "default": Color(0.0, 0.0, 0.0, 0.333333)},
	"profily/general/canvas_layer": {
		"type": TYPE_INT, "default": 128,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,128",
	},
	"profily/general/ui_scale": {
		"type": TYPE_FLOAT, "default": 0.66,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.2,3,0.01",
	},
	"profily/general/graph_modules_position": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Top Right,Top Left,Bottom Right,Bottom Left,Free",
	},
	"profily/general/graph_modules_offset": {"type": TYPE_VECTOR2, "default": Vector2.ZERO},

	# --- Hotkeys ---
	"profily/hotkeys/enabled": {"type": TYPE_BOOL, "default": true},
	"profily/hotkeys/toggle_mode_key": {"type": TYPE_INT, "default": KEY_G},
	"profily/hotkeys/toggle_mode_ctrl": {"type": TYPE_BOOL, "default": true},
	"profily/hotkeys/toggle_mode_alt": {"type": TYPE_BOOL, "default": false},
	"profily/hotkeys/toggle_active_key": {"type": TYPE_INT, "default": KEY_H},
	"profily/hotkeys/toggle_active_ctrl": {"type": TYPE_BOOL, "default": true},
	"profily/hotkeys/toggle_active_alt": {"type": TYPE_BOOL, "default": false},

	# --- FPS ---
	"profily/fps/module_state": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Full,Text,Basic,Background,Off",
	},
	"profily/fps/good_threshold": {
		"type": TYPE_INT, "default": 60,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,300",
	},
	"profily/fps/caution_threshold": {
		"type": TYPE_INT, "default": 30,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,300",
	},
	"profily/fps/good_color": {"type": TYPE_COLOR, "default": Color(0.2083, 0.6792, 0.6219)},
	"profily/fps/caution_color": {"type": TYPE_COLOR, "default": Color(0.9137, 0.7686, 0.4157)},
	"profily/fps/critical_color": {"type": TYPE_COLOR, "default": Color(0.9059, 0.4353, 0.3176)},
	"profily/fps/graph_resolution": {
		"type": TYPE_INT, "default": 150,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "10,300",
	},
	"profily/fps/text_update_rate": {
		"type": TYPE_INT, "default": 3,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,60",
	},

	# --- RAM ---
	"profily/ram/module_state": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Full,Text,Basic,Background,Off",
	},
	"profily/ram/allocated_color": {"type": TYPE_COLOR, "default": Color(0.9451, 0.3569, 0.7098)},
	"profily/ram/reserved_color": {"type": TYPE_COLOR, "default": Color(0.9961, 0.8941, 0.251)},
	"profily/ram/vram_color": {"type": TYPE_COLOR, "default": Color(0.0, 0.7333, 0.9765)},
	"profily/ram/graph_resolution": {
		"type": TYPE_INT, "default": 150,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "10,300",
	},
	"profily/ram/text_update_rate": {
		"type": TYPE_INT, "default": 3,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,60",
	},

	# --- Audio ---
	"profily/audio/module_state": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Full,Text,Basic,Background,Off",
	},
	"profily/audio/bus_name": {"type": TYPE_STRING, "default": "Master"},
	"profily/audio/graph_color": {"type": TYPE_COLOR, "default": Color.WHITE},
	"profily/audio/graph_resolution": {
		"type": TYPE_INT, "default": 81,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "10,300",
	},
	"profily/audio/spectrum_size": {
		"type": TYPE_INT, "default": 512,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "256:256,512:512,1024:1024,2048:2048,4096:4096",
	},
	"profily/audio/text_update_rate": {
		"type": TYPE_INT, "default": 3,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,60",
	},

	# --- Advanced ---
	"profily/advanced/module_state": {
		"type": TYPE_INT, "default": 0,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Full,Text,Basic,Background,Off",
	},
	"profily/advanced/module_position": {
		"type": TYPE_INT, "default": 3,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Top Right,Top Left,Bottom Right,Bottom Left,Free",
	},
	"profily/advanced/module_offset": {"type": TYPE_VECTOR2, "default": Vector2.ZERO},

	# --- Scene (Godot-specific extra, not present in Graphy) ---
	"profily/scene/module_state": {
		"type": TYPE_INT, "default": 4, # Off: out of the box identical to the original Graphy.
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Full,Text,Basic,Background,Off",
	},
	"profily/scene/graph_color": {"type": TYPE_COLOR, "default": Color(1.0, 0.65, 0.25)},
	"profily/scene/graph_resolution": {
		"type": TYPE_INT, "default": 150,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "10,300",
	},
	"profily/scene/text_update_rate": {
		"type": TYPE_INT, "default": 3,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,60",
	},

	# --- Debugger ---
	"profily/debugger/enabled": {"type": TYPE_BOOL, "default": true},
}


## Creates any missing keys and publishes their metadata (type/hints) so they
## show up properly editable in Project Settings. Idempotent.
static func register_all() -> void:
	for key: String in SETTINGS:
		var info: Dictionary = SETTINGS[key]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, info["default"])
		ProjectSettings.set_initial_value(key, info["default"])
		var property_info: Dictionary = {
			"name": key,
			"type": info["type"],
		}
		if info.has("hint"):
			property_info["hint"] = info["hint"]
		if info.has("hint_string"):
			property_info["hint_string"] = info["hint_string"]
		ProjectSettings.add_property_info(property_info)


## Reads a setting if it exists in ProjectSettings; otherwise returns
## [param fallback] (the manager passes its current value, which lets
## Inspector-configured scene instances keep their values when the plugin
## never registered the profily/* keys).
static func value_or(key: String, fallback: Variant) -> Variant:
	assert(SETTINGS.has(key), "Unknown Profily setting: %s" % key)
	return ProjectSettings.get_setting(key, fallback)
