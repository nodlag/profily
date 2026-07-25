extends Node
## Audio data collector. Port of G_AudioMonitor (Graphy, MIT (c) 2018 Martin Pane).
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## Godot mapping (the original read Unity's AudioListener):
##  - The spectrum comes from an AudioEffectSpectrumAnalyzer that this monitor
##    adds to the configured bus while capturing and removes when disabled
##    (the equivalent of the original's LookForAudioListener behaviour).
##  - max_db uses the bus peak volume instead of the waveform RMS (documented
##    deviation: it avoids inserting a second capture effect on the bus).

## Max output level of the monitored bus, clamped to -80..0 dB.
var max_db := -80.0
## Normalized 0..1 spectrum bars (no visual gap effect applied).
var spectrum := PackedFloat32Array()
## Normalized 0..1 peak-hold bars (decaying, like the original's highest values).
var spectrum_peaks := PackedFloat32Array()
## True once the analyzer instance is resolved and producing data.
var spectrum_available := false

var _manager: ProfilyManager
var _resolution := 81
var _bus_index := -1
var _analyzer: AudioEffectSpectrumAnalyzer
var _instance: AudioEffectSpectrumAnalyzerInstance
var _peak_lin := PackedFloat32Array()


func init(manager: ProfilyManager) -> void:
	_manager = manager
	update_parameters()


func update_parameters() -> void:
	_resolution = clampi(_manager.audio_graph_resolution, 10, 300)
	spectrum.resize(_resolution)
	spectrum.fill(0.0)
	spectrum_peaks.resize(_resolution)
	spectrum_peaks.fill(0.0)
	_peak_lin.resize(_resolution)
	_peak_lin.fill(0.0)
	# Recreate the analyzer so bus/fft_size changes take effect.
	if _analyzer != null:
		disable_capture()
		enable_capture()


## Adds the spectrum analyzer effect to the configured bus.
func enable_capture() -> void:
	if _analyzer != null:
		return
	_bus_index = AudioServer.get_bus_index(_manager.audio_bus_name)
	if _bus_index < 0:
		push_warning("[Profily] Audio bus \"%s\" not found; falling back to Master." % _manager.audio_bus_name)
		_bus_index = 0
	_analyzer = AudioEffectSpectrumAnalyzer.new()
	_analyzer.fft_size = _fft_size_for(_manager.audio_spectrum_size)
	_analyzer.buffer_length = 2.0
	AudioServer.add_bus_effect(_bus_index, _analyzer)
	_instance = null # Resolved lazily on the next frame.


## Removes the analyzer. The effect is located by identity right before
## removal: its index may have shifted if the game touched the bus.
func disable_capture() -> void:
	if _analyzer == null:
		return
	var index := _find_effect_index()
	if index >= 0:
		AudioServer.remove_bus_effect(_bus_index, index)
	_analyzer = null
	_instance = null
	spectrum_available = false
	max_db = -80.0


func _exit_tree() -> void:
	disable_capture()


func _process(delta: float) -> void:
	if _analyzer == null:
		return
	if _instance == null:
		var index := _find_effect_index()
		if index >= 0:
			_instance = AudioServer.get_bus_effect_instance(_bus_index, index) \
					as AudioEffectSpectrumAnalyzerInstance
		spectrum_available = _instance != null
		if _instance == null:
			return

	var left := AudioServer.get_bus_peak_volume_left_db(_bus_index, 0)
	var right := AudioServer.get_bus_peak_volume_right_db(_bus_index, 0)
	max_db = clampf(maxf(left, right), -80.0, 0.0)

	# Same Nyquist coverage as the original (which used 486 of 512 bins of a
	# 0..mix_rate/2 spectrum), split into linear per-bar frequency ranges.
	var freq_span := AudioServer.get_mix_rate() * 0.5 * (486.0 / 512.0)
	var step := freq_span / float(_resolution)
	for i in _resolution:
		var magnitude := _instance.get_magnitude_for_frequency_range(
			float(i) * step,
			float(i + 1) * step,
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
		)
		var linear := (magnitude.x + magnitude.y) * 0.5
		# Peak-hold with decay in the linear domain (port of the original).
		var peak := _peak_lin[i]
		if linear > peak:
			peak = linear
		else:
			peak = clampf(peak - peak * delta * 2.0, 0.0, 1.0)
		_peak_lin[i] = peak
		spectrum[i] = db_normalized(lin_to_db_clamped(linear))
		spectrum_peaks[i] = db_normalized(lin_to_db_clamped(peak))


## Port of the original lin2dB: clamp(20*log10(x), -160, 0).
## The epsilon is 1e-8 = exactly -160 dB, so silence normalizes to 0.
static func lin_to_db_clamped(linear: float) -> float:
	return clampf(linear_to_db(maxf(linear, 0.00000001)), -160.0, 0.0)


## Port of the original dBNormalized: maps -160..0 dB to 0..1.
static func db_normalized(db: float) -> float:
	return (db + 160.0) / 160.0


func _find_effect_index() -> int:
	if _bus_index < 0 or _bus_index >= AudioServer.bus_count:
		return -1
	for i in AudioServer.get_bus_effect_count(_bus_index):
		if AudioServer.get_bus_effect(_bus_index, i) == _analyzer:
			return i
	return -1


func _fft_size_for(spectrum_size: int) -> AudioEffectSpectrumAnalyzer.FFTSize:
	match spectrum_size:
		256: return AudioEffectSpectrumAnalyzer.FFT_SIZE_256
		512: return AudioEffectSpectrumAnalyzer.FFT_SIZE_512
		1024: return AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		2048: return AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		4096: return AudioEffectSpectrumAnalyzer.FFT_SIZE_4096
		_: return AudioEffectSpectrumAnalyzer.FFT_SIZE_512
