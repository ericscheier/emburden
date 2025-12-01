# Feature Integration Checklist

**Feature Name:** _[e.g., housing-dimensions, temporal-comparison, etc.]_
**Branch:** _[e.g., feature/housing-dimensions]_
**Target:** `dev`
**Date:** _[YYYY-MM-DD]_
**Author:** _[Your name]_

---

## Overview

Brief description of what this feature does and why it's being added:

_[2-3 sentences describing the feature]_

---

## Phase 1: Testing

### Test Coverage
- [ ] Created dedicated test file(s) in `tests/testthat/`
  - [ ] File(s): `_______________________`
  - [ ] Number of new test cases: `_______`
- [ ] Updated existing test files (if applicable)
  - [ ] File(s): `_______________________`
  - [ ] Number of new test cases: `_______`
- [ ] All tests pass locally (`devtools::test()`)
  - [ ] Total tests: `_______`
  - [ ] Pass: `_______`
  - [ ] Fail: `_______`
  - [ ] Skip: `_______`

### Test Categories Covered
- [ ] Unit tests for new functions
- [ ] Integration tests for feature workflow
- [ ] Edge cases and error handling
- [ ] Backward compatibility tests
- [ ] Performance tests (if applicable)

---

## Phase 2: Documentation

### Function Documentation
- [ ] Added/updated roxygen2 documentation
  - [ ] File(s): `_______________________`
  - [ ] All parameters documented with `@param`
  - [ ] Return values documented with `@return`
  - [ ] Examples added with `@examples`
  - [ ] Export status correct (`@export` or not)

### Vignettes
- [ ] Updated existing vignette(s)
  - [ ] Vignette(s): `_______________________`
  - [ ] Added section(s): `_______________________`
- [ ] Created new vignette (if needed)
  - [ ] Vignette: `_______________________`

### Package Metadata
- [ ] Updated `NEWS.md` with changelog entry
  - [ ] Version: `_______`
  - [ ] Category: `_______` (New Features / Enhancements / Bug Fixes)
  - [ ] Entry: `_______________________`
- [ ] Updated `DESCRIPTION` (if needed)
  - [ ] Version bumped: `_______`
  - [ ] Dependencies updated: `_______`
- [ ] Updated `inst/CITATION` (if needed)
  - [ ] What changed: `_______________________`

### Other Documentation
- [ ] Updated README.md (if needed)
- [ ] Created/updated technical documentation in `.dev/`
- [ ] Added code comments for complex logic

---

## Phase 3: Validation

### Local Checks
- [ ] `devtools::document()` completed successfully
- [ ] `devtools::test()` completed successfully
  - [ ] 0 errors
  - [ ] 0 failures
  - [ ] Acceptable warnings/notes (document below)
- [ ] `devtools::check()` completed successfully
  - [ ] 0 errors
  - [ ] Warnings: `_______` (acceptable: qpdf, time verification)
  - [ ] Notes: `_______`

### Code Quality
- [ ] No hardcoded file paths (use system.file, tempdir, etc.)
- [ ] No browser() or debug statements left in code
- [ ] Consistent coding style with package conventions
- [ ] Appropriate error messages and warnings
- [ ] No security vulnerabilities (XSS, SQL injection, etc.)

---

## Phase 4: Git Integration

### Branch Management
- [ ] Current branch: `_______`
- [ ] Target branch: `dev`
- [ ] Branch is up to date with latest `dev`
  - [ ] Ran: `git pull origin dev`
  - [ ] Resolved any merge conflicts

### Commit Preparation
- [ ] Reviewed all changed files
  - [ ] Number of files changed: `_______`
  - [ ] Files reviewed: YES / NO
- [ ] No unintended changes included
- [ ] No secrets or credentials in commits
- [ ] Removed debugging code and commented-out blocks

### Commit
- [ ] Staged appropriate files
- [ ] Created commit with descriptive message
  - [ ] Commit message: `_______________________`
  - [ ] Follows convention: `feat:` / `fix:` / `docs:` / `refactor:`
  - [ ] Commit SHA: `_______________________`

---

## Phase 5: CI/CD Validation

### Pre-Push
- [ ] Reviewed git log to verify commit history
- [ ] Confirmed no sensitive information in diff
- [ ] Ready to push to remote

### Push and CI
- [ ] Pushed to remote: `git push origin [branch]`
- [ ] CI workflow triggered on GitHub Actions
  - [ ] Workflow run ID: `_______________________`
  - [ ] Workflow URL: `_______________________`

### CI Results
- [ ] R CMD check passed on all platforms
  - [ ] Ubuntu: PASS / FAIL
  - [ ] macOS: PASS / FAIL
  - [ ] Windows: PASS / FAIL
- [ ] Test coverage workflow passed
  - [ ] Coverage %: `_______`
  - [ ] Coverage change: `_______`
- [ ] All checks green

### CI Issues (if any)
_[Document any CI failures and how they were resolved]_

---

## Phase 6: Staging Preparation

### Ready for Staging
- [ ] All CI checks passing
- [ ] Feature complete and tested
- [ ] Documentation complete
- [ ] No known issues or TODOs
- [ ] Reviewed by team (if applicable)

### Merge to Staging (when ready)
- [ ] Create PR: `dev` → `staging`
  - [ ] PR number: `_______`
  - [ ] PR URL: `_______________________`
- [ ] PR description includes feature summary and testing notes
- [ ] Linked to any relevant issues
- [ ] Ready for review

---

## Additional Notes

### Known Issues or Limitations
_[Document any known issues, limitations, or future improvements]_

### Dependencies
_[List any dependencies on other features or external packages]_

### Breaking Changes
_[Document any breaking changes and migration path]_

### Performance Impact
_[Note any performance implications, positive or negative]_

---

## Completion

**Integration Status:** ⬜ In Progress / ⬜ Complete / ⬜ Blocked

**Completed by:** _[Name]_
**Date completed:** _[YYYY-MM-DD]_
**Final commit SHA:** _[SHA]_

---

## Usage Example

For future reference, run the integration protocol with:

```bash
# Automated integration check
Rscript .dev/integrate-feature-to-dev.R --feature-name "your-feature-name"

# Skip R CMD check for faster iteration
Rscript .dev/integrate-feature-to-dev.R --feature-name "your-feature-name" --skip-check
```

---

**Template Version:** 1.0
**Last Updated:** 2025-11-25
