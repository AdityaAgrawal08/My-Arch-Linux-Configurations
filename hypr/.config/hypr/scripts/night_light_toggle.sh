#!/bin/bash

# Check if hyprsunset is already running
if pgrep -x "hyprsunset" >/dev/null; then
    killall hyprsunset
else
    hyprsunset -t 3000
fi
