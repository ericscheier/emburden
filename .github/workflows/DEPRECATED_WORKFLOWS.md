# Deprecated Workflows

This document tracks workflows that have been deprecated and replaced by the new branching strategy.

## Branching Strategy Migration

**Date:** 2025-01-XX
**Migration:** Feature → Dev → Staging → Main branching model

### Deprecated Workflows

The following workflows have been **disabled** and replaced by the new promotion workflows:

#### 1. `auto-tag-on-version-bump.yml`

**Original Purpose:**
Automatically created git tags when DESCRIPTION version changed

**Replaced By:**
`promote-to-main.yml` - Version tagging is now part of the production release process

**Why Deprecated:**
- Version bumping is now controlled through staging → main promotions
- Tags are created explicitly during the promote-to-main workflow
- More control over when tags are created (only after full approval)

---

#### 2. `auto-release.yml`

**Original Purpose:**
Automatically created GitHub releases when version tags were pushed

**Replaced By:**
`promote-to-main.yml` - GitHub release creation is integrated into the production release workflow

**Why Deprecated:**
- Release creation is now part of the atomic promote-to-main workflow
- Ensures releases are only created after all validations pass
- Better integration with the promotion approval process

---

#### 3. `auto-merge-version-bumps.yml`

**Original Purpose:**
Automatically merged version bump PRs based on special tags

**Replaced By:**
`promote-to-staging.yml` and `promote-to-main.yml` - Controlled promotion workflows with approval gates

**Why Deprecated:**
- New branching model uses explicit promotion workflows with environment approvals
- Better control over what gets merged and when
- No special tagging mechanism needed - approvals are explicit
- Supports dev → staging and staging → main promotions

---

## New Workflow Architecture

### Promotion Workflows

| Workflow | Purpose | Approval Required |
|----------|---------|-------------------|
| `promote-to-staging.yml` | Dev → Staging | staging-promotion environment |
| `promote-to-main.yml` | Staging → Main (production release) | production-release environment |

### Supporting Workflows

| Workflow | Purpose |
|----------|---------|
| `auto-approve-safe-changes.yml` | Auto-approve PRs with only docs/tests changes |
| `R-CMD-check.yml` | Multi-platform CI (dev, staging, main) |
| `test-coverage.yml` | Code coverage tracking (all branches) |
| `publish-to-public.yml` | Sync main to public repo |
| `cran-release.yml` | CRAN submission (public repo) |

---

## Migration Notes

### For Developers

- **Version bumps:** Use `promote-to-main.yml` manual trigger, which automatically bumps version
- **Creating releases:** Releases are created automatically when staging → main promotion completes
- **Merging changes:** Use promotion workflows instead of direct PRs to main

### Rollback Plan

If the new branching strategy needs to be temporarily reverted:

1. Re-enable deprecated workflows by removing `if: false` condition
2. Update trigger branches back to `main` only
3. Disable promotion workflows

---

## Cleanup Schedule

**Phase 1 (Current):** Workflows disabled via `if: false` condition
**Phase 2 (After 30 days):** Move to `.github/workflows/deprecated/` directory
**Phase 3 (After 90 days):** Remove entirely from repository

---

**Questions?** See `.github/BRANCHING_STRATEGY.md` for full documentation of the new workflow.
