#!/bin/bash
options="  Lock\n  Restart\n⏻  Shutdown"
chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")
echo "Chosen: '$chosen'" >/tmp/power-menu.log
case "$chosen" in
    *Lock*)
        pkill wofi
        aplay /home/aditya/Downloads/close.wav &
        ~/dotfiles/lid-sounds/unlock-hook.sh 
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
