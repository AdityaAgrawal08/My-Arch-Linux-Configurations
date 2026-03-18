#!/bin/bash
EVENT="$1"
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
HYPRLAND_DISPLAY=$(ls /run/user/1000/hypr/ | head -1)

LOCKED=$(pgrep -x hyprlock)

if echo "$EVENT" | grep -q "open"; then
    if [ -z "$LOCKED" ]; then
        su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 mpv --no-terminal '/home/aditya/Downloads/open.wav'" &
    fi
elif echo "$EVENT" | grep -q "close"; then
    if [ -z "$LOCKED" ]; then
        su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_DISPLAY hyprlock" &
    fi
fi
