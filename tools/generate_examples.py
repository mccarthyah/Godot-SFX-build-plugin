"""Generate example WAV files from curated presets using tools/synth.py.

Usage:
    python3 tools/generate_examples.py [--out DIR]

The same presets ship in the Godot plugin (addons/sfx_generator/presets.gd);
this script lets you audition them without Godot.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth import (  # noqa: E402
    FILTER_BANDPASS, FILTER_HIGHPASS, FILTER_LOWPASS,
    NOISE_BROWN, NOISE_PINK, NOISE_WHITE,
    WAVE_PULSE, WAVE_SAW, WAVE_SINE, WAVE_SQUARE, WAVE_TRIANGLE,
    generate_samples, write_wav,
)

# Curated subset mirroring presets.gd (name -> params).
PRESETS = {
    "soft_ui_click": {"mode": "osc", "wave": WAVE_SINE, "duration": 0.12,
        "base_freq": 900.0, "freq_end": 600.0, "amp_attack": 0.002,
        "amp_decay": 0.04, "amp_release": 0.05,
        "filter_type": FILTER_LOWPASS, "filter_freq": 5000.0},
    "glass_ui_tick": {"mode": "additive", "duration": 0.25, "base_freq": 1800.0,
        "partial_count": 6, "inharmonicity": 0.001, "partial_rolloff": 1.2,
        "noise_amount": 0.3, "noise_attack": 0.003,
        "amp_attack": 0.001, "amp_decay": 0.08, "amp_release": 0.12,
        "reverb_mix": 0.25, "reverb_decay": 1.2},
    "retro_coin_rich": {"mode": "osc", "wave": WAVE_SQUARE, "duration": 0.35,
        "base_freq": 988.0, "freq_end": 1319.0, "second_amount": 0.3,
        "second_detune": 4.0, "amp_attack": 0.002, "amp_decay": 0.1,
        "amp_sustain": 0.4, "amp_release": 0.15,
        "filter_type": FILTER_LOWPASS, "filter_freq": 6000.0,
        "distortion": 0.08, "reverb_mix": 0.15},
    "laser_zap": {"mode": "osc", "wave": WAVE_SAW, "duration": 0.45,
        "base_freq": 1800.0, "freq_end": 120.0, "fm_index": 4.0,
        "fm_ratio": 2.0, "fm_decay": 5.0, "noise_amount": 0.2,
        "amp_attack": 0.001, "amp_decay": 0.15, "amp_release": 0.2,
        "filter_type": FILTER_LOWPASS, "filter_freq": 8000.0,
        "filter_freq_end": 300.0, "distortion": 0.15, "reverb_mix": 0.2},
    "fm_bell": {"mode": "fm", "duration": 1.8, "base_freq": 660.0, "fm_ratio": 3.01,
        "fm_index": 6.0, "fm_decay": 2.5, "fm_feedback": 0.15,
        "amp_attack": 0.001, "amp_decay": 0.6, "amp_release": 0.9,
        "reverb_mix": 0.5, "reverb_decay": 3.5, "chorus": 0.3},
    "electric_spark": {"mode": "noise", "noise_type": NOISE_WHITE, "duration": 0.3,
        "base_freq": 200.0, "freq_end": 60.0, "noise_amount": 1.0,
        "filter_type": FILTER_BANDPASS, "filter_freq": 3000.0,
        "filter_freq_end": 500.0, "filter_q": 4.0,
        "amp_attack": 0.001, "amp_decay": 0.08, "amp_release": 0.12,
        "distortion": 0.4, "ring_mod": 0.5, "ring_mod_freq": 80.0},
    "robot_voice": {"mode": "formant", "duration": 0.8, "base_freq": 110.0,
        "freq_end": 90.0, "vibrato_rate": 6.0, "vibrato_depth": 0.02,
        "formant1": 600.0, "formant2": 1200.0, "formant3": 2600.0,
        "formant_bw": 60.0, "amp_attack": 0.02, "amp_decay": 0.2,
        "amp_sustain": 0.6, "amp_release": 0.2, "distortion": 0.2,
        "ring_mod": 0.3, "ring_mod_freq": 50.0},
    "magic_sparkle": {"mode": "granular", "duration": 1.5, "base_freq": 1200.0,
        "grain_density": 30.0, "grain_size": 0.06, "grain_spread": 18.0,
        "grain_wave": WAVE_SINE, "amp_attack": 0.05, "amp_decay": 0.4,
        "amp_release": 0.8, "reverb_mix": 0.6, "reverb_decay": 4.0, "chorus": 0.4},
    "crystal_chime": {"mode": "additive", "duration": 2.5, "base_freq": 880.0,
        "partial_count": 12, "inharmonicity": 0.0008, "partial_rolloff": 0.8,
        "partial_decay_spread": 2.0, "noise_amount": 0.2, "noise_attack": 0.002,
        "amp_attack": 0.001, "amp_decay": 0.8, "amp_release": 1.2,
        "reverb_mix": 0.6, "reverb_decay": 4.5},
    "enchanted_pluck": {"mode": "pluck", "duration": 1.2, "base_freq": 523.0,
        "pluck_damping": 0.998, "pluck_brightness": 0.7, "pluck_strings": 2,
        "amp_attack": 0.002, "amp_decay": 0.4, "amp_release": 0.6,
        "reverb_mix": 0.45, "reverb_decay": 3.0, "delay_mix": 0.2},
    "deep_explosion": {"mode": "noise", "noise_type": NOISE_BROWN, "duration": 2.0,
        "base_freq": 60.0, "freq_end": 30.0, "noise_amount": 1.0,
        "sub_amount": 0.8, "filter_type": FILTER_LOWPASS,
        "filter_freq": 1200.0, "filter_freq_end": 80.0,
        "amp_attack": 0.001, "amp_decay": 0.7, "amp_release": 1.0,
        "distortion": 0.5, "reverb_mix": 0.35, "reverb_decay": 2.0},
    "metallic_clang": {"mode": "fm", "duration": 1.0, "base_freq": 220.0,
        "fm_ratio": 2.76, "fm_index": 8.0, "fm_decay": 4.0, "fm_feedback": 0.3,
        "noise_amount": 0.4, "amp_attack": 0.001, "amp_decay": 0.3,
        "amp_release": 0.5, "distortion": 0.2, "reverb_mix": 0.3},
    "rain_loop": {"mode": "noise", "noise_type": NOISE_PINK, "duration": 4.0,
        "noise_amount": 1.0, "filter_type": FILTER_LOWPASS, "filter_freq": 4000.0,
        "amp_attack": 0.3, "amp_decay": 0.5, "amp_sustain": 0.8,
        "amp_release": 0.5, "tremolo_rate": 0.5, "tremolo_depth": 0.15},
    "bird_chirp": {"mode": "formant", "duration": 0.4, "base_freq": 2400.0,
        "freq_end": 3200.0, "vibrato_rate": 20.0, "vibrato_depth": 0.1,
        "formant1": 2500.0, "formant2": 3500.0, "formant3": 4500.0,
        "amp_attack": 0.01, "amp_decay": 0.1, "amp_release": 0.15,
        "reverb_mix": 0.2},
    "plucked_string": {"mode": "pluck", "duration": 1.5, "base_freq": 440.0,
        "pluck_damping": 0.997, "pluck_brightness": 0.6,
        "amp_attack": 0.002, "amp_decay": 0.5, "amp_release": 0.7,
        "reverb_mix": 0.3, "reverb_decay": 2.0},
    "bass_drop": {"mode": "osc", "wave": WAVE_SINE, "duration": 1.0,
        "base_freq": 150.0, "freq_end": 35.0, "sub_amount": 0.5,
        "amp_attack": 0.001, "amp_decay": 0.4, "amp_release": 0.5,
        "distortion": 0.1, "filter_type": FILTER_LOWPASS,
        "filter_freq": 1000.0, "filter_freq_end": 100.0},
    "glitch_blip": {"mode": "osc", "wave": WAVE_SQUARE, "duration": 0.2,
        "base_freq": 800.0, "freq_end": 400.0, "bitcrush_bits": 6.0,
        "bitcrush_rate": 11025.0, "ring_mod": 0.6, "ring_mod_freq": 120.0,
        "amp_attack": 0.001, "amp_decay": 0.06, "amp_release": 0.08,
        "distortion": 0.3},
    "cave_drip": {"mode": "osc", "wave": WAVE_SINE, "duration": 0.6,
        "base_freq": 1200.0, "freq_end": 500.0, "amp_attack": 0.001,
        "amp_decay": 0.15, "amp_release": 0.3, "reverb_mix": 0.7,
        "reverb_decay": 3.0, "delay_mix": 0.3, "delay_time": 0.3},
}


# Sample-based examples: bundled CC0 samples altered with the FX chain.
# Paths are relative to the repo root (resolved in main()).
SAMPLE_PRESETS = {
    "sample_boom_deep": {"mode": "sample",
        "sample_path": "samples/booms-and-bass/boom-hit-soft.wav",
        "sample_pitch": -7.0, "duration": 1.5,
        "amp_attack": 0.001, "amp_decay": 0.5, "amp_release": 0.7,
        "distortion": 0.15, "reverb_mix": 0.35, "reverb_decay": 2.0},
    "sample_whoosh_reversed": {"mode": "sample",
        "sample_path": "samples/whooshes/whoosh-medium-hard.wav",
        "sample_reverse": True, "sample_pitch": 3.0, "duration": 0.8,
        "amp_attack": 0.02, "amp_decay": 0.2, "amp_release": 0.3,
        "filter_type": FILTER_BANDPASS, "filter_freq": 1200.0,
        "filter_q": 2.0, "reverb_mix": 0.3},
    "sample_impact_pitched": {"mode": "sample",
        "sample_path": "samples/impacts/impact-deep-hard.wav",
        "sample_pitch": -5.0, "duration": 1.2,
        "amp_attack": 0.001, "amp_decay": 0.4, "amp_release": 0.6,
        "distortion": 0.3, "sub_amount": 0.4},
    "sample_riser_looped": {"mode": "sample",
        "sample_path": "samples/risers-and-fallers/riser-1s-soft.wav",
        "sample_loop": True, "duration": 4.0,
        "amp_attack": 0.5, "amp_decay": 0.8, "amp_sustain": 0.6,
        "amp_release": 1.0, "reverb_mix": 0.5, "chorus": 0.3},
}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default="examples", help="Output directory")
    args = ap.parse_args()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    repo_root = Path(__file__).resolve().parent.parent
    all_presets = dict(PRESETS)
    for name, params in SAMPLE_PRESETS.items():
        p = dict(params)
        p["sample_path"] = str(repo_root / params["sample_path"])
        all_presets[name] = p
    for name, params in all_presets.items():
        samples = generate_samples(params)
        path = out_dir / f"{name}.wav"
        write_wav(path, samples, stereo=True)
        print(f"wrote {path} ({len(samples) / 2 / 44100:.2f}s stereo)")
    print(f"Done: {len(all_presets)} examples -> {out_dir}")


if __name__ == "__main__":
    main()
