#!/usr/bin/env python3
"""Original Emerald Watch score and synthesized effects; no sampled recordings.

Offline build dependency: Python 3 + NumPy. The game needs neither.
Run: python assets/audio/generate_audio.py [--check]
All generated audio and this source are covered by the project's MIT license.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent
RATE = 22050
BPM = 90
BEAT = 60 / BPM
FRAMES = 64 * 14700  # 16 bars, exactly 64 beats; no rounded timing drift.
RNG = np.random.default_rng(41726)
STATS = {}


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def times(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def envelope(t, attack=0.006, release=0.05, decay=0.0):
    result = np.minimum(1.0, t / max(attack, 1 / RATE))
    result *= np.minimum(1.0, np.maximum(0, t[-1] - t) / max(release, 1 / RATE))
    if decay:
        result *= np.exp(-decay * t)
    return result


def tone(midi, seconds, kind='bell'):
    t = times(seconds)
    f = hz(midi)
    p = 2 * np.pi * f * t
    if kind == 'pad':
        y = (np.sin(p) + 0.24 * np.sin(p * 2) + 0.16 * np.sin(p * 1.002)) / 1.4
        return y * envelope(t, 0.65, 0.9) * (0.94 + 0.06 * np.sin(2 * np.pi * .4 * t))
    if kind == 'bass':
        return (np.sin(p) + .16 * np.sin(p * 2)) * envelope(t, .018, .14, .45)
    if kind == 'pluck':
        return (np.sin(p) + .22 * np.sin(p * 2) + .1 * np.sin(p * 3)) * envelope(t, .007, .1, 5)
    return (np.sin(p) + .33 * np.sin(p * 2) * np.exp(-4 * t) + .12 * np.sin(p * 3)) * envelope(t, .015, .18, 2.2)


def add(target, start, signal, gain=1.0, pan=0.0, wrap=False):
    """Equal-power pan. Circular writes retain the final notes' tails at loop start."""
    start = round(start * RATE)
    if signal.ndim == 1:
        signal = signal[:, None] * np.array([math.sqrt((1 - pan) / 2), math.sqrt((1 + pan) / 2)])
    signal = signal * gain
    if wrap:
        start %= len(target)
        first = min(len(signal), len(target) - start)
        target[start:start + first] += signal[:first]
        if first < len(signal):
            target[:len(signal) - first] += signal[first:]
    elif start < len(target):
        count = min(len(signal), len(target) - start)
        target[start:start + count] += signal[:count]


def noise(seconds, smooth=1):
    n = RNG.normal(0, .4, round(seconds * RATE))
    if smooth > 1:
        n = np.convolve(n, np.ones(smooth) / smooth, mode='same') * math.sqrt(smooth)
    return n


def chirp(start, end, seconds, decay=10):
    t = times(seconds)
    phase = 2 * np.pi * (start * t + (end - start) * t * t / (2 * seconds))
    return np.sin(phase) * envelope(t, .003, .025, decay)


def save(name, signal, peak):
    signal = signal.copy()
    # Remove negligible DC without creating a nonzero transient edge in SFX.
    maximum = float(np.max(np.abs(signal)))
    signal *= peak / max(maximum, 1e-9)
    pcm = np.round(signal * 32767).astype('<i2')
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as out:
        out.setnchannels(2 if signal.ndim == 2 else 1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    STATS[name] = {
        'seconds': round(len(signal) / RATE, 5),
        'channels': 2 if signal.ndim == 2 else 1,
        'sample_rate': RATE,
        'peak': round(float(np.max(np.abs(signal))), 5),
        'rms': round(float(np.sqrt(np.mean(signal ** 2))), 5),
    }


def music():
    bed = np.zeros((FRAMES, 2), np.float64)
    lead = np.zeros_like(bed)
    # Original 16-bar sketch: Fmaj7, Am7, Cmaj7, Gadd9, repeated with a varied reply.
    chords = [(41, [53, 57, 60, 64]), (45, [57, 60, 64, 67]),
              (36, [48, 52, 55, 59]), (43, [55, 59, 62, 69])]
    melody = [
        [(0, 76), (1.5, 72), (3, 69), (5, 72), (6.5, 76)],
        [(.5, 79), (2, 76), (3.5, 72), (5.5, 71), (7, 72)],
        [(0, 74), (2, 76), (3.5, 71), (5, 67), (7, 71)],
        [(.5, 74), (2.5, 69), (4, 71), (5.5, 74), (7, 72)],
        [(0, 76), (1.5, 79), (3, 76), (5, 72), (6.5, 69)],
        [(.5, 72), (2, 76), (3.5, 79), (5.5, 76), (7, 72)],
        [(0, 71), (2, 74), (3.5, 76), (5, 79), (7, 76)],
        [(.5, 74), (2.5, 71), (4, 69), (5.5, 67), (7, 72)],
    ]
    arp = [0, 2, 1, 3, 1, 2, 0, 2]
    for section in range(8):
        root, chord = chords[section % 4]
        start = section * 8 * BEAT
        for i, note in enumerate(chord):
            add(bed, start, tone(note, 8 * BEAT + .8, 'pad'), .055, (i - 1.5) / 2.3, True)
        for beat in [0, 2, 4, 6]:
            add(bed, start + beat * BEAT, tone(root, 1.8 * BEAT, 'bass'), .1, 0, True)
        for step in range(16):
            note = chord[arp[step % 8]] + 12
            pan = -.45 if step % 2 == 0 else .45
            add(bed, start + step * .5 * BEAT, tone(note, .65, 'pluck'), .028, pan, True)
        for beat, note in melody[section]:
            add(lead, start + beat * BEAT, tone(note, 1.8, 'bell'), .095, -.16, True)
    # Soft kick and tiny brushed hats are sparse enough for long sessions.
    for beat in range(64):
        if beat % 4 in [0, 2]:
            t = times(.24)
            kick = np.sin(2 * np.pi * (46 * t + 40 * .025 * (1 - np.exp(-t / .025))))
            add(bed, beat * BEAT, kick * envelope(t, .004, .035, 15), .075, 0, True)
        if beat % 2 == 1:
            t = times(.06)
            hat = noise(.06) * envelope(t, .002, .015, 55)
            add(bed, beat * BEAT + .5 * BEAT, hat, .022, .38, True)
    # Circular stereo taps are baked, so there is no runtime reverb cost or cut tail.
    for delay, gain in [(0, 1), (.75 * BEAT, .28), (1.5 * BEAT, .12), (2.25 * BEAT, .06)]:
        tap = np.roll(lead, round(delay * RATE), axis=0)
        if delay:
            tap = tap[:, ::-1]
        bed += tap * gain
    bed += np.roll(bed.copy()[:, ::-1], round(.18 * RATE), axis=0) * .12
    save('emerald_drift', bed, .58)


def chord_effect(name, sequence, duration, peak=.54):
    y = np.zeros((round(duration * RATE), 2))
    for i, (start, note) in enumerate(sequence):
        add(y, start, tone(note, min(.7, duration - start), 'bell'), 1, (i % 3 - 1) * .2)
    save(name, y, peak)


def effects():
    chord_effect('build', [(0, 60), (.07, 64), (.14, 67), (.21, 72)], .70)
    chord_effect('upgrade', [(0, 67), (.085, 72), (.17, 76), (.255, 79), (.34, 84)], 1.0)
    chord_effect('sell', [(0, 76), (.08, 72), (.16, 67)], .62, .46)
    chord_effect('wave', [(0, 60), (.10, 67), (.20, 72), (.38, 76)], 1.05, .55)
    chord_effect('win', [(0, 60), (.12, 64), (.24, 67), (.36, 72), (.70, 76), (.70, 79), (.70, 84)], 1.65, .60)
    chord_effect('loss', [(0, 64), (.22, 60), (.44, 57), (.66, 52)], 1.6, .54)
    chord_effect('leak', [(0, 74), (.16, 69)], .58, .50)
    save('shot', chirp(1200, 380, .13, 22), .50)
    t = times(.50)
    boom = .75 * chirp(85, 33, .50, 7) + .55 * noise(.50, 20) * envelope(t, .003, .1, 10)
    save('boom', boom, .65)
    t = times(.42)
    ice = sum(np.sin(2 * np.pi * f * t) * np.exp(-d * t) for f, d in [(1550, 8), (2070, 11), (2750, 16)])
    save('ice', ice * envelope(t, .004, .07), .48)
    t = times(.22)
    phase = 2 * np.pi * (560 * t + 1600 * t * t)
    arc = (.6 * np.sin(phase) + .3 * np.sin(phase * 2.7) + .25 * noise(.22))
    save('arc', arc * (0.7 + .3 * np.sin(2 * np.pi * 42 * t)) * envelope(t, .003, .04, 12), .52)
    t = times(.35)
    rail = chirp(2500, 110, .35, 9) + .45 * noise(.35, 4) * envelope(t, .003, .06, 20)
    save('rail', rail, .60)
    t = times(.34)
    burn = noise(.34, 10) * (.7 + .3 * np.sin(2 * np.pi * 62 * t)) + .15 * np.sin(2 * np.pi * 95 * t)
    save('burn', burn * envelope(t, .012, .07, 4), .48)
    t = times(.09)
    hit = (.5 * np.sin(2 * np.pi * 230 * t) + .25 * noise(.09, 5)) * envelope(t, .002, .02, 38)
    save('hit', hit, .42)


def check():
    expected = {'emerald_drift', 'build', 'upgrade', 'sell', 'wave', 'win', 'loss', 'leak', 'shot', 'boom', 'ice', 'arc', 'rail', 'burn', 'hit'}
    for name in sorted(expected):
        with wave.open(str(ROOT / f'{name}.wav'), 'rb') as source:
            assert source.getframerate() == RATE and source.getsampwidth() == 2
            channels = source.getnchannels()
            pcm = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2').reshape(-1, channels).astype(float) / 32767
        assert np.isfinite(pcm).all() and np.max(np.abs(pcm)) < .7, name
        assert np.sqrt(np.mean(pcm ** 2)) > .001, name
        if name == 'emerald_drift':
            assert len(pcm) == FRAMES and channels == 2
            seam = np.max(np.abs(pcm[-1] - pcm[0]))
            delta = np.max(np.abs(np.diff(pcm, axis=0)))
            assert seam < .02 and seam < delta, (seam, delta)
            print(f'Music: {len(pcm) / RATE:.6f}s, exact 64-beat cycle, seam jump {seam:.6f}, largest adjacent step {delta:.6f}')
        else:
            assert np.max(np.abs(pcm[[0, -1]])) == 0, name
    print(f'PASS: {len(expected)} files, 16-bit PCM, finite samples, bounded peaks, non-silent; all SFX start/end at zero')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Validate existing WAV assets without regenerating them')
    args = parser.parse_args()
    if not args.check:
        music()
        effects()
        (ROOT / 'audio_manifest.json').write_text(json.dumps({'bpm': BPM, 'bars': 16, 'tracks': STATS}, indent=2) + '\n')
    check()
