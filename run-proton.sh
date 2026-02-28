#!/bin/bash

# 1. Paths to Proton and the Steam Linux Runtime (SLR)
PROTON_PATH="/home/deck/.steam/steam/compatibilitytools.d/GE-Proton9-27"
RUNTIME_BASE="$HOME/.steam/steam/steamapps/common/SteamLinuxRuntime_sniper"

# 2. Path to the Wine prefix (Fixed shared location in /home/deck)
# We use $HOME here. In Linux, this is the standard for /home/user
PREFIX_PATH="$HOME/sharedprotonprefix"
mkdir -p "$PREFIX_PATH"

# 3. Environment Variables
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH="$PREFIX_PATH"
export PROTON_VERB="run"

# 4. Steam Runtime Integration (Auto-detect versioned folder)
# This finds the "sniper_platform_..." folder automatically
SNIPER_PLATFORM=$(ls -d "$RUNTIME_BASE"/sniper_platform_* 2>/dev/null | tail -n 1)
export PRESSURE_VESSEL_RUNTIME_ARCHIVE="$SNIPER_PLATFORM/files"

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-exe>"
    exit 1
fi

# 5. Execute via the Runtime Entry Point
if [ -d "$RUNTIME_BASE" ]; then
    "$RUNTIME_BASE/run-in-sniper" -- "$PROTON_PATH/proton" run "$@"
else
    echo "Warning: Steam Runtime not found at $RUNTIME_BASE. Attempting direct execution..."
    "$PROTON_PATH/proton" run "$@"
fi
