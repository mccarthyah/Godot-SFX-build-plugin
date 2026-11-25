"""Unit tests for tools/synth.py (run: python3 -m unittest tools.test_synth -v).

Checks DSP invariants that must hold for every synthesis mode:
- output length matches duration (+ FX tail)
- samples are finite and within [-1, 1] after normalization
- same seed -> identical output (determinism)
- different seeds -> different noise output
- silence in -> silence out (no DC blowup)
- envelope reaches ~0 at end for percussive sounds
"""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth import (  # noqa: E402
    FILTER_LOWPASS, NOISE_WHITE, SAMPLE_RATE, WAVE_SINE,
    default_params, generate_samples,
)

MODES = ["osc", "fm", "pluck", "noise", "additive", "granular", "formant", "hybrid", "sample"]


class TestSynth(unittest.TestCase):
    def test_all_modes_produce_finite_output(self):
        for mode in MODES:
            with self.subTest(mode=mode):
                p = default_params()
                p.update({"mode": mode, "duration": 0.3, "seed": 42, "stereo": False})
                if mode == "sample":
                    p["sample_path"] = str(Path(__file__).resolve().parent.parent
                                            / "samples/booms-and-bass/boom-hit-soft.wav")
                out = generate_samples(p)
                self.assertGreater(len(out), 0)
                self.assertTrue(np.all(np.isfinite(out)), f"{mode} has NaN/Inf")
                self.assertLessEqual(np.max(np.abs(out)), 1.0 + 1e-6)

    def test_output_length_matches_duration(self):
        p = default_params()
        p.update({"mode": "osc", "duration": 0.5, "stereo": False})
        out = generate_samples(p)
        self.assertEqual(len(out), int(0.5 * SAMPLE_RATE))

    def test_stereo_interleaves(self):
        p = default_params()
        p.update({"mode": "osc", "duration": 0.2, "stereo": True})
        out = generate_samples(p)
        self.assertEqual(len(out) % 2, 0)
        self.assertGreater(len(out), 0)

    def test_determinism(self):
        p = default_params()
        p.update({"mode": "noise", "duration": 0.2, "seed": 7, "stereo": False})
        a = generate_samples(p)
        b = generate_samples(p)
        np.testing.assert_array_equal(a, b)

    def test_different_seeds_differ(self):
        base = default_params()
        base.update({"mode": "noise", "noise_amount": 1.0, "duration": 0.2,
                     "stereo": False})
        a = generate_samples({**base, "seed": 1})
        b = generate_samples({**base, "seed": 2})
        self.assertFalse(np.allclose(a, b))

    def test_zero_volume_is_silent(self):
        p = default_params()
        p.update({"mode": "osc", "duration": 0.2, "volume": 0.0,
                  "normalize": False, "stereo": False})
        out = generate_samples(p)
        self.assertTrue(np.allclose(out, 0.0))

    def test_percussive_envelope_decays(self):
        p = default_params()
        p.update({"mode": "osc", "wave": WAVE_SINE, "duration": 0.5,
                  "amp_attack": 0.001, "amp_decay": 0.05, "amp_sustain": 0.0,
                  "amp_release": 0.05, "stereo": False})
        out = generate_samples(p)
        tail = np.max(np.abs(out[-int(0.05 * SAMPLE_RATE):]))
        self.assertLess(tail, 0.05, "percussive tail should decay to near silence")

    def test_lowpass_darkens(self):
        # Lowpassed white noise should have less high-frequency energy
        # than unfiltered white noise.
        base = default_params()
        base.update({"mode": "noise", "noise_type": NOISE_WHITE, "duration": 0.5,
                     "seed": 3, "stereo": False, "normalize": False})
        raw = generate_samples({**base, "filter_type": 0})
        dark = generate_samples({**base, "filter_type": FILTER_LOWPASS,
                                 "filter_freq": 500.0})
        def hf_energy(x):
            spec = np.abs(np.fft.rfft(x))
            freqs = np.fft.rfftfreq(len(x), 1 / SAMPLE_RATE)
            return np.sum(spec[freqs > 4000] ** 2) / max(np.sum(spec ** 2), 1e-12)
        self.assertLess(hf_energy(dark), hf_energy(raw))

    def test_pluck_decays(self):
        p = default_params()
        p.update({"mode": "pluck", "duration": 1.0, "base_freq": 440.0,
                  "stereo": False})
        out = generate_samples(p)
        early = np.max(np.abs(out[:int(0.05 * SAMPLE_RATE)]))
        late = np.max(np.abs(out[int(0.8 * SAMPLE_RATE):]))
        self.assertGreater(early, late, "pluck should decay over time")

    def test_sample_mode(self):
        sample = str(Path(__file__).resolve().parent.parent
                     / "samples/booms-and-bass/boom-hit-soft.wav")
        p = default_params()
        p.update({"mode": "sample", "sample_path": sample, "duration": 1.0,
                  "stereo": False})
        out = generate_samples(p)
        self.assertEqual(len(out), int(1.0 * SAMPLE_RATE))
        self.assertGreater(np.max(np.abs(out)), 0.1, "sample should be audible")
        # Pitch shift and reverse must change the output.
        self.assertFalse(np.allclose(out, generate_samples({**p, "sample_pitch": -12.0})))
        self.assertFalse(np.allclose(out, generate_samples({**p, "sample_reverse": True})))
        # Looping fills the full duration even for short samples.
        looped = generate_samples({**p, "sample_loop": True, "duration": 2.0,
                                   "amp_sustain": 1.0, "amp_decay": 0.01,
                                   "amp_release": 0.01})
        self.assertEqual(len(looped), int(2.0 * SAMPLE_RATE))
        self.assertGreater(np.max(np.abs(looped[int(1.5 * SAMPLE_RATE):])), 0.01)
        # Missing sample renders silence without crashing.
        silent = generate_samples({**p, "sample_path": "nope.wav"})
        self.assertTrue(np.allclose(silent, 0.0))

    def test_ogg_sample_mode(self):
        try:
            import soundfile  # noqa: F401
        except ImportError:
            self.skipTest("Install soundfile to test Ogg decoding in the Python mirror")
        ogg = str(Path(__file__).resolve().parents[1]
                  / "tests/fixtures/ogg/cc0_laser.ogg")
        p = default_params()
        p.update({"mode": "sample", "sample_path": ogg, "duration": 0.25,
                  "stereo": False, "normalize": False, "amp_sustain": 1.0})
        out = generate_samples(p)
        self.assertEqual(len(out), int(0.25 * SAMPLE_RATE))
        self.assertTrue(np.all(np.isfinite(out)))
        self.assertGreater(np.max(np.abs(out)), 0.01, "Ogg sample should decode audibly")

    def test_fm_produces_sidebands(self):
        # FM with high index should have energy away from the carrier.
        p = default_params()
        p.update({"mode": "fm", "duration": 0.5, "base_freq": 440.0,
                  "fm_ratio": 1.0, "fm_index": 0.0, "stereo": False,
                  "normalize": False})
        pure = generate_samples(p)
        p2 = {**p, "fm_index": 8.0, "fm_decay": 0.0}
        fm = generate_samples(p2)
        self.assertFalse(np.allclose(pure, fm), "FM index must change output")


if __name__ == "__main__":
    unittest.main()
