# Branch Protection & Environment Setup

This document describes the manual GitHub configuration required for the branching strategy.

## Branch Protection Rules

These must be configured via GitHub UI: `Settings` → `Branches` → `Branch protection rules`

### 1. `dev` Branch Protection

**Pattern:** `dev`

**Settings:**
- ✅ Require a pull request before merging
  - ✅ Require approvals: **0** (auto-approve safe changes via workflow)
  - ✅ Dismiss stale pull request approvals when new commits are pushed
  - ❌ Require review from Code Owners (optional for feature → dev)
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - **Required status checks:**
    - `ubuntu-latest (release)` (from R-CMD-check)
    - `test-coverage` (from test-coverage)
- ✅ Require conversation resolution before merging
- ✅ Require linear history (no merge commits)
- ✅ Do not allow bypassing the above settings
- ❌ Allow force pushes (disabled)
- ❌ Allow deletions (disabled)

**Rationale:** Dev is the integration branch. All feature work merges here first. We want basic CI checks but allow auto-approval for safe changes (docs, tests).

---

### 2. `staging` Branch Protection

**Pattern:** `staging`

**Settings:**
- ✅ Require a pull request before merging
  - ✅ Require approvals: **1**
  - ✅ Dismiss stale pull request approvals when new commits are pushed
  - ✅ Require review from Code Owners
  - ✅ Restrict who can dismiss pull request reviews (Admins only)
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - **Required status checks:**
    - `ubuntu-latest (release)` (from R-CMD-check)
    - `windows-latest (release)` (from R-CMD-check)
    - `macos-latest (release)` (from R-CMD-check)
    - `test-coverage` (from test-coverage)
    - `validate-workflows` (from validate-workflows)
- ✅ Require deployments to succeed before merging
  - **Required environment:** `staging-promotion`
- ✅ Require conversation resolution before merging
- ✅ Require linear history
- ✅ Do not allow bypassing the above settings
- ❌ Allow force pushes (disabled)
- ❌ Allow deletions (disabled)

**Rationale:** Staging is pre-production. Only promoted from dev after full multi-platform validation and manual approval. This is the final testing ground before main.

---

### 3. `main` Branch Protection

**Pattern:** `main`

**Settings:**
- ✅ Require a pull request before merging
  - ✅ Require approvals: **1**
  - ✅ Dismiss stale pull request approvals when new commits are pushed
  - ✅ Require review from Code Owners
  - ✅ Restrict who can dismiss pull request reviews (Admins only)
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - **Required status checks:**
    - `ubuntu-latest (release)` (from R-CMD-check)
    - `windows-latest (release)` (from R-CMD-check)
    - `macos-latest (release)` (from R-CMD-check)
    - `test-coverage` (from test-coverage)
    - `validate-workflows` (from validate-workflows)
- ✅ Require deployments to succeed before merging
  - **Required environment:** `production-release`
- ✅ Require conversation resolution before merging
- ✅ Require signed commits (optional but recommended)
- ✅ Require linear history
- ✅ Do not allow bypassing the above settings
- ❌ Allow force pushes (disabled)
- ❌ Allow deletions (disabled)
- ✅ Lock branch (optional: prevent all pushes)

**Rationale:** Main is production. Only accepts promotions from staging. Triggers version bumps, CRAN submission, and public repo publishing. Maximum protection.

**Note:** Main already has protection configured. Verify it matches the above settings.

---

## GitHub Environments

These must be configured via GitHub UI: `Settings` → `Environments`

### 1. `dev-deployment`

**Purpose:** Auto-deploy to development environment (if applicable)

**Protection rules:**
- ❌ Required reviewers: None (auto-deploy)
- ✅ Deployment branches: Only `dev` branch

**Environment secrets:** (if needed)
- None currently required

---

### 2. `staging-promotion`

**Purpose:** Manual approval gate for dev → staging promotions

**Protection rules:**
- ✅ Required reviewers: **You** (repository owner/maintainer)
- ⏱️ Wait timer: **0 minutes** (immediate after approval)
- ✅ Deployment branches: Only `dev` branch (via promote-to-staging workflow)

**Environment secrets:**
- None required

**Approval strategy:**
- Reviewer verifies all dev CI passes
- Reviewer confirms feature completion
- Reviewer checks changelogs/release notes
- Manual approval triggers promotion merge

---

### 3. `production-release`

**Purpose:** Manual approval gate for staging → main promotions (production releases)

**Protection rules:**
- ✅ Required reviewers: **You** (repository owner/maintainer)
- ⏱️ Wait timer: **0 minutes** (immediate after approval)
- ✅ Deployment branches: Only `staging` branch (via promote-to-main workflow)

**Environment secrets:**
- None required

**Approval strategy:**
- Reviewer verifies all staging CI passes (including multi-platform)
- Reviewer confirms staging testing complete
- Reviewer reviews version bump strategy
- Manual approval triggers:
  - Version bump (DESCRIPTION, CITATION, .zenodo.json)
  - Merge to main
  - Git tag creation
  - Public repo publishing
  - CRAN release workflow trigger

---

### 4. `cran-production` (Already exists)

**Purpose:** Final approval for CRAN submission

**Protection rules:**
- ✅ Required reviewers: **You**
- ⏱️ Wait timer: **0 minutes**
- ✅ Deployment branches: Only `main` branch

**Environment secrets:**
- `CRAN_EMAIL` - Email for CRAN submission

**Note:** Keep as-is. Used by existing `cran-release.yml` workflow.

---

## CODEOWNERS File

Create `.github/CODEOWNERS` to enforce code review requirements.

**Required for:**
- Dev → Staging promotions (require staging-promotion environment approval)
- Staging → Main promotions (require production-release environment approval)
- Critical files (DESCRIPTION, workflows, etc.)

See `.github/CODEOWNERS` (to be created in Phase 2).

---

## Workflow Triggers

After configuration, workflows will trigger as follows:

| Workflow | Trigger | Branches | Purpose |
|----------|---------|----------|---------|
| R-CMD-check | push, PR | dev, staging, main | Multi-platform validation |
| test-coverage | push, PR | dev, staging, main | Code coverage reporting |
| validate-workflows | push, PR | dev, staging, main | Workflow syntax validation |
| promote-to-staging | manual | dev → staging | Promote dev to staging |
| promote-to-main | manual | staging → main | Release to production |
| auto-approve-safe-changes | PR | dev | Auto-approve docs/tests |
| publish-to-public | tag push | main only | Sync to public repo |
| cran-release | tag push | main only | Submit to CRAN |

---

## Setup Checklist

Use this checklist to configure GitHub settings:

### Branch Protection
- [ ] Configure `dev` branch protection rules
- [ ] Configure `staging` branch protection rules
- [ ] Verify `main` branch protection rules (already exists)

### Environments
- [ ] Create `dev-deployment` environment
- [ ] Create `staging-promotion` environment (add yourself as required reviewer)
- [ ] Create `production-release` environment (add yourself as required reviewer)
- [ ] Verify `cran-production` environment exists with `CRAN_EMAIL` secret

### Code Owners
- [ ] Create `.github/CODEOWNERS` file
- [ ] Verify CODEOWNERS enforcement is enabled in branch protection

### Workflow Files
- [ ] Deploy `promote-to-staging.yml`
- [ ] Deploy `promote-to-main.yml`
- [ ] Deploy `auto-approve-safe-changes.yml`
- [ ] Update `R-CMD-check.yml` for multi-branch
- [ ] Update `test-coverage.yml` for multi-branch
- [ ] Update `publish-to-public.yml` to only trigger from main
- [ ] Remove `auto-merge-version-bumps.yml`
- [ ] Update `auto-tag-on-version-bump.yml` (or remove if redundant)

### Documentation
- [ ] Create `BRANCHING_STRATEGY.md`
- [ ] Update `CONTRIBUTING.md` with new workflow
- [ ] Create `.dev/promote.sh` helper script
- [ ] Update `.dev/release-version.sh` script

---

## Notes

- **Main branch already protected:** The main branch currently has protection requiring PRs and status checks. Verify these match the requirements above.
- **Environment approvals are critical:** Without proper environment configuration, promotions will auto-merge without human review.
- **Linear history:** All branches require linear history (rebase, no merge commits) for cleaner git history.
- **Status checks:** Workflows must complete successfully before merges are allowed. Failing CI blocks all promotions.
