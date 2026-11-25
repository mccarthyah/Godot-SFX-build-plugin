"""NumPy mirror of addons/sfx_generator/synth_engine.gd.

Implements the same synthesis algorithms so sounds can be previewed and
tested outside Godot (e.g. in CI). Not bit-identical to the GDScript
version, but algorithmically equivalent.
"""
import math
import numpy as np

SAMPLE_RATE = 44100
TAU = 2.0 * math.pi

WAVE_SINE, WAVE_SAW, WAVE_SQUARE, WAVE_TRIANGLE, WAVE_PULSE, WAVE_NOISE = range(6)
NOISE_WHITE, NOISE_PINK, NOISE_BROWN = range(3)
FILTER_NONE, FILTER_LOWPASS, FILTER_HIGHPASS, FILTER_BANDPASS, FILTER_NOTCH = range(5)


def default_params():
    return {
        "mode": "osc", "seed": 12345, "duration": 1.0, "sample_rate": SAMPLE_RATE,
        "stereo": True, "volume": 0.8, "normalize": True,
        "base_freq": 440.0, "freq_end": 0.0, "freq_curve": 1.0,
        "vibrato_rate": 0.0, "vibrato_depth": 0.0, "detune_cents": 0.0,
        "wave": WAVE_SINE, "duty": 0.5, "sub_amount": 0.0, "sub_wave": WAVE_SINE,
        "second_amount": 0.0, "second_detune": 8.0,
        "fm_ratio": 1.0, "fm_index": 0.0, "fm_decay": 3.0, "fm_feedback": 0.0,
        "noise_amount": 0.0, "noise_type": NOISE_WHITE, "noise_attack": 0.005,
        "pluck_damping": 0.996, "pluck_brightness": 0.5, "pluck_strings": 1,
        "partial_count": 8, "inharmonicity": 0.0002, "partial_rolloff": 1.0,
        "partial_decay_spread": 1.5,
        "grain_density": 20.0, "grain_size": 0.08, "grain_spread": 12.0,
        "grain_wave": WAVE_SINE, "grain_decay": 2.0,
        "formant1": 730.0, "formant2": 1090.0, "formant3": 2440.0,
        "formant_bw": 80.0, "formant_mix": 1.0,
        "sample_path": "", "sample_pitch": 0.0, "sample_loop": False,
        "sample_reverse": False,
        "filter_type": FILTER_LOWPASS, "filter_freq": 8000.0, "filter_freq_end": 0.0,
        "filter_q": 0.7, "filter_env": 0.0,
        "amp_attack": 0.005, "amp_decay": 0.1, "amp_sustain": 0.0, "amp_release": 0.15,
        "distortion": 0.0, "distortion_type": 0, "bitcrush_bits": 16.0,
        "bitcrush_rate": 44100.0, "ring_mod": 0.0, "ring_mod_freq": 100.0,
        "tremolo_rate": 0.0, "tremolo_depth": 0.0, "chorus": 0.0, "chorus_rate": 0.8,
        "delay_time": 0.25, "delay_feedback": 0.35, "delay_mix": 0.0,
        "reverb_mix": 0.0, "reverb_decay": 2.5, "stereo_width": 0.5,
    }


def _freq_at(p, t, duration):
    base = max(float(p["base_freq"]), 1.0)
    end = float(p["freq_end"])
    f = base
    if end > 0 and duration > 0:
        frac = min(max(t / duration, 0.0), 1.0)
        f = base * (end / base) ** (frac ** float(p["freq_curve"]))
    if p["vibrato_rate"] > 0 and p["vibrato_depth"] > 0:
        f *= 1.0 + p["vibrato_depth"] * math.sin(TAU * p["vibrato_rate"] * t)
    if p["detune_cents"] != 0:
        f *= 2.0 ** (p["detune_cents"] / 1200.0)
    return max(f, 1.0)


def _osc(phase, wave, duty):
    ph = phase % 1.0
    if wave == WAVE_SINE:
        return np.sin(TAU * ph)
    if wave == WAVE_SAW:
        return ph * 2.0 - 1.0
    if wave == WAVE_SQUARE:
        return np.where(ph < 0.5, 1.0, -1.0)
    if wave == WAVE_TRIANGLE:
        return 1.0 - 4.0 * np.abs(ph - 0.5)
    if wave == WAVE_PULSE:
        return np.where(ph < min(max(duty, 0.01), 0.99), 1.0, -1.0)
    return np.sin(TAU * ph)


def _adsr(t, duration, attack, decay, sustain, release):
    out = np.empty_like(t)
    rel_start = max(duration - release, attack + decay)
    for i, ti in enumerate(t):
        if ti < attack:
            out[i] = ti / max(attack, 1e-4)
        elif ti - attack < decay:
            out[i] = sustain + (1.0 - sustain) * (1.0 - (ti - attack) / max(decay, 1e-4))
        elif ti < rel_start:
            out[i] = sustain
        else:
            out[i] = sustain * (1.0 - min((ti - rel_start) / max(release, 1e-4), 1.0))
    return out


def _biquad_coeffs(ftype, freq, q, sr):
    w0 = TAU * min(max(freq, 10.0), sr * 0.45) / sr
    cw, sw = math.cos(w0), math.sin(w0)
    if ftype == FILTER_LOWPASS:
        alpha = sw / (2 * max(q, 0.1))
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif ftype == FILTER_HIGHPASS:
        alpha = sw / (2 * max(q, 0.1))
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif ftype == FILTER_BANDPASS:
        alpha = sw * math.sinh(0.5 * TAU * q * 100.0 / sr)
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif ftype == FILTER_NOTCH:
        alpha = sw / (2 * max(q, 0.1))
        b = [1.0, -2 * cw, 1.0]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    else:
        return np.array([1.0, 0.0, 0.0, 0.0, 0.0])
    return np.array([b[0] / a[0], b[1] / a[0], b[2] / a[0], a[1] / a[0], a[2] / a[0]])


def _apply_biquad(x, coeffs):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2, a1, a2 = coeffs
    for i in range(len(x)):
        yi = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x[i]
        y2, y1 = y1, yi
        y[i] = yi
    return y


def _pink_noise(rng, n):
    b0 = b1 = b2 = 0.0
    out = np.empty(n)
    white = rng.uniform(-1, 1, n)
    for i in range(n):
        w = white[i]
        b0 = 0.997 * b0 + w * 0.029591
        b1 = 0.985 * b1 + w * 0.032534
        b2 = 0.95 * b2 + w * 0.048056
        out[i] = (b0 + b1 + b2 + w * 0.05) * 0.5
    return out


def _brown_noise(rng, n):
    white = rng.uniform(-1, 1, n)
    out = np.empty(n)
    b = 0.0
    for i in range(n):
        b = (b + 0.02 * white[i]) / 1.02
        out[i] = b * 3.0
    return out


def _render_osc(p, sr, rng):
    n = int(p["duration"] * sr)
    t = np.arange(n) / sr
    freqs = np.array([_freq_at(p, ti, p["duration"]) for ti in t])
    phase = np.cumsum(freqs) / sr
    out = _osc(phase, p["wave"], p["duty"])
    if p["sub_amount"] > 0.001:
        out = out + p["sub_amount"] * _osc(phase * 0.5, p["sub_wave"], 0.5)
    if p["second_amount"] > 0.001:
        out = out + p["second_amount"] * _osc(phase * 2 ** (p["second_detune"] / 1200.0), p["wave"], p["duty"])
    if p["fm_index"] > 0.01:
        idx = p["fm_index"] * np.exp(-t * p["fm_decay"])
        mod_phase = np.cumsum(freqs * p["fm_ratio"]) / sr
        mod = np.sin(TAU * (mod_phase % 1.0))
        carrier = np.cumsum(freqs + idx * freqs * p["fm_ratio"] * mod) / sr
        out = _osc(carrier, p["wave"], p["duty"])
    if p["noise_amount"] > 0.001:
        if p["noise_type"] == NOISE_PINK:
            nz = _pink_noise(rng, n)
        elif p["noise_type"] == NOISE_BROWN:
            nz = _brown_noise(rng, n)
        else:
            nz = rng.uniform(-1, 1, n)
        out = out + p["noise_amount"] * nz
    return out


def _render_fm(p, sr, rng):
    n = int(p["duration"] * sr)
    t = np.arange(n) / sr
    freqs = np.array([_freq_at(p, ti, p["duration"]) for ti in t])
    idx = p["fm_index"] * np.exp(-t * p["fm_decay"])
    mod_phase = np.cumsum(freqs * p["fm_ratio"]) / sr
    mod = np.sin(TAU * (mod_phase % 1.0))
    if p["fm_feedback"] > 0.001:
        # Approximate feedback with one-pass carrier estimate.
        carrier_est = np.cumsum(freqs) / sr
        mod = mod + p["fm_feedback"] * np.sin(TAU * (carrier_est % 1.0))
    carrier = np.cumsum(freqs + idx * freqs * p["fm_ratio"] * mod) / sr
    out = np.sin(TAU * (carrier % 1.0))
    if p["sub_amount"] > 0.001:
        out = out + p["sub_amount"] * np.sin(TAU * ((np.cumsum(freqs * 0.5) / sr) % 1.0))
    if p["noise_amount"] > 0.001:
        out = out + p["noise_amount"] * rng.uniform(-1, 1, n)
    return out


def _render_pluck(p, sr, rng):
    n = int(p["duration"] * sr)
    f0 = _freq_at(p, 0.0, p["duration"])
    out = np.zeros(n)
    for s in range(max(int(p["pluck_strings"]), 1)):
        f = f0 * 2 ** (s * 4.0 / 1200.0)
        period = max(int(round(sr / max(f, 1.0))), 2)
        alpha = 0.05 + 0.85 * p["pluck_brightness"]
        line = np.empty(period)
        lp = 0.0
        for i in range(period):
            w = rng.uniform(-1, 1)
            lp += alpha * (w - lp)
            line[i] = lp
        idx = 0
        for i in range(n):
            cur = line[idx]
            nxt = line[(idx + 1) % period]
            line[idx] = 0.5 * (cur + nxt) * p["pluck_damping"]
            idx = (idx + 1) % period
            out[i] += cur
    out /= max(int(p["pluck_strings"]), 1)
    if p["noise_amount"] > 0.001:
        m = int(0.02 * sr)
        out[:m] += p["noise_amount"] * rng.uniform(-1, 1, m) * (1 - np.arange(m) / m)
    return out


def _render_noise(p, sr, rng):
    n = int(p["duration"] * sr)
    if p["noise_type"] == NOISE_PINK:
        nz = _pink_noise(rng, n)
    elif p["noise_type"] == NOISE_BROWN:
        nz = _brown_noise(rng, n)
    else:
        nz = rng.uniform(-1, 1, n)
    tonal = 1.0 - p["noise_amount"]
    if tonal > 0.001:
        t = np.arange(n) / sr
        freqs = np.array([_freq_at(p, ti, p["duration"]) for ti in t])
        phase = np.cumsum(freqs) / sr
        nz = (1 - tonal) * nz + tonal * _osc(phase, p["wave"], 0.5)
    return nz


def _render_additive(p, sr, rng):
    n = int(p["duration"] * sr)
    t = np.arange(n) / sr
    count = int(min(max(p["partial_count"], 1), 32))
    f0 = _freq_at(p, 0.0, p["duration"])
    out = np.zeros(n)
    for k in range(count):
        nn = float(k + 1)
        f = nn * f0 * math.sqrt(1.0 + p["inharmonicity"] * nn * nn)
        amp = 1.0 / nn ** p["partial_rolloff"]
        dec = 0.5 + p["partial_decay_spread"] * nn * 0.5
        ph = rng.uniform(0, TAU)
        out += amp * np.exp(-dec * t) * np.sin(TAU * f * t + ph)
    if p["noise_amount"] > 0.001 and p["noise_attack"] > 0:
        m = int(p["noise_attack"] * sr)
        out[:m] += p["noise_amount"] * rng.uniform(-1, 1, m) * (1 - np.arange(m) / m)
    return out * 0.6


def _render_granular(p, sr, rng):
    n = int(p["duration"] * sr)
    out = np.zeros(n)
    base = _freq_at(p, 0.0, p["duration"])
    grain_len = int(p["grain_size"] * sr)
    count = int(p["grain_density"] * p["duration"])
    for _ in range(count):
        start = rng.integers(0, max(n - grain_len, 1))
        f = base * 2 ** (rng.uniform(-p["grain_spread"], p["grain_spread"]) / 12.0)
        amp = rng.uniform(0.3, 1.0)
        ph = rng.uniform(0, TAU)
        j = np.arange(grain_len)
        frac = j / max(grain_len, 1)
        window = np.sin(np.pi * frac) ** 1.5
        gt = j / sr
        if p["grain_wave"] == WAVE_NOISE:
            gs = rng.uniform(-1, 1, grain_len)
        elif p["grain_wave"] == WAVE_SAW:
            gs = ((f * gt + ph / TAU) % 1.0) * 2.0 - 1.0
        else:
            gs = np.sin(TAU * f * gt + ph)
        end = min(start + grain_len, n)
        out[start:end] += gs[: end - start] * window[: end - start] * amp * np.exp(-gt[: end - start] * p["grain_decay"] * 0.3)
    return out


def _render_formant(p, sr, rng):
    n = int(p["duration"] * sr)
    t = np.arange(n) / sr
    freqs = np.array([_freq_at(p, ti, p["duration"]) for ti in t])
    phase = np.cumsum(freqs) / sr
    src = (phase % 1.0) * 2.0 - 1.0
    if p["noise_amount"] > 0.001:
        src = src + p["noise_amount"] * rng.uniform(-1, 1, n)
    out = np.zeros(n)
    for fkey in ("formant1", "formant2", "formant3"):
        coeffs = _biquad_coeffs(FILTER_BANDPASS, p[fkey], p["formant_bw"] / 100.0, sr)
        out += _apply_biquad(src, coeffs)
    out *= 0.5
    return (1 - p["formant_mix"]) * src * 0.3 + p["formant_mix"] * out


def _load_sample_mono(path):
    """Load a WAV file as mono float samples. Returns (samples, rate) or (None, 0)."""
    import wave
    try:
        with wave.open(str(path), "rb") as w:
            n = w.getnframes()
            ch = w.getnchannels()
            width = w.getsampwidth()
            rate = w.getframerate()
            raw = w.readframes(n)
    except wave.Error:
        # Ogg Vorbis decoding is optional in the Python mirror; the Godot
        # plugin itself decodes Ogg natively without extra dependencies.
        try:
            import soundfile as sf
            decoded, rate = sf.read(str(path), dtype="float32", always_2d=True)
        except (ImportError, OSError, RuntimeError, ValueError):
            return None, 0
        if decoded.size == 0:
            return None, 0
        return decoded.mean(axis=1), int(rate)
    except (FileNotFoundError, OSError):
        return None, 0
    if width == 1:
        data = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    elif width == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        values = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        values = np.where(values & 0x800000, values - 0x1000000, values)
        data = values.astype(np.float32) / 8388608.0
    elif width == 4:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        return None, 0
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    return data, rate


def _render_sample(p, sr, rng):
    n = int(p["duration"] * sr)
    src, src_rate = _load_sample_mono(p["sample_path"])
    if src is None or len(src) == 0:
        return np.zeros(n)
    if p["sample_reverse"]:
        src = src[::-1].copy()
    rate = 2.0 ** (p["sample_pitch"] / 12.0) * src_rate / sr
    out = np.zeros(n)
    for i in range(n):
        pos = i * rate
        idx = int(pos)
        if p["sample_loop"]:
            idx %= len(src)
        elif idx >= len(src):
            continue
        frac = pos - idx
        a = src[idx]
        if p["sample_loop"]:
            b = src[(idx + 1) % len(src)]
        else:
            b = src[idx + 1] if idx + 1 < len(src) else a
        out[i] = a + (b - a) * frac
    return out


def _render_hybrid(p, sr, rng):
    n = int(p["duration"] * sr)
    t = np.arange(n) / sr
    freqs = np.array([_freq_at(p, ti, p["duration"]) for ti in t])
    idx = p["fm_index"] * np.exp(-t * p["fm_decay"])
    mod_phase = np.cumsum(freqs * p["fm_ratio"]) / sr
    mod = np.sin(TAU * (mod_phase % 1.0))
    carrier = np.cumsum(freqs + idx * freqs * p["fm_ratio"] * mod) / sr
    out = np.sin(TAU * (carrier % 1.0))
    out += p["sub_amount"] * np.sin(TAU * ((np.cumsum(freqs * 0.5) / sr) % 1.0))
    out += p["noise_amount"] * _brown_noise(rng, n)
    return out * 0.7


def _fx_tail(p):
    tail = 0.0
    if p["delay_mix"] > 0.01:
        tail = max(tail, p["delay_time"] * 4.0)
    if p["reverb_mix"] > 0.01:
        tail = max(tail, p["reverb_decay"] * 0.8)
    return min(max(tail, 0.0), 3.0)


def generate_samples(params):
    p = default_params()
    p.update(params)
    sr = int(p["sample_rate"])
    duration = min(max(float(p["duration"]), 0.02), 30.0)
    rng = np.random.default_rng(int(p["seed"]))
    n_src = int(duration * sr)
    n_total = int((duration + _fx_tail(p)) * sr)

    renderers = {
        "fm": _render_fm, "pluck": _render_pluck, "noise": _render_noise,
        "additive": _render_additive, "granular": _render_granular,
        "formant": _render_formant, "hybrid": _render_hybrid,
        "sample": _render_sample,
    }
    mono = renderers.get(p["mode"], _render_osc)(p, sr, rng)
    buf = np.zeros(n_total)
    buf[:n_src] = mono[:n_src]

    # Filter with sweep.
    if p["filter_type"] != FILTER_NONE:
        f_start, f_end, q = p["filter_freq"], p["filter_freq_end"], p["filter_q"]
        sweep = f_end > 0 and abs(f_end - f_start) > 1.0
        if sweep:
            # Recompute per block for efficiency.
            block = 1024
            pos = 0
            while pos < n_total:
                frac = min(pos / max(n_src, 1), 1.0)
                f = f_start * (f_end / max(f_start, 1.0)) ** frac
                if p["filter_env"] != 0:
                    f *= 2.0 ** (p["filter_env"] * (1.0 - frac))
                coeffs = _biquad_coeffs(p["filter_type"], f, q, sr)
                seg = buf[pos:pos + block]
                buf[pos:pos + block] = _apply_biquad(seg, coeffs)
                pos += block
        else:
            buf = _apply_biquad(buf, _biquad_coeffs(p["filter_type"], f_start, q, sr))

    # Shaping: distortion, bitcrush, ring, tremolo.
    t_all = np.arange(n_total) / sr
    if p["distortion"] > 0.001:
        g = 1.0 + p["distortion"] * 20.0
        x = buf * g
        if p["distortion_type"] == 0:
            buf = np.tanh(x)
        elif p["distortion_type"] == 1:
            buf = np.clip(x, -1, 1)
        else:
            buf = np.abs(((x + 1) % 4) - 2) - 1  # foldback approx
    if p["bitcrush_bits"] < 15.9:
        levels = 2.0 ** p["bitcrush_bits"]
        hold = max(int(round(sr / max(p["bitcrush_rate"], 100.0))), 1)
        idx = (np.arange(n_total) // hold) * hold
        buf = np.round(buf[idx] * levels) / levels
    if p["ring_mod"] > 0.001:
        buf = buf * ((1 - p["ring_mod"]) + p["ring_mod"] * np.sin(TAU * p["ring_mod_freq"] * t_all))
    if p["tremolo_rate"] > 0 and p["tremolo_depth"] > 0:
        buf = buf * (1 - p["tremolo_depth"] * 0.5 * (1 + np.sin(TAU * p["tremolo_rate"] * t_all)))

    # Chorus (modulated delay).
    if p["chorus"] >= 0.01:
        dlen = int(0.02 * sr)
        line = np.zeros(dlen + 1)
        out = buf.copy()
        wi = 0
        for i in range(n_total):
            lfo = math.sin(TAU * p["chorus_rate"] * t_all[i])
            ro = int(dlen * (0.5 + 0.5 * lfo))
            delayed = line[(wi - ro) % len(line)]
            line[wi] = buf[i]
            wi = (wi + 1) % len(line)
            out[i] = (1 - p["chorus"] * 0.5) * buf[i] + p["chorus"] * 0.5 * delayed
        buf = out

    # Delay.
    if p["delay_mix"] >= 0.01:
        dlen = max(int(p["delay_time"] * sr), 1)
        line = np.zeros(dlen)
        out = buf.copy()
        idx = 0
        for i in range(n_total):
            delayed = line[idx]
            line[idx] = buf[i] + delayed * p["delay_feedback"]
            idx = (idx + 1) % dlen
            out[i] = (1 - p["delay_mix"]) * buf[i] + p["delay_mix"] * delayed
        buf = out

    # Schroeder reverb.
    if p["reverb_mix"] >= 0.01:
        comb_times = [0.0297, 0.0371, 0.0411, 0.0437]
        lines = [np.zeros(max(int(ct * sr), 1)) for ct in comb_times]
        idxs = [0] * 4
        gains = [10 ** (-3 * ct / max(p["reverb_decay"], 0.1)) for ct in comb_times]
        ap_len = max(int(0.005 * sr), 1)
        ap_line = np.zeros(ap_len)
        ap_idx = 0
        ap_gain = 0.5
        out = np.empty(n_total)
        for i in range(n_total):
            x = buf[i]
            s = 0.0
            for k in range(4):
                y = lines[k][idxs[k]]
                lines[k][idxs[k]] = x + y * gains[k]
                idxs[k] = (idxs[k] + 1) % len(lines[k])
                s += y
            s *= 0.25
            ap_y = ap_line[ap_idx]
            ap_out = -ap_gain * s + ap_y
            ap_line[ap_idx] = s + ap_out * ap_gain
            ap_idx = (ap_idx + 1) % ap_len
            out[i] = (1 - p["reverb_mix"]) * x + p["reverb_mix"] * ap_out
        buf = out

    # Amplitude envelope on source portion.
    t_src = np.arange(n_src) / sr
    buf[:n_src] *= _adsr(t_src, duration, p["amp_attack"], p["amp_decay"],
                         p["amp_sustain"], p["amp_release"])

    buf = buf * float(p["volume"])
    if p["normalize"]:
        peak = np.max(np.abs(buf)) if len(buf) else 0.0
        if peak > 1e-4:
            buf = buf * (0.89 / peak)

    if not p["stereo"]:
        return buf
    haas = int(0.0004 * sr)
    r = np.zeros_like(buf)
    r[haas:] = buf[:-haas] if haas > 0 else buf
    mid = (buf + r) * 0.5
    side = (buf - r) * 0.5 * (1.0 + float(p["stereo_width"]) * 2.0)
    stereo = np.empty(n_total * 2)
    stereo[0::2] = np.clip(mid + side, -1, 1)
    stereo[1::2] = np.clip(mid - side, -1, 1)
    return stereo


def write_wav(path, samples, stereo, sample_rate=SAMPLE_RATE):
    import wave
    import struct
    channels = 2 if stereo else 1
    pcm = np.clip(samples, -1, 1)
    ints = (pcm * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(ints.tobytes())
