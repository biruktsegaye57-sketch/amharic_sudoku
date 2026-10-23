"""Synthesises the game's sound effects (no third-party audio, no licences).

    python3 tool/sounds/make_sounds.py android/app/src/main/res/raw

Plucked notes use Karplus-Strong (a string model, close to a krar);
melodies use the Ethiopian tizita major pentatonic (C D E G A).
"""
import math, random, struct, sys, wave, os

SR = 22050
random.seed(7)

def note(name):
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    n, octave = name[:-1], int(name[-1])
    semis = names[n[0]] + (1 if '#' in n else 0) + (octave - 4) * 12
    return 261.63 * 2 ** (semis / 12)

def pluck(freq, dur, decay=0.996):
    """Karplus-Strong plucked string."""
    n = int(SR * dur)
    period = max(2, int(SR / freq))
    buf = [random.uniform(-1, 1) for _ in range(period)]
    out = []
    for i in range(n):
        v = buf[i % period]
        buf[i % period] = decay * 0.5 * (v + buf[(i + 1) % period])
        out.append(v)
    return out

def bell(freq, dur, partials=((1, 1), (2.76, .35), (5.4, .15)), tau=0.35):
    n = int(SR * dur)
    return [sum(a * math.sin(2 * math.pi * freq * m * i / SR) * math.exp(-i / SR / (tau / m ** .5))
                for m, a in partials) for i in range(n)]

def sine(freq, dur, tau=0.08, attack=0.004):
    n = int(SR * dur)
    return [math.sin(2 * math.pi * freq * i / SR) * min(1, i / SR / attack) * math.exp(-i / SR / tau)
            for i in range(n)]

def mix(*tracks):
    """tracks: (start_seconds, samples, gain)"""
    end = max(int(s * SR) + len(x) for s, x, _ in tracks)
    out = [0.0] * end
    for s, x, g in tracks:
        o = int(s * SR)
        for i, v in enumerate(x):
            out[o + i] += v * g
    return out

def save(path, x, peak=0.8):
    m = max(1e-9, max(abs(v) for v in x))
    fade = int(SR * 0.01)
    data = []
    for i, v in enumerate(x):
        g = min(1, (len(x) - i) / fade)
        data.append(int(max(-1, min(1, v / m * peak * g)) * 32767))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(data), *data))

def noise_click(dur=0.018):
    n = int(SR * dur)
    prev, out = 0.0, []
    for i in range(n):
        v = random.uniform(-1, 1)
        prev = prev * 0.6 + v * 0.4
        out.append(prev * math.exp(-i / SR / 0.004))
    return out

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
T = ['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'D6', 'E6']  # tizita major

save(f'{out}/sfx_tap.wav', noise_click(), 0.35)
save(f'{out}/sfx_place.wav', mix((0, sine(note('A5'), .09, .03), 1), (0, sine(note('E6'), .06, .02), .4)), 0.5)
save(f'{out}/sfx_note.wav', sine(note('E6'), .06, .02), 0.3)
save(f'{out}/sfx_error.wav', mix((0, sine(220, .18, .09), 1), (0, sine(233, .18, .09), .8),
                                  (.09, sine(185, .22, .1), 1)), 0.55)
save(f'{out}/sfx_unit.wav', mix(*[(i * .06, pluck(note(n), .5, decay=.995), 1) for i, n in enumerate(['E5', 'G5', 'C6'])]), 0.6)
save(f'{out}/sfx_hint.wav', bell(note('A5'), .8), 0.45)
save(f'{out}/sfx_coin.wav', mix((0, sine(note('E6'), .08, .05), 1), (.07, sine(note('A6'), .25, .12), 1)), 0.5)
save(f'{out}/sfx_word.wav', mix(*[(i * .09, bell(note(n), 1.0, tau=.5), 1) for i, n in enumerate(['C5', 'E5', 'G5', 'A5', 'C6'])]), 0.7)
win = ['C5', 'D5', 'E5', 'G5', 'E5', 'G5', 'A5', 'C6']
save(f'{out}/sfx_win.wav', mix(*[(i * .14, pluck(note(n), 1.4, decay=.997), 1) for i, n in enumerate(win)],
                               (len(win) * .14, bell(note('C6'), 1.4, tau=.7), .6),
                               (len(win) * .14, pluck(note('C4'), 1.4, decay=.998), .7)), 0.75)
lose = ['A4', 'G4', 'E4', 'D4', 'C4']
save(f'{out}/sfx_lose.wav', mix(*[(i * .2, pluck(note(n) / 2, 1.0, decay=.994), 1) for i, n in enumerate(lose)]), 0.6)
save(f'{out}/sfx_splash.wav', mix(*[(i * .07, pluck(note(n), .9, decay=.996), 1) for i, n in enumerate(['G4', 'C5', 'E5', 'G5'])]), 0.45)
print('ok', sorted(os.listdir(out)))
