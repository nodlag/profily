class_name ProfilyTypes
extends RefCounted
## Shared Profily enums.
##
## Port of the enums nested in GraphyManager (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
## They live in their own dependency-free class so any script in the addon
## can reference them without creating load cycles.

## Global mode: FULL uses graphs of up to 512 points; LIGHT caps them at 128
## (for old/mobile GPUs, mirroring the original's "Mobile" shader).
enum Mode {
	FULL = 0,
	LIGHT = 1,
}

## How graph modules draw their plots (Godot-only, no Graphy counterpart).
## SHADER is the parity path: a per-instance ShaderMaterial per graph.
## CANVAS draws the same plot on the CPU with canvas triangles, for drivers
## whose custom canvas materials are broken (Godot 4.7 Metal driver on
## iOS 26). AUTO resolves to CANVAS on iOS with the Metal driver and to
## SHADER everywhere else.
enum GraphBackend {
	AUTO = 0,
	SHADER = 1,
	CANVAS = 2,
}

## Available modules. SCENE is new in Profily (it does not exist in Graphy).
enum ModuleType {
	FPS = 0,
	RAM = 1,
	AUDIO = 2,
	ADVANCED = 3,
	SCENE = 4,
}

## Presentation state of a module.
enum ModuleState {
	FULL = 0, ## Text + graph + background.
	TEXT = 1, ## Text only, no graph.
	BASIC = 2, ## Minimal (FPS: just the number). In RAM/AUDIO/SCENE same as TEXT.
	BACKGROUND = 3, ## UI invisible but the monitor keeps collecting data.
	OFF = 4, ## Module fully disabled (stops collecting data too).
}

## Corner a module is anchored to. FREE keeps the manual position.
enum ModulePosition {
	TOP_RIGHT = 0,
	TOP_LEFT = 1,
	BOTTOM_RIGHT = 2,
	BOTTOM_LEFT = 3,
	FREE = 4,
}

## Predefined combos rotated by the "toggle mode" hotkey.
## Modules not present in the name are OFF. SCENE is intentionally excluded
## (it keeps its own state) to preserve 1:1 parity with the original rotation.
enum ModulePreset {
	FPS_BASIC = 0,
	FPS_TEXT = 1,
	FPS_FULL = 2,
	FPS_TEXT_RAM_TEXT = 3,
	FPS_FULL_RAM_TEXT = 4,
	FPS_FULL_RAM_FULL = 5,
	FPS_TEXT_RAM_TEXT_AUDIO_TEXT = 6,
	FPS_FULL_RAM_TEXT_AUDIO_TEXT = 7,
	FPS_FULL_RAM_FULL_AUDIO_TEXT = 8,
	FPS_FULL_RAM_FULL_AUDIO_FULL = 9,
	FPS_FULL_RAM_FULL_AUDIO_FULL_ADVANCED_FULL = 10,
	FPS_BASIC_ADVANCED_FULL = 11,
}

## Where ProfilyManager reads its configuration from when entering the tree.
enum SettingsSource {
	PROJECT_SETTINGS = 0, ## profily/* keys override Inspector values when they exist.
	INSPECTOR = 1, ## Only the values serialized in the scene are used.
}
