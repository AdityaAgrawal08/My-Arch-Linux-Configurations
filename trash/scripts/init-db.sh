#!/usr/bin/env bash

BASE="${TRASH_BASE:-$HOME/.local/share/trash-system}"
DB="${TRASH_DB:-$BASE/db/trash.db}"

mkdir -p "$(dirname "$DB")"

sqlite3 "$DB" "
CREATE TABLE IF NOT EXISTS trash (
    id TEXT PRIMARY KEY,
    original_path TEXT,
    filename TEXT,
    extension TEXT,
    deletion_time INTEGER,
    mime_type TEXT,
    category TEXT,
    origin_root TEXT,
    project_root TEXT,
    storage_path TEXT,
    size INTEGER,
    hash TEXT,
    is_restored INTEGER DEFAULT 0,
    active_days INTEGER DEFAULT 0,
    pinned INTEGER DEFAULT 0
);
"

touch "$DB.lock"

echo "Trash DB initialized"
