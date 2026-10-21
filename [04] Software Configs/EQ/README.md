# EQ presets for a single dynamic driver IEM

25 presets for one budget 10 mm single dynamic driver IEM, in five tiers and
five use cases. Every preset exists twice with identical filters: an
Equalizer APO text file for Windows and an Easy Effects JSON for Linux. The
Easy Effects bands use the "APO (DR)" filter mode, so the two platforms
produce the same curve.

No public measurement of this set exists on Squig.link or AutoEq. These were
built from reviewer descriptions and one B&K 5128 graph read by eye, so treat
them as starting points to judge, not finished corrections. The script is
the useful part for any other IEM: put the frequency response observations
in the table and it writes both formats with a safe preamp.

## Folder layout

```
windows/
  L1-high-confidence-safe/          IEM-L1-{Music,Game-Tactical,Game-Arena,Movies,Bass}.txt
  L2-medium-confidence-graph/       IEM-L2-....txt
  L3-low-confidence-aggressive/     IEM-L3-....txt
  ExtL1-high-confidence-extended/   IEM-ExtL1-....txt   (fixed 10-band layout)
  ExtL2-medium-confidence-extended/ IEM-ExtL2-....txt   (fixed 10-band layout)
linux/
  same five folders with .json, plus IEM-<tier>-Music-Crossfeed.json in each
EQ.py                               edit the table, re-run, both folders regenerate
```

## Confidence levels

| Level | Confidence | What it does | Max move |
|---|---|---|---|
| L1 | High | Wide, gentle moves every reviewer agrees on in direction. Should beat stock for almost everyone. | about 3 dB |
| L2 | Medium | Follows the published 5128 graph reading at moderate strength. Right if your unit matches that graph. | about 4 dB |
| L3 | Low | Full-strength correction, narrower Qs at guessed peak frequencies, plus an air shelf. Can sound wrong if the peaks sit elsewhere in your ears. | about 5 dB |
| ExtL1 | High | The L1 curve on a fixed 10-band layout. Same sound, every region gets a slider in Peace. | about 3 dB |
| ExtL2 | Medium | The L2 curve on the same 10-band layout. | about 4 dB |

### Extended layout

The L1 to L3 tiers only include filters where the evidence says something
is wrong. The Ext tiers put the same correction on a fixed 10-band plan so
you can tweak any region by ear without adding sliders. They are a layout,
not a different tuning. ExtL2 Music is numerically identical to L2 Music,
and the others track their targeted versions within about half a dB.

Bands with no evidence behind them ship at 0 dB on purpose. A filter you
cannot justify is noise, and half-dB filler on broad bands is below
audibility but still adds ripple. An earlier draft that nudged every slider
drifted up to 1.2 dB from the targeted curves and added about 1 dB of
ripple in the mids, so it was dropped.

| Band | Type | Region | Default |
|---|---|---|---|
| 105 / 60 / 80 Hz | Low shelf | Bass. Corner follows the profile: 105 neutral, 60 movies, 80 bass | set |
| 200 Hz | Bell | Mid-bass punch or bloat | 0 except the game, Movies and Bass profiles |
| 420 Hz | Bell | Lower-mid dip from the graph | set |
| 1 kHz | Bell | Body | 0, handle only |
| 2 kHz | Bell | Shout | 0 in L1, -1 in L2 |
| 3.1 kHz | Bell | Presence dip from the graph | set |
| 5 kHz | Bell | Transients | 0 except Game-Tactical |
| 8 kHz | Bell | Sibilance peak | set |
| 11 kHz | Bell | Upper treble peak | set |
| 14 kHz | High shelf | Air | 0, handle only |

Rejected during review and deliberately absent from every tier:

- A 300 Hz "mud" cut. The graph shows a dip at 350 to 500 Hz. Cutting 300 Hz deepens it.
- A 5 kHz "grain" cut. Reviewer grain is driver distortion, not a response peak. 5 kHz is part of the ear-gain region this set already lacks, so cutting it makes it duller without fixing the texture.
- A small air shelf at 14 kHz. Its transition band starts near 10 kHz and partly undoes the 11 kHz cut. Ear canal resonance makes anything above 12 kHz unpredictable per person. The L3 tier keeps a 1.5 to 2 dB version as an explicit experiment.
- A 2 kHz boost in the game profiles. More 2 kHz means more shout on a set that already has it.

## Use cases

| Profile | Intent |
|---|---|
| Music | Neutral target. Fills the 3 kHz dip, cuts 8 kHz and 11 kHz, trims sub-bass toward Harman. |
| Game-Tactical | Flat-map shooters: CS2, Valorant, Siege, PUBG, Dead by Daylight. Less sub-bass and low-mid mud for footsteps, presence lift at 3 to 5 kHz, lighter 8 kHz cut so transient snap survives. |
| Game-Arena | Multi-level and hero shooters: Overwatch, Marvel Rivals, The Finals, Arc Raiders, Apex, Fortnite. Same bass and mids as Tactical, no 5 kHz lift, wider and smoother 6 to 12 kHz. |
| Movies | Film and story games. More sub-bass rumble, dialog lift near 3 kHz, harder sibilance cut around 7.5 kHz. |
| Bass | EDM and hip-hop. Big sub-bass shelf with mid-bass kept clean, mild presence lift, same treble fixes. |
| Music-Crossfeed | Linux only. The Music preset of the same tier with the crossfeed plugin after the equalizer, Chu Moy values (700 Hz, 6 dB). For recordings with hard left-right panning. See below. |

### Why a crossfeed variant, and why only for music

On an IEM, an instrument panned fully to one side reaches one ear and not
the other. Speakers never do that: both ears hear both channels, the far
one a little later and with less treble. Crossfeed recreates that by
feeding a low-passed, delayed copy of each channel into the other. It is
the one improvement for IEMs that no equalizer filter can make, which is
why it gets its own preset instead of a band in the table.

It is a music setting. The left-right level and timing differences it
softens are exactly the cues the game profiles rely on, so it is never
combined with them. Movies are mixed for speakers too and would also
qualify; add `"Movies"` to `CROSSFEED_PROFILES` in `EQ.py` if you want
that variant.

Chu Moy (700 Hz, 6 dB) is the middle of the three classic settings and the
one to start with. Jan Meier (650 Hz, 9.5 dB) is stronger and narrows the
stage noticeably; the default (700 Hz, 4.5 dB) is barely audible. The
plugin compensates its own level, so the preamp is the same as the Music
preset it is built from.

Equalizer APO has no crossfeed, so these presets exist only in `linux/`.

Other Easy Effects plugins were tried and rejected for this set: a
de-esser at 8 kHz (the static 8 kHz cut already is the correction, and a
de-esser makes treble level depend on the music), a bass enhancer (adds
harmonics to a driver that already has too much sub-bass and whose weak
point is distortion), and a 16 kHz low-pass meant to block jack noise
(noise from the motherboard enters after the DAC, where no digital filter
can reach it; mute unused capture paths in alsamixer or use a USB dongle
instead).

### Why two gaming profiles

Left-right position comes from level and timing differences between your
ears. Any stereo IEM delivers those, so flat-map shooters work fine on this
set and reward footstep snap. That is Game-Tactical.

Above and below has no left-right difference to lean on. The game
synthesises those cues as small spectral notches between about 5 and
12 kHz using a generic HRTF. This set's own peaks at 8 kHz and 10 to
12 kHz sit on top of that band and smear the cues. Game-Arena removes the
5 kHz lift and uses wider, deeper cuts so the IEM adds as little spectral
shape of its own as possible. Expect it to sound slightly less snappy than
Tactical. The vertical improvement is partial: EQ cannot add driver
resolution or correct the generic HRTF for your ears. Make sure the game's
own HRTF option is on, and do not stack Windows Sonic or Atmos on top of it.

## What the filters are correcting

From one B&K 5128 measurement read by eye, plus the consensus of the
published reviews:

| Region | Observation | Fix used |
|---|---|---|
| 20 to 80 Hz | Sub-bass 5 to 6 dB above JM-1 target | Low shelf cut at 105 Hz (Music, Gaming); left or boosted for Movies and Bass |
| 350 to 500 Hz | Small lower-mid dip | +1 to +1.5 dB bell at 420 Hz (L2, L3) |
| 1 to 2.5 kHz | On target but heard as shouty | -1 to -1.5 dB bell at 1.8 to 2 kHz (L2, L3) |
| About 3 kHz | 3 to 4 dB below target | +2 to +4 dB bell at 2.8 to 3.2 kHz |
| About 8 kHz | Elevated, grain and sibilance | -1.5 to -4.5 dB bell, Q 2 to 2.5 |
| 10 to 12 kHz | Peak | -2 to -4 dB bell at 11 kHz |
| Above 15 kHz | Steep roll-off | +1.5 to +2 dB high shelf at 14 kHz (L3 only) |

Preamp is computed by summing every filter's response across 20 Hz to 20 kHz
and offsetting the peak, rounded up to the next 0.5 dB. Nothing clips.

## Install on Windows (Equalizer APO + Peace)

1. Open Peace.
2. Click Import (bottom left, or in the Settings menu depending on version).
3. Pick "Equalizer APO configuration file" and choose a `.txt` from `windows/`.
4. Peace loads preamp and filters into its sliders. Save it as a Peace preset with a name you recognise.
5. Repeat for each file you want to compare, then switch between them in Peace's preset list.

Without Peace you can copy a file's contents straight into Equalizer APO's
`config\config.txt` or reference it with an `Include:` line. Equalizer APO
reloads on save.

## Install on Linux (Easy Effects)

Easy Effects does not ship an equalizer of its own. It loads the one from the
LSP plugin suite, and on Arch that package is only an optional dependency.
Without it the equalizer tab says "cannot be used because Linux Studio
Plugins is not installed". Install it once, then quit and restart Easy
Effects including its background service:

```bash
sudo pacman -S --needed lsp-plugins-lv2
```

The Flatpak build bundles the plugins and needs nothing extra.

1. Copy the `.json` files you want into `~/.config/easyeffects/output/`.
   Flatpak install: `~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output/`.
2. Open Easy Effects, Presets menu, the names appear in the Output list. Click one to load it.
3. Switch presets from the same menu to compare.
4. The `-Crossfeed` presets load two plugins, equalizer then crossfeed. Loading any other preset removes the crossfeed again, so the game profiles stay clean.

The JSON uses the plugin key `equalizer#0`, which is the Easy Effects 7.x
format. On Easy Effects 6.x rename that key and the entry in `plugins_order`
to `equalizer`.

Easy Effects can also import the Windows `.txt` files directly from the
equalizer plugin's import button, which is useful if you tweak a preset in
Peace and want it on Linux.

## How to judge them

1. Start with L1 Music against stock. Toggle on and off at the same volume. Louder always sounds better, so adjust volume until the two feel equally loud before deciding.
2. If L1 is an improvement, move to L2 Music. If L2 sounds thin or dull in the treble, the 8 kHz and 11 kHz cuts are landing on the wrong frequency for your ears. See the next section.
3. Try L3 last, and only after L2. If L3 Music sounds right, your unit matches the published graph closely.
4. Judge Game-Tactical on footsteps in a quiet lobby then a loud firefight, Game-Arena on whether an enemy above or below you is readable, Movies on a dialog-heavy scene followed by an action scene, Bass on a track with sustained sub-bass.
5. Take breaks. Ears adapt within minutes.

## Finding your real treble peaks

The 8 kHz and 11 kHz cuts are the least certain filters in every preset.
Measurement rigs disagree with real ears above 8 kHz, and a cut in the wrong
place is worse than no cut.

1. Play a slow sine sweep from 5 kHz to 13 kHz at low volume. Any online tone generator works.
2. Note the frequencies where the tone jumps in loudness or turns piercing.
3. Open `EQ.py`, change the 8000 and 11000 values to what you heard, run the script, and both folders regenerate.

If you cannot hear any jump, the peaks are not a problem for you. Lower the
treble cuts to L1 values or remove them.

## Things EQ cannot fix on this set

- Grain and texture in the treble. That is driver behaviour, not frequency response.
- Resolution and separation on busy tracks.
- Air above 15 kHz. The L3 shelf tries, but a cheap dynamic driver boosted up there mostly adds distortion.
- Seal variance. Tip rolling matters more than any filter here. Get a seal first, then EQ.

## Using the script for another IEM

Find a measurement on Squig.link or a review graph, write down where it
departs from the target you like, and express each departure as one filter
in the `PROFILES` table: type, centre frequency, gain, Q. Run `EQ.py` and
both folders regenerate with the preamp recomputed. Keep the first tier
gentle and wide; narrow, deep cuts only pay off once you have confirmed the
peak frequency with the sine sweep above.
