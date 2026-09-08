# Branching Strategy

This document describes the branching strategy and deployment workflow
for the emburden R package.

## Table of Contents

- [Overview](#overview)
- [Branch Structure](#branch-structure)
- [Promotion Workflows](#promotion-workflows)
- [Developer Workflows](#developer-workflows)
- [Release Process](#release-process)
- [Manual Override](#manual-override)
- [Troubleshooting](#troubleshooting)

------------------------------------------------------------------------

## Overview

The emburden package uses a **GitFlow-inspired branching model** with
controlled promotion workflows and approval gates to ensure code quality
and stability through the deployment pipeline.

### Key Principles

1.  **Sequential flow only:** Code flows in one direction: Feature → Dev
    → Staging → Main → Public → CRAN
2.  **No bypassing:** Each stage must be completed successfully before
    moving to the next
3.  **Approval gates:** Critical promotions require manual approval
4.  **Automated validation:** CI checks run at every stage
5.  **Rollback capability:** All changes are versioned and can be
    reverted

### Deployment Pipeline

    ┌─────────────┐
    │  Feature    │  Developer creates feature branch
    │  Branches   │
    └──────┬──────┘
           │ PR + CI checks
           ↓
    ┌─────────────┐
    │     Dev     │  Integration branch (fast CI feedback)
    └──────┬──────┘
           │ promote-to-staging.yml (requires approval)
           ↓
    ┌─────────────┐
    │   Staging   │  Pre-production testing (multi-platform CI)
    └──────┬──────┘
           │ promote-to-main.yml (requires approval + version bump)
           ↓
    ┌─────────────┐
    │    Main     │  Production (private repo)
    └──────┬──────┘
           │ publish-to-public.yml (automatic)
           ↓
    ┌─────────────┐
    │   Public    │  Public repository (ericscheier/emburden)
    │    Repo     │
    └──────┬──────┘
           │ cran-release.yml (requires final approval)
           ↓
    ┌─────────────┐
    │    CRAN     │  Official R package repository
    └─────────────┘

------------------------------------------------------------------------

## Branch Structure

### `main` - Production Branch

**Purpose:** Production-ready code, synced to public repository

**Protection:** - Requires PR with approvals - Requires all status
checks to pass (ubuntu, windows, macos) - Requires `production-release`
environment approval - Linear history enforced - No direct commits
allowed

**Triggers:** - Creates version tags (`v*.*.*`) - Triggers GitHub
release creation - Syncs to public repository - Initiates CRAN
submission workflow

**Who can merge:** Only via promote-to-main.yml workflow after manual
approval

------------------------------------------------------------------------

### `staging` - Pre-Production Branch

**Purpose:** Final validation before production release

**Protection:** - Requires PR with approvals - Requires all status
checks to pass (ubuntu, windows, macos) - Requires `staging-promotion`
environment approval - Linear history enforced - No direct commits
allowed

**Validation:** - Multi-platform R CMD check (Ubuntu, Windows, macOS) -
Full test coverage - Workflow validation

**Who can merge:** Only via promote-to-staging.yml workflow after manual
approval

------------------------------------------------------------------------

### `dev` - Development Branch

**Purpose:** Integration branch for active development

**Protection:** - Requires PR - Auto-approval for safe changes (docs,
tests) - Manual review for code changes - Requires status checks to pass
(Ubuntu only - fast feedback) - Linear history enforced

**Validation:** - R CMD check (Ubuntu, release R only) - Test coverage -
Workflow validation

**Who can merge:** - Developers with approval - Auto-approved for
docs/tests changes via auto-approve-safe-changes.yml

------------------------------------------------------------------------

### Feature Branches

**Naming:** `feature/description`, `fix/description`, `docs/description`

**Purpose:** Individual feature development

**Protection:** None (developer responsibility)

**Merge target:** Always merge to `dev` branch via PR

**Lifecycle:** Delete after merge to dev

------------------------------------------------------------------------

## Promotion Workflows

### 1. Feature → Dev

**Trigger:** Manual PR creation

**Process:** 1. Developer creates PR from feature branch to `dev` 2. CI
runs R CMD check (Ubuntu only) and tests 3. Auto-approval if only
docs/tests changed 4. Manual approval required for code changes 5. PR
merges automatically after approval + CI pass

**Approval:** - None for docs/tests (auto-approved) - Code owner review
for R code changes

------------------------------------------------------------------------

### 2. Dev → Staging

**Workflow:** `.github/workflows/promote-to-staging.yml`

**Trigger:** Manual (via GitHub Actions UI)

**Process:** 1. Maintainer triggers “Promote Dev to Staging” workflow 2.
Workflow validates dev branch (R CMD check) 3. Creates promotion PR:
`dev` → `staging` 4. Requires manual approval via `staging-promotion`
environment 5. Auto-merges after approval 6. Creates promotion tag:
`staging/YYYYMMDD-HHMMSS`

**Approval:** Repository maintainer via staging-promotion environment

**When to promote:** - After feature development complete - All dev CI
checks passing - Ready for pre-production validation

------------------------------------------------------------------------

### 3. Staging → Main (Production Release)

**Workflow:** `.github/workflows/promote-to-main.yml`

**Trigger:** Manual (via GitHub Actions UI)

**Parameters:** - `version_bump`: patch \| minor \| major \| custom -
`custom_version`: (if version_bump=custom)

**Process:** 1. Maintainer triggers “Promote Staging to Main” workflow
2. Workflow validates staging (multi-platform R CMD check) 3. Bumps
version in DESCRIPTION, CITATION, .zenodo.json 4. Updates NEWS.md from
git commits 5. Creates release PR: `staging` → `main` 6. Requires manual
approval via `production-release` environment 7. Auto-merges after
approval 8. Creates version tag: `v*.*.*` 9. Creates GitHub release with
NEWS.md content 10. Triggers publish-to-public workflow 11. Triggers
CRAN release workflow

**Approval:** Repository maintainer via production-release environment

**When to promote:** - After staging validation complete - Ready for
public release - All stakeholders agree to release - CRAN submission
desired

**Version Bump Strategy:** - **patch** (0.5.20 → 0.5.21): Bug fixes,
minor improvements - **minor** (0.5.20 → 0.6.0): New features,
enhancements - **major** (0.5.20 → 1.0.0): Breaking changes, major
releases - **custom**: Specify exact version (e.g., for release
candidates)

------------------------------------------------------------------------

### 4. Main → Public Repo

**Workflow:** `.github/workflows/publish-to-public.yml`

**Trigger:** Automatic when GitHub release is published on main

**Process:** 1. Triggered automatically by GitHub release event 2. Full
CRAN validation (with vignettes) 3. Requires `cran-production`
environment approval 4. Cleans repository (removes private files, AI
attributions) 5. Force-pushes to public repository:
`ericscheier/emburden` 6. Pushes version tag to public repo 7. Creates
GitHub release on public repo

**Approval:** Repository maintainer via cran-production environment

**Automated cleaning:** - Removes `.private/` directory - Removes
`*.log` files - Removes `*_cache/` and `*_files/` directories - Removes
private workflow files - Strips AI attributions from commit messages

------------------------------------------------------------------------

### 5. Public Repo → CRAN

**Workflow:** `.github/workflows/cran-release.yml` (on public repo)

**Trigger:** Automatic when version tag pushed to public repo

**Process:** 1. Builds source package with vignettes 2. Runs full CRAN
checks 3. Provides instructions for manual CRAN submission 4. Uploads
tarball to GitHub release

**Note:** CRAN submission requires manual interaction and cannot be
fully automated

------------------------------------------------------------------------

## Developer Workflows

### Starting New Work

``` bash
# Ensure you're on dev and up to date
git checkout dev
git pull scheier dev

# Create feature branch
git checkout -b feature/my-new-feature

# Make your changes...
# Commit frequently
git add .
git commit -m "feat: Add new feature"

# Push to remote
git push scheier feature/my-new-feature
```

### Creating a Pull Request

``` bash
# Via GitHub CLI
gh pr create --base dev --head feature/my-new-feature \
  --title "Add new feature" \
  --body "Description of changes"

# Or via GitHub web UI
# Navigate to repository and click "New Pull Request"
```

### PR Guidelines

- **Title:** Use conventional commits format (`feat:`, `fix:`, `docs:`,
  etc.)
- **Description:** Explain what and why, not how
- **Tests:** Include tests for new features
- **Documentation:** Update docs and vignettes as needed
- **Changelog:** Notable changes should be mentioned (will auto-generate
  from commits)

### Auto-Approval for Safe Changes

PRs that **only** modify these files are auto-approved: - Documentation:
`*.md`, `man/`, `vignettes/` - Tests: `tests/` - Dev tools: `.github/`,
`.dev/`, `.lintr`, etc. - Data docs: `data-raw/`

All other changes require manual code review.

------------------------------------------------------------------------

## Release Process

### Preparing a Release

**1. Complete development on dev branch**

``` bash
# All features merged to dev
# All CI checks passing on dev
# Ready for staging validation
```

**2. Promote dev → staging**

``` bash
# Via GitHub Actions UI:
# Actions → "Promote Dev to Staging" → Run workflow
#
# Then approve the staging-promotion environment when PR is created
```

**3. Validate on staging**

``` bash
# Wait for multi-platform CI to complete
# Test the package manually if needed
# Verify all changes are ready for production
```

**4. Promote staging → main (production release)**

``` bash
# Via GitHub Actions UI:
# Actions → "Promote Staging to Main (Production Release)" → Run workflow
#   version_bump: patch | minor | major
#
# Workflow will:
# - Validate staging
# - Bump version automatically
# - Create release PR
#
# Then approve the production-release environment
```

**5. Automatic publishing**

``` bash
# After merge to main, workflows automatically:
# - Create version tag (v*.*.*)
# - Create GitHub release
# - Publish to public repo
# - Trigger CRAN submission workflow
```

**6. CRAN submission**

``` bash
# After publish-to-public completes:
# - Review CRAN workflow output
# - Download tarball from GitHub release
# - Submit via CRAN web form or email
```

### Hotfix Process

For critical bugs in production:

``` bash
# 1. Create hotfix branch from main
git checkout main
git pull scheier main
git checkout -b hotfix/critical-bug

# 2. Fix the bug
# ... make changes ...
git commit -m "fix: Critical bug in production"

# 3. Create PR to staging (not dev)
gh pr create --base staging --head hotfix/critical-bug

# 4. After merge to staging, promote to main immediately
# Use promote-to-main workflow

# 5. Backport to dev if needed
git checkout dev
git cherry-pick <hotfix-commit-sha>
git push scheier dev
```

------------------------------------------------------------------------

## Manual Override

### Emergency Procedures

**When to use:** Critical production issues only

**Process:** 1. Identify the issue and severity 2. Get approval from
repository owner 3. Create hotfix branch from affected branch 4. Apply
minimal fix 5. Follow expedited promotion process 6. Document in
post-mortem

### Bypassing Workflows

**NOT RECOMMENDED** but possible in emergencies:

``` bash
# Emergency push to main (requires admin)
# This bypasses all protections - use with extreme caution
git push --force scheier main

# Better: Use workflow_dispatch with skip_checks parameter
# Actions → promote-to-main → Run workflow → skip_checks: true
```

------------------------------------------------------------------------

## Troubleshooting

### CI Checks Failing

**Problem:** R CMD check fails on PR

**Solutions:** 1. Check error message in GitHub Actions log 2. Run
`R CMD check` locally: `devtools::check()` 3. Fix issues and push new
commit 4. CI will re-run automatically

### Merge Conflicts

**Problem:** PR has merge conflicts

**Solutions:**

``` bash
# Update your branch with latest dev
git checkout feature/my-feature
git fetch scheier dev
git merge scheier/dev

# Resolve conflicts manually
# ... edit files ...

git add .
git commit -m "chore: Resolve merge conflicts"
git push scheier feature/my-feature
```

### Promotion Workflow Stuck

**Problem:** Promotion workflow waiting for approval

**Solutions:** 1. Check GitHub Actions → Environments 2. Review and
approve the pending deployment 3. Workflow will resume automatically

### Version Bump Issues

**Problem:** Automated version bump created wrong version

**Solutions:** 1. Do NOT merge the release PR yet 2. Close the PR 3.
Manually edit DESCRIPTION, CITATION, .zenodo.json 4. Commit to staging:
`git commit -am "fix: Correct version number"` 5. Re-run promote-to-main
workflow with custom version

------------------------------------------------------------------------

## Configuration Reference

### GitHub Environments

| Environment          | Purpose         | Approvers  | Required For         |
|----------------------|-----------------|------------|----------------------|
| `staging-promotion`  | Dev → Staging   | Maintainer | Promotion to staging |
| `production-release` | Staging → Main  | Maintainer | Production releases  |
| `cran-production`    | Final CRAN gate | Maintainer | CRAN submission      |

### Branch Protection Rules

| Branch  | PR Required | Approvals | Status Checks     | Linear History |
|---------|-------------|-----------|-------------------|----------------|
| main    | ✅          | 1         | All (3 platforms) | ✅             |
| staging | ✅          | 1         | All (3 platforms) | ✅             |
| dev     | ✅          | 0\*       | Ubuntu only       | ✅             |

\*Auto-approved for docs/tests, manual review for code

### Status Checks

| Check | Branches | Platforms | Required |
|----|----|----|----|
| R-CMD-check | dev, staging, main | Ubuntu (dev), All (staging/main) | ✅ |
| test-coverage | dev, staging, main | Ubuntu only | ✅ |
| validate-workflows | dev, staging, main | Ubuntu only | ✅ |

------------------------------------------------------------------------

## Additional Resources

- [CODEOWNERS](https://emburden.org/.github/CODEOWNERS) - Code review
  requirements
- [BRANCH_PROTECTION_SETUP.md](https://emburden.org/BRANCH_PROTECTION_SETUP.md) -
  GitHub configuration
- [DEPRECATED_WORKFLOWS.md](https://emburden.org/workflows/DEPRECATED_WORKFLOWS.md) -
  Migration notes
- [CONTRIBUTING.md](https://emburden.org/CONTRIBUTING.md) - Contribution
  guidelines

------------------------------------------------------------------------

## Questions or Issues?

- **Workflow failures:** Check GitHub Actions logs and adjust code
- **Approval questions:** Contact repository maintainer
- **Feature requests:** Open an issue on GitHub
- **Emergency support:** Email <eric@scheier.org>
