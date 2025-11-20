# CRAN Release Workflow

This GitHub Actions workflow automates the CRAN package validation and submission process for the `emburden` package.

## Overview

The workflow is triggered automatically when you push a version tag (e.g., `v0.5.7`, `v1.0.0`) and performs:

1. **CRAN Validation** - Runs `R CMD check --as-cran` on multiple platforms
2. **Manual Approval Gate** - Requires approval via GitHub environment `cran-production`
3. **Package Submission** - Prepares package for CRAN submission
4. **GitHub Release** - Creates a release with the source tarball

## Setup

### 1. Create GitHub Environment

You need to create a GitHub environment called `cran-production` with manual approval:

1. Go to your repository **Settings** → **Environments**
2. Click **New environment**
3. Name it: `cran-production`
4. Under **Deployment protection rules**, check **Required reviewers**
5. Add yourself (or maintainers) as required reviewers
6. Click **Save protection rules**

### 2. Configure Secrets (Optional)

If you want automatic CRAN submission (currently commented out in workflow):

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add a secret: `CRAN_EMAIL` with your CRAN maintainer email

## Usage

### Creating a CRAN Release

The workflow triggers automatically when you bump the version and push a tag:

```bash
# 1. Update version in DESCRIPTION file
vim DESCRIPTION  # Change Version: 0.5.7 to Version: 0.5.8

# 2. Commit the version bump
git add DESCRIPTION
git commit -m "Bump version to 0.5.8 for CRAN"
git push

# 3. The auto-tag workflow will create v0.5.8 tag automatically
# 4. The tag triggers this CRAN release workflow
```

**Or create the tag manually:**

```bash
git tag -a v0.5.8 -m "Release v0.5.8"
git push origin v0.5.8
```

### Workflow Steps

1. **Automatic Validation** (5-10 minutes)
   - Checks out code
   - Builds source package (`.tar.gz`)
   - Runs `R CMD check --as-cran`
   - Uploads check results and tarball as artifacts

2. **Manual Approval** (human intervention required)
   - GitHub sends you a notification
   - Go to **Actions** tab → Select the workflow run
   - Review the CRAN check results
   - Click **Review deployments** → **Approve** (or Reject)

3. **CRAN Submission** (after approval)
   - Downloads the validated tarball
   - Creates CRAN submission comments
   - Prepares for submission (currently manual)
   - Creates GitHub Release with tarball attached

## Manual CRAN Submission

The workflow currently **does not** auto-submit to CRAN (safety measure). Instead:

### Option 1: Via GitHub Release

1. Go to the [Releases page](https://github.com/ericscheier/emburden/releases)
2. Download the `.tar.gz` file from the release
3. Upload it manually at: https://cran.r-project.org/submit.html

### Option 2: Via R Console

```r
# Download the tarball from the GitHub release
tarball <- "emburden_0.5.8.tar.gz"

# Submit to CRAN
devtools::submit_cran(tarball)
```

### Option 3: Enable Auto-Submit (Advanced)

Uncomment this line in `.github/workflows/cran-release.yml`:

```yaml
# Rscript -e "devtools::submit_cran('$TARBALL', email = Sys.getenv('CRAN_EMAIL'))"
```

**Warning**: This will automatically submit to CRAN after approval. Make sure you're ready!

## Monitoring

### During Validation

Check the workflow run in the **Actions** tab:

```bash
# Via GitHub CLI
gh run list --workflow=cran-release.yml
gh run view <run-id>
```

### After Submission

1. **CRAN Incoming**: https://cran.r-project.org/incoming/
2. **Your Package Page**: https://cran.r-project.org/web/packages/emburden/
3. **CRAN Checks**: https://cran.r-project.org/web/checks/check_results_emburden.html

## Troubleshooting

### Check Failed with Errors

1. View the workflow run in **Actions** tab
2. Download the **cran-check-results** artifact
3. Review the `00check.log` and `00install.out` files
4. Fix issues and create a new version tag

### Approval Timed Out

GitHub environments have a timeout (default: 30 days). If you don't approve in time:

1. The workflow will be marked as "cancelled" or "timed out"
2. Simply push a new tag to re-trigger: `git push origin v0.5.8 --force` (if same version)
3. Or bump to a new version: `v0.5.9`

### No Reviewers Configured

If you see "This environment has no protection rules":

1. Go to **Settings** → **Environments** → **cran-production**
2. Add required reviewers
3. Re-run the workflow

## Best Practices

1. **Test locally first**: Run `R CMD check --as-cran` on your machine before pushing
2. **Review artifacts**: Download and inspect the check results before approving
3. **Version bumps**: Always update `DESCRIPTION`, `NEWS.md`, and `inst/CITATION`
4. **CRAN policy**: Review [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
5. **Submission frequency**: CRAN prefers infrequent submissions (not more than once every 1-2 months)

## Example Timeline

```
10:00 - Push v0.5.8 tag
10:01 - Workflow starts validation
10:08 - Validation complete, tarball uploaded
10:08 - Waiting for approval (manual step)
10:30 - Maintainer reviews and approves
10:31 - CRAN submission prepared
10:32 - GitHub release created
10:35 - Manual upload to CRAN (or auto-submit if enabled)
```

## Related Workflows

- **auto-tag-on-version-bump.yml** - Automatically creates version tags when `DESCRIPTION` changes
- **auto-release.yml** - Creates GitHub releases from version tags
- **publish-to-public.yml** - Syncs this repository to the public mirror

## References

- [CRAN Submission Policy](https://cran.r-project.org/web/packages/policies.html)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [devtools::submit_cran()](https://devtools.r-lib.org/reference/submit_cran.html)
