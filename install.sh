#!/usr/bin/env bash
set -euo pipefail

# Ensure required tools
sudo pacman -S --needed stow git base-devel

# Core scripts
chmod +x scripts/core/*.sh
./scripts/core/detect.sh > state/env.json
./scripts/core/apply.sh

# Pacman packages
sudo pacman -S --needed - < packages/pacman/base.txt
sudo pacman -S --needed - < packages/pacman/hyprland.txt

# Zathura (explicit)
sudo pacman -S --needed \
  zathura \
  zathura-pdf-poppler \
  zathura-djvu \
  zathura-ps

# AUR helper (yay)
if ! command -v yay >/dev/null 2>&1; then
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay
  makepkg -si --noconfirm
  cd -
fi

# AUR packages
if [ -f packages/aur/aur.txt ]; then
  yay -S --needed - < packages/aur/aur.txt
fi

# Stow all configs (your structure is valid)
cd "$HOME/dotfiles"
stow fish
stow nvim
stow hypr
stow waybar
stow wofi
stow starship
stow zathura
stow trash

# Ensure local binaries executable + PATH
chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

# Systemd user services (trash system)
systemctl --user daemon-reexec
systemctl --user enable --now trash-age.timer
systemctl --user enable --now trash-clean.timer
systemctl --user enable --now trash-notify.timer

# Fish open command (idempotent)
mkdir -p ~/.config/fish
if ! grep -q "function open" ~/.config/fish/config.fish 2>/dev/null; then
  cat >> ~/.config/fish/config.fish << 'EOF'
function open
    zathura $argv
end
EOF
fi

# Bootstrap additional tools
./scripts/bootstrap-tools.sh

# Set fish as default shell
chsh -s "$(which fish)"

echo "Setup complete"
