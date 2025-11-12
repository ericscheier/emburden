# Release Process Documentation

This document describes the automated and semi-automated release process for the emburden package.

## Overview

The release process consists of three main stages:

1. **Development & Testing** (automatic via CI)
2. **Version Bumping & Tagging** (semi-automatic with helper scripts)
3. **Controlled Release** (automatic with manual approval gates)

## Stage 1: Development & Testing (Automatic)

When you push code or create a PR:

- ✅ **Automatic**: R CMD check runs on multiple platforms
- ✅ **Automatic**: Test coverage calculated
- ✅ **Automatic**: Package documentation built (pkgdown)

**No manual intervention required** - all checks run automatically via GitHub Actions.

## Stage 2: Version Bumping & Tagging (Semi-Automatic)

When you're ready to create a new release:

### Option A: Use Helper Script (Recommended)

1. **Bump version** (updates all metadata files consistently):
   ```bash
   Rscript .dev/bump-version.R 0.3.0
   ```

   This updates:
   - `DESCRIPTION`
   - `inst/CITATION`
   - `.zenodo.json`
   - `NEWS.md` (adds template section)

2. **Edit NEWS.md** to add release notes for the new version

3. **Commit and push changes**:
   ```bash
   git add -A
   git commit -m "Bump version to 0.3.0"
   git push scheier main
   ```

4. **Create release tag** (automatic validation + tagging):
   ```bash
   Rscript .dev/create-release-tag.R
   ```

   This script:
   - ✅ Verifies version consistency across all files
   - ✅ Checks that tag doesn't already exist
   - ✅ Extracts release notes from NEWS.md
   - ✅ Creates annotated git tag
   - ✅ Pushes tag to trigger release workflow
   - ✅ Provides instructions for monitoring progress

   **Dry run mode** (preview without creating tag):
   ```bash
   Rscript .dev/create-release-tag.R --dry-run
   ```

### Option B: Manual Process

If you prefer to do it manually:

```bash
# 1. Verify version consistency
Rscript .dev/check-version-consistency.R

# 2. Create annotated tag
git tag -a v0.3.0 -m "Release version 0.3.0

Your release notes here..."

# 3. Push tag
git push scheier v0.3.0
```

## Stage 3: Controlled Release (Automatic with Approval Gates)

Once the tag is pushed, the **Controlled Release** workflow automatically:

### 1. Validation (Automatic)

- Runs R CMD check on all platforms
- Runs full test suite with coverage checks
- Builds package tarball
- Generates validation report

### 2. Gate 1: Pre-Release Review (Manual Approval Required)

⚠️ **Manual approval required** via GitHub Actions UI

Review the validation report and approve if all checks pass.

### 3. Create Draft Release (Automatic)

- Creates draft GitHub release
- Uploads package tarball
- Uploads validation report
- Extracts release notes from NEWS.md

### 4. Gate 2: Production Release Approval (Manual Approval Required)

⚠️ **Manual approval required** via GitHub Actions UI

Final review before publishing the release.

### 5. Publish Release (Automatic)

- Publishes GitHub release
- Triggers Zenodo archival (automatic DOI assignment)
- Provides instructions for optional CRAN submission

## Monitoring Releases

### Check workflow status:

```bash
# List recent release workflows
gh run list --workflow="Controlled Release" --limit 5

# Watch current release in real-time
gh run watch --workflow="Controlled Release"

# View specific run details
gh run view <run-id>
```

### View releases:

```bash
# List all releases
gh release list

# View specific release
gh release view v0.2.0
```

## Helper Scripts

All helper scripts are in `.dev/` directory:

| Script | Purpose | Usage |
|--------|---------|-------|
| `bump-version.R` | Update version across all metadata files | `Rscript .dev/bump-version.R 0.3.0` |
| `check-version-consistency.R` | Verify versions match across files | `Rscript .dev/check-version-consistency.R` |
| `create-release-tag.R` | Automated tag creation with validation | `Rscript .dev/create-release-tag.R` |
| `run-tests-locally.R` | Run full test suite locally | `Rscript .dev/run-tests-locally.R` |

## Approval Gates Setup

The workflow requires two GitHub Environments with required reviewers:

### Environment: `pre-release-review`
- Required reviewers: 1-2 maintainers
- Reviews validation results before creating draft release

### Environment: `public-release`
- Required reviewers: 1-2 different maintainers (for dual approval)
- Final approval before publishing release

To configure environments:
1. Go to Settings → Environments → New environment
2. Add environment name
3. Enable "Required reviewers"
4. Add reviewers

## CRAN Submission (Optional, Manual)

CRAN submissions are **always manual** and done by the package maintainer:

1. Download package tarball from GitHub release
2. Review CRAN submission checklist
3. Submit to https://cran.r-project.org/submit.html
4. Monitor email for CRAN automated checks
5. Respond to any reviewer feedback

The workflow provides instructions after successful release publication.

## What's Automated vs Manual

| Task | Automation Level |
|------|-----------------|
| CI checks on PRs | ✅ Fully automatic |
| Test coverage reports | ✅ Fully automatic |
| Package documentation build | ✅ Fully automatic |
| Version bumping | ⚙️ Semi-automatic (helper script) |
| Release tag creation | ⚙️ Semi-automatic (helper script) |
| Validation stage | ✅ Fully automatic (triggered by tag) |
| Pre-release review | ⚠️ Manual approval required |
| Draft release creation | ✅ Fully automatic (after approval) |
| Production release approval | ⚠️ Manual approval required |
| Release publication | ✅ Fully automatic (after approval) |
| Zenodo archival | ✅ Fully automatic (triggered by release) |
| CRAN submission | ⚠️ Always manual |

## Quick Reference: Full Release Workflow

```bash
# 1. Bump version and update NEWS.md
Rscript .dev/bump-version.R 0.3.0
# Edit NEWS.md to add release notes

# 2. Commit and push
git add -A
git commit -m "Bump version to 0.3.0"
git push scheier main

# 3. Create and push release tag (with automatic validation)
Rscript .dev/create-release-tag.R

# 4. Monitor workflow
gh run watch --workflow="Controlled Release"

# 5. Approve at Gate 1 (via GitHub UI)
#    Review validation report, then approve in Actions tab

# 6. Approve at Gate 2 (via GitHub UI)
#    Final review before publication

# 7. Release is published automatically
#    Zenodo DOI assigned automatically

# 8. (Optional) Submit to CRAN manually
#    Download tarball from release and submit to CRAN
```

## Benefits of This Process

1. **Consistency**: Version numbers always in sync across all metadata files
2. **Safety**: Dual approval gates prevent accidental releases
3. **Automation**: Reduces manual steps and potential errors
4. **Validation**: Comprehensive checks before any release
5. **Reproducibility**: All releases have associated DOIs via Zenodo
6. **Transparency**: Full audit trail in GitHub Actions

## Troubleshooting

### Tag already exists

```bash
# Delete local tag
git tag -d v0.2.0

# Delete remote tag
git push scheier --delete v0.2.0

# Try again
Rscript .dev/create-release-tag.R
```

### Version mismatch errors

```bash
# Check what's inconsistent
Rscript .dev/check-version-consistency.R

# Use bump-version to fix
Rscript .dev/bump-version.R 0.2.0
```

### Workflow fails

```bash
# View failure details
gh run view --log-failed

# Check specific job
gh run view --job=<job-id>
```

## Future Improvements

Potential automation enhancements:

1. **Auto-create tags on version bumps**: Workflow that auto-tags when DESCRIPTION version changes on main branch
2. **Auto-CRAN submission**: Once stable, could automate CRAN submissions
3. **Release notes from commits**: Auto-generate release notes from commit messages
4. **Automated dependency updates**: Dependabot for R package dependencies

These can be added incrementally as the release process matures.
