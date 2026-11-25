# Godot SFX Generator Plugin

A sound-effect generator for **Godot 4** — create rich, layered, non-8-bit
SFX with FM bells, plucked strings, granular textures, formant voices and
resonant explosions, or start from bundled CC0 recordings and reshape them.

![Synthesis modes](https://img.shields.io/badge/modes-8%20synth%20engines%20%2B%20samples-4cc2ff)
![Presets](https://img.shields.io/badge/presets-46%20hand--tuned-ffd166)
![Godot](https://img.shields.io/badge/Godot-4.x-478cbf)

## Why not just 8-bit beeps?

Classic "beep generators" use a single square wave with a pitch blip. This
plugin layers **8 synthesis engines** and an audio-sample source with a full
effects chain, so sounds have body, texture and movement:

| Engine | What it does | Sounds like |
|---|---|---|
| **Oscillator** | Sine/saw/square/triangle/pulse + sub-osc + detuned 2nd osc + optional FM + noise layer | UI clicks, coins, bass drops, zaps |
| **FM** | 2-operator frequency modulation with decaying index + feedback | Bells, metallic clangs, electric tones |
| **Pluck** | Karplus–Strong physical modeling (1–2 strings) | Guitars, harps, plucked strings |
| **Noise** | White/pink/brown noise through resonant filters with sweeps | Explosions, whooshes, rain, wind |
| **Additive** | Inharmonic partial stack with per-partial decay | Crystal chimes, glass, piano-ish tones |
| **Granular** | Cloud of windowed grains with pitch spread | Magic sparkles, shimmer, textures |
| **Formant** | Sawtooth through 3 vocal-tract resonators (F1/F2/F3) | Robot voices, creatures, birds, owls |
| **Hybrid** | FM body + brown-noise breath + sub thump | Heavy impacts, thuds, punches |
| **Sample** | Load a WAV, resample/pitch-shift, reverse or loop it | Altered foley, booms, whooshes and risers |

The bundled sample picker scans `res://samples/` recursively. Its 76 WAVs are
48 kHz, 16-bit PCM from the **CC0 1.0** [wyzowl/sfx-kit](https://github.com/wyzowl/sfx-kit)
library. Choose **Sample** as the source mode, select a recording, then use
pitch, reverse/loop, envelope, filtering and the same effects chain as the
synth engines. Add your own WAV files under `res://samples/` to make them
available in the picker. See [`samples/README.md`](samples/README.md) for
attribution and the included sample list.

**Effects chain** (all optional, all parameterizable): resonant biquad filter
with sweep + envelope, distortion (tanh / hard clip / foldback), bitcrush,
ring modulation, tremolo, chorus, feedback delay, Schroeder reverb, ADSR
envelope, stereo width. Plus pitch sweeps, vibrato, detune, and seed-based
**randomization** for infinite variation.

## Installation

1. Copy both the `addons/` and `samples/` folders into your Godot project
   (or clone this repo and copy `addons/sfx_generator/` plus `samples/`).
2. In Godot: **Project → Project Settings → Plugins** → enable **SFX Generator**.
3. Open the dock: **View → SFX Generator**.

> This repo root is also a runnable demo project — open the folder in Godot
> and press Play (or just use the dock; no need to run the game).

## Quick start

1. Pick a preset from the dropdown (or filter by category).
2. Press **▶ Preview** to hear it.
3. Tweak sliders, hit **🎲 Randomize** for a new sound in the category, or
   **🧬 Mutate** to evolve the current one.
4. Press **💾 Export WAV** to save into `res://sfx_output/` (drag the file
   into your game), or **📦 Export All Presets** to dump the whole library.

Exported WAVs are 16-bit / 44.1 kHz stereo and work in any engine.

## Preset library (46 sounds)

- **UI** — Soft UI Click, Glass UI Tick, Retro Coin (rich), Bubble Pop
- **Sci-Fi** — Laser Zap, FM Bell, Electric Spark, Robot Voice, Alien Chirp,
  Glitch Blip, Alarm Klaxon
- **Magic** — Magic Sparkle, Crystal Chime, Enchanted Pluck, Portal Whoosh,
  Power-up Shimmer, Healing Glow
- **Impact** — Deep Explosion, Metallic Clang, Heavy Thud, Glass Smash,
  Whoosh, Footstep (gravel), Sword Swing
- **Nature** — Rain Loop, Wind Gust, Bird Chirp, Owl Hoot, Water Splash,
  Door Creak, Cave Drip
- **Musical** — Plucked String, Warm Pad Stab, Bass Drop, Chiptune Arp (warm),
  Bell Toll
- **Sample-based** — Sample Boom (deep), Sample Whoosh (reversed), Sample
  Impact (pitched), Sample Riser (looped), Sample Spring (bouncy), Sample
  Shimmer (stretched), Sample Digital Breach, Sample Cinematic Thunder,
  Sample Notification Glow, Sample Transform Morph

Listen to the curated procedural and sample-based renders in [`examples/`](examples/)
without opening Godot.

## Using sounds in code

Generate at runtime (prototyping / fully procedural games):

```gdscript
# Option 1: SFXPlayer node
var player := SFXPlayer.new()
player.preset_name = "Laser Zap"
add_child(player)
player.play()

# Option 2: direct API
var stream: AudioStreamWAV = SFXSynthEngine.generate_stream({
    "mode": "fm", "base_freq": 660.0, "fm_ratio": 3.01, "fm_index": 6.0,
    "duration": 1.8, "reverb_mix": 0.5,
})
var audio := AudioStreamPlayer.new()
audio.stream = stream
add_child(audio)
audio.play()

# Option 3: save to disk
SFXSynthEngine.save_wav("res://sfx_output/my_bell.wav", {
    "mode": "fm", "base_freq": 660.0, "fm_ratio": 3.01, "fm_index": 6.0,
})
```

For shipped games, prefer exported WAVs — runtime generation costs CPU at
startup. See `SFXSynthEngine.default_params()` for the full parameter list.

## Python tools (no Godot needed)

The DSP is mirrored in NumPy so you can audition and test sounds anywhere:

```bash
pip install numpy
python3 tools/generate_examples.py   # regenerate examples/*.wav
python3 -m unittest tools.test_synth -v  # run DSP unit tests
```

## Requirements

- Godot 4.x — validated on **4.7.2 official** (editor + headless). The plugin
  supports both the ≤4.3 dock API and the 4.4+ `EditorDock` API.
- Python 3 + NumPy (optional, for the tools only)

## Testing

Headless validation with a Godot binary (all checks must pass):

```bash
godot --headless --path . --import                       # parses every script
godot --headless --path . --script tests/godot_test.gd   # engine + presets
godot --headless --path . --script tests/godot_test_ui.gd # dock + player
python3 -m unittest tools.test_synth -v                  # Python DSP mirror
```

## License

MIT — see [LICENSE](LICENSE).
