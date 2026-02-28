#!/bin/bash

# 1. Paths to Proton and the Steam Linux Runtime (SLR)
PROTON_PATH="/home/deck/.steam/steam/compatibilitytools.d/GE-Proton10-29"
RUNTIME_BASE="$HOME/.steam/steam/steamapps/common/SteamLinuxRuntime_sniper"

# 2. Path to the Wine prefix (Fixed shared location in /home/deck)
PREFIX_PATH="$HOME/sharedprotonprefix"
mkdir -p "$PREFIX_PATH"

# 3. Environment Variables
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH="$PREFIX_PATH"
export PROTON_VERB="run"
# Disables the Steam client integration for non-Steam apps/standalone use
export PROTON_DISABLE_LSTEAMCLIENT=1

# 4. Steam Runtime Integration (Auto-detect versioned folder)
SNIPER_PLATFORM=$(ls -d "$RUNTIME_BASE"/sniper_platform_* 2>/dev/null | tail -n 1)
export PRESSURE_VESSEL_RUNTIME_ARCHIVE="$SNIPER_PLATFORM/files"

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-exe>"
    exit 1
fi

# --- FIX FOR SHORTCUTS/LINKS ---
# Get the absolute path of the EXE and its parent directory
EXE_PATH=$(realpath "$1")
EXE_DIR=$(dirname "$EXE_PATH")

# Change the working directory to the folder containing the EXE
# This allows the game to find its local DLLs and data files.
cd "$EXE_DIR" || exit
# -------------------------------

# 5. Execute via the Runtime Entry Point
if [ -d "$RUNTIME_BASE" ]; then
    # We use "$EXE_PATH" to ensure the full path is passed to Proton
    "$RUNTIME_BASE/run-in-sniper" -- "$PROTON_PATH/proton" run "$EXE_PATH"
else
    echo "Warning: Steam Runtime not found at $RUNTIME_BASE. Attempting direct execution..."
    "$PROTON_PATH/proton" run "$EXE_PATH"
fi
