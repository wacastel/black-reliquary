"""Original procedural audio for Black Reliquary. No samples or third-party assets."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Resources"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
RNG = np.random.default_rng(91743)
STATS = {}


def save(name, signal, peak=0.8):
    signal = np.asarray(signal, dtype=np.float64)
    signal -= signal.mean(axis=0)
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
    t = np.arange(int(SR * .57)) / SR
    punch = np.sin(2 * np.pi * (105 * t - 42 * t * t)) * np.exp(-t * 19)
    blast = noise(len(t), 95, 7400) * np.exp(-t * 24)
    body = noise(len(t), 30, 620) * np.exp(-t * 11)
    shotgun = fade(.8 * punch + .58 * blast + .21 * body, .001, .06)
    save('shotgun', reverb(shotgun, .23), .90)

    t = np.arange(int(SR * .58)) / SR
    launch = noise(len(t), 100, 4600) * np.exp(-t * 8)
    thump = np.sin(2 * np.pi * (76 * t - 23 * t * t)) * np.exp(-t * 13)
    save('rocket', reverb(fade(.55 * launch + .6 * thump, .001, .09)), .85)

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

    t = np.arange(int(SR * 3.7)) / SR
    seal = np.zeros(len(t))
    for freq, level in [(98, 1), (196.3, .43), (268.5, .27), (409.1, .19), (551, .08)]:
        seal += level * np.sin(2 * np.pi * freq * t) * np.exp(-t * 1.45)
    seal += noise(len(t), 85, 950) * .17 * np.exp(-t * 6)
    save('seal', reverb(fade(seal, .012, .6), .5), .74)

    t = np.arange(int(SR * 6)) / SR
    win = np.zeros(len(t))
    for when, freq in [(0, 130.81), (.35, 196), (.7, 261.63), (1.05, 311.13)]:
        tt = np.maximum(t - when, 0)
        env = (t >= when) * (1 - np.exp(-tt * 4)) * np.exp(-tt * .75)
        win += env * (np.sin(2 * np.pi * freq * tt) + .18 * np.sin(2 * np.pi * freq * 2.005 * tt))
    save('win', reverb(fade(win, .08, 1.6), .35), .65)


if __name__ == '__main__':
    music()
    effects()
    stats_file = ROOT / 'Tools' / 'audio-stats.json'
    stats_file.write_text(json.dumps(STATS, indent=2) + '\n')
    print(json.dumps(STATS, indent=2))
