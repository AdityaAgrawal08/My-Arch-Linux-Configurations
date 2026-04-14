#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/.local/share/trash-system"

mkdir -p "$HOME/.local/bin"
mkdir -p "$BASE/db"
mkdir -p "$BASE/objects"

cp bin/* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*

# initialize DB if missing
if [ ! -f "$BASE/db/trash.db" ]; then
    bash scripts/migrate.sh
    bash scripts/init-db.sh
fi


# ensure ~/.local/bin in PATH (fish)
if ! grep -q ".local/bin" "$HOME/.config/fish/config.fish" 2>/dev/null; then
    mkdir -p "$HOME/.config/fish"
    echo 'set -gx PATH $HOME/.local/bin $PATH' >> "$HOME/.config/fish/config.fish"
fi

echo "trash system installed"


