#!/usr/bin/env bash
# Sync bundled queries from the arborist-ts/queries repo.
# Run before a release to pull in the latest community query files.
#
# Usage: ./scripts/sync-queries.sh

set -euo pipefail

REPO_URL="https://github.com/arborist-ts/queries.git"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUERIES_DIR="$ROOT_DIR/queries"
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

echo "Cloning arborist-ts/queries..."
git clone --depth 1 --single-branch --quiet "$REPO_URL" "$TMP_DIR"

echo "Syncing queries..."
rm -rf "$QUERIES_DIR"
cp -r "$TMP_DIR/queries" "$QUERIES_DIR"

count=$(find "$QUERIES_DIR" -type d -mindepth 1 -maxdepth 1 | wc -l)
echo "Done. $count languages synced."
