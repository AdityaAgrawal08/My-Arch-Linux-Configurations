#!/bin/bash

# Set the low battery threshold to 20%
THRESHOLD=20

while true; do
    # Identify the correct battery path (usually BAT0 or BAT1)
    if [ -d "/sys/class/power_supply/BAT0" ]; then
        BAT_PATH="/sys/class/power_supply/BAT0"
    elif [ -d "/sys/class/power_supply/BAT1" ]; then
        BAT_PATH="/sys/class/power_supply/BAT1"
    else
        # Exit if no battery is detected to avoid errors
        exit 1
    fi

    BATTERY_LEVEL=$(cat "$BAT_PATH/capacity")
    BATTERY_STATUS=$(cat "$BAT_PATH/status")

    # 1. Check if battery is <= 20%
    # 2. Check if status is specifically "Discharging"
    # This ensures it stops as soon as you plug it in (status becomes "Charging")
    if [ "$BATTERY_LEVEL" -le "$THRESHOLD" ] && [ "$BATTERY_STATUS" = "Discharging" ]; then
        notify-send -u critical -a "System" "Battery Low" "Battery is at ${BATTERY_LEVEL}%. Please connect your charger."
    fi

    # Wait for 2 minutes before the next check
    sleep 120
done
