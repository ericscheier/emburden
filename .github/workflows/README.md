# Workflow Organization

This document explains how release workflows are organized between the private and public repositories.

## Private Repository (ScheierVentures/emburden)

**Workflows:**
- `auto-release.yml` - Automatic GitHub release creation
  - Triggers: Push tags matching `v*` (e.g., v0.5.9)
  - Creates initial GitHub release with release notes
  - Triggers `publish-to-public.yml` to sync to public repo

- `publish-to-public.yml` - Syncs releases to public repository
  - Triggered by auto-release workflow
  - Pushes code and tags to ericscheier/emburden

**Purpose:** Quick, automatic releases that publish to the public repository

## Public Repository (ericscheier/emburden)

**Workflows:**
- `controlled-release.yaml` - CRAN submission workflow (**lives in public repo**)
  - Triggers: Manual workflow_dispatch only
  - Updates existing GitHub release (created by auto-release)
  - Comprehensive CRAN validation (R CMD check --as-cran, Win-builder)
  - Dual approval gates (pre-release-review, public-release)
  - CRAN submission guidance

**Purpose:** CRAN releases with approval gates and comprehensive validation

## Release Process

### Regular Release (GitHub only)
1. Push version tag from private repo: `git tag v0.5.9 && git push origin v0.5.9`
2. auto-release.yml creates GitHub release
3. publish-to-public.yml syncs to public repo
4. Done!

### CRAN Release
1. Complete regular release process above
2. Go to public repo Actions tab
3. Manually trigger "Controlled Release" workflow
4. Approve at pre-release-review gate (after validation)
5. Approve at public-release gate (final approval)
6. Follow CRAN submission instructions from workflow output

## Why This Organization?

- **Separation of concerns**: Auto-release handles fast GitHub releases, controlled-release handles CRAN
- **No conflicts**: Workflows don't compete for same release
- **CRAN from public repo**: CRAN submissions should come from the public repository
- **Flexible**: Can do GitHub releases without CRAN, or add CRAN validation later
