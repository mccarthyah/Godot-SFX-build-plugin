# Additional CC0 audio libraries

These curated libraries are bundled in the sample picker. Every audio set below has a CC0 1.0 license in its source repository; the relevant license text is copied into each set's directory. OGG files are discovered recursively under `res://samples/`.

## Adbertiser SFX — 408 effects

- Source: [Reodelbasalan/adbertiser-sfx](https://github.com/Reodelbasalan/adbertiser-sfx/tree/ed6482ebd9c1283db4ee11b69dba3426c7dd5046)
- License: CC0 1.0 Universal, copied as [`adbertiser-sfx/LICENSE-CC0.txt`](adbertiser-sfx/LICENSE-CC0.txt)
- Source files: 408 WAV effects from `sounds/`; audition MP3 compilations are not included.
- Packaged as OGG Vorbis at quality 0.7 to reduce the bundled asset size. Sample rate and channel count are retained.

## Chip Sounds — 148 effects

- Source: [subsoap/chip-sounds](https://github.com/subsoap/chip-sounds/tree/60cf7ec97c7daf984e7af5f166eefd826f226b70)
- License: CC0 1.0 Universal, copied as [`chip-sounds/LICENSE-CC0.txt`](chip-sounds/LICENSE-CC0.txt)
- Source files: all 148 WAV effects from `chip-sounds/`.
- Packaged as OGG Vorbis at quality 0.7 to reduce the bundled asset size. Sample rate and channel count are retained.

## Meta Open-Sound instrument samples — 1,075 samples

Only the three instrument collections with their own CC0 license are included. The other corpora in Meta Open-Sound have different license terms and are not bundled here.

- Source: [facebookincubator/Meta-open-sound](https://github.com/facebookincubator/Meta-open-sound/tree/514c926efecdb3c7812bf00eedf8e5c8d61dd681)
- Nylon guitar: 348 OGG samples; source directory `systems/instruments/meta-nylon-guitar/ogg/`; license copied to [`meta-open-sound/meta-nylon-guitar/LICENSE-CC0.txt`](meta-open-sound/meta-nylon-guitar/LICENSE-CC0.txt).
- Piano: 352 OGG samples; source directory `systems/instruments/meta-piano/ogg/`; license copied to [`meta-open-sound/meta-piano/LICENSE-CC0.txt`](meta-open-sound/meta-piano/LICENSE-CC0.txt).
- Steel guitar: 375 OGG samples; source directory `systems/instruments/meta-steel-guitar/ogg/`; license copied to [`meta-open-sound/meta-steel-guitar/LICENSE-CC0.txt`](meta-open-sound/meta-steel-guitar/LICENSE-CC0.txt).
- The source `.ogg` files include both Vorbis and Opus bitstreams. Godot's OGG sample loader supports Vorbis, so the 352 Opus-encoded files were transcoded to Vorbis at quality 0.7; the 723 Vorbis files are unchanged.

The CC0 licenses permit redistribution and modification without attribution. Source links and exact revisions are recorded above for provenance. The full source catalog for this plugin now contains 1,951 audio files, including the 320 Wyzowl samples documented in [`../README.md`](../README.md).
