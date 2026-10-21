"""
EQ preset generator for a single dynamic driver IEM.

Edit the PROFILES table, run the script, and it rewrites:
  windows/<level>/*.txt   Equalizer APO config files (Peace can import these)
  linux/<level>/*.json    Easy Effects output presets (~/.config/easyeffects/output/)
                          plus a *-Crossfeed.json variant of the Music profile (Linux only)

Both outputs are generated from the same filter list, and both use the
APO filter math (Easy Effects band mode "APO (DR)"), so a preset sounds the
same on either platform. Preamp is computed numerically from the combined
response so no profile can clip.

Filter tuple: (type, fc_hz, gain_db, q)
  PK  = peaking bell
  LSC = low shelf
  HSC = high shelf
"""

import json
import math
import os

FS = 48000.0
HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# What the reviews and the one published 5128 graph agree on
# (see README.md for sources):
#   20-80 Hz     : sub-bass several dB above target
#   350-500 Hz   : small lower-mid dip
#   1-2.5 kHz    : roughly on target, but heard as shouty by some
#   ~3 kHz       : 3-4 dB below target
#   ~8 kHz       : elevated (partly coupler resonance, partly real)
#   10-12 kHz    : peak, then steep roll-off above ~15 kHz
# ---------------------------------------------------------------------------

LEVELS = {
    "L1-high-confidence-safe": (
        "High confidence. Only wide, gentle moves that every reviewer agrees "
        "on in direction. Max about 3 dB. Should sound better than stock for "
        "almost everyone. Start here."
    ),
    "L2-medium-confidence-graph": (
        "Medium confidence. Follows the published B&K 5128 graph reading at "
        "moderate strength. Correct if the graph reading and your unit match. "
        "Expect to tweak the 8 kHz and 11 kHz filters by +-1 kHz."
    ),
    "L3-low-confidence-aggressive": (
        "Low confidence. Full-strength correction with narrower Qs at guessed "
        "peak frequencies plus a treble air shelf. Can sound wrong if the "
        "peaks sit elsewhere in your ears. Use as an experiment, not a default."
    ),
    "ExtL1-high-confidence-extended": (
        "High confidence, extended layout. Same curve as L1 laid out on a "
        "fixed 10-band plan so every region has a slider in Peace. Bands with "
        "no evidence behind them are shipped at 0 dB on purpose: they are "
        "handles for tweaking by ear, not corrections."
    ),
    "ExtL2-medium-confidence-extended": (
        "Medium confidence, extended layout. Same curve as L2 on the same "
        "fixed 10-band plan, zero-gain handles included."
    ),
}

# Fixed band plan for the Ext tiers. One slider per region, low to high.
# The shelf frequency follows the profile (105 neutral, 60 movies, 80 bass)
# because a shelf's corner is part of the correction, not a layout choice.
#   LSC 60/80/105  bass shelf
#   PK  200        mid-bass punch / bloat          (0 unless the profile needs it)
#   PK  420        lower-mid dip (graph)
#   PK  1000       body                            (always 0: no evidence)
#   PK  2000       shout                           (0 in L1, -1 in L2)
#   PK  3100       presence dip (graph)
#   PK  5000       transients                      (0 except Gaming)
#   PK  8000       sibilance peak
#   PK  11000      upper treble peak
#   HSC 14000      air                             (always 0: unpredictable above 12k)
#
# Rejected in review and deliberately NOT in the plan:
#   - a 300 Hz "mud" cut: the graph shows a dip at 350-500, cutting 300 deepens it
#   - a 5 kHz "grain" cut: grain is driver distortion, not a response peak,
#     and 5 kHz is part of the ear-gain region this set already lacks
#   - +-0.5 dB filler nudges: below audibility for broad bands, add ripple,
#     and were measured to drift the curve up to 1.2 dB from the targeted tiers

PROFILES = {
    # -----------------------------------------------------------------------
    # L1 uses Q 1.5 on the 8 kHz cut rather than 2.0: the peak's exact
    # frequency is the least certain number we have (coupler resonance sits
    # right there), so the safe tier hedges with a wider cut.
    "L1-high-confidence-safe": {
        "Music": [
            ("LSC", 105, -2.0, 0.70),
            ("PK", 3000, 2.0, 1.20),
            ("PK", 8000, -2.5, 1.50),
            ("PK", 11000, -2.0, 2.00),
        ],
        "Game-Tactical": [
            ("LSC", 100, -3.0, 0.70),
            ("PK", 250, -1.0, 1.00),
            ("PK", 3000, 2.0, 1.20),
            ("PK", 8000, -1.5, 1.50),
            ("PK", 11000, -2.0, 2.00),
        ],
        "Game-Arena": [
            ("LSC", 100, -3.0, 0.70),
            ("PK", 250, -1.0, 1.00),
            ("PK", 3000, 2.0, 1.20),
            ("PK", 8000, -2.5, 1.50),
            ("PK", 11000, -2.0, 1.50),
        ],
        "Movies": [
            ("LSC", 60, 1.5, 0.70),
            ("PK", 150, -1.5, 1.00),
            ("PK", 2800, 2.0, 1.20),
            ("PK", 8000, -3.0, 1.50),
            ("PK", 11000, -2.0, 2.00),
        ],
        "Bass": [
            ("LSC", 80, 3.0, 0.70),
            ("PK", 200, -1.0, 1.00),
            ("PK", 3000, 1.5, 1.20),
            ("PK", 8000, -2.5, 1.50),
            ("PK", 11000, -2.0, 2.00),
        ],
    },
    # -----------------------------------------------------------------------
    "L2-medium-confidence-graph": {
        "Music": [
            ("LSC", 105, -3.0, 0.70),
            ("PK", 420, 1.0, 1.20),
            ("PK", 2000, -1.0, 1.50),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 8000, -3.5, 2.00),
            ("PK", 11000, -3.0, 2.00),
        ],
        "Game-Tactical": [
            ("LSC", 100, -4.0, 0.70),
            ("PK", 250, -1.5, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 5000, 1.0, 1.50),
            ("PK", 8000, -2.0, 2.00),
            ("PK", 11000, -3.0, 2.00),
        ],
        "Game-Arena": [
            ("LSC", 100, -4.0, 0.70),
            ("PK", 250, -1.5, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 8000, -3.0, 1.50),
            ("PK", 11000, -3.0, 1.50),
        ],
        "Movies": [
            ("LSC", 60, 2.0, 0.70),
            ("PK", 150, -2.0, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 2000, -1.0, 1.50),
            ("PK", 2900, 3.0, 1.50),
            ("PK", 7500, -4.0, 1.50),
            ("PK", 11000, -3.0, 2.00),
        ],
        "Bass": [
            ("LSC", 80, 4.0, 0.70),
            ("PK", 200, -1.5, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 3100, 2.5, 1.50),
            ("PK", 8000, -3.5, 2.00),
            ("PK", 11000, -3.0, 2.00),
        ],
    },
    # -----------------------------------------------------------------------
    "L3-low-confidence-aggressive": {
        "Music": [
            ("LSC", 105, -4.0, 0.70),
            ("PK", 420, 1.5, 1.20),
            ("PK", 1800, -1.5, 1.50),
            ("PK", 3200, 4.0, 1.80),
            ("PK", 8000, -4.5, 2.50),
            ("PK", 11000, -4.0, 2.50),
            ("HSC", 14000, 2.0, 0.70),
        ],
        "Game-Tactical": [
            ("LSC", 100, -5.0, 0.70),
            ("PK", 250, -2.0, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 3200, 3.5, 1.80),
            ("PK", 5000, 1.5, 1.50),
            ("PK", 8000, -2.5, 2.50),
            ("PK", 11000, -4.0, 2.50),
            ("HSC", 14000, 1.5, 0.70),
        ],
        # Arena drops the air shelf as well as the 5 kHz lift: both add
        # spectral shape in the 5-14 kHz band the game's HRTF cues live in.
        "Game-Arena": [
            ("LSC", 100, -5.0, 0.70),
            ("PK", 250, -2.0, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 3200, 3.5, 1.80),
            ("PK", 8000, -4.0, 1.50),
            ("PK", 11000, -4.0, 1.50),
        ],
        "Movies": [
            ("LSC", 60, 3.0, 0.70),
            ("PK", 150, -2.5, 1.00),
            ("PK", 420, 1.5, 1.20),
            ("PK", 1800, -1.5, 1.50),
            ("PK", 3000, 3.5, 1.80),
            ("PK", 7500, -5.0, 2.00),
            ("PK", 11000, -4.0, 2.50),
            ("HSC", 14000, 1.5, 0.70),
        ],
        "Bass": [
            ("LSC", 80, 5.0, 0.70),
            ("PK", 200, -2.0, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 3200, 3.0, 1.80),
            ("PK", 8000, -4.5, 2.50),
            ("PK", 11000, -4.0, 2.50),
            ("HSC", 14000, 1.5, 0.70),
        ],
    },
    # -----------------------------------------------------------------------
    "ExtL1-high-confidence-extended": {
        "Music": [
            ("LSC", 105, -2.0, 0.70),
            ("PK", 200, 0.0, 1.00),
            ("PK", 420, 0.5, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 2.0, 1.20),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -2.5, 1.50),
            ("PK", 11000, -2.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Game-Tactical": [
            ("LSC", 105, -3.0, 0.70),
            ("PK", 200, -1.0, 1.00),
            ("PK", 420, 0.5, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 2.0, 1.20),
            ("PK", 5000, 1.0, 1.50),
            ("PK", 8000, -1.5, 1.50),
            ("PK", 11000, -2.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Game-Arena": [
            ("LSC", 105, -3.0, 0.70),
            ("PK", 200, -1.0, 1.00),
            ("PK", 420, 0.5, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 2.0, 1.20),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -2.5, 1.50),
            ("PK", 11000, -2.0, 1.50),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Movies": [
            ("LSC", 60, 1.5, 0.70),
            ("PK", 200, -1.5, 1.00),
            ("PK", 420, 0.5, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 2.0, 1.20),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -3.0, 1.50),
            ("PK", 11000, -2.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Bass": [
            ("LSC", 80, 3.0, 0.70),
            ("PK", 200, -1.0, 1.00),
            ("PK", 420, 0.5, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 1.5, 1.20),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -2.5, 1.50),
            ("PK", 11000, -2.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
    },
    # -----------------------------------------------------------------------
    "ExtL2-medium-confidence-extended": {
        "Music": [
            ("LSC", 105, -3.0, 0.70),
            ("PK", 200, 0.0, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, -1.0, 1.50),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -3.5, 2.00),
            ("PK", 11000, -3.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Game-Tactical": [
            ("LSC", 105, -4.0, 0.70),
            ("PK", 200, -1.5, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 5000, 1.0, 1.50),
            ("PK", 8000, -2.0, 2.00),
            ("PK", 11000, -3.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Game-Arena": [
            ("LSC", 105, -4.0, 0.70),
            ("PK", 200, -1.5, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, 0.0, 1.50),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -3.0, 1.50),
            ("PK", 11000, -3.0, 1.50),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Movies": [
            ("LSC", 60, 2.0, 0.70),
            ("PK", 200, -2.0, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, -1.0, 1.50),
            ("PK", 3100, 3.0, 1.50),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -4.0, 1.50),
            ("PK", 11000, -3.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
        "Bass": [
            ("LSC", 80, 4.0, 0.70),
            ("PK", 200, -1.5, 1.00),
            ("PK", 420, 1.0, 1.20),
            ("PK", 1000, 0.0, 1.20),
            ("PK", 2000, -1.0, 1.50),
            ("PK", 3100, 2.5, 1.50),
            ("PK", 5000, 0.0, 1.50),
            ("PK", 8000, -3.5, 2.00),
            ("PK", 11000, -3.0, 2.00),
            ("HSC", 14000, 0.0, 0.70),
        ],
    },
}

# Linux-only extra: a crossfeed variant of the Music profile in every tier.
# Crossfeed (bs2b) bleeds a low-passed, delayed copy of each channel into the
# other, the way speakers reach both ears. It fixes hard left-right panning
# that sits in one ear on an IEM, which no EQ filter can touch. Chu Moy
# values: gentler than Jan Meier (650 Hz, 9.5 dB). Never on the game
# profiles: the left-right separation it softens is the positional cue.
# Equalizer APO has no crossfeed, so these presets exist only in linux/.
CROSSFEED = {"fcut": 700.0, "feed": 6.0}
CROSSFEED_PROFILES = ("Music",)

PROFILE_NOTES = {
    "Music": "Neutral target. Fixes the 3 kHz dip, tames 8 kHz and 11 kHz, trims sub-bass toward Harman.",
    "Game-Tactical": "Flat-map shooters (CS2, Valorant, Siege, PUBG, DbD). Less sub-bass and low-mid mud for footsteps, presence lift at 3-5 kHz, lighter 8 kHz cut so transient snap survives.",
    "Game-Arena": "Multi-level and hero shooters (Overwatch, Rivals, The Finals, Arc Raiders, Apex). Same bass and mids, no 5 kHz lift, wider smoother 6-12 kHz so the game's elevation cues arrive less distorted.",
    "Movies": "Cinema. More sub-bass rumble, dialog lift near 3 kHz, harder sibilance cut around 7.5 kHz.",
    "Bass": "EDM / hip-hop. Big sub-bass shelf with mid-bass kept clean, mild presence lift, same treble fixes.",
}


# ---------------------------------------------------------------------------
# RBJ biquad response (the math Equalizer APO and lsp "APO (DR)" mode use)
# ---------------------------------------------------------------------------

def biquad_coeffs(ftype, fc, gain_db, q):
    a = 10 ** (gain_db / 40.0)
    w0 = 2 * math.pi * fc / FS
    cos_w0 = math.cos(w0)
    sin_w0 = math.sin(w0)
    alpha = sin_w0 / (2 * q)
    sqrt_a = math.sqrt(a)

    if ftype == "PK":
        b0 = 1 + alpha * a
        b1 = -2 * cos_w0
        b2 = 1 - alpha * a
        a0 = 1 + alpha / a
        a1 = -2 * cos_w0
        a2 = 1 - alpha / a
    elif ftype == "LSC":
        b0 = a * ((a + 1) - (a - 1) * cos_w0 + 2 * sqrt_a * alpha)
        b1 = 2 * a * ((a - 1) - (a + 1) * cos_w0)
        b2 = a * ((a + 1) - (a - 1) * cos_w0 - 2 * sqrt_a * alpha)
        a0 = (a + 1) + (a - 1) * cos_w0 + 2 * sqrt_a * alpha
        a1 = -2 * ((a - 1) + (a + 1) * cos_w0)
        a2 = (a + 1) + (a - 1) * cos_w0 - 2 * sqrt_a * alpha
    elif ftype == "HSC":
        b0 = a * ((a + 1) + (a - 1) * cos_w0 + 2 * sqrt_a * alpha)
        b1 = -2 * a * ((a - 1) + (a + 1) * cos_w0)
        b2 = a * ((a + 1) + (a - 1) * cos_w0 - 2 * sqrt_a * alpha)
        a0 = (a + 1) - (a - 1) * cos_w0 + 2 * sqrt_a * alpha
        a1 = 2 * ((a - 1) - (a + 1) * cos_w0)
        a2 = (a + 1) - (a - 1) * cos_w0 - 2 * sqrt_a * alpha
    else:
        raise ValueError(ftype)

    return (b0 / a0, b1 / a0, b2 / a0, 1.0, a1 / a0, a2 / a0)


def biquad_mag_db(coeffs, f):
    b0, b1, b2, _, a1, a2 = coeffs
    w = 2 * math.pi * f / FS
    z1 = complex(math.cos(-w), math.sin(-w))
    z2 = z1 * z1
    num = b0 + b1 * z1 + b2 * z2
    den = 1 + a1 * z1 + a2 * z2
    return 20 * math.log10(abs(num / den))


def combined_response(filters, n=600):
    coeffs = [biquad_coeffs(*f) for f in filters]
    out = []
    for i in range(n):
        f = 20 * (20000 / 20) ** (i / (n - 1))
        out.append((f, sum(biquad_mag_db(c, f) for c in coeffs)))
    return out


def preamp_for(filters):
    peak = max(g for _, g in combined_response(filters))
    if peak <= 0:
        return 0.0
    return -math.ceil(peak * 2) / 2.0   # round up to next 0.5 dB


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------

def write_apo(path, name, level, profile, filters, preamp):
    lines = [
        f"# {name}",
        f"# Level: {level}",
        f"# {PROFILE_NOTES[profile]}",
        f"Preamp: {preamp:.1f} dB",
    ]
    for i, (ftype, fc, gain, q) in enumerate(filters, 1):
        lines.append(
            f"Filter {i}: ON {ftype} Fc {fc:g} Hz Gain {gain:.1f} dB Q {q:.2f}"
        )
    with open(path, "w", encoding="utf-8", newline="\r\n") as fh:
        fh.write("\n".join(lines) + "\n")


EE_TYPE = {"PK": "Bell", "LSC": "Lo-shelf", "HSC": "Hi-shelf"}


def ee_band(ftype, fc, gain, q):
    return {
        "frequency": float(fc),
        "gain": float(gain),
        "mode": "APO (DR)",
        "mute": False,
        "q": float(q),
        "slope": "x1",
        "solo": False,
        "type": EE_TYPE[ftype],
        "width": 4.0,
    }


def write_easyeffects(path, filters, preamp, crossfeed=None):
    bands = {f"band{i}": ee_band(*flt) for i, flt in enumerate(filters)}
    eq = {
        "balance": 0.0,
        "bypass": False,
        "input-gain": float(preamp),
        "left": bands,
        "mode": "IIR",
        "num-bands": len(filters),
        "output-gain": 0.0,
        "pitch-left": 0.0,
        "pitch-right": 0.0,
        "right": json.loads(json.dumps(bands)),
        "split-channels": False,
    }
    output = {
        "blocklist": [],
        "equalizer#0": eq,
        "plugins_order": ["equalizer#0"],
    }
    if crossfeed:
        output["crossfeed#0"] = {
            "bypass": False,
            "fcut": float(crossfeed["fcut"]),
            "feed": float(crossfeed["feed"]),
            "input-gain": 0.0,
            "output-gain": 0.0,
        }
        output["plugins_order"].append("crossfeed#0")
    preset = {"output": output}
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(preset, fh, indent=4)
        fh.write("\n")


def main():
    summary = []
    for level, profiles in PROFILES.items():
        win_dir = os.path.join(HERE, "windows", level)
        lin_dir = os.path.join(HERE, "linux", level)
        os.makedirs(win_dir, exist_ok=True)
        os.makedirs(lin_dir, exist_ok=True)
        short = level.split("-")[0]  # L1 / L2 / L3
        for profile, filters in profiles.items():
            name = f"IEM-{short}-{profile}"
            preamp = preamp_for(filters)
            write_apo(os.path.join(win_dir, name + ".txt"), name, level, profile, filters, preamp)
            write_easyeffects(os.path.join(lin_dir, name + ".json"), filters, preamp)
            if profile in CROSSFEED_PROFILES:
                write_easyeffects(
                    os.path.join(lin_dir, name + "-Crossfeed.json"),
                    filters, preamp, crossfeed=CROSSFEED,
                )
            resp = combined_response(filters)
            peak_f, peak_g = max(resp, key=lambda p: p[1])
            summary.append((name, len(filters), preamp, peak_f, peak_g))

    print(f"{'preset':34} {'bands':>5} {'preamp':>7} {'peak @ Hz':>10} {'peak dB':>8}")
    for name, n, pre, pf, pg in summary:
        print(f"{name:34} {n:>5} {pre:>7.1f} {pf:>10.0f} {pg:>8.2f}")


if __name__ == "__main__":
    main()
