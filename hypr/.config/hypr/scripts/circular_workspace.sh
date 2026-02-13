#!/bin/bash

# Run hyprctl silently always
hypr() {
    hyprctl "$@" 2>/dev/null >/tmp/hypr_silent
}

# Current workspace ID
current=$(hyprctl activeworkspace 2>/dev/null | grep "workspace ID" | awk '{print $3}')

# Validate
if ! [[ "$current" =~ ^[0-9]+$ ]]; then
    exit 0
fi

# Get REAL workspaces (only the ones with windows)
mapfile -t workspaces < <(
    hyprctl workspaces 2>/dev/null | \
    grep "workspace ID" | \
    awk '{print $3}' | sort -n
)

if [ ${#workspaces[@]} -eq 0 ]; then
    exit 0
fi

next=""

# Find next workspace numerically
for ws in "${workspaces[@]}"; do
    if (( ws > current )); then
        next=$ws
        break
    fi
done

# Wrap
if [ -z "$next" ]; then
    next="${workspaces[0]}"
fi

# Switch workspace silently
hypr dispatch workspace "$next"

