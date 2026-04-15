#!/usr/bin/env bash
set -euo pipefail

# Speaker EQ installer for ThinkPad laptops
# Auto-detects the internal speaker sink and installs the PipeWire filter-chain config.

CONFIG_DIR="$HOME/.config/pipewire/pipewire.conf.d"
CONFIG_FILE="$CONFIG_DIR/speaker-eq.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/speaker-eq.conf"

info()  { printf '\033[1;34m>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m>\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m>\033[0m %s\n' "$*" >&2; }

# ── Check source file exists ────────────────────────────────────────────────

if [[ ! -f "$SOURCE_FILE" ]]; then
    err "speaker-eq.conf not found at $SOURCE_FILE"
    err "Make sure you're running this from the repo directory."
    exit 1
fi

# ── Check PipeWire ──────────────────────────────────────────────────────────

if ! pactl info 2>/dev/null | grep -q "PipeWire"; then
    err "PipeWire is not running. This config only works with PipeWire."
    err "Check with: pactl info | grep 'Server Name'"
    exit 1
fi

# ── Detect speaker sink ─────────────────────────────────────────────────────

info "Detecting internal speaker sink..."

# Look for the built-in speaker sink (not HDMI, not USB, not Bluetooth, not network)
speaker_sink=""
while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $2}')
    # Match common internal speaker sink patterns
    if echo "$name" | grep -qiE 'speaker.*sink$' && \
       ! echo "$name" | grep -qiE 'hdmi|usb|bluez|bluetooth|raop'; then
        speaker_sink="$name"
        break
    fi
done < <(pactl list short sinks 2>/dev/null)

# Fallback: look for any SOF/HDA analog output
if [[ -z "$speaker_sink" ]]; then
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $2}')
        if echo "$name" | grep -qiE '(sof|hda|analog)' && \
           echo "$name" | grep -qiE 'output|playback|sink' && \
           ! echo "$name" | grep -qiE 'hdmi|usb|bluez|bluetooth|raop|monitor'; then
            speaker_sink="$name"
            break
        fi
    done < <(pactl list short sinks 2>/dev/null)
fi

if [[ -z "$speaker_sink" ]]; then
    err "Could not auto-detect internal speaker sink."
    echo ""
    echo "Available sinks:"
    pactl list short sinks 2>/dev/null | awk '{print "  " $2}'
    echo ""
    read -rp "Enter the speaker sink name from the list above: " speaker_sink
    if [[ -z "$speaker_sink" ]]; then
        err "No sink specified. Aborting."
        exit 1
    fi
fi

ok "Found speaker sink: $speaker_sink"

# ── Volume boost ───────────────────────────────────────────────────────────

DEFAULT_BOOST=8
echo ""
info "Volume boost: each preamp stage adds gain to compensate for quiet laptop speakers."
echo "  The default is +${DEFAULT_BOOST} dB per stage (3 stages = +$((DEFAULT_BOOST * 3)) dB total)."
echo "  If your speakers are too quiet, increase this. If audio distorts, decrease it."
echo ""
read -rp "  Boost per stage in dB [${DEFAULT_BOOST}]: " boost_input
boost="${boost_input:-$DEFAULT_BOOST}"

# Validate it's a number
if ! [[ "$boost" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    err "Invalid number: $boost. Using default ${DEFAULT_BOOST} dB."
    boost="$DEFAULT_BOOST"
fi

total_boost=$(echo "$boost * 3" | bc)
ok "Volume boost: +${boost} dB per stage (+${total_boost} dB total)"

# ── Check for existing config ───────────────────────────────────────────────

if [[ -f "$CONFIG_FILE" ]]; then
    echo ""
    info "Existing speaker EQ config found at $CONFIG_FILE"
    read -rp "Overwrite? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Aborting."
        exit 0
    fi
fi

# ── Install ─────────────────────────────────────────────────────────────────

mkdir -p "$CONFIG_DIR"

# Copy config, substitute speaker sink and preamp gain values
sed -e "s|node.target = \".*\"|node.target = \"$speaker_sink\"|" \
    -e "s|# Preamp part 1: +.* dB across all frequencies|# Preamp part 1: +${boost} dB across all frequencies|" \
    -e "s|# Preamp part 2: +.* dB across all frequencies|# Preamp part 2: +${boost} dB across all frequencies|" \
    -e "s|# Preamp part 3: +.* dB more|# Preamp part 3: +${boost} dB more|" \
    "$SOURCE_FILE" | \
    awk -v boost="$boost" '
        /# Preamp part [123]/ { preamp=1 }
        preamp && /"Gain"/ { sub(/"Gain"  = [0-9.]+/, "\"Gain\"  = " boost); preamp=0 }
        { print }
    ' > "$CONFIG_FILE"

ok "Config installed to $CONFIG_FILE"

# ── Restart PipeWire ────────────────────────────────────────────────────────

info "Restarting PipeWire..."
systemctl --user restart pipewire 2>/dev/null || true
systemctl --user restart pipewire-pulse 2>/dev/null || true
sleep 2

# ── Set as default ──────────────────────────────────────────────────────────

# Extract node ID: match "  42. effect_input.speaker_eq" and pull the number before the dot
node_id=$(wpctl status 2>/dev/null | grep 'effect_input.speaker_eq' | head -1 | sed -n 's/.*\s\([0-9]\+\)\.\s*effect_input\.speaker_eq.*/\1/p')
if [[ -n "$node_id" ]]; then
    wpctl set-default "$node_id"
    ok "Speaker EQ active (output: Internal Speakers, node $node_id)"
else
    ok "Config loaded. Select 'Internal Speakers' in your sound settings."
fi

echo ""
echo "Done! Play some audio to hear the difference."
echo "Volume boost: +${total_boost} dB. To change, run ./install.sh again."
echo "To uninstall: $SCRIPT_DIR/uninstall.sh"
