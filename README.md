# auto-merge-testing

Empty repo configured to test GitHub's **auto-merge** feature. `allow_auto_merge` is enabled and `main` is protected with a required `ci` check (configurable delay, 15s default) so you can observe the full auto-merge lifecycle.

## Setup

Already configured — nothing to do manually:

- **Allow auto-merge**: enabled on repo (`gh api repos/ranger-ross/auto-merge-testing --jq .allow_auto_merge` → `true`)
- **Branch protection on `main`**:
  - Require pull request (0 approvals — solo-friendly)
  - Require status check `ci` to pass
  - Strict (branch must be up to date)
  - No force pushes / deletions

Re-apply protection if needed:

```bash
gh api -X PUT repos/ranger-ross/auto-merge-testing/branches/main/protection \
  --input <(jq -n '{
    required_status_checks: {strict: true, contexts: ["ci"]},
    enforce_admins: false,
    required_pull_request_reviews: {
      dismiss_stale_reviews: false,
      require_code_owner_reviews: false,
      required_approving_review_count: 0
    },
    restrictions: null
  }')
```

## CI

`.github/workflows/ci.yml` — single required job `ci`:

- Runs on `pull_request` → `main` (and pushes to `main`)
  - Add `[delay=N]` or `[delay=N s]` to the commit message (e.g. `[delay=0]`, `[delay=60s]`, `[delay: 30]`, `[delay 10]`) — first match wins, capped at 600s (10 min)
  - No marker → 15s default; `[delay=0]` → instant pass; `[delay=600]` → 10 min max
- Fails if commit message contains `[fail-ci]` (for negative testing)
- Passes otherwise

## Quick start

### 1-command passing PR (auto-merges after ~15s)

```bash
./scripts/new-pr.sh
# → creates branch test/auto-merge-*, pushes, opens PR, enables auto-merge (squash)
# → watch: gh pr checks <branch> --watch
```

### Configurable delay

```bash
./scripts/new-pr.sh --delay 0     # instant CI, merges as fast as possible
./scripts/new-pr.sh --delay 60    # 60s delay to observe queued state longer
./scripts/new-pr.sh --delay=5     # alternate syntax
# also works manually: git commit -m "my change [delay=30]"
```

### Failing PR (blocked, never merges)

```bash
./scripts/new-pr.sh --fail
# commit contains [fail-ci] → CI fails → auto-merge stays queued/blocked

# combine with delay
./scripts/new-pr.sh --fail --delay 5   # fail after 5s instead of 15s
```

### Manual flow (what the script does)

```bash
# create branch + commit (with optional markers)
git checkout main && git pull
git checkout -b test/my-feature
echo "change" >> .auto-merge-test && git add .auto-merge-test
git commit -m "test: my change [delay=30]"   # or [delay=0] / [fail-ci]
git push -u origin HEAD

# open PR
gh pr create --title "test: my change" --body "testing" --base main

# enable auto-merge (squash | merge | rebase)
gh pr merge --auto --squash --delete-branch

# alternatives
gh pr merge --auto --merge    # merge commit
gh pr merge --auto --rebase   # rebase

# disable if needed
gh pr merge --disable-auto

# inspect
gh pr view --json autoMergeRequest,mergeStateStatus,statusCheckRollup --jq .
gh pr checks --watch
```

### Test matrix (passing + fast + failing PRs)

```bash
./scripts/test-matrix.sh
gh pr list --limit 5
```

## Options

```bash
./scripts/new-pr.sh --delay 0                # 0-600s, default 15
./scripts/new-pr.sh --delay 30 --fail        # failing with custom delay
./scripts/new-pr.sh --no-auto                # create PR without enabling auto-merge
./scripts/new-pr.sh --merge merge            # use merge commit instead of squash
./scripts/new-pr.sh --merge rebase
./scripts/new-pr.sh --title "custom" --body "details"
./scripts/new-pr.sh --fail --no-auto         # failing PR without auto-merge
```

## Verifying auto-merge

```bash
# PR should show autoMergeRequest after enabling
gh pr view <number|branch> --json autoMergeRequest --jq .autoMergeRequest

# Check merge state (BLOCKED → BEHIND → CLEAN → merged)
gh pr view <branch> --json mergeStateStatus --jq .mergeStateStatus

# Watch checks live
gh pr checks <branch> --watch

# List recent PRs
gh pr list --limit 10 --json number,title,state,autoMergeRequest,mergeStateStatus
```

## Cleanup

```bash
gh pr list --json number,headRefName --jq '.[] | select(.headRefName | startswith("test/")) | .number' \
  | xargs -I{} gh pr close {} --delete-branch

# or delete branches directly
git branch -D test/auto-merge-... 2>/dev/null; git push origin --delete test/auto-merge-... 2>/dev/null
```

## Files

```
.github/workflows/ci.yml   required check (configurable delay via [delay=N], 15s default, capped at 600s, [fail-ci] to fail)
scripts/new-pr.sh          one-command PR + auto-merge (--delay 0-600, --fail, --merge, --no-auto)
scripts/test-matrix.sh     passing + fast + failing PR matrix
.auto-merge-test           bump file (commits touch this)
```
