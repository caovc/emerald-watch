# Emerald Watch: original procedural audio

All audio is original, synthesized for this project. No downloaded recordings,
third-party samples, or pre-existing melodies are used. Project MIT license applies.

`emerald_drift.wav` is a light electronic/ambient 16-bar score at 90 BPM with warm
extended chords, a bell melody, stereo arpeggios, rounded bass and restrained
percussion. Its 940,800 frames at 22,050 Hz make a precisely timed 42⅔-second loop.
Delays and note tails wrap circularly into the beginning, preserving the loop seam.
The runtime adds a gentle startup fade; it does not fade the loop boundary.

There are 14 distinct short effects: build, upgrade, shot, boom, ice, arc, rail,
burn, hit, leak, wave, win, loss and sell. Every effect starts and ends at zero.
Files are 16-bit PCM with conservative peaks, under 5 MB total.

## Runtime API

Instantiate `GameAudio` from `scripts/game_audio.gd` once and add it to the tree.
Music starts automatically. Calls are safe before `_ready()`; stored volume/mute
values take effect when initialized. `play_sfx` calls before ready are ignored.

- `play_sfx(key: String)`
- `set_music_volume(value: float)` (clamped to 0–1; default 0.42)
- `set_sfx_volume(value: float)` (clamped to 0–1; default 0.65)
- `set_muted(value: bool)` (preserves configured volumes)
- `get_music_volume() -> float`, `get_sfx_volume() -> float`, `is_muted() -> bool`

The dedicated Music and SFX buses are created automatically. Six combat voices
and three reserved event voices bound polyphony; per-key and global real-time
cooldowns prevent dense or accelerated combat from flooding the mix. An SFX
limiter leaves headroom for music. Pause does not restart the music. No settings
persistence is performed here; the caller may save and restore preferences.

## Reproduce / validate

The shipped WAV files play without Python or any additional runtime dependency.
To regenerate them, use Python 3 with NumPy:

```
python assets/audio/generate_audio.py
python assets/audio/generate_audio.py --check
godot --headless --path . --script res://assets/audio/validate_runtime.gd
```

Generation is deterministic. `audio_manifest.json` records duration, channels,
peak and RMS levels. Validation checks exact loop length, sample format, bounded
peaks, a bounded seam step, non-silence and zero SFX endpoints. Headless runtime
checks verify resource loading and controls, but do not constitute listening QA.

Runtime validation also exercises every event key, burst limiting, volume bounds,
mute/restore, pause, an actual loop-boundary seek, repeat instantiation and a
captured maximum-volume nine-explosion stress mix. It checks the mixed PCM for
non-silence and clipping; no claim of human listening is made.
