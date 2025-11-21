# Complete CRAN Submission Workflow Guide

This guide walks through the full process for submitting the `emburden` package to CRAN, from local validation to automated submission.

## Overview

The CRAN submission process has multiple validation layers:

```
Local Pre-flight → Git Push → Auto-tag → GitHub Actions → Win-builder → Manual Approval → Auto-submit
```

## Prerequisites

### 1. GitHub Setup (One-time)

- **GitHub Environment**: `cran-production` with manual approval requirement
  - Go to repository **Settings** → **Environments**
  - Create `cran-production` environment
  - Add yourself as required reviewer

- **GitHub Secrets**:
  - `CRAN_EMAIL`: Your CRAN maintainer email address
  - `PUBLIC_REPO_TOKEN`: Personal Access Token for triggering workflows

### 2. Local Setup (One-time)

- R packages: `devtools`, `rcmdcheck`, `usethis`
- Git configured with your name and email
- Optional: Set `CRAN_EMAIL` environment variable locally

```bash
# In your ~/.bashrc or ~/.zshrc
export CRAN_EMAIL="your.email@example.com"
```

## Full CRAN Release Process

### Step 1: Pre-flight Checks (Local)

Before making any version changes, ensure your package is CRAN-ready:

```bash
# Validate GitHub Actions workflow files
bash .dev/validate-workflows.sh

# Run comprehensive local validation
Rscript .dev/pre-tag-cran-check.R

# Optional: Also submit to Win-builder for Windows testing
Rscript .dev/pre-tag-cran-check.R --submit-winbuilder
```

This validation will:
- ✅ Validate GitHub Actions workflow YAML syntax (prevents tagging errors)
- ✅ Check version consistency across files
- ✅ Validate NEWS.md is updated
- ✅ Check git status
- ✅ Build source package
- ✅ Run R CMD check --as-cran
- ✅ Optionally submit to Win-builder

**If any checks fail, fix them before proceeding!**

**Note**: The workflow validation is critical - it prevents YAML syntax errors in GitHub Actions workflows from blocking the automated tagging and release process. The auto-tag workflow will also validate workflows before creating version tags as a safety gate.

### Step 2: Update Version and Documentation

Update three key files:

#### a. DESCRIPTION
```r
Version: 0.5.8  # Increment version
```

#### b. NEWS.md
```markdown
# emburden 0.5.8

## New Features
- Added new functionality...

## Bug Fixes
- Fixed issue with...

## Documentation
- Updated vignette...
```

#### c. inst/CITATION
```r
note = "R package version 0.5.8",
```

### Step 3: Run Pre-tag Validation Again

After version updates, validate everything again:

```bash
Rscript .dev/pre-tag-cran-check.R --submit-winbuilder
```

If Win-builder is enabled, wait ~30 minutes for email results before proceeding.

### Step 4: Commit and Push Version Bump

```bash
git add DESCRIPTION NEWS.md inst/CITATION
git commit -m "Bump version to 0.5.8 for CRAN submission"
git push
```

**This will automatically trigger:**
1. **auto-tag-on-version-bump.yml** - Creates `v0.5.8` tag
2. **auto-release.yml** - Creates GitHub release
3. **publish-to-public.yml** - Syncs to public repository
4. **cran-release.yml** - Starts CRAN validation workflow

### Step 5: Monitor GitHub Actions

The automated workflow will:

#### Phase 1: Validation (5-10 minutes)
```bash
# Check workflow status
gh run list --workflow=cran-release.yml

# Watch live
gh run watch
```

The validation phase:
- ✅ Builds source package (.tar.gz)
- ✅ Runs R CMD check --as-cran
- ✅ Submits to Win-builder (optional, ~30 min for results)
- ✅ Uploads artifacts

#### Phase 2: Manual Approval (Human Required)

GitHub will notify you when validation completes.

1. Go to **Actions** tab in GitHub
2. Click the running `CRAN Release` workflow
3. Review the check results
4. Click **Review deployments**
5. Select `cran-production`
6. Click **Approve and deploy**

**Before approving, verify:**
- ✅ R CMD check passed (0 errors, 0 warnings)
- ✅ Win-builder results received (check email)
- ✅ Package tarball uploaded
- ✅ All files up to date

#### Phase 3: Auto-submission (Automated)

After approval, the workflow automatically:
- ✅ Downloads validated tarball
- ✅ Generates CRAN submission comments
- ✅ Submits to CRAN via `devtools::submit_cran()`
- ✅ Creates GitHub release with tarball

### Step 6: CRAN Response

Within minutes to hours, you'll receive an email from CRAN:

**Possible responses:**

1. **Auto-check success** → Package accepted, published within 1-3 days
2. **Auto-check issues** → Fix and resubmit
3. **Manual review required** → CRAN team will email feedback

Monitor at:
- **CRAN Incoming**: https://cran.r-project.org/incoming/
- **Package page**: https://cran.r-project.org/web/packages/emburden/

## Repository Structure

This workflow works across your private and public repositories:

```
Private: ScheierVentures/emburden (working repo)
    ↓ (publish-to-public.yml)
Public: ericscheier/emburden (CRAN submission happens here)
```

**Important**: The CRAN release workflow runs on the **public repository** after the tag is synced from private.

## Quick Reference Commands

```bash
# Validate GitHub Actions workflows (prevents tagging issues)
bash .dev/validate-workflows.sh

# Pre-flight validation
Rscript .dev/pre-tag-cran-check.R --submit-winbuilder

# Version consistency check only
Rscript .dev/check-version-consistency.R

# Manual Win-builder submission
Rscript -e "devtools::check_win_release(email = Sys.getenv('CRAN_EMAIL'))"

# Check workflow status
gh run list --workflow=cran-release.yml
gh run view <run-id>

# Check existing tags
git tag -l "v*"

# Check existing releases
gh release list
```

## Triggering CRAN Submission for Existing Version

If you already have a tagged version (e.g., v0.5.7) and want to submit it to CRAN:

### Option 1: Manual Workflow Trigger (Safest)

```bash
# Trigger the workflow manually on the public repo
gh workflow run cran-release.yml --repo ericscheier/emburden
```

Then approve when validation completes.

### Option 2: Re-push Existing Tag

```bash
# Delete and recreate tag (forces workflow to run)
git tag -d v0.5.7
git push origin :refs/tags/v0.5.7
git tag -a v0.5.7 -m "Release v0.5.7"
git push origin v0.5.7
```

**Note**: Only do this if the tag hasn't been used for CRAN submission yet.

### Option 3: Wait for Next Version

If v0.5.7 has issues or you want to test the full workflow:
- Bump to v0.5.8
- Go through the complete process

## Troubleshooting

### Workflow Not Triggered

**Problem**: Version bump pushed but no tag created

**Solution**: Check auto-tag-on-version-bump workflow:
```bash
gh run list --workflow=auto-tag-on-version-bump.yml
```

The workflow requires:
- Version changed in DESCRIPTION
- Push to main branch
- PUBLIC_REPO_TOKEN configured

### CRAN Check Failures

**Problem**: R CMD check fails with errors/warnings

**Solution**:
1. Download check results artifact from GitHub Actions
2. Review `00check.log` and `00install.out`
3. Fix issues locally
4. Re-run pre-tag validation
5. Bump version and retry

### Win-builder Issues

**Problem**: Win-builder email shows errors

**Solution**:
- Win-builder is optional for approval decision
- Common issues: Windows-specific path problems, missing system deps
- If critical, fix and resubmit with new version
- If minor, note in CRAN submission comments

### Approval Timeout

**Problem**: Didn't approve within timeout window

**Solution**:
```bash
# Re-run the workflow
gh run rerun <run-id>

# Or create a new version tag
git push origin v0.5.8 --force  # if same version
# OR
# Bump to v0.5.9 and push
```

### CRAN Submission Failed

**Problem**: devtools::submit_cran() failed

**Solution**:
1. Check error in workflow logs
2. Common causes: network issues, CRAN temporarily down
3. Manual submission:
   ```bash
   # Download tarball from GitHub release
   wget https://github.com/ericscheier/emburden/releases/download/v0.5.8/emburden_0.5.8.tar.gz

   # Submit manually
   Rscript -e "devtools::submit_cran('emburden_0.5.8.tar.gz', email = Sys.getenv('CRAN_EMAIL'))"
   ```

## Best Practices

1. **Test locally first**: Always run pre-tag validation before pushing
2. **Check Win-builder**: Use `--submit-winbuilder` at least once before submission
3. **Version consistently**: Update all three files (DESCRIPTION, NEWS.md, CITATION)
4. **Review before approval**: Don't auto-approve; check results
5. **Timing**: CRAN prefers submissions no more than once per 1-2 months
6. **Communication**: Respond promptly to CRAN reviewer feedback

## Timeline Example

```
10:00 - Run pre-tag-cran-check.R locally
10:10 - Update version files (DESCRIPTION, NEWS.md, CITATION)
10:15 - Commit and push version bump
10:16 - Auto-tag creates v0.5.8 tag
10:17 - Publish-to-public syncs to public repo
10:18 - CRAN release workflow starts validation
10:25 - Validation complete (R CMD check passed)
10:25 - Win-builder submission sent (email arrives ~10:55)
10:55 - Review Win-builder results
11:00 - Approve deployment in GitHub
11:01 - Auto-submit to CRAN
11:02 - GitHub release created
11:05 - CRAN confirmation email received
11:30 - CRAN auto-check email (success/failure)
```

**Total time**: ~1-1.5 hours from start to CRAN submission

## Related Documentation

- `.github/workflows/CRAN-RELEASE.md` - Workflow technical details
- `.dev/pre-tag-cran-check.R` - Local validation script
- `.dev/check-version-consistency.R` - Version consistency checker
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
- [devtools documentation](https://devtools.r-lib.org/)

## Questions?

If you encounter issues not covered here:
1. Check workflow logs in GitHub Actions
2. Review CRAN emails carefully
3. Consult CRAN policy documentation
4. For workflow issues, check `.github/workflows/` configuration
