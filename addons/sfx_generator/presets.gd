class_name SFXPresets
extends RefCounted
## Hand-tuned preset library for SFXSynthEngine.
##
## Each preset is a partial parameter dictionary (missing keys fall back to
## SFXSynthEngine.default_params()). Categories: ui, sci-fi, magic, impact,
## nature, musical.

const CATEGORIES: Array = ["ui", "sci-fi", "magic", "impact", "nature", "musical"]


static func get_presets() -> Array:
	var list: Array = []
	list.append(_mk("Soft UI Click", "ui", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SINE, "duration": 0.12,
		"base_freq": 900.0, "freq_end": 600.0, "amp_attack": 0.002,
		"amp_decay": 0.04, "amp_release": 0.05,
		"filter_type": SFXSynthEngine.FILTER_LOWPASS, "filter_freq": 5000.0,
	}))
	list.append(_mk("Glass UI Tick", "ui", {
		"mode": "additive", "duration": 0.25, "base_freq": 1800.0,
		"partial_count": 6, "inharmonicity": 0.001, "partial_rolloff": 1.2,
		"noise_amount": 0.3, "noise_attack": 0.003,
		"amp_attack": 0.001, "amp_decay": 0.08, "amp_release": 0.12,
		"reverb_mix": 0.25, "reverb_decay": 1.2,
	}))
	list.append(_mk("Retro Coin (rich)", "ui", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SQUARE, "duration": 0.35,
		"base_freq": 988.0, "freq_end": 1319.0, "second_amount": 0.3,
		"second_detune": 4.0, "amp_attack": 0.002, "amp_decay": 0.1,
		"amp_sustain": 0.4, "amp_release": 0.15,
		"filter_type": SFXSynthEngine.FILTER_LOWPASS, "filter_freq": 6000.0,
		"distortion": 0.08, "reverb_mix": 0.15,
	}))
	list.append(_mk("Bubble Pop", "ui", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SINE, "duration": 0.18,
		"base_freq": 300.0, "freq_end": 900.0, "amp_attack": 0.001,
		"amp_decay": 0.05, "amp_release": 0.08,
		"filter_type": SFXSynthEngine.FILTER_BANDPASS, "filter_freq": 1200.0,
		"filter_q": 2.0, "reverb_mix": 0.2,
	}))
	list.append(_mk("Laser Zap", "sci-fi", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SAW, "duration": 0.45,
		"base_freq": 1800.0, "freq_end": 120.0, "fm_index": 4.0,
		"fm_ratio": 2.0, "fm_decay": 5.0, "noise_amount": 0.2,
		"amp_attack": 0.001, "amp_decay": 0.15, "amp_release": 0.2,
		"filter_type": SFXSynthEngine.FILTER_LOWPASS, "filter_freq": 8000.0,
		"filter_freq_end": 300.0, "distortion": 0.15, "reverb_mix": 0.2,
	}))
	list.append(_mk("FM Bell", "sci-fi", {
		"mode": "fm", "duration": 1.8, "base_freq": 660.0, "fm_ratio": 3.01,
		"fm_index": 6.0, "fm_decay": 2.5, "fm_feedback": 0.15,
		"amp_attack": 0.001, "amp_decay": 0.6, "amp_release": 0.9,
		"reverb_mix": 0.5, "reverb_decay": 3.5, "chorus": 0.3,
	}))
	list.append(_mk("Electric Spark", "sci-fi", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_WHITE, "duration": 0.3,
		"base_freq": 200.0, "freq_end": 60.0, "noise_amount": 1.0,
		"filter_type": SFXSynthEngine.FILTER_BANDPASS, "filter_freq": 3000.0,
		"filter_freq_end": 500.0, "filter_q": 4.0,
		"amp_attack": 0.001, "amp_decay": 0.08, "amp_release": 0.12,
		"distortion": 0.4, "ring_mod": 0.5, "ring_mod_freq": 80.0,
	}))
	list.append(_mk("Robot Voice", "sci-fi", {
		"mode": "formant", "duration": 0.8, "base_freq": 110.0,
		"freq_end": 90.0, "vibrato_rate": 6.0, "vibrato_depth": 0.02,
		"formant1": 600.0, "formant2": 1200.0, "formant3": 2600.0,
		"formant_bw": 60.0, "amp_attack": 0.02, "amp_decay": 0.2,
		"amp_sustain": 0.6, "amp_release": 0.2, "distortion": 0.2,
		"ring_mod": 0.3, "ring_mod_freq": 50.0,
	}))
	list.append(_mk("Alien Chirp", "sci-fi", {
		"mode": "formant", "duration": 0.5, "base_freq": 800.0,
		"freq_end": 1600.0, "vibrato_rate": 12.0, "vibrato_depth": 0.08,
		"formant1": 900.0, "formant2": 1800.0, "formant3": 3200.0,
		"amp_attack": 0.01, "amp_decay": 0.15, "amp_release": 0.2,
		"reverb_mix": 0.4, "delay_mix": 0.25, "delay_time": 0.18,
	}))
	list.append(_mk("Magic Sparkle", "magic", {
		"mode": "granular", "duration": 1.5, "base_freq": 1200.0,
		"grain_density": 30.0, "grain_size": 0.06, "grain_spread": 18.0,
		"grain_wave": SFXSynthEngine.WAVE_SINE,
		"amp_attack": 0.05, "amp_decay": 0.4, "amp_release": 0.8,
		"reverb_mix": 0.6, "reverb_decay": 4.0, "chorus": 0.4,
	}))
	list.append(_mk("Crystal Chime", "magic", {
		"mode": "additive", "duration": 2.5, "base_freq": 880.0,
		"partial_count": 12, "inharmonicity": 0.0008, "partial_rolloff": 0.8,
		"partial_decay_spread": 2.0, "noise_amount": 0.2, "noise_attack": 0.002,
		"amp_attack": 0.001, "amp_decay": 0.8, "amp_release": 1.2,
		"reverb_mix": 0.6, "reverb_decay": 4.5,
	}))
	list.append(_mk("Enchanted Pluck", "magic", {
		"mode": "pluck", "duration": 1.2, "base_freq": 523.0,
		"pluck_damping": 0.998, "pluck_brightness": 0.7, "pluck_strings": 2,
		"amp_attack": 0.002, "amp_decay": 0.4, "amp_release": 0.6,
		"reverb_mix": 0.45, "reverb_decay": 3.0, "delay_mix": 0.2,
	}))
	list.append(_mk("Portal Whoosh", "magic", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_PINK, "duration": 1.2,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_BANDPASS,
		"filter_freq": 400.0, "filter_freq_end": 3000.0, "filter_q": 3.0,
		"amp_attack": 0.3, "amp_decay": 0.3, "amp_sustain": 0.5,
		"amp_release": 0.4, "reverb_mix": 0.5, "chorus": 0.3,
	}))
	list.append(_mk("Deep Explosion", "impact", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_BROWN, "duration": 2.0,
		"base_freq": 60.0, "freq_end": 30.0, "noise_amount": 1.0,
		"sub_amount": 0.8, "filter_type": SFXSynthEngine.FILTER_LOWPASS,
		"filter_freq": 1200.0, "filter_freq_end": 80.0,
		"amp_attack": 0.001, "amp_decay": 0.7, "amp_release": 1.0,
		"distortion": 0.5, "reverb_mix": 0.35, "reverb_decay": 2.0,
	}))
	list.append(_mk("Metallic Clang", "impact", {
		"mode": "fm", "duration": 1.0, "base_freq": 220.0, "fm_ratio": 2.76,
		"fm_index": 8.0, "fm_decay": 4.0, "fm_feedback": 0.3,
		"noise_amount": 0.4, "amp_attack": 0.001, "amp_decay": 0.3,
		"amp_release": 0.5, "distortion": 0.2, "reverb_mix": 0.3,
	}))
	list.append(_mk("Heavy Thud", "impact", {
		"mode": "hybrid", "duration": 0.6, "base_freq": 90.0, "freq_end": 40.0,
		"fm_ratio": 1.5, "fm_index": 5.0, "fm_decay": 8.0,
		"noise_amount": 0.6, "sub_amount": 1.0,
		"filter_type": SFXSynthEngine.FILTER_LOWPASS, "filter_freq": 800.0,
		"amp_attack": 0.001, "amp_decay": 0.2, "amp_release": 0.3,
		"distortion": 0.3,
	}))
	list.append(_mk("Glass Smash", "impact", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_WHITE, "duration": 0.8,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_HIGHPASS,
		"filter_freq": 2000.0, "amp_attack": 0.001, "amp_decay": 0.25,
		"amp_release": 0.4, "reverb_mix": 0.4, "reverb_decay": 1.5,
		"bitcrush_bits": 10.0,
	}))
	list.append(_mk("Whoosh (swish)", "impact", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_PINK, "duration": 0.5,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_BANDPASS,
		"filter_freq": 300.0, "filter_freq_end": 2500.0, "filter_q": 1.5,
		"amp_attack": 0.08, "amp_decay": 0.15, "amp_release": 0.2,
	}))
	list.append(_mk("Rain Loop", "nature", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_PINK, "duration": 4.0,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_LOWPASS,
		"filter_freq": 4000.0, "amp_attack": 0.3, "amp_decay": 0.5,
		"amp_sustain": 0.8, "amp_release": 0.5, "tremolo_rate": 0.5,
		"tremolo_depth": 0.15,
	}))
	list.append(_mk("Wind Gust", "nature", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_BROWN, "duration": 3.0,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_BANDPASS,
		"filter_freq": 500.0, "filter_freq_end": 900.0, "filter_q": 0.8,
		"amp_attack": 0.8, "amp_decay": 0.8, "amp_sustain": 0.4,
		"amp_release": 0.8, "tremolo_rate": 0.3, "tremolo_depth": 0.4,
	}))
	list.append(_mk("Bird Chirp", "nature", {
		"mode": "formant", "duration": 0.4, "base_freq": 2400.0,
		"freq_end": 3200.0, "vibrato_rate": 20.0, "vibrato_depth": 0.1,
		"formant1": 2500.0, "formant2": 3500.0, "formant3": 4500.0,
		"amp_attack": 0.01, "amp_decay": 0.1, "amp_release": 0.15,
		"reverb_mix": 0.2,
	}))
	list.append(_mk("Owl Hoot", "nature", {
		"mode": "formant", "duration": 0.7, "base_freq": 350.0, "freq_end": 300.0,
		"formant1": 400.0, "formant2": 900.0, "formant3": 2000.0,
		"amp_attack": 0.05, "amp_decay": 0.2, "amp_sustain": 0.5,
		"amp_release": 0.25, "vibrato_rate": 4.0, "vibrato_depth": 0.02,
	}))
	list.append(_mk("Water Splash", "nature", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_WHITE, "duration": 0.7,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_BANDPASS,
		"filter_freq": 1500.0, "filter_freq_end": 600.0, "filter_q": 1.0,
		"amp_attack": 0.005, "amp_decay": 0.2, "amp_release": 0.3,
		"reverb_mix": 0.3,
	}))
	list.append(_mk("Plucked String", "musical", {
		"mode": "pluck", "duration": 1.5, "base_freq": 440.0,
		"pluck_damping": 0.997, "pluck_brightness": 0.6,
		"amp_attack": 0.002, "amp_decay": 0.5, "amp_release": 0.7,
		"reverb_mix": 0.3, "reverb_decay": 2.0,
	}))
	list.append(_mk("Warm Pad Stab", "musical", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SAW, "duration": 1.5,
		"base_freq": 220.0, "second_amount": 0.5, "second_detune": 10.0,
		"sub_amount": 0.4, "amp_attack": 0.05, "amp_decay": 0.4,
		"amp_sustain": 0.5, "amp_release": 0.6,
		"filter_type": SFXSynthEngine.FILTER_LOWPASS, "filter_freq": 2500.0,
		"chorus": 0.4, "reverb_mix": 0.4,
	}))
	list.append(_mk("Bass Drop", "musical", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SINE, "duration": 1.0,
		"base_freq": 150.0, "freq_end": 35.0, "sub_amount": 0.5,
		"amp_attack": 0.001, "amp_decay": 0.4, "amp_release": 0.5,
		"distortion": 0.1, "filter_type": SFXSynthEngine.FILTER_LOWPASS,
		"filter_freq": 1000.0, "filter_freq_end": 100.0,
	}))
	list.append(_mk("Chiptune Arp (warm)", "musical", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_TRIANGLE, "duration": 0.8,
		"base_freq": 523.0, "freq_end": 1047.0, "second_amount": 0.2,
		"amp_attack": 0.002, "amp_decay": 0.2, "amp_sustain": 0.3,
		"amp_release": 0.3, "filter_type": SFXSynthEngine.FILTER_LOWPASS,
		"filter_freq": 5000.0, "delay_mix": 0.2, "delay_time": 0.2,
		"reverb_mix": 0.2,
	}))
	list.append(_mk("Bell Toll", "musical", {
		"mode": "fm", "duration": 3.0, "base_freq": 196.0, "fm_ratio": 2.0,
		"fm_index": 4.0, "fm_decay": 1.5, "amp_attack": 0.001,
		"amp_decay": 1.0, "amp_release": 1.5, "reverb_mix": 0.5,
		"reverb_decay": 4.0,
	}))
	list.append(_mk("Footstep (gravel)", "impact", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_BROWN, "duration": 0.18,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_LOWPASS,
		"filter_freq": 900.0, "amp_attack": 0.002, "amp_decay": 0.05,
		"amp_release": 0.08, "distortion": 0.15,
	}))
	list.append(_mk("Door Creak", "nature", {
		"mode": "formant", "duration": 1.0, "base_freq": 120.0, "freq_end": 200.0,
		"formant1": 500.0, "formant2": 1100.0, "formant3": 2400.0,
		"vibrato_rate": 3.0, "vibrato_depth": 0.05,
		"amp_attack": 0.1, "amp_decay": 0.3, "amp_sustain": 0.4,
		"amp_release": 0.3, "noise_amount": 0.3,
	}))
	list.append(_mk("Power-up Shimmer", "magic", {
		"mode": "additive", "duration": 1.0, "base_freq": 523.0,
		"freq_end": 1568.0, "partial_count": 10, "inharmonicity": 0.0003,
		"amp_attack": 0.02, "amp_decay": 0.3, "amp_release": 0.5,
		"reverb_mix": 0.5, "chorus": 0.3, "delay_mix": 0.2,
	}))
	list.append(_mk("Glitch Blip", "sci-fi", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SQUARE, "duration": 0.2,
		"base_freq": 800.0, "freq_end": 400.0, "bitcrush_bits": 6.0,
		"bitcrush_rate": 11025.0, "ring_mod": 0.6, "ring_mod_freq": 120.0,
		"amp_attack": 0.001, "amp_decay": 0.06, "amp_release": 0.08,
		"distortion": 0.3,
	}))
	list.append(_mk("Cave Drip", "nature", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SINE, "duration": 0.6,
		"base_freq": 1200.0, "freq_end": 500.0, "amp_attack": 0.001,
		"amp_decay": 0.15, "amp_release": 0.3, "reverb_mix": 0.7,
		"reverb_decay": 3.0, "delay_mix": 0.3, "delay_time": 0.3,
	}))
	list.append(_mk("Sword Swing", "impact", {
		"mode": "noise", "noise_type": SFXSynthEngine.NOISE_WHITE, "duration": 0.35,
		"noise_amount": 1.0, "filter_type": SFXSynthEngine.FILTER_BANDPASS,
		"filter_freq": 800.0, "filter_freq_end": 4000.0, "filter_q": 2.5,
		"amp_attack": 0.02, "amp_decay": 0.1, "amp_release": 0.15,
	}))
	list.append(_mk("Healing Glow", "magic", {
		"mode": "granular", "duration": 2.5, "base_freq": 660.0,
		"grain_density": 15.0, "grain_size": 0.15, "grain_spread": 7.0,
		"amp_attack": 0.4, "amp_decay": 0.6, "amp_sustain": 0.5,
		"amp_release": 1.0, "reverb_mix": 0.6, "chorus": 0.5,
	}))
	list.append(_mk("Alarm Klaxon", "sci-fi", {
		"mode": "osc", "wave": SFXSynthEngine.WAVE_SAW, "duration": 1.2,
		"base_freq": 600.0, "freq_end": 900.0, "vibrato_rate": 2.0,
		"vibrato_depth": 0.15, "distortion": 0.3,
		"amp_attack": 0.01, "amp_decay": 0.3, "amp_sustain": 0.7,
		"amp_release": 0.2, "filter_type": SFXSynthEngine.FILTER_BANDPASS,
		"filter_freq": 1200.0, "filter_q": 1.0,
	}))
	# --- Sample-based presets (require the bundled samples/ folder) ---
	list.append(_mk("Sample Boom (deep)", "impact", {
		"mode": "sample", "sample_path": "res://samples/booms-and-bass/boom-hit-soft.wav",
		"sample_pitch": -7.0, "duration": 1.5,
		"amp_attack": 0.001, "amp_decay": 0.5, "amp_release": 0.7,
		"distortion": 0.15, "reverb_mix": 0.35, "reverb_decay": 2.0,
	}))
	list.append(_mk("Sample Whoosh (reversed)", "sci-fi", {
		"mode": "sample", "sample_path": "res://samples/whooshes/whoosh-medium-hard.wav",
		"sample_reverse": true, "sample_pitch": 3.0, "duration": 0.8,
		"amp_attack": 0.02, "amp_decay": 0.2, "amp_release": 0.3,
		"filter_type": SFXSynthEngine.FILTER_BANDPASS, "filter_freq": 1200.0,
		"filter_q": 2.0, "reverb_mix": 0.3,
	}))
	list.append(_mk("Sample Impact (pitched)", "impact", {
		"mode": "sample", "sample_path": "res://samples/impacts/impact-deep-hard.wav",
		"sample_pitch": -5.0, "duration": 1.2,
		"amp_attack": 0.001, "amp_decay": 0.4, "amp_release": 0.6,
		"distortion": 0.3, "sub_amount": 0.4,
	}))
	list.append(_mk("Sample Riser (looped)", "magic", {
		"mode": "sample", "sample_path": "res://samples/risers-and-fallers/riser-1s-soft.wav",
		"sample_loop": true, "sample_pitch": 0.0, "duration": 4.0,
		"amp_attack": 0.5, "amp_decay": 0.8, "amp_sustain": 0.6,
		"amp_release": 1.0, "reverb_mix": 0.5, "chorus": 0.3,
	}))
	list.append(_mk("Sample Spring (bouncy)", "musical", {
		"mode": "sample", "sample_path": "res://samples/bounce-spin-zoom/move-spring.wav",
		"sample_pitch": 5.0, "duration": 0.9,
		"amp_attack": 0.002, "amp_decay": 0.2, "amp_release": 0.4,
		"delay_mix": 0.25, "delay_time": 0.15, "reverb_mix": 0.2,
	}))
	list.append(_mk("Sample Shimmer (stretched)", "magic", {
		"mode": "sample", "sample_path": "res://samples/shimmers/shimmer-short-sparkle.wav",
		"sample_pitch": -12.0, "duration": 2.0,
		"amp_attack": 0.05, "amp_decay": 0.6, "amp_release": 0.9,
		"reverb_mix": 0.6, "reverb_decay": 4.0, "chorus": 0.4,
	}))
	list.append(_mk("Sample Digital Breach", "sci-fi", {
		"mode": "sample", "sample_path": "res://samples/digital/digital-breach.wav",
		"sample_pitch": -4.0, "duration": 1.5,
		"amp_attack": 0.002, "amp_decay": 0.35, "amp_release": 0.7,
		"filter_type": SFXSynthEngine.FILTER_HIGHPASS, "filter_freq": 380.0,
		"bitcrush_bits": 9.0, "distortion": 0.2, "delay_mix": 0.15,
		"reverb_mix": 0.3,
	}))
	list.append(_mk("Sample Cinematic Thunder", "impact", {
		"mode": "sample", "sample_path": "res://samples/cinematic-hits/cinematic-thunder-massive.wav",
		"sample_pitch": -7.0, "duration": 3.5,
		"amp_attack": 0.003, "amp_decay": 1.0, "amp_sustain": 0.15,
		"amp_release": 1.4, "filter_type": SFXSynthEngine.FILTER_LOWPASS,
		"filter_freq": 4200.0, "reverb_mix": 0.35, "reverb_decay": 4.0,
	}))
	list.append(_mk("Sample Notification Glow", "ui", {
		"mode": "sample", "sample_path": "res://samples/notifications/notification-success-chime.wav",
		"sample_pitch": -2.0, "duration": 1.8,
		"amp_attack": 0.002, "amp_decay": 0.4, "amp_release": 0.8,
		"filter_type": SFXSynthEngine.FILTER_LOWPASS, "filter_freq": 7600.0,
		"delay_mix": 0.18, "delay_time": 0.2, "reverb_mix": 0.45,
	}))
	list.append(_mk("Sample Transform Morph", "magic", {
		"mode": "sample", "sample_path": "res://samples/shape-changes/transform-morph.wav",
		"sample_reverse": true, "sample_pitch": -5.0, "duration": 2.5,
		"amp_attack": 0.03, "amp_decay": 0.7, "amp_release": 1.0,
		"filter_type": SFXSynthEngine.FILTER_BANDPASS, "filter_freq": 1600.0,
		"filter_q": 1.5, "chorus": 0.25, "reverb_mix": 0.5,
	}))
	return list


static func _mk(name: String, category: String, params: Dictionary) -> Dictionary:
	return {"name": name, "category": category, "params": params}


static func get_by_name(preset_name: String) -> Dictionary:
	for entry in get_presets():
		if String(entry["name"]) == preset_name:
			return entry
	return {}


static func get_by_category(category: String) -> Array:
	var out: Array = []
	for entry in get_presets():
		if String(entry["category"]) == category:
			out.append(entry)
	return out
