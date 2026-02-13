#!/bin/bash

# get highest workspace ID
max=$(hyprctl workspaces -j | jq '.[].id' | sort -n | tail -n 1)

# create NEW workspace = highest + 1
new=$((max + 1))

# go to newly created workspace
hyprctl dispatch workspace "$new"

