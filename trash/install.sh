#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/trash-system/db"
mkdir -p "$HOME/.local/share/trash-system/objects"

cp bin/* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*

# initialize DB if missing
if [ ! -f "$HOME/.local/share/trash-system/db/trash.db" ]; then
    bash scripts/init-db.sh
fi

echo "trash system installed"
