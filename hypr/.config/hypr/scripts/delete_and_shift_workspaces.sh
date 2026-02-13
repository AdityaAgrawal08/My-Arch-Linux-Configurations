#!/bin/bash
set -euo pipefail

# Strictly compact Hyprland workspaces to 1..N every time this is run.
# Requires: jq

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for workspace compaction." >&2
    exit 1
fi

# Get current active workspace ID (fallback to 1 if anything fails)
current_ws_id=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id' 2>/dev/null || echo 1)

# Get sorted list of existing workspace IDs
mapfile -t ws_ids < <(hyprctl workspaces -j | jq '.[].id' | sort -n)

# If there are no workspaces, nothing to do
if [ ${#ws_ids[@]} -eq 0 ]; then
    exit 0
fi

# Build mapping: old_id -> new_id (1..N)
declare -A new_for_old
new_id=1
for old_id in "${ws_ids[@]}"; do
    new_for_old["$old_id"]=$new_id
    new_id=$((new_id + 1))
done

# Move all clients to their new workspace IDs according to mapping
clients_json=$(hyprctl clients -j)

# Each line: ADDRESS<TAB>WORKSPACE_ID
while IFS=$'\t' read -r addr wsid; do
    # If for some reason wsid not in mapping, leave it
    target="${new_for_old["$wsid"]:-$wsid}"

    if [ "$target" != "$wsid" ]; then
        hyprctl dispatch movetoworkspacesilent "$target",address:"$addr" 2>/dev/null || true
    fi
done < <(echo "$clients_json" | jq -r '.[] | "\(.address)\t\(.workspace.id)"')

# Refocus to the "same" logical workspace as before, if possible
new_current="${new_for_old["$current_ws_id"]:-$current_ws_id}"
hyprctl dispatch workspace "$new_current" 2>/dev/null || true

# Refresh Waybar workspaces (if Waybar is running)
pkill -SIGUSR1 waybar 2>/dev/null || true

