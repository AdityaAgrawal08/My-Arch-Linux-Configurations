#!/usr/bin/env bash
set -euo pipefail

mkdir -p state

PACMAN_PKGS=()
AUR_PKGS=()

# Read profiles from manifest (simple parse, deterministic)
PROFILES=$(grep -A10 "profiles:" system/manifest.yaml | grep "-" | awk '{print $2}')

for profile in $PROFILES; do
    PACMAN_FILE="packages/pacman/$profile.txt"
    AUR_FILE="packages/aur/$profile.txt"

    if [[ -f "$PACMAN_FILE" ]]; then
        mapfile -t PKGS < "$PACMAN_FILE"
        PACMAN_PKGS+=("${PKGS[@]}")
    fi

    if [[ -f "$AUR_FILE" ]]; then
        mapfile -t PKGS < "$AUR_FILE"
        AUR_PKGS+=("${PKGS[@]}")
    fi
done

printf "%s\n" "${PACMAN_PKGS[@]}" | sort -u > state/pacman.resolved
printf "%s\n" "${AUR_PKGS[@]}" | sort -u > state/aur.resolved
