#!/bin/bash
NOTIFIED=false

while true; do
    BATTERY_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
    BATTERY_STATUS=$(cat /sys/class/power_supply/BAT0/status)

    if [ "$BATTERY_LEVEL" -le 30 ] && [ "$BATTERY_STATUS" = "Discharging" ]; then
        if [ "$NOTIFIED" = false ]; then
            notify-send -u critical -a "System" "Battery Low" "Battery is at ${BATTERY_LEVEL}%. Please connect your charger."
            NOTIFIED=true
        fi
    else
        # Reset flag once battery is charging or above threshold
        NOTIFIED=false
    fi

    sleep 120
done
