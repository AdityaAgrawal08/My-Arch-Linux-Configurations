#!/bin/bash
OPEN_SOUND="/home/aditya/Downloads/open.wav"
CLOSE_SOUND="/home/aditya/Downloads/close.wav"
EVENT="$1"

export XDG_RUNTIME_DIR=/run/user/1000

LOCKED=$(su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 pgrep hyprlock")

if echo "$EVENT" | grep -q "open"; then
    if [ -z "$LOCKED" ]; then
        su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 aplay '$OPEN_SOUND'" &
    fi
elif echo "$EVENT" | grep -q "close"; then
    if [ -z "$LOCKED" ]; then
        su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 aplay '$CLOSE_SOUND'" &
        su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 ~/dotfiles/lid-sounds/unlock-hook.sh" &
    else
        su aditya -c "XDG_RUNTIME_DIR=/run/user/1000 aplay '$CLOSE_SOUND'" &
    fi
fi
