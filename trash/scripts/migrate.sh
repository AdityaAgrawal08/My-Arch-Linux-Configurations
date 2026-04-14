#!/usr/bin/env bash
set -euo pipefail

BASE="${TRASH_BASE:-$HOME/.local/share/trash-system}"
DB="${TRASH_DB:-$BASE/db/trash.db}"

[ -f "$DB" ] || exit 0

version=$(sqlite3 "$DB" "SELECT value FROM meta WHERE key='schema_version';")

case "$version" in
    1)
        # future migrations go here
        ;;
    *)
        echo "Unknown schema version: $version"
        exit 1
        ;;
esac
