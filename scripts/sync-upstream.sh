#!/usr/bin/env bash
# Sync bundled queries and registry from upstream repos.
# Run before a release to pull in the latest community data.
#
# Downloads tarballs directly — no git clone, no .git metadata.
#
# Usage: ./scripts/sync-upstream.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

# --- Queries ---
echo "Fetching arborist-ts/queries..."
curl -fsSL "https://github.com/arborist-ts/queries/archive/refs/heads/main.tar.gz" \
  | tar -xz -C "$TMP_DIR"

rm -rf "$ROOT_DIR/queries"
cp -r "$TMP_DIR/queries-main/queries" "$ROOT_DIR/queries"

query_count=$(find "$ROOT_DIR/queries" -type d -mindepth 1 -maxdepth 1 | wc -l)
echo "  $query_count languages synced."

# --- Registry ---
echo "Fetching arborist-ts/registry..."
curl -fsSL "https://github.com/arborist-ts/registry/archive/refs/heads/main.tar.gz" \
  | tar -xz -C "$TMP_DIR"

mkdir -p "$ROOT_DIR/registry"
cp "$TMP_DIR/registry-main/parsers.toml"          "$ROOT_DIR/registry/parsers.toml"
cp "$TMP_DIR/registry-main/neovim-filetypes.toml" "$ROOT_DIR/registry/filetypes.toml"
cp "$TMP_DIR/registry-main/neovim-ignore.toml"    "$ROOT_DIR/registry/ignore.toml"

parser_count=$(grep -c '^\[' "$ROOT_DIR/registry/parsers.toml")
echo "  $parser_count parsers synced."

echo "Done."
