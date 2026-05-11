#!/usr/bin/env bash

set -euo pipefail

readonly WARNING_THRESHOLD=20
readonly CRITICAL_THRESHOLD=10
readonly CHECK_INTERVAL=30

readonly NOTIFICATION_ID=9991

BAT_PATH=""

for bat in /sys/class/power_supply/BAT*; do
    [[ -d "$bat" ]] || continue
    BAT_PATH="$bat"
    break
done

[[ -n "$BAT_PATH" ]] || {
    echo "battery-notify: no battery detected" >&2
    exit 1
}

readonly BAT_PATH

warning_sent=0
critical_sent=0

send_notification() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    notify-send \
        -r "$NOTIFICATION_ID" \
        -u "$urgency" \
        -a "Battery Monitor" \
        "$title" \
        "$message"
}

while true; do
    battery_level=$(<"$BAT_PATH/capacity")
    battery_status=$(<"$BAT_PATH/status")

    case "$battery_status" in
        Charging|Full)
            warning_sent=0
            critical_sent=0
            ;;

        Discharging)

            if (( battery_level <= CRITICAL_THRESHOLD )); then
                if (( critical_sent == 0 )); then

                    send_notification \
                        critical \
                        "Critical Battery" \
                        "Battery at ${battery_level}%"

                    critical_sent=1
                fi

            elif (( battery_level <= WARNING_THRESHOLD )); then
                if (( warning_sent == 0 )); then

                    send_notification \
                        normal \
                        "Low Battery" \
                        "Battery at ${battery_level}%"

                    warning_sent=1
                fi

            else
                warning_sent=0
                critical_sent=0
            fi
            ;;

        *)
            ;;
    esac

    sleep "$CHECK_INTERVAL"
done
