class_name SFXSynthEngine
extends RefCounted
## Procedural SFX synthesizer.
##
## Generates rich, layered sound effects (FM bells, Karplus-Strong plucks,
## resonant noise bursts, granular textures, formant voices, additive
## shimmer) as AudioStreamWAV resources or WAV files — no samples needed.
##
## All synthesis is offline (rendered to a buffer), so sounds can be
## previewed in the editor and exported as .wav files for use anywhere.
##
## Parameter dictionary keys (see default_params() for full list):
##   mode, duration, base_freq, freq_end, seed, stereo, volume,
##   wave, duty, fm_ratio, fm_index, fm_decay, fm_feedback,
##   noise_amount, noise_type, filter_type, filter_freq, filter_freq_end,
##   filter_q, filter_env, amp_attack, amp_decay, amp_sustain, amp_release,
##   distortion, bitcrush_bits, ring_mod, chorus, delay_mix, reverb_mix, ...

const SAMPLE_RATE: int = 44100
const TAU_F: float = 6.283185307179586

# Waveform ids
const WAVE_SINE: int = 0
const WAVE_SAW: int = 1
const WAVE_SQUARE: int = 2
const WAVE_TRIANGLE: int = 3
const WAVE_PULSE: int = 4
const WAVE_NOISE: int = 5

# Noise ids
const NOISE_WHITE: int = 0
const NOISE_PINK: int = 1
const NOISE_BROWN: int = 2

# Filter ids
const FILTER_NONE: int = 0
const FILTER_LOWPASS: int = 1
const FILTER_HIGHPASS: int = 2
const FILTER_BANDPASS: int = 3
const FILTER_NOTCH: int = 4


## ---------------------------------------------------------------------------
## Parameter defaults
## ---------------------------------------------------------------------------

static func default_params() -> Dictionary:
	var p: Dictionary = {}
	p["mode"] = "osc" # osc | fm | pluck | noise | additive | granular | formant | hybrid
	p["seed"] = 12345
	p["duration"] = 1.0 # seconds
	p["sample_rate"] = SAMPLE_RATE
	p["stereo"] = true
	p["volume"] = 0.8
	p["normalize"] = true
	# Pitch
	p["base_freq"] = 440.0
	p["freq_end"] = 0.0 # 0 = no pitch sweep
	p["freq_curve"] = 1.0 # exponential sweep factor (1 = straight exp)
	p["vibrato_rate"] = 0.0
	p["vibrato_depth"] = 0.0
	p["detune_cents"] = 0.0
	# Oscillator
	p["wave"] = WAVE_SINE
	p["duty"] = 0.5
	p["sub_amount"] = 0.0 # sub-oscillator one octave below
	p["sub_wave"] = WAVE_SINE
	p["second_amount"] = 0.0 # detuned second oscillator
	p["second_detune"] = 8.0 # cents
	# FM
	p["fm_ratio"] = 1.0
	p["fm_index"] = 0.0
	p["fm_decay"] = 3.0 # index envelope decay rate (1/s)
	p["fm_feedback"] = 0.0
	# Noise
	p["noise_amount"] = 0.0
	p["noise_type"] = NOISE_WHITE
	p["noise_attack"] = 0.005 # transient burst length for additive/pluck
	# Pluck (Karplus-Strong)
	p["pluck_damping"] = 0.996
	p["pluck_brightness"] = 0.5 # 0 = dark, 1 = bright
	p["pluck_strings"] = 1 # 1 or 2 (detuned pair)
	# Additive
	p["partial_count"] = 8
	p["inharmonicity"] = 0.0002 # B factor (bell/metal)
	p["partial_rolloff"] = 1.0
	p["partial_decay_spread"] = 1.5
	# Granular
	p["grain_density"] = 20.0 # grains per second
	p["grain_size"] = 0.08 # seconds
	p["grain_spread"] = 12.0 # semitones
	p["grain_wave"] = WAVE_SINE
	p["grain_decay"] = 2.0
	# Formant
	p["formant1"] = 730.0
	p["formant2"] = 1090.0
	p["formant3"] = 2440.0
	p["formant_bw"] = 80.0
	p["formant_mix"] = 1.0
	# Filter
	p["filter_type"] = FILTER_LOWPASS
	p["filter_freq"] = 8000.0
	p["filter_freq_end"] = 0.0 # 0 = no sweep
	p["filter_q"] = 0.7
	p["filter_env"] = 0.0 # envelope amount in octaves
	# Amplitude envelope (ADSR)
	p["amp_attack"] = 0.005
	p["amp_decay"] = 0.1
	p["amp_sustain"] = 0.0
	p["amp_release"] = 0.15
	# FX
	p["distortion"] = 0.0 # 0..1 drive
	p["distortion_type"] = 0 # 0 tanh, 1 hard clip, 2 foldback
	p["bitcrush_bits"] = 16.0
	p["bitcrush_rate"] = 44100.0
	p["ring_mod"] = 0.0 # amount
	p["ring_mod_freq"] = 100.0
	p["tremolo_rate"] = 0.0
	p["tremolo_depth"] = 0.0
	p["chorus"] = 0.0 # amount
	p["chorus_rate"] = 0.8
	p["delay_time"] = 0.25
	p["delay_feedback"] = 0.35
	p["delay_mix"] = 0.0
	p["reverb_mix"] = 0.0
	p["reverb_decay"] = 2.5 # seconds
	p["stereo_width"] = 0.5
	return p


static func _p(params: Dictionary, key: String, fallback: Variant) -> Variant:
	if params.has(key):
		return params[key]
	return fallback


## ---------------------------------------------------------------------------
## Public API
## ---------------------------------------------------------------------------

## Render parameters to interleaved float samples (-1..1).
## Stereo output is L,R,L,R... when params["stereo"] is true.
static func generate_samples(params: Dictionary) -> PackedFloat32Array:
	var p: Dictionary = default_params()
	for k in params.keys():
		p[k] = params[k]

	var sr: int = int(_p(p, "sample_rate", SAMPLE_RATE))
	var duration: float = clampf(float(_p(p, "duration", 1.0)), 0.02, 30.0)
	var stereo: bool = bool(_p(p, "stereo", true))
	var seed_val: int = int(_p(p, "seed", 12345))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var mode: String = String(_p(p, "mode", "osc"))
	var tail: float = _fx_tail_seconds(p)
	var n_src: int = int(duration * float(sr))
	var n_total: int = int((duration + tail) * float(sr))

	# 1. Source synthesis (mono, source length only).
	var mono := PackedFloat32Array()
	mono.resize(n_src)
	match mode:
		"fm":
			_render_fm(mono, p, sr, rng)
		"pluck":
			_render_pluck(mono, p, sr, rng)
		"noise":
			_render_noise(mono, p, sr, rng)
		"additive":
			_render_additive(mono, p, sr, rng)
		"granular":
			_render_granular(mono, p, sr, rng)
		"formant":
			_render_formant(mono, p, sr, rng)
		"hybrid":
			_render_hybrid(mono, p, sr, rng)
		_:
			_render_osc(mono, p, sr, rng)

	# 2. Pad to total length (FX tails ring out here).
	var buf := PackedFloat32Array()
	buf.resize(n_total)
	for i in n_src:
		buf[i] = mono[i]

	# 3. Filter (with sweep + envelope).
	_apply_filter(buf, p, sr, duration)

	# 4. Distortion / bitcrush / ring mod / tremolo (per-sample).
	_apply_shaping(buf, p, sr)

	# 5. Chorus (modulated delay).
	_apply_chorus(buf, p, sr)

	# 6. Delay + reverb (tails).
	_apply_delay(buf, p, sr)
	_apply_reverb(buf, p, sr)

	# 7. Amplitude envelope on the source portion.
	_apply_amp_envelope(buf, p, sr, n_src, duration)

	# 8. Volume + normalize.
	var volume: float = clampf(float(_p(p, "volume", 0.8)), 0.0, 2.0)
	for i in n_total:
		buf[i] *= volume
	if bool(_p(p, "normalize", true)):
		_normalize(buf, 0.89)

	# 9. Stereo image.
	if not stereo:
		return buf
	return _to_stereo(buf, p, sr)


## Render parameters to an AudioStreamWAV resource.
static func generate_stream(params: Dictionary) -> AudioStreamWAV:
	var p: Dictionary = default_params()
	for k in params.keys():
		p[k] = params[k]
	var samples: PackedFloat32Array = generate_samples(p)
	var sr: int = int(_p(p, "sample_rate", SAMPLE_RATE))
	var stereo: bool = bool(_p(p, "stereo", true))
	return samples_to_stream(samples, stereo, sr)


## Convert interleaved float samples to a 16-bit AudioStreamWAV.
static func samples_to_stream(samples: PackedFloat32Array, stereo: bool, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = stereo
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		var s: int = int(round(v * 32767.0))
		if s < 0:
			s += 65536
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	stream.data = bytes
	return stream


## Save parameters as a 16-bit WAV file. Returns Error.OK on success.
static func save_wav(path: String, params: Dictionary) -> Error:
	var p: Dictionary = default_params()
	for k in params.keys():
		p[k] = params[k]
	var samples: PackedFloat32Array = generate_samples(p)
	var sr: int = int(_p(p, "sample_rate", SAMPLE_RATE))
	var stereo: bool = bool(_p(p, "stereo", true))
	return write_wav_file(path, samples, stereo, sr)


## Write interleaved float samples to a WAV file (manual RIFF, 16-bit PCM).
static func write_wav_file(path: String, samples: PackedFloat32Array, stereo: bool, sample_rate: int) -> Error:
	var channels: int = 2 if stereo else 1
	var data_bytes: int = samples.size() * 2
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# RIFF header
	file.store_buffer(PackedByteArray([0x52, 0x49, 0x46, 0x46])) # "RIFF"
	file.store_32(36 + data_bytes)
	file.store_buffer(PackedByteArray([0x57, 0x41, 0x56, 0x45])) # "WAVE"
	file.store_buffer(PackedByteArray([0x66, 0x6D, 0x74, 0x20])) # "fmt "
	file.store_32(16)
	file.store_16(1) # PCM
	file.store_16(channels)
	file.store_32(sample_rate)
	file.store_32(sample_rate * channels * 2)
	file.store_16(channels * 2)
	file.store_16(16)
	file.store_buffer(PackedByteArray([0x64, 0x61, 0x74, 0x61])) # "data"
	file.store_32(data_bytes)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		var s: int = int(round(v * 32767.0))
		if s < 0:
			s += 65536
		file.store_8(s & 0xFF)
		file.store_8((s >> 8) & 0xFF)
	file.close()
	return OK


## Random parameters for a category: ui | sci-fi | magic | impact | nature | musical | any
static func random_params(rng: RandomNumberGenerator, category: String = "any") -> Dictionary:
	var p: Dictionary = default_params()
	p["seed"] = rng.randi()
	var cat: String = category.to_lower()
	if cat == "any":
		var cats: Array = ["ui", "sci-fi", "magic", "impact", "nature", "musical"]
		cat = String(cats[rng.randi_range(0, cats.size() - 1)])

	match cat:
		"ui":
			p["mode"] = "osc"
			p["wave"] = WAVE_SINE if rng.randf() < 0.5 else WAVE_TRIANGLE
			p["duration"] = rng.randf_range(0.06, 0.35)
			p["base_freq"] = rng.randf_range(400.0, 1600.0)
			p["freq_end"] = p["base_freq"] * rng.randf_range(0.7, 1.6)
			p["amp_attack"] = 0.002
			p["amp_decay"] = rng.randf_range(0.03, 0.12)
			p["amp_release"] = rng.randf_range(0.03, 0.1)
			p["filter_type"] = FILTER_LOWPASS
			p["filter_freq"] = rng.randf_range(3000.0, 9000.0)
			p["reverb_mix"] = rng.randf_range(0.0, 0.15)
		"sci-fi":
			var modes: Array = ["fm", "noise", "osc", "formant"]
			p["mode"] = String(modes[rng.randi_range(0, modes.size() - 1)])
			p["duration"] = rng.randf_range(0.3, 1.8)
			p["base_freq"] = rng.randf_range(80.0, 900.0)
			p["freq_end"] = p["base_freq"] * rng.randf_range(0.05, 4.0)
			p["fm_ratio"] = rng.randf_range(0.5, 5.0)
			p["fm_index"] = rng.randf_range(1.0, 8.0)
			p["fm_decay"] = rng.randf_range(1.0, 6.0)
			p["noise_amount"] = rng.randf_range(0.1, 0.7)
			p["filter_type"] = FILTER_BANDPASS
			p["filter_freq"] = rng.randf_range(400.0, 4000.0)
			p["filter_freq_end"] = p["filter_freq"] * rng.randf_range(0.1, 3.0)
			p["filter_q"] = rng.randf_range(1.0, 8.0)
			p["distortion"] = rng.randf_range(0.0, 0.5)
			p["reverb_mix"] = rng.randf_range(0.1, 0.5)
			p["delay_mix"] = rng.randf_range(0.0, 0.3)
		"magic":
			var modes2: Array = ["additive", "granular", "fm"]
			p["mode"] = String(modes2[rng.randi_range(0, modes2.size() - 1)])
			p["duration"] = rng.randf_range(0.8, 3.0)
			p["base_freq"] = rng.randf_range(300.0, 1400.0)
			p["inharmonicity"] = rng.randf_range(0.0001, 0.002)
			p["partial_count"] = rng.randi_range(5, 16)
			p["grain_density"] = rng.randf_range(10.0, 40.0)
			p["grain_spread"] = rng.randf_range(6.0, 24.0)
			p["reverb_mix"] = rng.randf_range(0.3, 0.7)
			p["reverb_decay"] = rng.randf_range(2.0, 5.0)
			p["chorus"] = rng.randf_range(0.2, 0.8)
		"impact":
			var modes3: Array = ["noise", "pluck", "fm", "hybrid"]
			p["mode"] = String(modes3[rng.randi_range(0, modes3.size() - 1)])
			p["duration"] = rng.randf_range(0.4, 2.5)
			p["base_freq"] = rng.randf_range(40.0, 300.0)
			p["freq_end"] = p["base_freq"] * rng.randf_range(0.1, 0.6)
			p["noise_amount"] = rng.randf_range(0.5, 1.0)
			p["filter_type"] = FILTER_LOWPASS
			p["filter_freq"] = rng.randf_range(200.0, 2000.0)
			p["filter_freq_end"] = p["filter_freq"] * rng.randf_range(0.05, 0.3)
			p["distortion"] = rng.randf_range(0.2, 0.8)
			p["sub_amount"] = rng.randf_range(0.3, 1.0)
			p["amp_attack"] = 0.001
			p["amp_decay"] = rng.randf_range(0.2, 0.8)
			p["amp_release"] = rng.randf_range(0.3, 1.2)
		"nature":
			var modes4: Array = ["noise", "granular", "formant", "pluck"]
			p["mode"] = String(modes4[rng.randi_range(0, modes4.size() - 1)])
			p["duration"] = rng.randf_range(0.5, 4.0)
			p["base_freq"] = rng.randf_range(100.0, 800.0)
			p["noise_type"] = rng.randi_range(0, 2)
			p["filter_type"] = FILTER_BANDPASS
			p["filter_freq"] = rng.randf_range(300.0, 3000.0)
			p["filter_q"] = rng.randf_range(0.5, 4.0)
			p["vibrato_rate"] = rng.randf_range(2.0, 8.0)
			p["vibrato_depth"] = rng.randf_range(0.0, 0.05)
			p["reverb_mix"] = rng.randf_range(0.1, 0.4)
		"musical":
			var modes5: Array = ["pluck", "additive", "fm", "osc"]
			p["mode"] = String(modes5[rng.randi_range(0, modes5.size() - 1)])
			p["duration"] = rng.randf_range(0.5, 3.0)
			p["base_freq"] = rng.randf_range(110.0, 880.0)
			p["wave"] = rng.randi_range(0, 4)
			p["pluck_damping"] = rng.randf_range(0.99, 0.999)
			p["inharmonicity"] = rng.randf_range(0.0, 0.0005)
			p["amp_attack"] = rng.randf_range(0.002, 0.05)
			p["amp_decay"] = rng.randf_range(0.1, 0.6)
			p["amp_sustain"] = rng.randf_range(0.0, 0.4)
			p["reverb_mix"] = rng.randf_range(0.1, 0.5)
			p["chorus"] = rng.randf_range(0.0, 0.4)
		_:
			p["mode"] = "osc"
			p["duration"] = rng.randf_range(0.2, 1.0)
			p["base_freq"] = rng.randf_range(100.0, 1000.0)
	return p


## Mutate parameters slightly (for "evolve" / variation workflow).
static func mutate_params(base: Dictionary, rng: RandomNumberGenerator, amount: float = 0.25) -> Dictionary:
	var p: Dictionary = base.duplicate(true)
	var keys: Array = ["base_freq", "freq_end", "duration", "fm_ratio", "fm_index",
		"filter_freq", "filter_q", "noise_amount", "distortion", "reverb_mix",
		"delay_mix", "chorus", "amp_attack", "amp_decay", "amp_release",
		"pluck_damping", "inharmonicity", "grain_density", "grain_spread",
		"formant1", "formant2", "formant3", "vibrato_depth", "sub_amount"]
	for k in keys:
		if p.has(k) and rng.randf() < 0.5:
			var v: float = float(p[k])
			var factor: float = 1.0 + rng.randf_range(-amount, amount)
			p[k] = maxf(v * factor, 0.0001)
	p["seed"] = rng.randi()
	return p


## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------

static func _fx_tail_seconds(p: Dictionary) -> float:
	var tail: float = 0.0
	if float(_p(p, "delay_mix", 0.0)) > 0.01:
		tail = maxf(tail, float(_p(p, "delay_time", 0.25)) * 4.0)
	if float(_p(p, "reverb_mix", 0.0)) > 0.01:
		tail = maxf(tail, float(_p(p, "reverb_decay", 2.5)) * 0.8)
	return clampf(tail, 0.0, 3.0)


static func _freq_at(p: Dictionary, t: float, duration: float) -> float:
	var base: float = maxf(float(_p(p, "base_freq", 440.0)), 1.0)
	var end: float = float(_p(p, "freq_end", 0.0))
	var f: float = base
	if end > 0.0 and duration > 0.0:
		var curve: float = float(_p(p, "freq_curve", 1.0))
		var frac: float = clampf(t / duration, 0.0, 1.0)
		f = base * pow(end / base, pow(frac, curve))
	var vib_rate: float = float(_p(p, "vibrato_rate", 0.0))
	var vib_depth: float = float(_p(p, "vibrato_depth", 0.0))
	if vib_rate > 0.0 and vib_depth > 0.0:
		f *= 1.0 + vib_depth * sin(TAU_F * vib_rate * t)
	var detune: float = float(_p(p, "detune_cents", 0.0))
	if detune != 0.0:
		f *= pow(2.0, detune / 1200.0)
	return maxf(f, 1.0)


static func _osc(phase: float, wave: int, duty: float) -> float:
	# phase in cycles (0..1)
	var ph: float = fposmod(phase, 1.0)
	match wave:
		WAVE_SINE:
			return sin(TAU_F * ph)
		WAVE_SAW:
			return ph * 2.0 - 1.0
		WAVE_SQUARE:
			return 1.0 if ph < 0.5 else -1.0
		WAVE_TRIANGLE:
			return 1.0 - 4.0 * absf(ph - 0.5)
		WAVE_PULSE:
			return 1.0 if ph < clampf(duty, 0.01, 0.99) else -1.0
		_:
			return sin(TAU_F * ph)


static func _adsr(t: float, duration: float, attack: float, decay: float, sustain: float, release: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	var t2: float = t - attack
	if t2 < decay:
		return lerpf(1.0, sustain, t2 / maxf(decay, 0.0001))
	# Sustain until release phase (last `release` seconds of duration).
	var rel_start: float = maxf(duration - release, attack + decay)
	if t < rel_start:
		return sustain
	var rt: float = (t - rel_start) / maxf(release, 0.0001)
	return sustain * (1.0 - clampf(rt, 0.0, 1.0))


static func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var maxv: float = 0.0001
	for i in buf.size():
		maxv = maxf(maxv, absf(buf[i]))
	if maxv > 0.0001:
		var g: float = peak / maxv
		for i in buf.size():
			buf[i] *= g


## ---------------------------------------------------------------------------
## Source renderers (mono, source length)
## ---------------------------------------------------------------------------

static func _render_osc(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var wave: int = int(_p(p, "wave", WAVE_SINE))
	var duty: float = float(_p(p, "duty", 0.5))
	var sub_amt: float = float(_p(p, "sub_amount", 0.0))
	var sub_wave: int = int(_p(p, "sub_wave", WAVE_SINE))
	var second_amt: float = float(_p(p, "second_amount", 0.0))
	var second_detune: float = float(_p(p, "second_detune", 8.0))
	var noise_amt: float = float(_p(p, "noise_amount", 0.0))
	var noise_type: int = int(_p(p, "noise_type", NOISE_WHITE))
	var fm_index: float = float(_p(p, "fm_index", 0.0))
	var fm_ratio: float = float(_p(p, "fm_ratio", 1.0))
	var fm_decay: float = float(_p(p, "fm_decay", 3.0))

	var phase: float = 0.0
	var sub_phase: float = 0.0
	var second_phase: float = 0.0
	var mod_phase: float = 0.0
	var carrier_phase: float = 0.0
	# Stateful noise (pink via 3 one-poles, brown via leaky integrator).
	var pb0: float = 0.0
	var pb1: float = 0.0
	var pb2: float = 0.0
	var brown: float = 0.0

	for n in buf.size():
		var t: float = float(n) / float(sr)
		var f: float = _freq_at(p, t, duration)
		phase += f / float(sr)
		sub_phase += (f * 0.5) / float(sr)
		second_phase += (f * pow(2.0, second_detune / 1200.0)) / float(sr)

		var sample: float
		if fm_index > 0.01:
			# FM carrier (waveform selectable) with decaying index.
			var idx: float = fm_index * exp(-t * fm_decay)
			mod_phase += (f * fm_ratio) / float(sr)
			var mod: float = sin(TAU_F * fposmod(mod_phase, 1.0))
			carrier_phase += (f + idx * f * fm_ratio * mod) / float(sr)
			sample = _osc(carrier_phase, wave, duty)
		else:
			sample = _osc(phase, wave, duty)

		if sub_amt > 0.001:
			sample += sub_amt * _osc(sub_phase, sub_wave, 0.5)
		if second_amt > 0.001:
			sample += second_amt * _osc(second_phase, wave, duty)
		if noise_amt > 0.001:
			var white: float = rng.randf_range(-1.0, 1.0)
			var nz: float = white
			if noise_type == NOISE_PINK:
				pb0 = 0.997 * pb0 + white * 0.029591
				pb1 = 0.985 * pb1 + white * 0.032534
				pb2 = 0.95 * pb2 + white * 0.048056
				nz = (pb0 + pb1 + pb2 + white * 0.05) * 0.5
			elif noise_type == NOISE_BROWN:
				brown = (brown + 0.02 * white) / 1.02
				nz = brown * 3.0
			sample += noise_amt * nz
		buf[n] = sample


static func _render_fm(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var ratio: float = float(_p(p, "fm_ratio", 1.0))
	var index: float = float(_p(p, "fm_index", 3.0))
	var decay: float = float(_p(p, "fm_decay", 3.0))
	var feedback: float = clampf(float(_p(p, "fm_feedback", 0.0)), 0.0, 0.9)
	var noise_amt: float = float(_p(p, "noise_amount", 0.0))
	var sub_amt: float = float(_p(p, "sub_amount", 0.0))

	var carrier_phase: float = 0.0
	var mod_phase: float = 0.0
	var sub_phase: float = 0.0
	for n in buf.size():
		var t: float = float(n) / float(sr)
		var f: float = _freq_at(p, t, duration)
		var idx: float = index * exp(-t * decay)
		var mod_in: float = sin(TAU_F * fposmod(mod_phase, 1.0))
		if feedback > 0.001:
			mod_in += feedback * sin(TAU_F * fposmod(carrier_phase, 1.0))
		mod_phase += (f * ratio) / float(sr)
		carrier_phase += (f + idx * f * ratio * mod_in) / float(sr)
		sub_phase += (f * 0.5) / float(sr)
		var s: float = sin(TAU_F * fposmod(carrier_phase, 1.0))
		if sub_amt > 0.001:
			s += sub_amt * sin(TAU_F * fposmod(sub_phase, 1.0))
		if noise_amt > 0.001:
			s += noise_amt * rng.randf_range(-1.0, 1.0)
		buf[n] = s


static func _render_pluck(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var damping: float = clampf(float(_p(p, "pluck_damping", 0.996)), 0.9, 0.9999)
	var brightness: float = clampf(float(_p(p, "pluck_brightness", 0.5)), 0.0, 1.0)
	var strings: int = int(_p(p, "pluck_strings", 1))
	var noise_amt: float = float(_p(p, "noise_amount", 0.0))

	var lines: Array = []
	var idxs: Array = []
	for s in maxi(strings, 1):
		var f: float = _freq_at(p, 0.0, duration) * pow(2.0, float(s) * 4.0 / 1200.0)
		var period: int = maxi(int(round(float(sr) / maxf(f, 1.0))), 2)
		var line := PackedFloat32Array()
		line.resize(period)
		var lp: float = 0.0
		var alpha: float = lerpf(0.05, 0.9, brightness)
		for i in period:
			var w: float = rng.randf_range(-1.0, 1.0)
			lp += alpha * (w - lp)
			line[i] = lp
		lines.append(line)
		idxs.append(0)

	for n in buf.size():
		var t: float = float(n) / float(sr)
		# Pitch sweep: re-tune by interpolating? KS is fixed-pitch; apply
		# sweep by resampling factor is complex — instead crossfade to a
		# swept sine tail if freq_end differs strongly. Keep KS at base
		# freq (classic pluck) and let filter/FX provide movement.
		var s: float = 0.0
		for si in lines.size():
			var line: PackedFloat32Array = lines[si]
			var idx: int = int(idxs[si])
			var period: int = line.size()
			var cur: float = line[idx]
			var nxt: float = line[(idx + 1) % period]
			line[idx] = 0.5 * (cur + nxt) * damping
			lines[si] = line # store back (packed arrays are copy-on-write)
			idxs[si] = (idx + 1) % period
			s += cur
		s /= float(lines.size())
		if noise_amt > 0.001 and t < 0.02:
			s += noise_amt * rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.02)
		buf[n] = s


static func _render_noise(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var noise_type: int = int(_p(p, "noise_type", NOISE_WHITE))
	var tonal: float = 1.0 - float(_p(p, "noise_amount", 0.0))
	var wave: int = int(_p(p, "wave", WAVE_SINE))

	# Stateful noise generators.
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var brown: float = 0.0
	var phase: float = 0.0

	for n in buf.size():
		var t: float = float(n) / float(sr)
		var white: float = rng.randf_range(-1.0, 1.0)
		var nz: float = white
		if noise_type == NOISE_PINK:
			b0 = 0.997 * b0 + white * 0.029591
			b1 = 0.985 * b1 + white * 0.032534
			b2 = 0.95 * b2 + white * 0.048056
			nz = (b0 + b1 + b2 + white * 0.05) * 0.5
		elif noise_type == NOISE_BROWN:
			brown = (brown + 0.02 * white) / 1.02
			nz = brown * 3.0
		var f: float = _freq_at(p, t, duration)
		phase += f / float(sr)
		var s: float = nz
		if tonal > 0.001:
			s = lerpf(nz, _osc(phase, wave, 0.5), tonal)
		buf[n] = s


static func _render_additive(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var count: int = clampi(int(_p(p, "partial_count", 8)), 1, 32)
	var inharmonic: float = float(_p(p, "inharmonicity", 0.0002))
	var rolloff: float = float(_p(p, "partial_rolloff", 1.0))
	var spread: float = float(_p(p, "partial_decay_spread", 1.5))
	var noise_amt: float = float(_p(p, "noise_amount", 0.0))
	var attack_noise: float = float(_p(p, "noise_attack", 0.005))

	var freqs := PackedFloat32Array()
	var amps := PackedFloat32Array()
	var decays := PackedFloat32Array()
	var phases := PackedFloat32Array()
	var f0: float = _freq_at(p, 0.0, duration)
	for k in count:
		var n: float = float(k + 1)
		var f: float = n * f0 * sqrt(1.0 + inharmonic * n * n)
		freqs.append(f)
		amps.append(1.0 / pow(n, rolloff))
		decays.append(0.5 + spread * n * 0.5)
		phases.append(rng.randf_range(0.0, TAU_F))

	for n in buf.size():
		var t: float = float(n) / float(sr)
		var s: float = 0.0
		for k in count:
			var env: float = exp(-decays[k] * t)
			s += amps[k] * env * sin(TAU_F * freqs[k] * t + phases[k])
		if noise_amt > 0.001 and t < attack_noise:
			s += noise_amt * rng.randf_range(-1.0, 1.0) * (1.0 - t / maxf(attack_noise, 0.001))
		buf[n] = s * 0.6


static func _render_granular(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var density: float = float(_p(p, "grain_density", 20.0))
	var size: float = clampf(float(_p(p, "grain_size", 0.08)), 0.005, 1.0)
	var spread: float = float(_p(p, "grain_spread", 12.0))
	var grain_wave: int = int(_p(p, "grain_wave", WAVE_SINE))
	var decay: float = float(_p(p, "grain_decay", 2.0))
	var base: float = _freq_at(p, 0.0, duration)

	var grain_len: int = int(size * float(sr))
	var grain_count: int = int(density * duration)
	for g in grain_count:
		var start: int = rng.randi_range(0, maxi(buf.size() - grain_len, 0))
		var semis: float = rng.randf_range(-spread, spread)
		var f: float = base * pow(2.0, semis / 12.0)
		var amp: float = rng.randf_range(0.3, 1.0)
		var phase: float = rng.randf_range(0.0, TAU_F)
		for j in grain_len:
			var idx: int = start + j
			if idx >= buf.size():
				break
			var frac: float = float(j) / float(maxi(grain_len, 1))
			var window: float = pow(sin(PI * frac), 1.5)
			var gt: float = float(j) / float(sr)
			var gs: float
			if grain_wave == WAVE_NOISE:
				gs = rng.randf_range(-1.0, 1.0)
			elif grain_wave == WAVE_SAW:
				gs = fposmod(f * gt + phase / TAU_F, 1.0) * 2.0 - 1.0
			else:
				gs = sin(TAU_F * f * gt + phase)
			buf[idx] += gs * window * amp * exp(-gt * decay * 0.3)


static func _render_formant(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	var duration: float = float(_p(p, "duration", 1.0))
	var f1: float = float(_p(p, "formant1", 730.0))
	var f2: float = float(_p(p, "formant2", 1090.0))
	var f3: float = float(_p(p, "formant3", 2440.0))
	var bw: float = float(_p(p, "formant_bw", 80.0))
	var mix: float = float(_p(p, "formant_mix", 1.0))
	var noise_amt: float = float(_p(p, "noise_amount", 0.0))

	# Three parallel bandpass resonators (RBJ bandpass, constant 0 dB peak).
	# Filter state is kept in local variables and updated inline because
	# GDScript passes floats by value (a helper cannot update caller state).
	var c1: Array = _biquad_bandpass(f1, bw, sr)
	var c2: Array = _biquad_bandpass(f2, bw, sr)
	var c3: Array = _biquad_bandpass(f3, bw, sr)
	var x1a: float = 0.0
	var x2a: float = 0.0
	var y1a: float = 0.0
	var y2a: float = 0.0
	var x1b: float = 0.0
	var x2b: float = 0.0
	var y1b: float = 0.0
	var y2b: float = 0.0
	var x1c: float = 0.0
	var x2c: float = 0.0
	var y1c: float = 0.0
	var y2c: float = 0.0

	var phase: float = 0.0
	for n in buf.size():
		var t: float = float(n) / float(sr)
		var f: float = _freq_at(p, t, duration)
		phase += f / float(sr)
		var src: float = fposmod(phase, 1.0) * 2.0 - 1.0 # sawtooth source
		if noise_amt > 0.001:
			src += noise_amt * rng.randf_range(-1.0, 1.0)

		var ya: float = float(c1[0]) * src + float(c1[1]) * x1a + float(c1[2]) * x2a \
			- float(c1[3]) * y1a - float(c1[4]) * y2a
		x2a = x1a
		x1a = src
		y2a = y1a
		y1a = ya

		var yb: float = float(c2[0]) * src + float(c2[1]) * x1b + float(c2[2]) * x2b \
			- float(c2[3]) * y1b - float(c2[4]) * y2b
		x2b = x1b
		x1b = src
		y2b = y1b
		y1b = yb

		var yc: float = float(c3[0]) * src + float(c3[1]) * x1c + float(c3[2]) * x2c \
			- float(c3[3]) * y1c - float(c3[4]) * y2c
		x2c = x1c
		x1c = src
		y2c = y1c
		y1c = yc

		var formant_out: float = (ya + yb + yc) * 0.5
		buf[n] = lerpf(src * 0.3, formant_out, mix)


static func _render_hybrid(buf: PackedFloat32Array, p: Dictionary, sr: int, rng: RandomNumberGenerator) -> void:
	# Layered: FM body + noise breath + sub thump.
	var duration: float = float(_p(p, "duration", 1.0))
	var ratio: float = float(_p(p, "fm_ratio", 2.0))
	var index: float = float(_p(p, "fm_index", 2.0))
	var decay: float = float(_p(p, "fm_decay", 2.0))
	var noise_amt: float = float(_p(p, "noise_amount", 0.3))
	var sub_amt: float = float(_p(p, "sub_amount", 0.5))

	var carrier_phase: float = 0.0
	var mod_phase: float = 0.0
	var sub_phase: float = 0.0
	var brown: float = 0.0
	for n in buf.size():
		var t: float = float(n) / float(sr)
		var f: float = _freq_at(p, t, duration)
		var idx: float = index * exp(-t * decay)
		mod_phase += (f * ratio) / float(sr)
		var mod: float = sin(TAU_F * fposmod(mod_phase, 1.0))
		carrier_phase += (f + idx * f * ratio * mod) / float(sr)
		sub_phase += (f * 0.5) / float(sr)
		var white: float = rng.randf_range(-1.0, 1.0)
		brown = (brown + 0.02 * white) / 1.02
		var s: float = sin(TAU_F * fposmod(carrier_phase, 1.0))
		s += sub_amt * sin(TAU_F * fposmod(sub_phase, 1.0))
		s += noise_amt * brown * 3.0
		buf[n] = s * 0.7


## ---------------------------------------------------------------------------
## Biquad helpers (RBJ cookbook)
## ---------------------------------------------------------------------------

static func _biquad_lowpass(freq: float, q: float, sr: int) -> Array:
	var w0: float = TAU_F * clampf(freq, 10.0, float(sr) * 0.45) / float(sr)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.1))
	var cw: float = cos(w0)
	var b0: float = (1.0 - cw) * 0.5
	var b1: float = 1.0 - cw
	var b2: float = (1.0 - cw) * 0.5
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


static func _biquad_highpass(freq: float, q: float, sr: int) -> Array:
	var w0: float = TAU_F * clampf(freq, 10.0, float(sr) * 0.45) / float(sr)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.1))
	var cw: float = cos(w0)
	var b0: float = (1.0 + cw) * 0.5
	var b1: float = -(1.0 + cw)
	var b2: float = (1.0 + cw) * 0.5
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


static func _biquad_bandpass(freq: float, bw: float, sr: int) -> Array:
	# Constant 0 dB peak gain bandpass, bandwidth in Hz.
	var w0: float = TAU_F * clampf(freq, 10.0, float(sr) * 0.45) / float(sr)
	var alpha: float = sin(w0) * sinh(0.5 * TAU_F * bw / float(sr))
	var cw: float = cos(w0)
	var b0: float = alpha
	var b1: float = 0.0
	var b2: float = -alpha
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


static func _biquad_notch(freq: float, q: float, sr: int) -> Array:
	var w0: float = TAU_F * clampf(freq, 10.0, float(sr) * 0.45) / float(sr)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.1))
	var cw: float = cos(w0)
	var b0: float = 1.0
	var b1: float = -2.0 * cw
	var b2: float = 1.0
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


static func _biquad_coeffs(filter_type: int, freq: float, q: float, sr: int) -> Array:
	match filter_type:
		FILTER_LOWPASS:
			return _biquad_lowpass(freq, q, sr)
		FILTER_HIGHPASS:
			return _biquad_highpass(freq, q, sr)
		FILTER_BANDPASS:
			return _biquad_bandpass(freq, q * 100.0, sr)
		FILTER_NOTCH:
			return _biquad_notch(freq, q, sr)
		_:
			return [1.0, 0.0, 0.0, 0.0, 0.0]


## ---------------------------------------------------------------------------
## Post-processing
## ---------------------------------------------------------------------------

static func _apply_filter(buf: PackedFloat32Array, p: Dictionary, sr: int, duration: float) -> void:
	var filter_type: int = int(_p(p, "filter_type", FILTER_LOWPASS))
	if filter_type == FILTER_NONE:
		return
	var f_start: float = float(_p(p, "filter_freq", 8000.0))
	var f_end: float = float(_p(p, "filter_freq_end", 0.0))
	var q: float = float(_p(p, "filter_q", 0.7))
	var env_amt: float = float(_p(p, "filter_env", 0.0))

	var coeffs: Array = _biquad_coeffs(filter_type, f_start, q, sr)
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var sweep: bool = f_end > 0.0 and absf(f_end - f_start) > 1.0
	var n_src: int = int(duration * float(sr))

	for n in buf.size():
		if sweep and n < n_src:
			var frac: float = float(n) / float(maxi(n_src, 1))
			var f: float = f_start * pow(f_end / maxf(f_start, 1.0), frac)
			if env_amt != 0.0:
				f *= pow(2.0, env_amt * (1.0 - frac))
			coeffs = _biquad_coeffs(filter_type, f, q, sr)
		var x: float = buf[n]
		var y: float = float(coeffs[0]) * x + float(coeffs[1]) * x1 + float(coeffs[2]) * x2 \
			- float(coeffs[3]) * y1 - float(coeffs[4]) * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[n] = y


static func _apply_shaping(buf: PackedFloat32Array, p: Dictionary, sr: int) -> void:
	var drive: float = float(_p(p, "distortion", 0.0))
	var dtype: int = int(_p(p, "distortion_type", 0))
	var bits: float = float(_p(p, "bitcrush_bits", 16.0))
	var crush_rate: float = float(_p(p, "bitcrush_rate", 44100.0))
	var ring_amt: float = float(_p(p, "ring_mod", 0.0))
	var ring_freq: float = float(_p(p, "ring_mod_freq", 100.0))
	var trem_rate: float = float(_p(p, "tremolo_rate", 0.0))
	var trem_depth: float = float(_p(p, "tremolo_depth", 0.0))

	var crush: bool = bits < 15.9
	var levels: float = pow(2.0, bits)
	var hold: int = maxi(int(round(float(sr) / maxf(crush_rate, 100.0))), 1)
	var held: float = 0.0

	for n in buf.size():
		var t: float = float(n) / float(sr)
		var x: float = buf[n]
		if drive > 0.001:
			var g: float = 1.0 + drive * 20.0
			x *= g
			match dtype:
				0:
					x = tanh(x)
				1:
					x = clampf(x, -1.0, 1.0)
				2:
					# Foldback
					while x > 1.0 or x < -1.0:
						if x > 1.0:
							x = 2.0 - x
						if x < -1.0:
							x = -2.0 - x
				_:
					x = tanh(x)
		if crush:
			if n % hold == 0:
				held = roundf(x * levels) / levels
			x = held
		if ring_amt > 0.001:
			x *= lerpf(1.0, sin(TAU_F * ring_freq * t), ring_amt)
		if trem_rate > 0.0 and trem_depth > 0.0:
			x *= 1.0 - trem_depth * 0.5 * (1.0 + sin(TAU_F * trem_rate * t))
		buf[n] = x


static func _apply_chorus(buf: PackedFloat32Array, p: Dictionary, sr: int) -> void:
	var amount: float = float(_p(p, "chorus", 0.0))
	if amount < 0.01:
		return
	var rate: float = float(_p(p, "chorus_rate", 0.8))
	var delay_len: int = int(0.02 * float(sr)) # 20ms base
	var line := PackedFloat32Array()
	line.resize(delay_len + 1)
	var write_idx: int = 0
	for n in buf.size():
		var t: float = float(n) / float(sr)
		var lfo: float = sin(TAU_F * rate * t)
		var read_off: int = int(float(delay_len) * (0.5 + 0.5 * lfo))
		var read_idx: int = (write_idx - read_off + line.size()) % line.size()
		var delayed: float = line[read_idx]
		line[write_idx] = buf[n]
		write_idx = (write_idx + 1) % line.size()
		buf[n] = lerpf(buf[n], delayed, amount * 0.5)


static func _apply_delay(buf: PackedFloat32Array, p: Dictionary, sr: int) -> void:
	var mix: float = float(_p(p, "delay_mix", 0.0))
	if mix < 0.01:
		return
	var time: float = float(_p(p, "delay_time", 0.25))
	var feedback: float = clampf(float(_p(p, "delay_feedback", 0.35)), 0.0, 0.9)
	var dlen: int = maxi(int(time * float(sr)), 1)
	var line := PackedFloat32Array()
	line.resize(dlen)
	var idx: int = 0
	for n in buf.size():
		var delayed: float = line[idx]
		var wet: float = buf[n] + delayed * feedback
		line[idx] = wet
		idx = (idx + 1) % dlen
		buf[n] = lerpf(buf[n], delayed, mix)


static func _apply_reverb(buf: PackedFloat32Array, p: Dictionary, sr: int) -> void:
	var mix: float = float(_p(p, "reverb_mix", 0.0))
	if mix < 0.01:
		return
	var decay: float = float(_p(p, "reverb_decay", 2.5))
	# Schroeder reverb: 4 parallel combs -> 2 series allpasses.
	var comb_times: Array = [0.0297, 0.0371, 0.0411, 0.0437]
	var comb_lines: Array = []
	var comb_idx: Array = []
	var comb_gains: Array = []
	for i in comb_times.size():
		var len_i: int = maxi(int(float(comb_times[i]) * float(sr)), 1)
		var line := PackedFloat32Array()
		line.resize(len_i)
		comb_lines.append(line)
		comb_idx.append(0)
		# Gain for desired decay: g = 10^(-3 * len / (decay * sr))
		comb_gains.append(pow(10.0, -3.0 * float(comb_times[i]) / maxf(decay, 0.1)))
	var ap_len: int = maxi(int(0.005 * float(sr)), 1)
	var ap_line := PackedFloat32Array()
	ap_line.resize(ap_len)
	var ap_idx: int = 0
	var ap_gain: float = 0.5

	var out := PackedFloat32Array()
	out.resize(buf.size())
	for n in buf.size():
		var x: float = buf[n]
		var comb_sum: float = 0.0
		for i in comb_lines.size():
			var line: PackedFloat32Array = comb_lines[i]
			var idx: int = int(comb_idx[i])
			var y: float = line[idx]
			line[idx] = x + y * float(comb_gains[i])
			comb_lines[i] = line # store back (packed arrays are copy-on-write)
			comb_idx[i] = (idx + 1) % line.size()
			comb_sum += y
		comb_sum *= 0.25
		# Allpass
		var ap_y: float = ap_line[ap_idx]
		var ap_out: float = -ap_gain * comb_sum + ap_y
		ap_line[ap_idx] = comb_sum + ap_out * ap_gain
		ap_idx = (ap_idx + 1) % ap_len
		out[n] = lerpf(x, ap_out, mix)
	for n in buf.size():
		buf[n] = out[n]


static func _apply_amp_envelope(buf: PackedFloat32Array, p: Dictionary, sr: int, n_src: int, duration: float) -> void:
	var attack: float = float(_p(p, "amp_attack", 0.005))
	var decay: float = float(_p(p, "amp_decay", 0.1))
	var sustain: float = clampf(float(_p(p, "amp_sustain", 0.0)), 0.0, 1.0)
	var release: float = float(_p(p, "amp_release", 0.15))
	for n in mini(n_src, buf.size()):
		var t: float = float(n) / float(sr)
		buf[n] *= _adsr(t, duration, attack, decay, sustain, release)


static func _to_stereo(mono: PackedFloat32Array, p: Dictionary, sr: int) -> PackedFloat32Array:
	var width: float = clampf(float(_p(p, "stereo_width", 0.5)), 0.0, 1.0)
	var haas: int = int(0.0004 * float(sr)) # 0.4ms Haas delay on R
	var out := PackedFloat32Array()
	out.resize(mono.size() * 2)
	for n in mono.size():
		var l: float = mono[n]
		var r_idx: int = n - haas
		var r: float = mono[r_idx] if r_idx >= 0 else 0.0
		# Mid/side width: widen by pushing side out.
		var mid: float = (l + r) * 0.5
		var side: float = (l - r) * 0.5 * (1.0 + width * 2.0)
		out[n * 2] = clampf(mid + side, -1.0, 1.0)
		out[n * 2 + 1] = clampf(mid - side, -1.0, 1.0)
	return out
