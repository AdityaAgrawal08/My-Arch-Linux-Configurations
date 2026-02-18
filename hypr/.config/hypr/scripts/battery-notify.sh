#!/bin/bash

while true; do
    # Get current battery level and status for BAT0
    BATTERY_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
    BATTERY_STATUS=$(cat /sys/class/power_supply/BAT0/status)

    # Check logic:
    # 1. Is the battery level 30% or less?
    # 2. Is the battery currently "Discharging"? (This ensures no notification if Charging or Full)
    if [ "$BATTERY_LEVEL" -le 30 ] && [ "$BATTERY_STATUS" = "Discharging" ]; then
        notify-send -u critical -a "System" "Battery Low" "Battery is at ${BATTERY_LEVEL}%. Please connect your charger."
    fi

    # Wait for 120 seconds (2 minutes) before the next check
    sleep 120
done
