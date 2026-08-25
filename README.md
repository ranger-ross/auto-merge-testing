# auto-merge-testing

Empty repo configured to test GitHub's **auto-merge** feature. `allow_auto_merge` is enabled and `main` is protected with a required `ci` check (15s delay) so you can observe the full auto-merge lifecycle.

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
cat .github/protection.json  # not committed; example in README history
# or re-run:
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
- Sleeps 15s so you can see `auto-merge` queued state
- Fails if commit message contains `[fail-ci]` (for negative testing)
- Passes otherwise

## Quick start

### 1-command passing PR (auto-merges after ~15s)

```bash
./scripts/new-pr.sh
# → creates branch test/auto-merge-*, pushes, opens PR, enables auto-merge (squash)
# → watch: gh pr checks <branch> --watch
```

### Failing PR (blocked, never merges)

```bash
./scripts/new-pr.sh --fail
# commit contains [fail-ci] → CI fails → auto-merge stays queued/blocked
```

### Manual flow (what the script does)

```bash
# create branch + commit
git checkout main && git pull
git checkout -b test/my-feature
echo "change" >> .auto-merge-test && git add .auto-merge-test
git commit -m "test: my change"
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

### Test matrix (one passing + one failing PR)

```bash
./scripts/test-matrix.sh
gh pr list --limit 5
```

## Options

```bash
./scripts/new-pr.sh --help
./scripts/new-pr.sh --no-auto              # create PR without enabling auto-merge
./scripts/new-pr.sh --merge merge          # use merge commit instead of squash
./scripts/new-pr.sh --merge rebase
./scripts/new-pr.sh --title "custom" --body "details"
./scripts/new-pr.sh --fail --no-auto       # failing PR without auto-merge
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
.github/workflows/ci.yml   required check (15s, [fail-ci] to fail)
scripts/new-pr.sh          one-command PR + auto-merge
scripts/test-matrix.sh     passing + failing PR matrix
.auto-merge-test           bump file (commits touch this)
```
