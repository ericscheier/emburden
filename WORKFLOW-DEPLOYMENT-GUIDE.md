# Workflow Deployment Guide

This guide explains how to deploy the automatic CRAN workflow with
approval gates to the public repository.

## Architecture Overview

The workflow system uses a **two-repository architecture** with
automatic triggering and dual approval gates:

    PRIVATE REPO (ScheierVentures/emburden)
    │
    ├── Push tag v0.6.0
    │   └── auto-release.yml triggers
    │       ├── Creates GitHub release (fast, ~10 seconds)
    │       └── Triggers publish-to-public.yml
    │           └── Syncs release and tags to PUBLIC REPO
    │
    PUBLIC REPO (ericscheier/emburden)
    │
    ├── Release published event triggers controlled-release.yaml AUTOMATICALLY
    │   ├── STAGE 1: CRAN validation (R CMD check, Win-builder, etc.)
    │   ├── GATE 1: Pre-release review (manual approval required)
    │   ├── STAGE 2: Update release with CRAN artifacts
    │   ├── GATE 2: Final CRAN approval (manual approval required)
    │   └── STAGE 3: CRAN submission guidance

## Key Features

✅ **Automatic Trigger**: Workflow starts automatically when release is
synced to public repo ✅ **Dual Approval Gates**: Two independent
reviewers must approve before CRAN submission ✅ **Comprehensive
Validation**: R CMD check –as-cran, Win-builder, URL checks, spell check
✅ **No Conflicts**: Auto-release creates release first, CRAN workflow
updates it later ✅ **Private-to-Public Flow**: Maintains secure
development in private repo

## Files Created

### `controlled-release-public.yaml`

The automatic CRAN release workflow for the public repository
(ericscheier/emburden).

**Location:**
`/home/ess/Documents/apps/net_energy_equity/controlled-release-public.yaml`

**Key Differences from Manual Approach:** - Triggers automatically on
`release: types: [published]` event - Still includes `workflow_dispatch`
for manual triggering if needed - Updates existing release (doesn’t
create new one) - Runs after auto-release completes successfully

## Deployment Steps

### 1. Ensure PR \#56 is Merged

PR \#56 removes the conflicting `controlled-release.yaml` from the
private repository. Verify it’s merged:

``` bash
gh pr view 56 --json state,title
```

### 2. Deploy Workflow to Public Repository

You’ll need to manually add the workflow file to the public repository
(ericscheier/emburden):

``` bash
# Option A: Manual upload via GitHub UI
1. Go to https://github.com/ericscheier/emburden
2. Navigate to .github/workflows/
3. Find existing controlled-release.yaml (or create new file)
4. Replace entire contents with controlled-release-public.yaml
5. Commit directly to main branch

# Option B: Via git (if you have write access)
cd /path/to/ericscheier/emburden
cp /home/ess/Documents/apps/net_energy_equity/controlled-release-public.yaml .github/workflows/controlled-release.yaml
git add .github/workflows/controlled-release.yaml
git commit -m "feat: Update to automatic CRAN workflow with dual approval gates

- Triggers automatically on release published events
- Maintains dual approval gates (pre-release-review and public-release)
- Updates existing releases with CRAN artifacts
- Keeps manual trigger option via workflow_dispatch"
git push origin main
```

### 3. Verify GitHub Environments (Public Repo)

In the public repository (ericscheier/emburden), verify these two
environments exist:

**Environment 1: `pre-release-review`** - Go to Settings →
Environments - Verify environment exists with “Required reviewers”
enabled - Should have 1-2 reviewers configured - If missing, create: -
Go to Settings → Environments → New environment - Name:
`pre-release-review` - Enable “Required reviewers” - Add 1-2 reviewers
who will review CRAN validation results

**Environment 2: `public-release`** - Go to Settings → Environments -
Verify environment exists with “Required reviewers” enabled - Should
have 1-2 reviewers (preferably different from pre-release-review) -
Optional: Enable “Wait timer” for cooling-off period - If missing,
create it with required reviewers

### 4. (Optional) Add CRAN_EMAIL Secret

For automatic Win-builder submission: - Go to Settings → Secrets and
variables → Actions - Add repository secret: `CRAN_EMAIL` - Value: Your
CRAN maintainer email address

## How the Automatic Workflow Works

### For Regular GitHub Releases (Fast - ~10 seconds)

1.  Push tag from private repo:
    `git tag v0.6.0 && git push origin v0.6.0`
2.  `auto-release.yml` creates GitHub release in private repo
3.  `publish-to-public.yml` syncs to public repo
4.  Public repo now has the release
5.  **CRAN workflow triggers automatically** when release is published
6.  Done! Fast release created, CRAN validation runs in background

### CRAN Validation Workflow (Automatic with Approval Gates)

After the fast release is created, the CRAN workflow runs automatically:

1.  **STAGE 1 - Validation** (automatic, ~5-10 minutes):
    - Checkout code at release tag
    - Run R CMD check –as-cran
    - Submit to Win-builder for Windows validation
    - Run URL validation
    - Run spell check
    - Build package tarball
    - Generate validation report
2.  **GATE 1 - Pre-Release Review** (manual approval required):
    - Reviewer sees validation report
    - Reviews Win-builder email results (~30 min after submission)
    - Approves if all checks pass
3.  **STAGE 2 - Update Release** (automatic after approval):
    - Downloads package tarball and validation report
    - Updates existing GitHub release with CRAN artifacts
    - Attaches tarball and validation report to release
4.  **GATE 2 - Final CRAN Approval** (manual approval required):
    - Second reviewer verifies everything is ready
    - Reviews final checklist
    - Approves for CRAN submission
5.  **STAGE 3 - CRAN Guidance** (automatic after approval):
    - Provides detailed CRAN submission instructions
    - Links to download tarball
    - Provides submission checklist

### Manual Trigger (If Needed)

You can still trigger the CRAN workflow manually:

1.  Go to public repo Actions tab:
    <https://github.com/ericscheier/emburden/actions>
2.  Select “Controlled Release” workflow
3.  Click “Run workflow”
4.  Enter version number (e.g., 0.6.0)
5.  Workflow runs with same approval gates

## Benefits of This Architecture

✅ **Automatic Triggering**: No need to manually start CRAN workflow ✅
**No Conflicts**: Auto-release creates release first, CRAN workflow
updates it ✅ **Fast GitHub Releases**: Auto-release completes in ~10
seconds ✅ **Thorough CRAN Validation**: Comprehensive checks run
automatically ✅ **Dual Approval Gates**: Two independent reviewers must
approve ✅ **Public Repository**: CRAN submissions come from public repo
(as intended) ✅ **Flexible**: Manual trigger still available if needed
✅ **Private Development**: Development happens in private repo securely

## Troubleshooting

### Workflow Doesn’t Trigger Automatically

**Problem**: CRAN workflow doesn’t start after release is synced to
public repo.

**Check**: 1. Verify workflow file exists in public repo:
`.github/workflows/controlled-release.yaml` 2. Check workflow has
correct trigger: `on: release: types: [published]` 3. Look for workflow
errors in Actions tab

### Approval Gate Blocked

**Problem**: Workflow waits at approval gate indefinitely.

**Solution**: 1. Go to Actions tab in public repo 2. Find the running
workflow 3. Click on the job waiting for approval 4. Review validation
results 5. Approve via the environment approval UI

### Win-builder Results Not Received

**Problem**: Win-builder email doesn’t arrive.

**Check**: 1. Verify `CRAN_EMAIL` secret is set correctly 2. Check spam
folder for win-builder emails 3. Wait up to 60 minutes (service can be
slow) 4. Win-builder step is optional - you can proceed without it if
needed

## Testing the Workflow

To test the workflow without creating a real release:

1.  Use the manual trigger option
2.  Pick an existing version (e.g., 0.5.9)
3.  Workflow will run validation and stop at approval gates
4.  You can review the process without completing CRAN submission

## Next Steps After Deployment

1.  **Test the workflow**: Push a test tag to verify automatic
    triggering
2.  **Update documentation**: Update any README or wiki pages that
    reference the workflow
3.  **Train reviewers**: Ensure reviewers know how to use GitHub
    Environment approvals
4.  **Monitor first run**: Watch the first automatic run to ensure
    everything works

## Notes

- CRAN submissions remain manual per CRAN requirements
- The workflow guides you through submission but doesn’t auto-submit
- Approval gates ensure quality control before CRAN submission
- Win-builder validation is optional but recommended
