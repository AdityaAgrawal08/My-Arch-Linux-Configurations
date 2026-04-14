#!/usr/bin/env bash
set -euo pipefail

BASE="${TRASH_BASE:-$HOME/.local/share/trash-system}"
DB="${TRASH_DB:-$BASE/db/trash.db}"

mkdir -p "$(dirname "$DB")"

sqlite3 "$DB" <<'EOF'

-- ================= DURABILITY =================
PRAGMA journal_mode=WAL;
PRAGMA synchronous=FULL;
PRAGMA foreign_keys=ON;

-- ================= META =================
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- ================= MAIN =================
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

-- ================= SCHEMA VERSION =================
INSERT OR IGNORE INTO meta (key, value)
VALUES ('schema_version', '1');

EOF

touch "$DB.lock"

echo "Trash DB initialized (schema v1, WAL enabled)"
