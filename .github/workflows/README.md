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
  - Triggers: Automatically when release is published (synced from private repo)
  - Also supports manual workflow_dispatch as fallback
  - Updates existing GitHub release (created by auto-release)
  - Comprehensive CRAN validation (R CMD check --as-cran, Win-builder)
  - Dual approval gates (pre-release-review, public-release)
  - CRAN submission guidance

**Purpose:** CRAN releases with automatic triggering, approval gates, and comprehensive validation

## Release Process

### Regular Release (GitHub only)
1. Push version tag from private repo: `git tag v0.5.9 && git push origin v0.5.9`
2. auto-release.yml creates GitHub release
3. publish-to-public.yml syncs to public repo
4. Done!

### CRAN Release (Automatic)
1. Complete regular release process above
2. CRAN workflow triggers automatically in public repo
3. Workflow runs comprehensive CRAN validation
4. Approve at pre-release-review gate (after reviewing validation results)
5. Approve at public-release gate (final approval)
6. Follow CRAN submission instructions from workflow output

**Note:** The workflow can also be triggered manually via Actions tab if needed

## Why This Organization?

- **Separation of concerns**: Auto-release handles fast GitHub releases, controlled-release handles CRAN
- **No conflicts**: Workflows don't compete for same release
- **CRAN from public repo**: CRAN submissions should come from the public repository
- **Flexible**: Can do GitHub releases without CRAN, or add CRAN validation later
