# ThinkPad X1 Carbon PipeWire Speaker EQ

**Does your ThinkPad X1 Carbon sound thin, tinny, or hollow on Linux?** This is a known issue. On Windows, Lenovo includes Dolby Audio software that tunes the speakers to sound good. On Linux, that software doesn't exist, so the speakers run with flat/generic settings that sound significantly worse.

This project provides a simple config file that fixes this. No extra software to install -- it uses PipeWire's built-in audio processing, which is already running on your system.

## Before and after

Without this fix, the speakers have:
- Almost no bass
- A harsh, "tin can" resonance around 700 Hz
- Low overall volume compared to Windows

With this fix applied, the speakers sound fuller, warmer, and louder -- much closer to how they sound on Windows.

## Installation

### Step 1: Download the config file

Clone this repo or just download `speaker-eq.conf`:

```bash
git clone https://github.com/jakobhviid/thinkpad-x1-carbon-pipewire-eq.git
cd thinkpad-x1-carbon-pipewire-eq
```

### Step 2: Copy it to the right place

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d
cp speaker-eq.conf ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
```

### Step 3: Restart PipeWire

```bash
systemctl --user restart pipewire pipewire-pulse
```

### Step 4: Select the output

Open your system **Sound Settings** (GNOME Settings > Sound, or click the volume icon in the top bar). You should see a new output called **"Internal Speakers"**. Select it.

Alternatively, from the terminal:

```bash
# Find the node number (look for "effect_input.speaker_eq")
wpctl status

# Set it as default (replace 42 with the actual number from above)
wpctl set-default 42
```

### Step 5: Verify it's working

Play some audio. It should sound noticeably fuller and louder. You can verify the filter is loaded:

```bash
pactl list sinks | grep -A2 effect_input
```

You should see:

```
Name: effect_input.speaker_eq
Description: Internal Speakers
Driver: PipeWire
```

## Uninstall

To remove the EQ and go back to the default sound:

```bash
rm ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

## Adjusting the EQ

If the default settings aren't quite right for you, the config file is plain text and easy to edit. Open `~/.config/pipewire/pipewire.conf.d/speaker-eq.conf` in any text editor, change the `Gain` values, and restart PipeWire:

```bash
systemctl --user restart pipewire pipewire-pulse
```

Common adjustments:

| Problem | What to change | Where in the file |
|---------|---------------|-------------------|
| Too quiet | Increase `Gain` on `preamp1`/`preamp2`/`preamp3` | Top of the file (each is +8 dB, add more stages or increase) |
| Too boomy / muddy | Reduce `Gain` on `eq_band1` (currently +10) | Low shelf at 250 Hz |
| Still tinny | Make `Gain` on `eq_band4` more negative (currently -4) | Peaking at 700 Hz |
| Voices sound thin | Increase `Gain` on `eq_band3` (currently +3) | Peaking at 250 Hz |
| Too harsh | Make `Gain` on `eq_band6` more negative (currently -3) | Peaking at 2500 Hz |

## What the EQ does

The config applies 10 audio filters in a chain:

| Filter | Type | Frequency | Gain | Purpose |
|--------|------|-----------|------|---------|
| Preamp 1-3 | Shelf filters | Full range | +8 dB each | Overall volume boost (+24 dB total) |
| Band 1 | Low shelf | 250 Hz | +10 dB | Bass boost (speakers are 17 dB weak here) |
| Band 2 | Peaking | 120 Hz | +6 dB | Extra bass at the weakest point |
| Band 3 | Peaking | 250 Hz | +3 dB | Fill the gap between bass and mids |
| Band 4 | Peaking | 700 Hz | -4 dB | Cut the "tin can" resonance |
| Band 5 | Peaking | 1000 Hz | -2 dB | Tame the loudest frequency |
| Band 6 | Peaking | 2500 Hz | -3 dB | Reduce harshness |
| Band 7 | High shelf | 8000 Hz | -2 dB | Gentle treble rolloff |

## How it was created

The EQ was calibrated by playing frequency sweeps through the speakers and recording them with the built-in microphone, then analyzing the frequency response. Several rounds of measurement and adjustment were done to arrive at the current settings. See the [Calibration tool](#calibration-tool) section below if you want to measure your own speakers.

## Compatibility

**Tested on:**
- ThinkPad X1 Carbon Gen 13 (Type 21NS), Intel Core Ultra 7 258V (Lunar Lake)
- Fedora 44, PipeWire 1.6.3, Kernel 6.19.12

**Should also work on:**
- ThinkPad X1 Carbon Gen 12 (similar speaker hardware)
- Other thin Lenovo laptops with RT1318 speaker amplifiers
- Any Linux distro using PipeWire (Fedora, Ubuntu 22.10+, Arch, etc.)

**Requirements:**
- PipeWire as your audio server (this is the default on most modern distros)
- WirePlumber (usually installed with PipeWire)

To check if you're running PipeWire:

```bash
pactl info | grep "Server Name"
# Should show: Server Name: PulseAudio (on PipeWire x.y.z)
```

---

## Calibration tool

A Python script (`speaker-calibrate.py`) is included that can measure your speaker's frequency response. This is optional -- you don't need it to use the EQ config above.

### What it does

1. Generates a sine sweep (50 Hz - 20 kHz)
2. Plays it through the speakers
3. Records through the built-in DMIC
4. Computes and displays the frequency response
5. Optionally auto-generates a new EQ config (not recommended -- the hand-tuned config above is better)

### Prerequisites

```bash
# Fedora
sudo dnf install -y python3-numpy python3-scipy

# Ubuntu/Debian
sudo apt install -y python3-numpy python3-scipy

# Arch
sudo pacman -S python-numpy python-scipy
```

You also need `paplay`, `parecord`, and `pactl`, which are included with PipeWire on most distros.

### Usage

**Measure only (recommended)** -- shows the frequency response without changing anything:

```bash
python3 speaker-calibrate.py --measure-only
```

For more accurate results, run multiple passes:

```bash
python3 speaker-calibrate.py --measure-only --iterations 5
```

**Auto-calibrate (use with caution)** -- overwrites your EQ config:

```bash
# Back up your current config first!
cp ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf ~/speaker-eq-backup.conf

python3 speaker-calibrate.py
```

If auto-calibration makes things worse, restore your backup:

```bash
cp ~/speaker-eq-backup.conf ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

### Interpreting the output

```
   63 Hz:  -19.0 dB  █
  125 Hz:  -28.7 dB  
  250 Hz:  -17.1 dB  ██
  500 Hz:  -12.6 dB  ███████
 1000 Hz:   -7.7 dB  ████████████
 2000 Hz:  -46.4 dB               (unreliable -- DMIC limitation)
```

- All values are relative -- the absolute numbers don't matter, only the shape
- A flat line would mean all frequencies are equally loud
- The DMIC can't reliably measure above ~1.5 kHz, so ignore those readings
- The 500-2000 Hz range is used as the reference point

### Limitations

- The built-in DMIC has very limited high-frequency sensitivity -- readings above ~1.5 kHz are unreliable
- Background noise and room acoustics affect the measurement -- keep the room quiet
- The hardcoded ALSA device names are specific to the X1 Carbon Gen 13 -- other machines will need to edit the `SPEAKER_SINK` and `MIC_SOURCE` variables at the top of the script

---

## Contributing

If you have a ThinkPad model that isn't covered and want to contribute a tuned config:

1. Install the calibration tool prerequisites
2. Run `python3 speaker-calibrate.py --measure-only --iterations 5` and save the output
3. Tune the EQ for your speakers (start with the existing config and adjust)
4. Submit a PR with your config and measurement data

## Related projects

- [linux-thinkpad-speaker-improvements](https://github.com/shuhaowu/linux-thinkpad-speaker-improvements) -- EasyEffects convolver with IRS files for various ThinkPad models
- [gpd-pocket-4-pipewire](https://github.com/Manawyrm/gpd-pocket-4-pipewire) -- Similar PipeWire DSP approach for GPD Pocket 4
- [EasyEffects](https://github.com/wwmm/easyeffects) -- GUI-based audio effects for PipeWire

## License

MIT
