#!/bin/bash

# --- 0. SELF-INSTALLATION / UNINSTALLATION LOGIC ---
DESKTOP_NAME="run-proton.desktop"
DESKTOP_FILE="$HOME/.local/share/applications/$DESKTOP_NAME"

# UNINSTALL BLOCK
if [[ "$1" == "--uninstall" ]]; then
    echo "Reverting installation..."

    # 1. Remove the desktop entry
    if [ -f "$DESKTOP_FILE" ]; then
        rm "$DESKTOP_FILE"
        echo "Removed: $DESKTOP_FILE"
    fi

    # 2. Reset MIME associations (optional but clean)
    # We don't necessarily set a new default, as the system will
    # automatically fallback to the next available handler once this one is gone.
    update-desktop-database "$HOME/.local/share/applications"

    echo "Uninstallation complete. .exe files will revert to system defaults."
    exit 0
fi

# INSTALL BLOCK
if [[ "$1" == "--install" ]] || [[ -z "$1" && -t 0 ]]; then
    SCRIPT_PATH=$(realpath "$0")

    echo "Registering script as default .exe handler..."

    mkdir -p "$(dirname "$DESKTOP_FILE")"
    cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Proton Runner
Comment=Run Windows EXEs via GE-Proton
Exec="$SCRIPT_PATH" %f
Icon=steam
Terminal=false
Categories=Game;
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/x-executable;
EOF

    chmod +x "$DESKTOP_FILE"
    xdg-mime default "$DESKTOP_NAME" application/x-ms-dos-executable
    xdg-mime default "$DESKTOP_NAME" application/x-msdownload
    update-desktop-database "$HOME/.local/share/applications"

    echo "Installation complete! You can now double-click .exe files."
    exit 0
fi

# 1. Paths to Proton and the Steam Linux Runtime (SLR)
PROTON_PATH="$HOME/.steam/steam/compatibilitytools.d/GE-Proton10-29"
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

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-exe> OR <wine-command>"
    echo "Flags: --install, --uninstall"
    exit 1
fi

# --- SMART PATH HANDLING ---
if [ -f "$1" ]; then
    EXE_PATH=$(realpath "$1")
    EXE_DIR=$(dirname "$EXE_PATH")
    cd "$EXE_DIR" || exit

    shift
    SET_ARGS=("$EXE_PATH" "$@")
else
    SET_ARGS=("$@")
fi

# 5. Execute via the Runtime Entry Point
if [ -d "$RUNTIME_BASE" ]; then
    "$RUNTIME_BASE/run-in-sniper" -- "$PROTON_PATH/proton" run "${SET_ARGS[@]}"
else
    echo "Warning: Steam Runtime not found at $RUNTIME_BASE. Attempting direct execution..."
    "$PROTON_PATH/proton" run "${SET_ARGS[@]}"
fi
