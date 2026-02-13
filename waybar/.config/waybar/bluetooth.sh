#!/bin/bash

# Check Bluetooth power
if ! bluetoothctl show | grep -q "Powered: yes"; then
    echo '{"text":" off","tooltip":"Bluetooth powered off"}'
    exit 0
fi

# Check connected device
connected_device=$(bluetoothctl devices Connected | head -n 1)

if [[ -n "$connected_device" ]]; then
    name=$(echo "$connected_device" | cut -d ' ' -f3-)
    echo "{\"text\":\" $name\",\"tooltip\":\"Bluetooth connected\"}"
    exit 0
fi

# No device connected
echo '{"text":"","tooltip":"Bluetooth on (no device connected)"}'

