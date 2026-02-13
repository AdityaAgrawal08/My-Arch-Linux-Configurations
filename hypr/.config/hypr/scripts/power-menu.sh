#!/bin/bash

options="  Lock\n  Restart\n⏻  Shutdown"

chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")

echo "Chosen: '$chosen'" >/tmp/power-menu.log

case "$chosen" in
    *Lock*)
        # Close wofi before locking
        pkill wofi
        sleep 0.15
        hyprlock
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

