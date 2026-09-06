"""Original procedural audio for Black Reliquary. No samples or third-party assets."""
from pathlib import Path
import argparse
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Resources"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
RNG = np.random.default_rng(91743)
STATS = {}
WANTED = None
BASE_EFFECTS = {'shotgun', 'rocket', 'explosion', 'hurt', 'enemy', 'pickup', 'seal', 'win', 'player_jump'}
EMPOWERED_EFFECTS = {'empowered_shot', 'empowered_rocket', 'gore_burst', 'monster_leap',
                     'monster_roar', 'monster_land', 'powerup', 'gate_open'}


def save(name, signal, peak=0.8, smooth_edges=False):
    if WANTED is not None and name not in WANTED:
        return
    signal = np.asarray(signal, dtype=np.float64)
    signal -= signal.mean(axis=0)
    if smooth_edges:
        # DC removal can lift zero endpoints on asymmetric creature voices.
        # Fade after removing DC so one-shot playback cannot click at its edges.
        signal = fade(signal, .002, .035)
    signal *= peak / max(np.max(np.abs(signal)), 1e-9)
    pcm = np.rint(signal * 32767).astype('<i2')
    channels = 1 if signal.ndim == 1 else signal.shape[1]
    with wave.open(str(OUT / (name + '.wav')), 'wb') as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    STATS[name] = {
        'duration_seconds': round(len(signal) / SR, 3),
        'channels': channels,
        'peak': round(float(np.max(np.abs(signal))), 4),
        'rms': round(float(np.sqrt(np.mean(signal ** 2))), 4),
        'loop_edge_delta': round(float(np.max(np.abs(signal[0] - signal[-1]))), 6),
    }


def noise(n, lo, hi):
    """Periodic Gaussian noise with smooth frequency rolloff."""
    spectrum = np.fft.rfft(RNG.normal(size=n))
    f = np.fft.rfftfreq(n, 1 / SR)
    weight = np.exp(-(f / hi) ** 4) * (1 - np.exp(-(f / lo) ** 4))
    x = np.fft.irfft(spectrum * weight, n=n)
    return x / max(np.std(x), 1e-9)


def fade(x, attack=0.005, release=0.08):
    n = len(x)
    env = np.ones(n)
    a = min(int(attack * SR), n)
    r = min(int(release * SR), n)
    env[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    env[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return x * env


def reverb(x, wet=0.24):
    # Several damped, irregular reflections; returned tail is explicitly faded.
    result = np.pad(x, (0, int(SR * 0.8)))
    for delay, gain in [(0.071, .55), (.127, .39), (.223, .27), (.389, .17), (.607, .10)]:
        offset = int(SR * delay)
        result[offset:offset + len(x)] += x * gain * wet
    return fade(result, .002, .12)


def music():
    duration = 72
    n = SR * duration
    t = np.arange(n) / SR
    phase = 2 * np.pi * t / duration
    bed = np.zeros((n, 2))

    def tone(freq, offset=0):
        # Quantized Fourier frequencies guarantee that the 72-second loop closes.
        freq = round(freq * duration) / duration
        return np.sin(2 * np.pi * freq * t + offset)

    # Slow beating stone-deep pedal tones, with no regular percussion.
    for i, freq in enumerate([32.70, 32.75, 49.00, 65.41, 65.47, 98.0]):
        swell = .67 + .21 * np.sin((i % 3 + 1) * phase + i * 1.7)
        voice = tone(freq, i * 0.7) * swell * [0.15, .075, .025, .065, .04, .018][i]
        pan = [-.3, .3, -.7, .25, -.2, .55][i]
        bed[:, 0] += voice * np.sqrt((1 - pan) / 2)
        bed[:, 1] += voice * np.sqrt((1 + pan) / 2)

    # A distant, dissonant vocal-like organ. Upper partials imply vowels.
    for i, base in enumerate([130.81, 138.59, 196.0, 207.65]):
        swell = (.5 + .5 * np.cos((i % 2 + 1) * phase + i * 1.8)) ** 2
        voice = np.zeros(n)
        for partial, level in [(1, .55), (2, .16), (3, .28), (5, .10), (7, .065)]:
            voice += tone(base * partial, i + partial) * level
        voice *= swell * .023
        drift = .55 * np.sin(phase + i)
        bed[:, 0] += voice * (.7 + .2 * drift)
        bed[:, 1] += voice * (.7 - .2 * drift)

    for channel in range(2):
        air = noise(n, 180, 2400)
        rumble = noise(n, 24, 145)
        breath = (.5 + .5 * np.sin(3 * phase + channel * .43)) ** 4
        bed[:, channel] += air * (.003 + .013 * breath)
        bed[:, channel] += rumble * .014 * (.7 + .3 * np.cos(2 * phase + channel))

    # Four long metallic tolls with deliberately inharmonic overtones.
    for start, base, pan in [(7, 81.3, -.7), (24, 68.0, .65), (43, 102.7, -.2), (64, 76.0, .4)]:
        length = SR * 19
        tt = np.arange(length) / SR
        bell = np.zeros(length)
        for j, ratio in enumerate([1, 2.007, 2.73, 4.16, 5.43, 6.79]):
            bell += np.sin(2 * np.pi * base * ratio * tt + .2 * j) * np.exp(-tt / (4.7 - .43 * j)) / (1 + j * 1.5)
        bell = fade(bell, .065, 2.0) * .051
        idx = (np.arange(length) + start * SR) % n
        bed[idx, 0] += bell * np.sqrt((1 - pan) / 2)
        bed[idx, 1] += bell * np.sqrt((1 + pan) / 2)
        # Early reflections inside a large stone hall, wrapped across loop.
        for delay, amount in [(.293, .32), (.587, .21), (1.13, .13)]:
            reflection = (idx + int(delay * SR)) % n
            bed[reflection, 0] += bell * amount * np.sqrt((1 + pan) / 2)
            bed[reflection, 1] += bell * amount * np.sqrt((1 - pan) / 2)

    save('music', bed, .54)


def effects():
    global RNG
    original_rng = RNG
    # Retain the original stream for unchanged effects. Advancing the four music
    # noise buffers reproduces its state without synthesizing the 72-second bed.
    RNG = np.random.default_rng(91743)
    for _ in range(4):
        RNG.normal(size=SR * 72)
    legacy_rng = RNG
    # Revised sounds have their own streams: --only and full builds are identical.
    RNG = np.random.default_rng(917438)
    t = np.arange(int(SR * 1.14)) / SR
    # A pressure wave, audible low-mid body, tearing muzzle blast, and pump cycle.
    # Most of the weight lives above 140 Hz so small laptop speakers retain it.
    punch = np.sin(2 * np.pi * (185 * t - 74 * t * t + 15 * t ** 3)) * np.exp(-t * 9)
    body = noise(len(t), 145, 1050) * np.exp(-t * 6.7)
    blast = noise(len(t), 550, 5700) * np.exp(-t * 18)
    shotgun = np.tanh((.70 * punch + .59 * body + .40 * blast) * 1.7) * .68
    shotgun += .10 * noise(len(t), 120, 780) * np.exp(-t * 3.2)
    for when, amount, freq in [(.19, .16, 1350), (.31, .12, 920)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 700)) * np.exp(-tt * 49)
        shotgun += amount * env * (noise(len(t), 550, 3600) + .27 * np.sin(2 * np.pi * freq * tt))
    save('shotgun', reverb(fade(shotgun, .0017, .19), .40), .88, smooth_edges=True)

    t = np.arange(int(SR * 1.25)) / SR
    pitch = 151 * t - 49 * t * t + 9 * t ** 3
    launch = .61 * np.sin(2 * np.pi * pitch) * np.exp(-t * 7)
    launch += .55 * noise(len(t), 155, 2400) * np.exp(-t * 5.8)
    launch += .32 * noise(len(t), 650, 5300) * np.exp(-t * 25)
    exhaust = (.7 + .3 * np.sin(2 * np.pi * 38 * t)) * (1 - np.exp(-t * 27)) * np.exp(-t * 4.4)
    launch += .16 * noise(len(t), 330, 2900) * exhaust
    tt = np.maximum(t - .27, 0)
    launch += .13 * (t >= .27) * noise(len(t), 720, 3500) * (1 - np.exp(-tt * 600)) * np.exp(-tt * 45)
    save('rocket', reverb(fade(np.tanh(launch * 1.55) * .7, .002, .23), .38), .85, smooth_edges=True)

    RNG = legacy_rng
    for length in [.57, .57, .58]:
        RNG.normal(size=int(SR * length))  # Original shotgun and rocket noise draws.

    t = np.arange(int(SR * 1.5)) / SR
    boom = .64 * noise(len(t), 22, 330) * np.exp(-t * 3.3)
    boom += .31 * noise(len(t), 250, 5200) * np.exp(-t * 12)
    boom += .42 * np.sin(2 * np.pi * (54 * t - 11 * t * t)) * np.exp(-t * 6)
    save('explosion', reverb(fade(boom, .004, .28), .4), .92)

    t = np.arange(int(SR * .38)) / SR
    # Nonverbal, synthetic impact. No recorded voices.
    pitch = 155 * t - 68 * t * t
    hurt = (.7 * np.sin(2 * np.pi * pitch) + .24 * np.sin(2 * np.pi * 3 * pitch)) * np.exp(-t * 10)
    hurt += .22 * noise(len(t), 180, 2200) * np.exp(-t * 18)
    save('hurt', reverb(fade(hurt, .004, .12), .12), .69)

    t = np.arange(int(SR * .7)) / SR
    pitch = 96 * t - 38 * t * t
    rasp = np.sin(2 * np.pi * pitch) + .33 * np.sin(2 * np.pi * 2.04 * pitch)
    rasp = np.tanh(rasp * 2.2) * np.exp(-t * 5.0)
    rasp += .3 * noise(len(t), 95, 1700) * np.exp(-t * 7)
    save('enemy', reverb(fade(rasp, .008, .20), .26), .64)

    t = np.arange(int(SR * .48)) / SR
    pickup = np.zeros(len(t))
    for when, freq in [(0, 523.25), (.09, 783.99), (.18, 1046.5)]:
        tt = np.maximum(t - when, 0)
        pickup += (t >= when) * np.sin(2 * np.pi * freq * tt) * (1 - np.exp(-tt * 220)) * np.exp(-tt * 12)
    save('pickup', reverb(fade(pickup, .003, .15), .2), .52)

    legacy_rng = RNG
    RNG = np.random.default_rng(917439)
    t = np.arange(int(SR * 4.8)) / SR
    # A mallet strike excites an inharmonic bronze body, then rising silver chimes.
    strike = .38 * noise(len(t), 320, 4100) * np.exp(-t * 43)
    seal = strike + .24 * np.sin(2 * np.pi * (230 * t - 40 * t * t)) * np.exp(-t * 14)
    for freq, level, decay in [(196, .64, 1.08), (392.8, .35, .83),
                              (536, .25, 1.13), (814, .17, 1.34),
                              (1063, .12, 1.65), (1487, .06, 2.05)]:
        env = (1 - np.exp(-t * 95)) * np.exp(-t * decay)
        beating = .86 + .14 * np.cos(2 * np.pi * 1.7 * t)
        seal += level * np.sin(2 * np.pi * freq * t) * env * beating
    for when, freq, level in [(.29, 587.33, .20), (.56, 783.99, .18),
                              (.85, 1046.5, .145), (1.13, 1174.66, .10)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 130)) * np.exp(-tt * 2)
        seal += level * env * (np.sin(2 * np.pi * freq * tt) + .21 * np.sin(2 * np.pi * freq * 2.73 * tt))
    save('seal', reverb(fade(seal, .003, .75), .65), .81, smooth_edges=True)
    RNG = legacy_rng
    RNG.normal(size=int(SR * 3.7))  # Original seal's noise draw.

    t = np.arange(int(SR * 6)) / SR
    win = np.zeros(len(t))
    for when, freq in [(0, 130.81), (.35, 196), (.7, 261.63), (1.05, 311.13)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 4)) * np.exp(-tt * .75)
        win += env * (np.sin(2 * np.pi * freq * tt) + .18 * np.sin(2 * np.pi * freq * 2.005 * tt))
    save('win', reverb(fade(win, .08, 1.6), .35), .65)

    RNG = np.random.default_rng(917440)
    t = np.arange(int(SR * .43)) / SR
    # Original source-filter vocal synthesis: an airy /h/ enters a short voiced
    # open-back vowel. No recorded person, speech service, or borrowed sample.
    pitch = 136 + 28 * np.exp(-((t - .08) / .045) ** 2) - 41 * t
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    voiced = np.zeros(len(t))
    for harmonic in range(1, 24):
        freq = harmonic * 140
        formant = (.85 * np.exp(-.5 * ((freq - 640) / 165) ** 2)
                   + .37 * np.exp(-.5 * ((freq - 1110) / 200) ** 2)
                   + .13 * np.exp(-.5 * ((freq - 2450) / 390) ** 2))
        voiced += np.sin(harmonic * phase + .13 * harmonic) * (formant + .20) / harmonic ** .76
    voicing_env = (1 - np.exp(-np.maximum(t - .024, 0) * 70)) * np.exp(-t * 9.2)
    breath_env = (1 - np.exp(-t * 150)) * np.exp(-t * 19)
    huh = .83 * voiced * voicing_env + .18 * noise(len(t), 500, 3500) * breath_env
    save('player_jump', reverb(fade(huh, .008, .13), .07)[:int(SR * .68)], .62, smooth_edges=True)
    RNG = original_rng


def empowered_effects():
    """Heavy relic weapons, creature voices, and gate magic; all synthesized here."""
    # Use a separate seed so these effects can be rebuilt independently and match
    # a full rebuild exactly, without changing the existing soundtrack.
    global RNG
    original_rng = RNG
    RNG = np.random.default_rng(914726)

    t = np.arange(int(SR * 1.03)) / SR
    pitch = 112 * t - 58 * t * t + 15 * t ** 3
    thunder = .75 * np.sin(2 * np.pi * pitch) * np.exp(-t * 10)
    thunder += .55 * noise(len(t), 38, 980) * np.exp(-t * 6.8)
    thunder += .34 * noise(len(t), 680, 6700) * np.exp(-t * 32)
    # A brief saturated core gives the blast weight without a large volume jump.
    thunder = .7 * np.tanh(thunder * 1.6)
    thunder += .14 * noise(len(t), 26, 210) * np.exp(-t * 3.4)
    save('empowered_shot', reverb(fade(thunder, .0018, .17), .33), .88, smooth_edges=True)

    t = np.arange(int(SR * 1.2)) / SR
    exhaust = noise(len(t), 95, 3800) * np.exp(-t * 6)
    exhaust *= .75 + .25 * np.sin(2 * np.pi * (31 * t - 9 * t * t))
    core = np.sin(2 * np.pi * (86 * t - 28 * t * t + 5 * t ** 3)) * np.exp(-t * 7.5)
    ignition = noise(len(t), 850, 6000) * np.exp(-t * 37)
    launch = .52 * exhaust + .73 * core + .21 * ignition
    launch += .18 * noise(len(t), 24, 250) * np.exp(-t * 3.5)
    save('empowered_rocket', reverb(fade(np.tanh(launch * 1.4), .002, .20), .35), .86, smooth_edges=True)

    legacy_rng = RNG
    RNG = np.random.default_rng(914727)
    t = np.arange(int(SR * 2.0)) / SR
    # A substantial body burst, staggered bone snaps and airborne wet debris.
    burst = .55 * noise(len(t), 130, 1450) * np.exp(-t * 7.5)
    burst += .49 * np.sin(2 * np.pi * (192 * t - 64 * t * t + 9 * t ** 3)) * np.exp(-t * 9)
    burst += .29 * noise(len(t), 1300, 6700) * np.exp(-t * 23)
    burst = .74 * np.tanh(burst * 1.55)
    for when, level, pitch in [(0.031, .48, 340), (.098, .41, 490),
                               (.175, .38, 280), (.29, .34, 390),
                               (.43, .28, 230), (.59, .23, 350),
                               (.79, .19, 260), (1.02, .14, 310),
                               (1.28, .11, 230), (1.54, .075, 360)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 1100)) * np.exp(-tt * 26)
        liquid_phase = 2 * np.pi * (pitch * tt - pitch * 2 * tt * tt)
        pop = .65 * np.sin(liquid_phase) + .40 * noise(len(t), 680, 5600)
        burst += level * pop * env
    burst += .065 * noise(len(t), 260, 1900) * (1 - np.exp(-t * 30)) * np.exp(-t * 2.4)
    save('gore_burst', reverb(fade(burst, .0018, .3), .31), .86, smooth_edges=True)
    RNG = legacy_rng
    for _ in range(8):
        RNG.normal(size=int(SR * .9))  # Preserve unchanged creature and gate sounds.

    def creature(t, pitch, breath):
        phase = 2 * np.pi * np.cumsum(pitch) / SR
        # Irregular pulse rasp plus moving upper resonances: a nonhuman snarl.
        pulse = np.sin(phase + 1.15 * np.sin(phase * .503))
        pulse += .34 * np.sin(phase * 2.01) + .20 * np.sin(phase * 3.98)
        voice = .6 * np.tanh(pulse * 2.5)
        voice += .16 * np.sin(phase * 7.03 + 1.3 * np.sin(2 * np.pi * 19 * t))
        voice += breath * noise(len(t), 350, 3400)
        return voice * (.79 + .15 * np.sin(2 * np.pi * 27 * t)
                        + .06 * np.sin(2 * np.pi * 41 * t))

    t = np.arange(int(SR * .83)) / SR
    pitch = 96 + 175 * np.exp(-((t - .22) / .16) ** 2) + 19 * np.sin(2 * np.pi * 9 * t)
    leap = creature(t, pitch, .25) * (1 - np.exp(-t * 35)) * np.exp(-t * 2.7)
    save('monster_leap', reverb(fade(leap, .013, .22), .27), .75, smooth_edges=True)

    t = np.arange(int(SR * 1.9)) / SR
    pitch = 72 + 57 * np.exp(-t * 1.7) + 9 * np.sin(2 * np.pi * 5.5 * t)
    roar = creature(t, pitch, .22) * (1 - np.exp(-t * 12)) * np.exp(-t * 1.7)
    roar += .16 * noise(len(t), 35, 270) * (1 - np.exp(-t * 20)) * np.exp(-t * 2)
    save('monster_roar', reverb(fade(roar, .024, .4), .37), .72, smooth_edges=True)

    t = np.arange(int(SR * .72)) / SR
    land = .68 * np.sin(2 * np.pi * (72 * t - 31 * t * t)) * np.exp(-t * 15)
    land += .48 * noise(len(t), 32, 700) * np.exp(-t * 11)
    land += .22 * noise(len(t), 1000, 5200) * np.exp(-t * 32)
    # Claws scrape stone just after the main body impact.
    scrape = np.maximum(t - .055, 0)
    land += (t >= .055) * noise(len(t), 1600, 6200) * .085 * np.exp(-scrape * 15)
    save('monster_land', reverb(fade(land, .002, .16), .30), .80, smooth_edges=True)

    t = np.arange(int(SR * 2.6)) / SR
    swell = (1 - np.exp(-t * 5)) * np.exp(-t * 2.3)
    surge = .33 * noise(len(t), 95, 1700) * swell
    surge += .32 * np.sin(2 * np.pi * (54 * t + 27 * t * t)) * swell
    for when, freq, level in [(0, 98, .70), (.15, 146.83, .42),
                              (.29, 207.65, .29), (.46, 392, .17)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 45)) * np.exp(-tt * 2.1)
        surge += level * env * (np.sin(2 * np.pi * freq * tt)
                                + .22 * np.sin(2 * np.pi * freq * 2.71 * tt))
    save('powerup', reverb(fade(surge, .009, .5), .42), .75, smooth_edges=True)

    t = np.arange(int(SR * 4.7)) / SR
    gate = .30 * noise(len(t), 28, 250) * (1 - np.exp(-t * 14)) * np.exp(-t * 2.6)
    gate += .17 * noise(len(t), 340, 2000) * (1 - np.exp(-t * 8)) * np.exp(-t * 3.7)
    for when, freq, level in [(.13, 65.41, .65), (.16, 130.81, .38),
                              (.24, 196, .28), (.33, 261.63, .21),
                              (.47, 311.13, .16)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 18)) * np.exp(-tt * .94)
        gate += level * np.sin(2 * np.pi * freq * tt) * env
    for i, when in enumerate(np.linspace(.47, 2.35, 15)):
        tt = np.maximum(t - when, 0)
        freq = [783.99, 1046.5, 1244.5, 1568][i % 4]
        env = (t >= when) * (1 - np.exp(-tt * 220)) * np.exp(-tt * 7.5)
        gate += .068 * env * (np.sin(2 * np.pi * freq * tt)
                              + .35 * np.sin(2 * np.pi * freq * 2.03 * tt))
    save('gate_open', reverb(fade(gate, .012, .85), .55), .77, smooth_edges=True)
    RNG = original_rng


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', nargs='+', choices=sorted(BASE_EFFECTS | EMPOWERED_EFFECTS | {'music'}),
                        help='Regenerate only these WAVs; leave other assets and the default stats file untouched.')
    parser.add_argument('--stats-output', type=Path, help='Optional JSON report destination, including for a selective build.')
    args = parser.parse_args()
    WANTED = set(args.only) if args.only else None
    if WANTED is None or 'music' in WANTED:
        music()
    if WANTED is None or WANTED & BASE_EFFECTS:
        effects()
    if WANTED is None or WANTED & EMPOWERED_EFFECTS:
        empowered_effects()
    stats_file = args.stats_output or (ROOT / 'Tools' / 'audio-stats.json' if WANTED is None else None)
    if stats_file is not None:
        stats_file.write_text(json.dumps(STATS, indent=2) + '\n')
    print(json.dumps(STATS, indent=2))
