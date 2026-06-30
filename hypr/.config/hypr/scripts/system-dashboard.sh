#!/usr/bin/env bash
# System Dashboard Launcher (Hyprland + Waybar)

# Run the dashboard script.
# Since the GTK4 application is single-instance and runs persistently,
# running this script will natively toggle the dashboard's visibility (show/hide).
python3 "$HOME/.config/hypr/scripts/system-dashboard/dashboard.py" &
