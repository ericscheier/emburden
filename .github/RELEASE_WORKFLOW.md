# Controlled Release Workflow Guide

This document explains how the dual-approval controlled release workflow works for the emburden R package.

## Overview

The controlled release workflow provides a secure, multi-stage process for releasing new versions of the package. It includes **two manual approval gates** to ensure thorough review before publication.

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TRIGGER: Push v* tag                      │
│                  (e.g., git push origin v0.1.0)             │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 1: VALIDATION (Automatic)                            │
│  ✓ Version consistency check                                │
│  ✓ R CMD check (0 errors, 0 warnings)                       │
│  ✓ Test suite with coverage (≥70%)                          │
│  ✓ Build package tarball                                    │
│  ✓ Generate validation report                               │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  🚦 GATE 1: PRE-RELEASE REVIEW (Manual Approval Required)   │
│  → Reviewer examines validation report                      │
│  → Approves if all quality checks pass                      │
│  → Environment: "pre-release-review"                        │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 2: CREATE PRE-RELEASE (Automatic after approval)     │
│  ✓ Generate release notes from NEWS.md                      │
│  ✓ Create draft GitHub release                              │
│  ✓ Upload package tarball                                   │
│  ✓ Upload validation report                                 │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  🚦 GATE 2: PRODUCTION RELEASE (Final Approval Required)    │
│  → Reviewer examines draft release                          │
│  → Final sign-off before publication                        │
│  → Environment: "public-release"                            │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 3: PUBLISH RELEASE (Automatic after approval)        │
│  ✓ Publish GitHub release (triggers Zenodo archival)        │
│  ✓ Generate CRAN submission instructions                    │
│  ✓ Provide post-release checklist                           │
└─────────────────────────────────────────────────────────────┘
```

## Initial Setup

Before using the workflow for the first time, you must configure two GitHub Environments with protection rules.

### Step 1: Create "pre-release-review" Environment

1. Go to your GitHub repository
2. Navigate to **Settings** → **Environments**
3. Click **New environment**
4. Name: `pre-release-review`
5. Under **Environment protection rules**:
   - Enable **Required reviewers**
   - Add 1-2 team members who should review validation results
   - These reviewers will check that all tests pass and quality checks succeed
6. Click **Save protection rules**

### Step 2: Configure "public-release" Environment

If you already have a `public-release` environment, verify its settings. Otherwise:

1. In **Settings** → **Environments**, go to your existing `public-release` environment (or create a new one)
2. Name: `public-release`
3. Under **Environment protection rules**:
   - Enable **Required reviewers**
   - Add 1-2 DIFFERENT team members from Gate 1 (for independent review)
   - These reviewers will perform final sign-off before publication
   - **Optional**: Enable **Wait timer** (e.g., 60 minutes) for a cooling-off period
4. Click **Save protection rules**

### Step 3: Verify Workflow File

Ensure the workflow file exists at:
```
.github/workflows/controlled-release.yaml
```

This file should already be committed to the repository.

## How to Use the Workflow

### Preparing for a Release

1. **Update version number** in `DESCRIPTION` file:
   ```r
   Version: 0.1.0
   ```

2. **Update NEWS.md** with release notes:
   ```markdown
   # emburden 0.1.0

   ## New Features
   - Feature 1 description
   - Feature 2 description

   ## Bug Fixes
   - Fix 1 description

   ## Breaking Changes
   - None
   ```

3. **Commit all changes**:
   ```bash
   git add DESCRIPTION NEWS.md
   git commit -m "Prepare release 0.1.0"
   git push origin main
   ```

### Triggering a Release

#### Method 1: Git Tag (Recommended)

```bash
# Create annotated tag
git tag -a v0.1.0 -m "Release version 0.1.0"

# Push tag to GitHub (triggers workflow)
git push origin v0.1.0
```

#### Method 2: Manual Workflow Dispatch

1. Go to **Actions** tab in GitHub
2. Select **Controlled Release** workflow
3. Click **Run workflow**
4. Enter version (e.g., `0.1.0`)
5. Click **Run workflow**

### Monitoring the Release Process

#### Stage 1: Validation (5-10 minutes)

The workflow automatically runs:
- R CMD check on multiple platforms
- Full test suite with coverage analysis
- Package tarball build
- Version consistency verification

**What to watch for:**
- Check the **Actions** tab for progress
- All jobs should show green checkmarks
- Validation report will be generated

#### Gate 1: Pre-Release Review (Manual)

**You will receive a notification** when approval is needed.

**Reviewers should:**
1. Click the notification or go to **Actions** → Select the running workflow
2. Review the validation report artifact
3. Check that all quality metrics pass:
   - R CMD check: 0 errors, 0 warnings
   - Test coverage: ≥70%
   - Package builds successfully
4. Click **Review deployments** button
5. Select **pre-release-review** environment
6. Click **Approve and deploy** or **Reject**

#### Stage 2: Create Pre-Release (2-3 minutes)

After Gate 1 approval, the workflow automatically:
- Extracts release notes from NEWS.md
- Creates a draft GitHub release
- Uploads package tarball
- Uploads validation report

#### Gate 2: Production Release (Manual)

**Second approval notification** will be sent.

**Reviewers should:**
1. Go to **Releases** tab in GitHub
2. Review the draft release:
   - Check release notes are accurate
   - Verify tarball is attached
   - Confirm this is the correct version
3. Return to **Actions** tab
4. Click **Review deployments**
5. Select **production-release** environment
6. Click **Approve and deploy** or **Reject**

#### Stage 3: Publish Release (1-2 minutes)

After Gate 2 approval, the workflow automatically:
- Publishes the GitHub release
- Triggers Zenodo DOI archival (via Zenodo-GitHub integration)
- Generates CRAN submission instructions

## Post-Release Checklist

After the workflow completes:

### 1. Verify GitHub Release

- [ ] Go to **Releases** tab
- [ ] Confirm v0.1.0 is published (not draft)
- [ ] Verify tarball is downloadable
- [ ] Check release notes are correct

### 2. Verify Zenodo Archival

- [ ] Wait 5-10 minutes for Zenodo to process
- [ ] Refresh the GitHub release page
- [ ] Look for a Zenodo badge with DOI
- [ ] Click the badge to verify Zenodo record

### 3. Optional: Submit to CRAN

The workflow provides detailed CRAN submission instructions.

**Steps:**
1. Download the package tarball from the GitHub release
2. Go to https://cran.r-project.org/submit.html
3. Upload the tarball
4. Fill in submission form
5. Confirm maintainer email
6. Monitor email for CRAN feedback

**Typical timeline:**
- Initial automated checks: 1-2 hours
- Human review: 2-7 days
- Appears on CRAN: 24 hours after acceptance

### 4. Update Package Website (if applicable)

If you have a pkgdown website:
```bash
# Update website with new version
Rscript -e "pkgdown::build_site()"

# Deploy to GitHub Pages
git add docs/
git commit -m "Update website for v0.1.0"
git push
```

### 5. Announce Release

- [ ] Social media (Twitter, Mastodon, etc.)
- [ ] Mailing lists or forums
- [ ] Project collaborators
- [ ] Update README if needed

## Approval Best Practices

### For Gate 1 Reviewers (Pre-Release)

**Focus on:** Technical quality

✅ **Approve if:**
- All automated checks pass
- Test coverage meets threshold
- No errors or warnings in R CMD check
- Package builds successfully

❌ **Reject if:**
- Tests are failing
- Coverage is too low
- R CMD check shows errors/warnings
- Build fails

### For Gate 2 Reviewers (Production)

**Focus on:** Release readiness

✅ **Approve if:**
- Release notes are accurate and complete
- Version number is correct
- No last-minute concerns
- Ready for public release

❌ **Reject if:**
- Release notes missing or incorrect
- Wrong version number
- Need to make additional changes
- Not ready for publication

## Troubleshooting

### Workflow fails at validation stage

**Problem:** R CMD check fails, tests fail, or build errors

**Solution:**
1. Review the error logs in Actions tab
2. Fix the issues locally
3. Commit and push fixes
4. Delete the tag: `git tag -d v0.1.0 && git push origin :v0.1.0`
5. Recreate the tag after fixes

### Approval notification not received

**Problem:** Reviewer doesn't see approval request

**Solution:**
1. Check GitHub notification settings
2. Go directly to Actions tab → Select workflow
3. Look for "Review deployments" button
4. Click to approve/reject

### Need to cancel a release

**Problem:** Want to stop the release process

**Solution:**
1. **Before Gate 1:** Simply don't approve, workflow will timeout
2. **Between gates:** Reject at Gate 2
3. **After publication:** Cannot unpublish, must create new patch release

### Version mismatch error

**Problem:** "Tag version does not match DESCRIPTION version"

**Solution:**
1. Verify DESCRIPTION has correct version
2. Verify git tag matches (without 'v' prefix in DESCRIPTION)
3. Delete incorrect tag
4. Recreate with correct version

## Security Considerations

### Why Dual Approval?

- **Separation of concerns:** Technical review vs. release readiness
- **Prevents accidents:** Two people must agree to publish
- **Audit trail:** All approvals are logged in GitHub
- **Human oversight:** Catches issues automated tests might miss

### Who Should Be Reviewers?

**Gate 1 (Pre-Release):**
- Technical team members
- People familiar with R CMD check requirements
- Those who can interpret test results

**Gate 2 (Production):**
- Project maintainers
- People authorized to make releases
- Independent from Gate 1 reviewers (for true dual approval)

### Best Practice: Use Different Reviewers

For true dual approval, Gate 1 and Gate 2 should have **different reviewers**. This provides independent verification at each stage.

## Advanced Configuration

### Adjusting Coverage Threshold

Edit `.github/workflows/controlled-release.yaml`:

```yaml
if (covr_percent < 70) {  # Change 70 to your threshold
```

### Adding Wait Timer

In the `production-release` environment settings:
- Enable "Wait timer"
- Set duration (e.g., 60 minutes)
- Forces a cooling-off period before final approval

### Disabling Dual Approval (Not Recommended)

To use single approval:
1. Keep only `production-release` environment
2. Remove `pre-release-review` job from workflow
3. Update job dependencies

## FAQ

**Q: Can I skip the approval gates for urgent releases?**

A: No. The approvals are enforced by GitHub Environment protection rules. This is intentional for safety. If truly urgent, you can:
1. Use GitHub's "Bypass environment protection" feature (requires admin privileges)
2. Or manually publish a release outside this workflow

**Q: How long do approvals stay pending?**

A: By default, GitHub workflow runs timeout after 72 hours. Approve within that timeframe.

**Q: Can I approve my own releases?**

A: Yes, if you're listed as a reviewer, but this defeats the purpose of dual approval. Best practice is to have different people approve.

**Q: What happens if Zenodo doesn't create a DOI?**

A: Check that:
1. Zenodo-GitHub integration is enabled in repository settings
2. The repository is public
3. Wait 10-15 minutes for Zenodo to process
4. Check Zenodo dashboard for any errors

**Q: Can I test the workflow without publishing?**

A: Yes:
1. Create a test branch
2. Push a tag like `v0.0.1-test`
3. The workflow will run but you can reject at Gate 2
4. Delete the draft release afterward

## Related Documentation

- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution guidelines
- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Zenodo-GitHub Integration](https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content)
- [CRAN Submission Guidelines](https://cran.r-project.org/web/packages/policies.html)

## Support

If you encounter issues with the release workflow:

1. Check this documentation first
2. Review GitHub Actions logs for error details
3. Open an issue in the repository
4. Contact the package maintainer: eric.scheier@gmail.com

---

**Last Updated:** 2025-11-04
**Workflow Version:** 1.0
