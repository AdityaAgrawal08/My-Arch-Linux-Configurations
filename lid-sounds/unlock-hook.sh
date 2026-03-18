#!/bin/bash
HYPRLAND_DISPLAY=$(ls /run/user/1000/hypr/ | head -1)
export XDG_RUNTIME_DIR=/run/user/1000
export HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_DISPLAY
su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_DISPLAY hyprlock"
mpv --no-terminal /home/aditya/Downloads/open.wav
