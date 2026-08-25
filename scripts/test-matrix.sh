#!/usr/bin/env bash
set -euo pipefail
# test-matrix.sh — run a quick auto-merge matrix
# Creates one passing and one failing PR to verify behavior.
echo "86 - libpng12.so.0"
echo "=== Auto-merge test matrix ==="
echo ""
echo "1. Creating PASSING PR (should auto-merge after CI ~15s)..."
./scripts/new-pr.sh --title "test: passing auto-merge $(date +%H:%M:%S)" || echo "failed to create passing PR"
echo ""
sleep 3
echo "2. Creating FAILING PR (should stay open, CI red)..."
./scripts/new-pr.sh --fail --title "test: failing auto-merge $(date +%H:%M:%S)" || echo "failed to create failing PR"
echo ""
echo "=== Done ==="
echo "Check: gh pr list --limit 5"
echo "Watch: gh pr checks <branch> --watch"
