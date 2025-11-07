# GitHub Repository Setup - Development Workflow

**Date:** 2025-10-16
**Status:** Development branch ready, awaiting ScheierVentures repository creation

---

## Current State

### ✅ Completed

1. **Package transformation committed** to `package-transformation` branch
   - 37 files changed (6,448 insertions)
   - Commit message documents all changes
   - Perfect R CMD check score (0/0/0)

2. **Git remotes configured:**
   - `origin` → `git@github.com:ericscheier/net_energy_equity.git` (public)
   - `scheier` → `git@github.com:ScheierVentures/net_energy_equity.git` (development)

3. **Development branch created:** `package-transformation`

### ⏳ Pending

**ScheierVentures repository needs to be created** on GitHub before we can push.

---

## Next Steps

### Option 1: Create ScheierVentures Repository (Recommended)

**On GitHub:**
1. Go to https://github.com/ScheierVentures
2. Click "New repository"
3. Name: `net_energy_equity`
4. Make it **Private** (for development)
5. **DO NOT** initialize with README, .gitignore, or license (we have those)
6. Click "Create repository"

**Then from terminal:**
```bash
cd /home/ess/Documents/apps/net_energy_equity

# Push development branch to ScheierVentures
git push -u scheier package-transformation

# Verify
git branch -vv
```

### Option 2: Fork from Existing Repository

If you want to fork from ericscheier/net_energy_equity:

**On GitHub:**
1. Go to https://github.com/ericscheier/net_energy_equity
2. Click "Fork" button
3. Select "ScheierVentures" organization
4. Wait for fork to complete

**Then from terminal:**
```bash
cd /home/ess/Documents/apps/net_energy_equity

# Update remote URL to forked repo
git remote set-url scheier git@github.com:ScheierVentures/net_energy_equity.git

# Push development branch
git push -u scheier package-transformation
```

### Option 3: Work Locally First, Push Later

Continue working on package-transformation branch locally:

```bash
# Make changes
devtools::load_all()
devtools::test()
devtools::check()

# Commit locally
git add .
git commit -m "Description"

# Push when ScheierVentures repo is ready
git push -u scheier package-transformation
```

---

## Development Workflow

### Daily Development

```bash
# Ensure you're on development branch
git checkout package-transformation

# Make changes, test
devtools::load_all()
devtools::test()      # 52 tests should pass
devtools::check()     # 0/0/0

# Commit and push to development remote
git add .
git commit -m "Descriptive message"
git push scheier package-transformation
```

### When Ready for Public Release

```bash
# Ensure all tests pass
devtools::check()

# Merge to main
git checkout main
git merge package-transformation

# Push to public repository
git push origin main

# Tag the release
git tag -a v0.1.0 -m "Initial package release

- 11 exported functions
- 52 passing tests
- Complete documentation
- Ready for GitHub installation"

git push origin v0.1.0
git push scheier v0.1.0  # Also push to development remote
```

---

## Remote Strategy

### Purpose of Two Remotes

**`origin` (ericscheier/net_energy_equity) - Public**
- Main public repository
- Only push stable, release-ready code
- For users to install from: `devtools::install_github("ericscheier/net_energy_equity")`

**`scheier` (ScheierVentures/net_energy_equity) - Private**
- Development repository
- Can be messy, experimental
- Review and test before merging to origin
- Team collaboration space

### Keeping Them in Sync

```bash
# Fetch latest from both remotes
git fetch origin
git fetch scheier

# Update main from origin (if others made changes)
git checkout main
git pull origin main

# Update development branch
git checkout package-transformation
git rebase main  # or merge main

# Push to scheier
git push scheier package-transformation
```

---

## Current Branch Status

```bash
$ git branch -vv
* package-transformation d35d842 Transform to R package structure (0/0/0)
  main                   50b6c4a [origin/main] catching up
```

**Active branch:** `package-transformation`
**Commits ahead of main:** 1 (the transformation commit)

---

## What's in the Transformation Commit

### Files Created (22 new files)

**Package infrastructure:**
- `.Rbuildignore`, `.Rprofile`, `DESCRIPTION`, `NAMESPACE`
- `_pkgdown.yml` - Website configuration

**Source code:**
- `R/energy_ratios.R` - Energy metric functions
- `R/metrics.R` - Weighted statistics
- `R/formatting.R` - Output formatting
- `R/netenergyequity-package.R` - Package documentation
- `R/utils.R` - Pipe imports and globals

**Testing:**
- `tests/testthat.R`
- `tests/testthat/test-energy_ratios.R` - 21 tests
- `tests/testthat/test-formatting.R` - 31 tests

**CI/CD:**
- `.github/workflows/R-CMD-check.yaml`
- `.github/workflows/pkgdown.yaml`

**Documentation:**
- `NEWS.md`, `CHECK_RESULTS.md`, `STATUS.md`
- `PACKAGE_TRANSFORMATION.md`, `QUICK_START.md`

**Analysis separation:**
- `analysis/README.md`
- `analysis/scripts/*.R` - 8 analysis scripts
- `analysis/outputs/*.md` - Analysis documentation

**Utilities:**
- `cleanup_conflicts.R`

### Files Modified (1 file)

- `README.md` - Updated with package documentation

---

## Repository Size

**Before transformation:**
- Total size: ~1.7GB (with data files)
- Would fail package size checks

**After transformation:**
- Package tarball: 21KB (excludes data via .Rbuildignore)
- Repository: Still ~1.7GB (data stays in repo, just not distributed)
- Perfect for development, excludes properly for distribution

---

## Verification Commands

```bash
# Check remote configuration
git remote -v

# Check current branch
git branch -vv

# See what would be pushed to origin (should be nothing on package-transformation)
git log origin/main..package-transformation

# See changed files in commit
git show --stat package-transformation

# Verify package still works
devtools::load_all()
devtools::test()
devtools::check()
```

---

## Troubleshooting

### "Repository not found" when pushing to scheier

**Cause:** ScheierVentures/net_energy_equity doesn't exist yet

**Solution:** Create the repository on GitHub first (see "Option 1" above)

### Want to remove scheier remote

```bash
git remote remove scheier
```

### Want to rename branch

```bash
git branch -m package-transformation dev
```

### Want to squash commits before pushing to origin

```bash
git checkout main
git merge --squash package-transformation
git commit -m "Transform to R package structure"
```

---

## Summary

**Ready to push when ScheierVentures repository is created!**

The package transformation is complete, committed, and ready to push to a development repository. Once the ScheierVentures/net_energy_equity repository exists, simply run:

```bash
git push -u scheier package-transformation
```

Then continue development on that branch before eventually merging to main and pushing to the public origin.
