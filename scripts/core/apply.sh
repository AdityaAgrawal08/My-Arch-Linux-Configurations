#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="logs/install.log"
mkdir -p logs state

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Starting system apply"

# Ensure sudo upfront
sudo -v

if ! command -v paru &> /dev/null; then
    echo "[INFO] Installing paru"

    PARU_DIR="/tmp/paru"

    # Clean previous state safely
    if [[ -d "$PARU_DIR" ]]; then
        echo "[INFO] Cleaning existing paru build directory"
        rm -rf "$PARU_DIR"
    fi

    git clone https://aur.archlinux.org/paru.git "$PARU_DIR"
    pushd "$PARU_DIR" >/dev/null

    makepkg -si --noconfirm

    popd >/dev/null

    # Cleanup after install (prevents future conflicts)
    rm -rf "$PARU_DIR"
fi

# Resolve packages
./scripts/core/reconcile.sh

# Install pacman packages
if [[ -s state/pacman.resolved ]]; then
    echo "[INFO] Installing pacman packages"
    sudo pacman -Syu --needed --noconfirm \
        $(tr '\n' ' ' < state/pacman.resolved)
fi

# Install AUR packages
if [[ -s state/aur.resolved ]]; then
    echo "[INFO] Installing AUR packages"
    paru -S --needed --noconfirm \
        $(tr '\n' ' ' < state/aur.resolved)
fi

# Apply dotfiles via stow (DYNAMIC + SAFE)
echo "[INFO] Applying dotfiles via stow"

for dir in */ ; do
    dir="${dir%/}"

    # Skip non-dotfile/system directories
    case "$dir" in
        scripts|packages|system|state|logs|.git)
            continue
            ;;
    esac

    # Only stow valid packages (must contain .config or home-mapped dirs)
    if [[ -d "$dir/.config" || -d "$dir/.local" || -d "$dir/.cache" || -d "$dir/.themes" ]]; then
        echo "[INFO] Stowing $dir"
        stow -Rv "$dir"
    else
        echo "[SKIP] $dir is not a valid stow package"
    fi
done

# Enable user services (idempotent)
echo "[INFO] Enabling services"

systemctl --user daemon-reexec || true

for svc in pipewire wireplumber; do
    systemctl --user enable --now "$svc.service" || true
done

echo "[INFO] Completed successfully"
