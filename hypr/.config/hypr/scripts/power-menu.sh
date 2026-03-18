#!/bin/bash
options="  Lock\n  Restart\n⏻  Shutdown"
chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")
echo "Chosen: '$chosen'" >/tmp/power-menu.log
case "$chosen" in
    *Lock*)
        pkill wofi
        mpv --no-terminal /home/aditya/Downloads/close.wav &
        MPV_PID=$!
        hyprlock &
        sleep 2.5
        kill $MPV_PID 2>/dev/null
        wait
        mpv --no-terminal /home/aditya/Downloads/open.wav
        ;;
    *Restart*)
        pkill wofi
        sleep 0.1
        systemctl reboot
        ;;
    *Shutdown*)
        pkill wofi
        sleep 0.1
        systemctl poweroff
        ;;
esac
