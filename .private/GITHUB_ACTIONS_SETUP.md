# GitHub Actions Setup for Public Release

This guide explains how to set up and use the automated GitHub Actions workflow that publishes cleaned code to the public repository.

## Overview

The workflow automatically:
1. Cleans the repository (removes `.private/`, logs, caches)
2. Pushes the cleaned code to `ericscheier/net_energy_burden` (public repo)
3. Only runs when you explicitly trigger it (via tag or protected branch)

## Setup Steps

### 1. Create Personal Access Token (PAT)

You need a GitHub Personal Access Token with write access to the public repository:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: `net_energy_burden_publisher`
4. Set expiration (recommend: 90 days or 1 year, set calendar reminder to renew)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
6. Click "Generate token"
7. **IMPORTANT:** Copy the token immediately (you won't see it again!)

### 2. Add Token as Repository Secret

1. Go to **this** repository (private): Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `PUBLIC_REPO_TOKEN`
4. Value: Paste the PAT you created above
5. Click "Add secret"

### 3. Push the Workflow to GitHub

The workflow file already exists at `.github/workflows/publish-to-public.yml`.

Commit and push it:

```bash
git add .github/workflows/publish-to-public.yml
git commit -m "Add GitHub Actions workflow for public release"
git push origin package-transformation
```

## Usage

You have **three ways** to trigger the public release:

### Option 1: Tag-based Release (Recommended)

When you're ready to publish a version:

```bash
# Create and push a version tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Or use a release tag
git tag -a release-2024-10-31 -m "Release for October 31, 2024"
git push origin release-2024-10-31
```

The workflow will automatically:
- Clean the code
- Push to public repository
- Also push the tag to public repo

### Option 2: Protected Branch (Controlled)

1. Create a protected branch called `ready-for-public`:

```bash
# On GitHub: Settings → Branches → Add branch protection rule
# Branch name pattern: ready-for-public
# Enable: Require pull request reviews before merging
# Enable: Require approvals (at least 1)
```

2. When ready to publish:

```bash
# Create branch from current state
git checkout -b ready-for-public
git push origin ready-for-public

# Or merge into existing ready-for-public
git checkout ready-for-public
git merge package-transformation
git push origin ready-for-public
```

This gives you a review process before publishing.

### Option 3: Manual Trigger

1. Go to GitHub Actions tab in your private repository
2. Select "Publish to Public Repository" workflow
3. Click "Run workflow"
4. Select the branch to publish from
5. Click "Run workflow"

## Verification

After the workflow runs:

1. Check the workflow run in Actions tab
2. See the summary showing what was cleaned
3. Verify public repository: https://github.com/ericscheier/net_energy_burden
4. Check that `.private/` directory is NOT present in public repo

## What Gets Removed

The workflow removes:
- `.private/` directory (all internal docs, scripts, configs)
- `*.log` files
- `*_cache/` directories (R Markdown caches)
- `*_files/` directories (R Markdown outputs)
- The workflow file itself (`.github/workflows/publish-to-public.yml`)

## What Stays

Everything else:
- `R/` package code
- `man/` documentation
- `data-raw/` data preparation scripts
- `vignettes/` package vignettes
- `tests/` test files
- `analysis/` analysis scripts
- `research/` research files
- `README.md`, `DESCRIPTION`, `NAMESPACE`, `LICENSE`

## Troubleshooting

### Error: "Authentication failed"

- Check that `PUBLIC_REPO_TOKEN` secret is set correctly
- Verify the PAT has correct scopes (`repo` + `workflow`)
- Check if PAT has expired

### Error: "Remote already exists"

The workflow cleans up after itself, but if it fails midway:

```bash
# In the GitHub Actions runner, the public remote is temporary
# No action needed on your end
```

### Workflow doesn't trigger

- Check that the trigger matches what you did:
  - Tag must start with `v` or `release-`
  - Branch must be exactly `ready-for-public`
- Check the workflow file is pushed to GitHub
- Verify the workflow is enabled (Actions tab → Enable workflow)

### Public repo has wrong content

The workflow uses `--force-with-lease` for safety. If you need to force push:

1. Go to public repository locally
2. Reset to desired state
3. Force push: `git push --force origin main`

Or re-run the workflow after fixing the private repo.

## Best Practices

1. **Test first**: Use manual trigger to test before setting up automated triggers
2. **Review changes**: Check what will be published with `git diff`
3. **Use tags for versions**: Tags create clear release points
4. **Set PAT expiration reminders**: Don't let the PAT expire unexpectedly
5. **Monitor workflow runs**: Check the Actions tab after each publish

## Updating the Workflow

If you need to modify the workflow:

1. Edit `.github/workflows/publish-to-public.yml`
2. Test changes locally if possible
3. Commit and push
4. Test with manual trigger before relying on automatic triggers

## Security Notes

- The `PUBLIC_REPO_TOKEN` secret is only accessible to GitHub Actions
- The workflow only runs on this repository, not forks
- The token is never exposed in logs
- Use `--force-with-lease` instead of `--force` for safety

## Alternative: Manual Sync

If you prefer not to use GitHub Actions, you can still use the manual scripts:

```bash
# See .private/README.md for manual workflow
bash .private/scripts/sync_to_public.sh
```

## Questions?

See:
- `.private/README.md` - Manual workflow documentation
- `.private/FILTER_CONFIG.yaml` - What gets filtered
- `.private/scripts/sync_to_public.sh` - Manual sync script
