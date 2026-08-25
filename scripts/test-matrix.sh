#!/usr/bin/env bash
set -euo pipefail
# test-matrix.sh — run a quick auto-merge matrix
# Creates passing and failing PRs with varying delays to verify behavior.
echo "=== Auto-merge test matrix ==="
echo ""
echo "1. Creating PASSING PR with default delay (15s)..."
./scripts/new-pr.sh --title "test: passing auto-merge default $(date +%H:%M:%S)" || echo "failed to create passing PR"
echo ""
sleep 3
echo "2. Creating FAST PR with 0s delay (should merge almost immediately)..."
./scripts/new-pr.sh --delay 0 --title "test: fast auto-merge 0s $(date +%H:%M:%S)" || echo "failed to create fast PR"
echo ""
sleep 3
echo "3. Creating FAILING PR (should stay open, CI red)..."
./scripts/new-pr.sh --fail --title "test: failing auto-merge $(date +%H:%M:%S)" || echo "failed to create failing PR"
echo ""
echo "=== Done ==="
echo "Check: gh pr list --limit 5"
echo "Watch: gh pr checks <branch> --watch"
