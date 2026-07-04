#!/usr/bin/env bash
# Compile the C daemon if it has changed, then run it.
set -euo pipefail

SCRIPT_DIR="$HOME/.config/hypr/scripts"
SRC="$SCRIPT_DIR/battery-notify.c"
BIN="$SCRIPT_DIR/battery-notify"

if [[ ! -f "$BIN" ]] || [[ "$SRC" -nt "$BIN" ]]; then
    gcc -O2 "$SRC" -o "$BIN" $(pkg-config --cflags --libs gio-2.0)
fi

exec "$BIN"
