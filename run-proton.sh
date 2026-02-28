#!/bin/bash

# 1. Paths to Proton and the Steam Linux Runtime (SLR)
PROTON_PATH="/home/deck/.steam/steam/compatibilitytools.d/GE-Proton10-29"
RUNTIME_BASE="$HOME/.steam/steam/steamapps/common/SteamLinuxRuntime_sniper"

# 2. Path to the Wine prefix
PREFIX_PATH="$HOME/sharedprotonprefix"
mkdir -p "$PREFIX_PATH"

# 3. Environment Variables
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH="$PREFIX_PATH"
export PROTON_VERB="run"
export PROTON_DISABLE_LSTEAMCLIENT=1

# 4. Steam Runtime Integration
SNIPER_PLATFORM=$(ls -d "$RUNTIME_BASE"/sniper_platform_* 2>/dev/null | tail -n 1)
export PRESSURE_VESSEL_RUNTIME_ARCHIVE="$SNIPER_PLATFORM/files"

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-exe> OR <wine-command>"
    exit 1
fi

# --- SMART PATH HANDLING ---
# If the first argument is a file that exists, we handle the directory change.
if [ -f "$1" ]; then
    EXE_PATH=$(realpath "$1")
    EXE_DIR=$(dirname "$EXE_PATH")
    cd "$EXE_DIR" || exit

    # Re-build the arguments so the first one is the full path
    # and any following arguments (like --fullscreen) are preserved.
    shift # Remove the original $1
    SET_ARGS=("$EXE_PATH" "$@")
else
    # If it's not a file (like 'winecfg'), just use all arguments as-is.
    SET_ARGS=("$@")
fi
# ---------------------------

# 5. Execute via the Runtime Entry Point
if [ -d "$RUNTIME_BASE" ]; then
    "$RUNTIME_BASE/run-in-sniper" -- "$PROTON_PATH/proton" run "${SET_ARGS[@]}"
else
    echo "Warning: Steam Runtime not found at $RUNTIME_BASE. Attempting direct execution..."
    "$PROTON_PATH/proton" run "${SET_ARGS[@]}"
fi
