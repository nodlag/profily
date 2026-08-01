extends Node
## FPS data collector. Port of G_FpsMonitor (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Measures frame time with Time.get_ticks_usec() so Engine.time_scale never
## distorts the readings (parity with Unity's unscaledDeltaTime).

const SAMPLES_CAPACITY := 1024

## Startup grace period (deviation from the original): Godot's very first
## frames can run sub-millisecond before vsync kicks in, which would poison
## the average and pin the graph's decaying ceiling for minutes. Samples are
## ignored until this elapses.
const WARMUP_SECONDS := 0.5

## FPS of the last frame (rounded), like the original's CurrentFPS.
var current_fps := 0.0
## Average over the whole sample window.
var average_fps := 0.0
## 1% low: average of the worst capacity/100 (=10) samples in the window.
var one_percent_fps := 0.0
## 0.1% low: the single worst sample in the window (capacity/1000 = 1).
var zero1_percent_fps := 0.0

## Unscaled seconds elapsed during the last frame (0 on the very first frame).
var unscaled_delta := 0.0

var _samples := PackedInt32Array()
var _samples_sorted := PackedInt32Array()
var _sample_index := 0
var _samples_count := 0
var _samples_sum := 0
var _last_ticks_usec := 0
var _has_last_ticks := false
var _warmup_left := WARMUP_SECONDS


func _ready() -> void:
	_samples.resize(SAMPLES_CAPACITY)
	# Sorted mirror of _samples, kept in sync incrementally in _process().
	_samples_sorted.resize(SAMPLES_CAPACITY)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if not _has_last_ticks:
		# Discard the first frame: there is no previous tick to diff against.
		_last_ticks_usec = now
		_has_last_ticks = true
		return
	var delta_usec := now - _last_ticks_usec
	_last_ticks_usec = now
	if delta_usec <= 0:
		return
	unscaled_delta = float(delta_usec) / 1_000_000.0
	if _warmup_left > 0.0:
		_warmup_left -= unscaled_delta
		return
	current_fps = roundf(1.0 / unscaled_delta)

	# Circular buffer insert, with a running sum for the average.
	var fps_int := int(current_fps)
	var outgoing := _samples[_sample_index]
	_samples_sum += fps_int - outgoing
	_samples[_sample_index] = fps_int
	_sample_index = (_sample_index + 1) % SAMPLES_CAPACITY
	_samples_count = mini(_samples_count + 1, SAMPLES_CAPACITY)

	average_fps = float(_samples_sum) / float(_samples_count)

	# Percentile lows over the sorted mirror, updated by swapping the outgoing
	# sample for the incoming one via binary search (implementation deviation:
	# the original re-sorts a copy of the window every frame; the resulting
	# order — and therefore every derived value — is identical). Empty slots
	# are zeros that sit at the front of the ascending order and are skipped.
	if outgoing != fps_int:
		_samples_sorted.remove_at(_samples_sorted.bsearch(outgoing))
		_samples_sorted.insert(_samples_sorted.bsearch(fps_int), fps_int)
	var start := SAMPLES_CAPACITY - _samples_count
	@warning_ignore("integer_division")
	var to_take := mini(SAMPLES_CAPACITY / 100, _samples_count)
	var sum_low := 0
	for i in to_take:
		sum_low += _samples_sorted[start + i]
	# Micro-fix vs Unity: divide by the samples actually taken (the original
	# divides by 10 even while the window is still filling up).
	one_percent_fps = float(sum_low) / float(to_take) if to_take > 0 else 0.0
	zero1_percent_fps = float(_samples_sorted[start])
