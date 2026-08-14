#!/usr/bin/env bash

# Lock file to prevent duplicate confirmation dialogs
LOCK_FILE="/tmp/confirm_close.lock"

if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    # Check if the process is actually running
    if kill -0 "$PID" 2>/dev/null; then
        exit 0
    fi
fi

# Store the current script PID in the lock file
echo "$$" > "$LOCK_FILE"

# Clean up lock file on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Get active window info in JSON format
WINDOW_JSON=$(hyprctl activewindow -j)
WINDOW_ADDRESS=$(echo "$WINDOW_JSON" | jq -r '.address')
WINDOW_CLASS=$(echo "$WINDOW_JSON" | jq -r '.class')
WINDOW_TITLE=$(echo "$WINDOW_JSON" | jq -r '.title')

# Exit if no window is active
if [ -z "$WINDOW_ADDRESS" ] || [ "$WINDOW_ADDRESS" = "null" ] || [ "$WINDOW_ADDRESS" = "0x" ]; then
    exit 0
fi

# Bypass confirmation for utility/overlay windows
if [[ "$WINDOW_CLASS" =~ ^(wofi|system-dashboard|com\.system\.dashboard)$ ]]; then
    hyprctl dispatch "hl.dsp.window.close({ window = \"address:$WINDOW_ADDRESS\" })"
    exit 0
fi

# Format the window class/display name for the prompt
DISPLAY_NAME=$(echo "$WINDOW_CLASS" | tr '[:lower:]' '[:upper:]')

# Build prompt and pad it to center horizontally (approx 34 chars fit in width 350)
PROMPT_TEXT="CLOSE $DISPLAY_NAME"
TOTAL_WIDTH=34
TEXT_LEN=${#PROMPT_TEXT}
PADDING_LEN=$(( (TOTAL_WIDTH - TEXT_LEN) / 2 ))
if [ $PADDING_LEN -gt 0 ]; then
    PADDING=$(printf '%*s' "$PADDING_LEN" "")
    PROMPT="${PADDING}${PROMPT_TEXT}"
else
    PROMPT="$PROMPT_TEXT"
fi

# Show wofi confirmation dialog
CHOICE=$(printf "NO\nYES" | wofi --dmenu \
    --prompt "$PROMPT" \
    --width 350 \
    --height 105 \
    --columns 2 \
    -k /dev/null \
    -D content_halign=center \
    -D single_click=true \
    -s ~/.config/wofi/confirm.css)

# If choice is yes, close the window by its address
if [ "$CHOICE" = "YES" ]; then
    hyprctl dispatch "hl.dsp.window.close({ window = \"address:$WINDOW_ADDRESS\" })"
fi
