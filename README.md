# ThinkPad X1 Carbon PipeWire Speaker EQ

PipeWire filter-chain EQ configuration that fixes the thin, tinny, hollow speaker sound on the Lenovo ThinkPad X1 Carbon Gen 13 running Linux.

On Windows, Lenovo ships Dolby Audio DSP that applies bass enhancement, speaker EQ calibration, and dynamic range compression tuned to the specific chassis. None of this exists on Linux -- the SOF (Sound Open Firmware) topology loads with flat/default EQ coefficients, making the speakers sound significantly worse than on Windows.

This project provides a drop-in PipeWire config that compensates for this, plus a calibration tool to measure and verify the results.

## The problem

The X1 Carbon Gen 13 uses a Realtek RT1318 SoundWire amplifier with an RT713 codec, driven by Intel SOF firmware. The loaded topology (`sof-lnl-rt713-l0-rt1318-l1-2ch.tplg`) includes IIR EQ, FIR EQ, and DRC filter stages, but they're loaded with generic passthrough coefficients.

The result:
- Very weak bass (17 dB below mids at 125 Hz)
- A resonance peak at 500-1000 Hz that creates a "tin can" sound
- Overall low volume compared to Windows

## What the EQ does

The config uses PipeWire's built-in `filter-chain` module with 10 biquad filter stages. No extra software needed -- it runs entirely within PipeWire.

| Stage | Type | Frequency | Gain | Purpose |
|-------|------|-----------|------|---------|
| Preamp 1 | Low shelf | 20 kHz | +8 dB | Volume boost |
| Preamp 2 | High shelf | 20 Hz | +8 dB | Volume boost |
| Preamp 3 | Low shelf | 20 kHz | +8 dB | Volume boost |
| Band 1 | Low shelf | 250 Hz | +10 dB | Bass boost (measured 17 dB deficit) |
| Band 2 | Peaking | 120 Hz | +6 dB | Sub-bass fill at weakest point |
| Band 3 | Peaking | 250 Hz | +3 dB | Low-mid gap fill |
| Band 4 | Peaking | 700 Hz | -4 dB | Cut "tin can" resonance |
| Band 5 | Peaking | 1000 Hz | -2 dB | Tame loudest frequency |
| Band 6 | Peaking | 2500 Hz | -3 dB | Reduce harshness |
| Band 7 | High shelf | 8000 Hz | -2 dB | Gentle high rolloff |

## How it was created

1. Initial measurement using the built-in DMIC with a logarithmic sine sweep (50 Hz - 20 kHz), analyzed with Welch's power spectral density method
2. Identified the 700 Hz resonance peak as the primary "tin can" culprit
3. Iterative tuning of EQ bands, re-measuring after each change with 3-pass averaged sweeps
4. Manual high-frequency tuning (the DMIC has limited sensitivity above ~1.5 kHz)
5. Volume calibration to match expected loudness levels

## Installation

### Quick install

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d
cp speaker-eq.conf ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

Then select **"Internal Speakers"** as your output device in your sound settings, or run:

```bash
# Find the node ID and set it as default
wpctl status | grep effect_input.speaker_eq
wpctl set-default <node_id>
```

### Verify it's working

```bash
pactl list sinks | grep -A2 effect_input
```

You should see:
```
Name: effect_input.speaker_eq
Description: Internal Speakers
Driver: PipeWire
```

### Uninstall

```bash
rm ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

## Calibration tool

A Python script is included to measure the current speaker frequency response using the built-in DMIC. See [speaker-calibrate.md](speaker-calibrate.md) for full documentation.

### Quick usage

```bash
# Prerequisites (Fedora)
sudo dnf install -y python3-numpy python3-scipy pipewire-utils

# Measure current response without changing anything
python3 speaker-calibrate.py --measure-only

# Measure with 5 passes for better accuracy
python3 speaker-calibrate.py --measure-only --iterations 5
```

## Compatibility

**Tested on:**
- ThinkPad X1 Carbon Gen 13 (Type 21NS), Intel Core Ultra 7 258V (Lunar Lake)
- Fedora 44 with PipeWire 1.6.3
- Kernel 6.19.12
- SOF firmware: alsa-sof-firmware 2025.12.2
- Topology: `sof-lnl-rt713-l0-rt1318-l1-2ch.tplg`

**Should also work on:**
- ThinkPad X1 Carbon Gen 12 (similar speaker hardware, different SoC)
- Other thin Lenovo laptops with RT1318 speaker amplifiers
- Any Linux distro using PipeWire as the audio server

**Requirements:**
- PipeWire (with `libpipewire-module-filter-chain`)
- WirePlumber (for `wpctl`)
- PulseAudio compatibility layer (`pactl`, `paplay`, `parecord`)

## Adjusting the EQ

The config file is plain text. Edit `~/.config/pipewire/pipewire.conf.d/speaker-eq.conf` and restart PipeWire:

```bash
systemctl --user restart pipewire pipewire-pulse
```

Common adjustments:
- **Too quiet?** Increase `Gain` on the preamp stages (each +1 dB is a noticeable bump)
- **Too boomy?** Reduce `Gain` on eq_band1 (low shelf at 250 Hz)
- **Still tinny?** Increase the negative `Gain` on eq_band4 (700 Hz cut)
- **Voices sound thin?** Increase `Gain` on eq_band3 (250 Hz peaking)

## Contributing

If you have a different ThinkPad model and want to contribute a tuned config:

1. Install the calibration tool prerequisites
2. Run `python3 speaker-calibrate.py --measure-only --iterations 5` and save the output
3. Tune the EQ for your speakers
4. Submit a PR with your config and measurement data

## Related projects

- [linux-thinkpad-speaker-improvements](https://github.com/shuhaowu/linux-thinkpad-speaker-improvements) -- EasyEffects convolver approach with IRS files for various ThinkPad models
- [gpd-pocket-4-pipewire](https://github.com/Manawyrm/gpd-pocket-4-pipewire) -- Similar PipeWire DSP approach for GPD Pocket 4
- [EasyEffects](https://github.com/wwmm/easyeffects) -- GUI-based audio effects for PipeWire (heavier alternative)

## License

MIT
