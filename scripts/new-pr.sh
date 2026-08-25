#!/usr/bin/env bash
set -euo pipefail

# new-pr.sh — create a test PR with auto-merge enabled
#
# Usage:
#   ./scripts/new-pr.sh                  # passing PR (auto-merges after ~15s)
#   ./scripts/new-pr.sh --fail           # failing PR (blocked, tests failure path)
#   ./scripts/new-pr.sh --no-auto        # create PR without enabling auto-merge
#   ./scripts/new-pr.sh --merge squash|merge|rebase
#   ./scripts/new-pr.sh --title "my title" --body "my body"
#
# Requires: gh CLI authenticated with repo scope

MERGE_METHOD="squash"
FAIL_CI=false
AUTO_MERGE=true
TITLE=""
BODY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fail) FAIL_CI=true; shift ;;
    --no-auto) AUTO_MERGE=false; shift ;;
    --merge) MERGE_METHOD="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# //;s/^#//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if ! gh auth status &>/dev/null; then
  echo "error: gh not authenticated — run 'gh auth login'" >&2
  exit 1
fi

BRANCH="test/auto-merge-$(date +%Y%m%d-%H%M%S)-$$"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -z "$TITLE" ]]; then
  if [[ "$FAIL_CI" == true ]]; then
    TITLE="test: auto-merge with failing CI [fail-ci]"
  else
    TITLE="test: auto-merge $TIMESTAMP"
  fi
fi

if [[ -z "$BODY" ]]; then
  BODY="Automated test PR for auto-merge.

- Branch: \`$BRANCH\`
- CI: ${FAIL_CI:+failing (contains [fail-ci])}${FAIL_CI:-passing (15s delay)}
- Auto-merge: $AUTO_MERGE ($MERGE_METHOD)

Created by \`scripts/new-pr.sh\` at $TIMESTAMP"
fi

# ensure we're on main and up to date
git fetch origin main -q
if [[ $(git rev-parse --abbrev-ref HEAD) != "main" ]]; then
  echo "Switching to main..."
  git checkout main -q
fi
git rebase origin/main -q || git merge origin/main --ff-only -q

# create commit
git checkout -b "$BRANCH" -q
echo "$TIMESTAMP" >> .auto-merge-test
# keep file sorted/deduped to avoid huge diff
sort -u .auto-merge-test -o .auto-merge-test
git add .auto-merge-test

COMMIT_MSG="$TITLE"
if [[ "$FAIL_CI" == true ]]; then
  COMMIT_MSG="$COMMIT_MSG [fail-ci]"
fi
git commit -m "$COMMIT_MSG" -q

echo "Pushing $BRANCH..."
git push -u origin "$BRANCH" -q

echo "Creating PR..."
PR_URL=$(gh pr create --title "$TITLE" --body "$BODY" --base main --head "$BRANCH" 2>&1)
# gh pr create prints URL on success; capture it
if [[ "$PR_URL" != http* ]]; then
  # fallback: query for PR
  PR_URL=$(gh pr view "$BRANCH" --json url --jq .url)
fi
echo "PR: $PR_URL"

# wait a moment for PR to be fully created
sleep 2

if [[ "$AUTO_MERGE" == true ]]; then
  echo "Enabling auto-merge ($MERGE_METHOD)..."
  if gh pr merge --auto --"$MERGE_METHOD" --delete-branch "$BRANCH" 2>&1; then
    echo "✅ Auto-merge enabled ($MERGE_METHOD) — will merge when CI passes (~15s)"
  else
    echo "⚠️  Failed to enable auto-merge — check branch protection / CI status"
    echo "   Try manually: gh pr merge --auto --$MERGE_METHOD $BRANCH"
    exit 1
  fi
else
  echo "Skipping auto-merge (--no-auto). Enable manually:"
  echo "  gh pr merge --auto --$MERGE_METHOD $BRANCH"
fi

echo ""
echo "Watch: gh pr view $BRANCH --json state,mergeStateStatus,statusCheckRollup -q ."
echo "Checks: gh pr checks $BRANCH --watch"
