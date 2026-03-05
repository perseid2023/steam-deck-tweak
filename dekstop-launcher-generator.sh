#!/usr/bin/env bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROTON="$SCRIPT_DIR/run-proton.sh"
APPDIR="$HOME/.local/share/applications"
PREFIX="generated-launcher"

mkdir -p "$APPDIR"

list_games() {
ls "$APPDIR"/$PREFIX-*.desktop 2>/dev/null | \
sed "s|$APPDIR/$PREFIX-||" | \
sed "s|\.desktop||"
}

add_game() {

FORM=$(zenity --forms \
--title="Desktop Launcher Generator" \
--add-entry="Proton Script / Wine Binary" \
--add-entry="Game Name" \
--add-entry="Game EXE")

[ $? -ne 0 ] && exit

IFS="|" read SCRIPT NAME EXE <<< "$FORM"

if [ -z "$SCRIPT" ] && [ -f "$DEFAULT_PROTON" ]; then
SCRIPT="$DEFAULT_PROTON"
fi

if [ -z "$SCRIPT" ] || [ -z "$NAME" ] || [ -z "$EXE" ]; then
zenity --error --text="All fields must be filled"
exit 1
fi

SAFE_NAME=$(echo "$NAME" | tr ' ' '-' | tr -cd '[:alnum:]-')
FILE="$APPDIR/$PREFIX-$SAFE_NAME.desktop"

cat > "$FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Exec="$SCRIPT" "$EXE"
Icon=steam
Terminal=false
Categories=Game;
EOF

chmod +x "$FILE"

zenity --info --text="Launcher created:

$FILE

Now open Steam → Add Non-Steam Game"
}

remove_game() {

LIST=$(list_games)

[ -z "$LIST" ] && zenity --info --text="No launchers found" && exit

SELECT=$(echo "$LIST" | zenity --list \
--title="Remove Launcher" \
--column="Game")

[ -z "$SELECT" ] && exit

FILE="$APPDIR/$PREFIX-$SELECT.desktop"

rm -f "$FILE"

zenity --info --text="Launcher removed"
}

edit_game() {

LIST=$(list_games)

[ -z "$LIST" ] && zenity --info --text="No launchers found" && exit

SELECT=$(echo "$LIST" | zenity --list \
--title="Edit Launcher" \
--column="Game")

[ -z "$SELECT" ] && exit

FILE="$APPDIR/$PREFIX-$SELECT.desktop"

NAME=$(grep "^Name=" "$FILE" | cut -d= -f2)
EXEC=$(grep "^Exec=" "$FILE" | cut -d= -f2-)

FORM=$(zenity --forms \
--title="Edit Launcher" \
--add-entry="Game Name" \
--add-entry="Exec Command" \
--add-entry="Icon" \
--add-entry="Terminal (true/false)" \
--text="Edit values")

IFS="|" read NEWNAME NEWEXEC NEWICON NEWTERM <<< "$FORM"

[ -z "$NEWNAME" ] && NEWNAME="$NAME"
[ -z "$NEWEXEC" ] && NEWEXEC="$EXEC"

cat > "$FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$NEWNAME
Exec=$NEWEXEC
Icon=${NEWICON:-steam}
Terminal=${NEWTERM:-false}
Categories=Game;
EOF

zenity --info --text="Launcher updated"
}

show_list() {
list_games | zenity --text-info --title="Created Launchers"
}

ACTION=$(zenity --list \
--width=750 --height=450 \
--title="Desktop Launcher Generator" \
--column="Action" \
"Add Game Launcher" \
"Edit Launcher" \
"Remove Launcher" \
"List Launchers" \
"Open Steam Add Game Window" \
"Exit")

case "$ACTION" in
"Add Game Launcher") add_game ;;
"Edit Launcher") edit_game ;;
"Remove Launcher") remove_game ;;
"List Launchers") show_list ;;
"Open Steam Add Game Window") steam steam://open/addnonsteamgame ;;
esac
