#!/bin/bash

# 1. Paths to Proton and the Steam Linux Runtime (SLR)
# Adjust 'sniper' to 'soldier' or 'medic' if using much older Proton versions
PROTON_PATH="/home/deck/.steam/steam/compatibilitytools.d/GE-Proton9-27"
RUNTIME_PATH="$HOME/.steam/steam/steamapps/common/SteamLinuxRuntime_sniper"

# 2. Path to the Wine prefix
PREFIX_PATH="$(pwd)/pfx"
mkdir -p "$PREFIX_PATH"

# 3. Environment Variables
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH="$PREFIX_PATH"
export PROTON_VERB="run"

# 4. Steam Runtime Integration
# This tells Proton where the containerized runtime lives
export PRESSURE_VESSEL_RUNTIME_ARCHIVE="$RUNTIME_PATH/sniper_platform_0.20241118.110034/files"

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-exe>"
    exit 1
fi

# 5. Execute via the Runtime Entry Point
# Running through 'run-in-sniper' ensures all shared libraries are present
if [ -d "$RUNTIME_PATH" ]; then
    "$RUNTIME_PATH/run-in-sniper" -- "$PROTON_PATH/proton" run "$@"
else
    echo "Warning: Steam Runtime not found at $RUNTIME_PATH. Attempting direct execution..."
    "$PROTON_PATH/proton" run "$@"
fi
