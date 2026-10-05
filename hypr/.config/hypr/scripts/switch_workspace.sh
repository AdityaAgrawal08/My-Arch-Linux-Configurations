#!/bin/bash

# Switch to the previous / next workspace that has windows.
# Unlike circular_workspace.sh (ALT + TAB) this does NOT wrap around:
# if there is no workspace in that direction, nothing happens.
#
# Usage: switch_workspace.sh next|prev

direction="${1:-next}"

current=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id')
if ! [[ "$current" =~ ^-?[0-9]+$ ]]; then
    exit 0
fi

# Real workspaces only: positive IDs (skips special:magic) that have windows.
mapfile -t workspaces < <(
    hyprctl -j workspaces 2>/dev/null \
        | jq -r '.[] | select(.id > 0 and .windows > 0) | .id' \
        | sort -n
)

if [ ${#workspaces[@]} -eq 0 ]; then
    exit 0
fi

target=""

case "$direction" in
    next)
        for ws in "${workspaces[@]}"; do
            if (( ws > current )); then
                target="$ws"
                break
            fi
        done
        ;;
    prev)
        for (( i = ${#workspaces[@]} - 1; i >= 0; i-- )); do
            if (( workspaces[i] < current )); then
                target="${workspaces[i]}"
                break
            fi
        done
        ;;
esac

# No workspace in that direction -> stay where we are.
[ -n "$target" ] || exit 0

hyprctl dispatch "hl.dsp.focus({ workspace = $target })" >/dev/null 2>&1
