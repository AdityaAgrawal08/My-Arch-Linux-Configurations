#!/usr/bin/env bash
set -euo pipefail

chmod +x scripts/core/*.sh

./scripts/core/detect.sh > state/env.json
./scripts/core/apply.sh

# Zathura
sudo pacman -S --needed \
  zathura \
  zathura-pdf-poppler \
  zathura-djvu \
  zathura-ps

# Stow configs
cd "$HOME/dotfiles"
stow zathura

# Fish open command
mkdir -p ~/.config/fish
if ! grep -q "function open" ~/.config/fish/config.fish 2>/dev/null; then
  echo '
function open
    zathura $argv
end
' >> ~/.config/fish/config.fish
fi

./scripts/bootstrap-tools.sh
