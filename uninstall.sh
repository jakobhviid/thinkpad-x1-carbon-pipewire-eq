#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/pipewire/pipewire.conf.d/speaker-eq.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    rm "$CONFIG_FILE"
    systemctl --user restart pipewire 2>/dev/null || true
    systemctl --user restart pipewire-pulse 2>/dev/null || true
    echo "Speaker EQ removed. Default audio restored."
else
    echo "No speaker EQ config found at $CONFIG_FILE"
fi
