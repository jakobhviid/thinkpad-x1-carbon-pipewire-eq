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

### Step 1: Clone the repo

```bash
git clone https://github.com/jakobhviid/thinkpad-x1-carbon-pipewire-eq.git
cd thinkpad-x1-carbon-pipewire-eq
```

### Step 2: Run the installer

```bash
./install.sh
```

The installer will:
1. Check that PipeWire is running
2. Auto-detect your internal speaker sink (so it works on different ThinkPad models)
3. Install the EQ config to `~/.config/pipewire/pipewire.conf.d/speaker-eq.conf`
4. Restart PipeWire
5. Set the new output as your default

If auto-detection fails, it will list your available audio outputs and ask you to pick one.

### Step 3: Select the new audio output

The EQ works by creating a **new virtual audio device** called **"Internal Speakers"**. This device routes your audio through the EQ filters before sending it to the physical speakers.

After installation, **"Internal Speakers"** should already be selected as your default output. If it isn't, open your system **Sound Settings** (GNOME Settings > Sound, or click the speaker icon in the top bar) and select **"Internal Speakers"** from the output list.

> **Important:** You should always use **"Internal Speakers"** as your output when using the laptop speakers. The original speaker output (usually named something like "Lunar Lake-M HD Audio Controller Speaker") still exists but bypasses the EQ -- if you select it, you'll hear the original thin sound.

### Step 4: Play some audio

It should sound noticeably fuller, warmer, and louder. The difference is immediate.

### Manual installation

If you prefer not to use the install script:

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d
cp speaker-eq.conf ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

> **Note:** If you're not on a ThinkPad X1 Carbon Gen 13, you may need to edit the `node.target` line in the config to match your speaker sink name. Run `pactl list short sinks` to find it.

## Uninstall

```bash
./uninstall.sh
```

Or manually:

```bash
rm ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

This removes the virtual "Internal Speakers" device and restores the default audio output.

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

A Python script (`speaker-calibrate.py`) is included that can measure your speaker's frequency response. This is optional -- you don't need it to use the EQ config above. It's useful if you want to:

- Verify how the EQ is performing on your machine
- Create a custom EQ profile for a different laptop model
- Fine-tune the existing profile to your preference

### How it works

The script measures what your speakers actually sound like by playing a test signal and recording what comes back through the microphone:

1. **Generates a test signal** -- a logarithmic sine sweep from 50 Hz to 20 kHz (3 seconds long). This covers the full audible range, spending more time on the low frequencies where laptop speakers are weakest.

2. **Plays through the speakers** -- the sweep is played via PulseAudio/PipeWire so it passes through any active EQ filter chain. This means you can measure the "before" (without EQ installed) and "after" (with EQ installed) to see the difference.

3. **Records through the built-in DMIC** -- simultaneously captures what the speakers are producing. The digital microphone is built into the laptop chassis, so the recording reflects what the speakers actually output.

4. **Analyzes the frequency response** -- uses Welch's method (power spectral density estimation) to compare the recorded signal against the original. The result shows how loud each frequency is relative to the others -- revealing where the speakers are weak (bass) and where they resonate (mids).

5. **Displays an ASCII chart** -- shows the response at key frequencies so you can see the shape at a glance. Multiple passes can be averaged for more reliable results.

6. **Optionally auto-generates EQ** -- in calibration mode (without `--measure-only`), it designs parametric EQ bands to correct toward a target curve and writes a PipeWire filter-chain config. However, the hand-tuned config in this repo generally sounds better than the auto-generated one, because the built-in mic has limitations (see below).

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
- The typical laptop pattern: weak bass, a peak around 500-1000 Hz, then the DMIC drops off
- The 500-2000 Hz range is used as the normalization reference
- Readings above ~1.5 kHz are unreliable due to the DMIC's limited high-frequency sensitivity -- ignore them

### Creating a profile for a different laptop

If you have a different ThinkPad (or any laptop), you can use the calibration tool to understand your speakers and build a custom EQ:

1. **Set up the script for your hardware.** Edit the two device name variables at the top of `speaker-calibrate.py`:

   ```python
   SPEAKER_SINK = "alsa_output.pci-..."  # your speaker sink
   MIC_SOURCE = "alsa_input.pci-..."     # your built-in mic
   ```

   Find your sink name with `pactl list short sinks` and your source name with `pactl list short sources`.

2. **Measure without any EQ installed** to see the raw speaker response:

   ```bash
   # Remove any existing EQ first
   rm -f ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
   systemctl --user restart pipewire pipewire-pulse

   # Run measurement
   python3 speaker-calibrate.py --measure-only --iterations 5
   ```

3. **Read the chart and identify problems.** Common patterns:
   - **Deep dip at low frequencies (63-250 Hz)** -- the speakers need bass boost. Add a `bq_lowshelf` with positive gain.
   - **A peak at a specific frequency** -- this is a resonance. Add a `bq_peaking` filter at that frequency with negative gain to cut it. On the X1 Carbon Gen 13, this was at 700 Hz.
   - **Everything is too quiet** -- add preamp stages (see the existing config for the shelf filter trick).

4. **Start with the existing `speaker-eq.conf` and modify it.** Copy the file, adjust the frequency and gain values based on your measurements, install it, and re-measure to see if it improved:

   ```bash
   # Edit the config
   nano speaker-eq.conf

   # Install and test
   ./install.sh

   # Measure again to see the effect
   python3 speaker-calibrate.py --measure-only --iterations 3
   ```

5. **Iterate.** Adjust, reinstall, re-measure. Focus on the frequencies below 1.5 kHz where the DMIC gives reliable readings. For higher frequencies, trust your ears.

### Limitations

- The built-in DMIC has very limited high-frequency sensitivity -- readings above ~1.5 kHz are unreliable and should not be used for tuning decisions. Use your ears for the upper range.
- The measurement is affected by room acoustics and background noise. Keep the room quiet and avoid running the test near hard reflective surfaces.
- The auto-calibrate mode tends to overcorrect because it trusts the unreliable high-frequency DMIC readings. The `--measure-only` mode combined with manual tuning produces much better results.

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
