# Controlled Release Workflow

This document describes the **fully automated but controlled** workflow for publishing to the public repository.

## Overview

The workflow provides **two layers of approval** before code reaches the public:

1. **Private side approval**: Pull request review on `ready-for-public` branch (REQUIRED)
2. **GitHub Actions approval**: Environment-based manual approval gate (OPTIONAL but recommended)

Both are controlled from the private repository, ensuring you maintain complete control over what gets published.

---

## Architecture

```
Private Repo (ScheierVentures/net_energy_burden)
├── package-transformation (main development)
│   └── PR → ready-for-public (protected, requires approval)
│       └── Triggers GitHub Actions workflow
│           └── Optional environment approval
│               └── Automatic cleaning & publishing
│                   └── Push to Public Repo main branch

Public Repo (ericscheier/net_energy_burden)
└── main (receives cleaned code automatically)
```

---

## Setup Instructions

### Step 1: Create Personal Access Token (PAT)

If you haven't already:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name: `net_energy_burden_publisher`
4. Expiration: 90 days or 1 year (set a calendar reminder)
5. Scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
6. Generate and copy the token

### Step 2: Add Token as Repository Secret

1. Go to private repo: Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `PUBLIC_REPO_TOKEN`
4. Value: Paste the PAT
5. Click "Add secret"

### Step 3: Set Up Protected Branch

Set up the `ready-for-public` branch with required approvals:

**Option A: Via GitHub Web UI**

1. Go to private repo: Settings → Branches → Add branch protection rule
2. Branch name pattern: `ready-for-public`
3. Enable these protections:
   - ✅ **Require a pull request before merging**
     - ✅ Require approvals: **1** (or more if you want multiple reviewers)
     - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ **Require status checks to pass before merging** (optional)
   - ✅ **Do not allow bypassing the above settings**
4. Click "Create" or "Save changes"

**Option B: Programmatically (if you prefer)**

```bash
# Using GitHub CLI
gh api repos/ScheierVentures/net_energy_burden/branches/ready-for-public/protection \
  --method PUT \
  --field required_pull_request_reviews[required_approving_review_count]=1 \
  --field required_pull_request_reviews[dismiss_stale_reviews]=true \
  --field enforce_admins=true
```

### Step 4: Set Up GitHub Actions Environment (RECOMMENDED)

Add an additional approval gate within GitHub Actions:

1. Go to private repo: Settings → Environments → New environment
2. Environment name: `public-release`
3. Configure environment protection rules:
   - ✅ **Required reviewers**
     - Add yourself (and/or other trusted collaborators)
     - You can add up to 6 reviewers
     - Only 1 approval needed to proceed
   - ⏱️ **Wait timer**: 0 minutes (or add a delay if you want)
   - 🔒 **Deployment branches**: Only allow `ready-for-public` branch
4. Click "Save protection rules"

**What this does:**
- When the workflow runs, it will pause at the "Clean and publish" job
- You'll get a notification to review and approve the deployment
- You can review what will be published before giving final approval
- Only after you approve will the workflow push to the public repo

### Step 5: Create Initial `ready-for-public` Branch

```bash
# Create the branch from current state of package-transformation
git checkout package-transformation
git pull origin package-transformation
git checkout -b ready-for-public
git push origin ready-for-public
```

---

## Daily Workflow

### Normal Development (Private Only)

Work on `package-transformation` as usual:

```bash
git checkout package-transformation
# ... make changes ...
git add .
git commit -m "Add new feature"
git push origin package-transformation
```

Nothing gets published automatically. Code stays private.

### Publishing to Public Repository

When you're ready to make a public release:

#### 1. Create Pull Request

```bash
# Make sure package-transformation is up to date
git checkout package-transformation
git pull origin package-transformation

# Create a new branch for the PR
git checkout -b release-$(date +%Y%m%d)

# Push it
git push origin release-$(date +%Y%m%d)
```

Then on GitHub:
1. Go to private repo → Pull requests → New pull request
2. Base: `ready-for-public`
3. Compare: `release-20241102` (or `package-transformation` for ongoing sync)
4. Title: "Release YYYY-MM-DD" or "Sync to public"
5. Description: Summarize what's being published
6. Create pull request

#### 2. Review and Approve (FIRST APPROVAL GATE)

1. Review the PR changes - this is what will be published (after cleaning)
2. Check the diff to ensure no sensitive data
3. Approve and merge the PR

**The moment you merge, the workflow triggers automatically.**

#### 3. GitHub Actions Approval (SECOND APPROVAL GATE - if configured)

If you set up the `public-release` environment:

1. Go to private repo → Actions tab
2. Click on the running "Publish to Public Repository" workflow
3. You'll see a "Review deployments" button
4. Click it and review:
   - What branch is being published
   - The workflow steps
   - Confirmation that cleaning will happen
5. Click "Approve and deploy"

**Only after this approval will the workflow push to public.**

#### 4. Verify Publication

After the workflow completes:

1. Check the workflow summary for confirmation
2. Visit the public repo: https://github.com/ericscheier/net_energy_burden
3. Verify:
   - ✅ Code is present
   - ✅ `.private/` directory is NOT present
   - ✅ Commit messages are clean (no AI attributions)
   - ✅ `*.log` files removed
   - ✅ `*_cache/` and `*_files/` removed

---

## Approval Flow Summary

### With Both Approval Gates (Recommended)

```
Developer → PR to ready-for-public
           ↓
    Reviewer approves PR
           ↓
    PR merged (triggers workflow)
           ↓
    Workflow starts cleaning
           ↓
    ⏸️  Pauses for environment approval
           ↓
    You review and approve
           ↓
    ✅ Published to public repo
```

**Total approvals: 2**
- PR approval (private side)
- Deployment approval (GitHub Actions)

### With PR Approval Only

```
Developer → PR to ready-for-public
           ↓
    Reviewer approves PR
           ↓
    PR merged (triggers workflow)
           ↓
    ✅ Automatically published to public repo
```

**Total approvals: 1**
- PR approval (private side)

---

## What Gets Cleaned Automatically

The workflow automatically removes:

### Files and Directories
- `.private/` - All internal docs, scripts, configs
- `*.log` - All log files
- `*_cache/` - R Markdown caches
- `*_files/` - R Markdown output directories
- `.github/workflows/publish-to-public.yml` - The workflow itself

### Commit History
- `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- `Co-Authored-By: Claude <noreply@anthropic.com>`
- Multiple consecutive blank lines (cleanup)

### What Stays
- Author/Committer metadata (ericscheier)
- All commit timestamps
- All R package code (`R/`, `man/`, `data-raw/`)
- All analysis code (`analysis/`, `research/`)
- Documentation (`README.md`, `DESCRIPTION`, etc.)

---

## Safety Features

### Built-in Protections

1. **Branch protection**: Prevents accidental direct pushes to `ready-for-public`
2. **Required approvals**: Ensures human review before publication
3. **Environment approval**: Second check before final push
4. **Force-with-lease**: Won't overwrite unexpected public repo changes
5. **Commit filtering**: Automatic AI attribution removal
6. **Full history**: git-filter-repo rewrites history cleanly

### Recovery Options

If something goes wrong:

**1. Stop a running workflow:**
```bash
# Go to Actions tab → Click running workflow → Cancel workflow
```

**2. Revert public repo:**
```bash
# Clone public repo
git clone https://github.com/ericscheier/net_energy_burden.git
cd net_energy_burden

# Find the commit to revert to
git log --oneline

# Force push to that commit
git reset --hard <commit-hash>
git push --force origin main
```

**3. Reset ready-for-public branch:**
```bash
# In private repo
git checkout ready-for-public
git reset --hard <safe-commit>
git push --force origin ready-for-public
```

---

## Monitoring and Notifications

### Email Notifications

GitHub will email you when:
- PR is created
- PR needs your review
- Workflow requires deployment approval
- Workflow completes (success or failure)

### Slack/Discord Integration (Optional)

You can add webhook notifications:

1. Go to private repo: Settings → Webhooks → Add webhook
2. Configure for:
   - Pull request reviews
   - Workflow runs
   - Push events on `ready-for-public`

---

## Troubleshooting

### Workflow doesn't trigger

**Check:**
- Is the branch name exactly `ready-for-public`?
- Is the workflow file pushed to the private repo?
- Is the workflow enabled? (Actions tab → Enable workflow)

**Fix:**
```bash
# Verify workflow file exists
ls .github/workflows/publish-to-public.yml

# Verify it's committed
git log --all --oneline -- .github/workflows/publish-to-public.yml

# Verify branch name
git branch -a | grep ready-for-public
```

### Approval request doesn't appear

**Check:**
- Is the `public-release` environment configured?
- Are you listed as a required reviewer?
- Do you have notifications enabled?

**Fix:**
1. Settings → Environments → public-release
2. Check "Required reviewers" includes you
3. Check your GitHub notification settings

### Workflow fails with authentication error

**Check:**
- Is `PUBLIC_REPO_TOKEN` secret set?
- Is the PAT expired?
- Does the PAT have `repo` and `workflow` scopes?

**Fix:**
1. Generate new PAT (see Step 1 above)
2. Update secret: Settings → Secrets and variables → Actions
3. Re-run the workflow

### Public repo has unexpected content

**Check:**
- Did the cleaning step complete?
- Check the workflow logs for errors

**Fix:**
```bash
# Review workflow logs
# Go to Actions tab → Click failed run → Check each step

# If needed, manually clean and re-run
bash .private/scripts/clean_for_public.sh
git add -A
git commit -m "Manual cleanup"
git push origin ready-for-public
```

---

## Alternative: Manual Trigger

If you need to publish without merging to `ready-for-public`:

1. Go to Actions tab
2. Select "Publish to Public Repository" workflow
3. Click "Run workflow"
4. Select branch: `package-transformation` (or any branch)
5. Click "Run workflow"

**Note:** This still requires environment approval if configured.

---

## Best Practices

1. **Regular syncs**: Merge to `ready-for-public` regularly to keep public repo current
2. **Clear PR descriptions**: Document what's changing in each release
3. **Test before publishing**: Run `R CMD check` before creating PR
4. **Review diffs carefully**: Check PR diff for any sensitive data
5. **Monitor workflow runs**: Check Actions tab after each publish
6. **Keep PAT fresh**: Set calendar reminders for PAT expiration
7. **Backup branches**: GitHub Actions creates backups during history rewriting

---

## Quick Reference

### Check what will be published
```bash
git diff ready-for-public..package-transformation
```

### View commit messages that will be cleaned
```bash
git log ready-for-public..package-transformation --pretty=full
```

### Test cleaning locally (doesn't affect remotes)
```bash
bash .private/scripts/sync_to_public.sh
# Then review the public-release branch
git log public-release --oneline -10
```

### Emergency: Stop everything
```bash
# Cancel running workflow (via GitHub UI)
# Then reset ready-for-public
git checkout ready-for-public
git reset --hard <last-good-commit>
git push --force origin ready-for-public
```

---

## See Also

- `.private/README.md` - General private development docs
- `.private/GITHUB_ACTIONS_SETUP.md` - Initial setup guide
- `.private/FILTER_CONFIG.yaml` - What gets filtered
- `.private/scripts/sync_to_public.sh` - Manual sync script
