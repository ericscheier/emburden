# Release Automation Guide

Comprehensive guide for using the automated version bump and release workflow.

## Quick Start

```bash
# Fully automated release (no prompts)
bash .dev/release-version.sh 0.5.11 --auto

# Interactive release (recommended for first-time users)
bash .dev/release-version.sh 0.5.11

# Or manually with individual steps
Rscript .dev/bump-version.R 0.5.11
```

## Scripts Overview

### `release-version.sh` - Complete Release Automation (Recommended)

**Location**: `.dev/release-version.sh`

**What it does**:
1. ✅ Validates git repository state
2. ✅ Checks for uncommitted changes
3. ✅ Warns if not on main branch
4. ✅ Runs `bump-version.R` to update version files
5. ✅ Auto-creates NEWS.md template entry
6. ✅ Opens editor for NEWS.md editing
7. ✅ Shows git diff for review
8. ✅ Stages changes
9. ✅ Creates commit
10. ✅ Pushes to remote (optional)
11. ✅ Creates or updates pull request

**Usage**:
```bash
bash .dev/release-version.sh 0.5.11
```

**Features**:
- Interactive prompts with sensible defaults
- Color-coded output (success, warnings, errors)
- Comprehensive error handling
- Safe defaults (won't push without confirmation)
- Automatic NEWS.md template generation
- Editor integration (respects $EDITOR, falls back to nano/vi)
- **NEW: `--auto` flag for fully automated releases (no prompts)**

### `bump-version.R` - Version File Updater

**Location**: `.dev/bump-version.R`

**What it does**:
- Updates `DESCRIPTION`
- Updates `inst/CITATION` (both version references)
- Updates `.zenodo.json`
- Validates semantic versioning format
- Shows summary of updated files

**Usage**:
```bash
Rscript .dev/bump-version.R 0.5.11
```

**Standalone mode** (when you want manual control):
```bash
# 1. Update version files
Rscript .dev/bump-version.R 0.5.11

# 2. Manually edit NEWS.md

# 3. Review changes
git diff

# 4. Stage and commit
git add DESCRIPTION inst/CITATION .zenodo.json NEWS.md
git commit -m "Bump version to 0.5.11"

# 5. Push and create PR
git push scheier <branch-name>
gh pr create --base main --head <branch-name>

# Note: Git tag will be created automatically by auto-tag-on-version-bump
#       workflow after the PR is merged to main
```

## Versioning Format

Follows **semantic versioning**: `MAJOR.MINOR.PATCH`

Examples:
- `0.5.11` - Standard release
- `0.5.11.9001` - Development version (optional)

Pattern validation:
- Must match: `^\d+\.\d+\.\d+(\.\d{4})?$`
- Valid: `0.5.11`, `1.0.0`, `0.5.11.9001`
- Invalid: `0.5`, `v0.5.11`, `0.5.11-beta`

## NEWS.md Template

When `release-version.sh` creates a NEWS.md entry, it uses this template:

```markdown
# emburden 0.5.11

## Changes

### New Features

* (Add new features here)

### Bug Fixes

* (Add bug fixes here)

### Enhancements

* (Add enhancements here)

---
```

**Guidelines**:
- Use clear, concise bullet points
- Group related changes together
- Include PR/issue references if applicable
- Focus on user-facing changes
- Delete unused sections

## Workflow Integration

The release automation integrates with your CI/CD pipeline:

```
release-version.sh (local)
         ↓
    [Push commit to branch]
         ↓
    [Create/update PR]
         ↓
    [Merge PR to main]
         ↓
  auto-tag-on-version-bump.yml (creates git tag on main)
         ↓
  auto-release.yml (creates GitHub release)
         ↓
  publish-to-public.yml (syncs to public repo)
         ↓
  cran-release.yml (public repo - manual approval)
```

## Safety Features

### Pre-flight Checks
- ✅ Validates git repository exists
- ✅ Checks for DESCRIPTION and NEWS.md files
- ✅ Validates semantic versioning format
- ✅ Warns about uncommitted changes
- ✅ Warns if not on main branch

### Interactive Confirmation
- Confirms changes before committing
- Asks before pushing to remote
- Shows full diff for review
- Allows custom commit messages
- Supports aborting at any step

### Error Handling
- Uses `set -euo pipefail` for strict error checking
- Colored error messages
- Descriptive exit codes
- Clean failure modes

## Environment Variables

### `$EDITOR`
Controls which editor opens NEWS.md:
```bash
# Use VS Code
export EDITOR="code --wait"

# Use Emacs
export EDITOR="emacs"

# Use nano (default fallback)
export EDITOR="nano"
```

Falls back to: `nano` → `vi` → manual edit

## Troubleshooting

### "You have uncommitted changes"
```bash
# Option 1: Commit them first
git add .
git commit -m "Pre-release cleanup"

# Option 2: Stash them
git stash

# Then retry
bash .dev/release-version.sh 0.5.11
```

### "Not on main branch"
```bash
# Switch to main
git checkout main

# Or continue anyway (script will warn)
# The script allows this but warns you
```

### Script execution permission denied
```bash
chmod +x .dev/release-version.sh
```

## Automation Modes

### Fully Automated Mode (`--auto`)

**NEW FEATURE**: Use the `--auto` flag for completely automated releases with no interactive prompts.

```bash
bash .dev/release-version.sh 0.5.11 --auto
```

**What it does automatically**:
- ✅ Continues despite uncommitted changes (with warning)
- ✅ Continues if not on main branch (with warning)
- ✅ Skips NEWS.md editor (uses template)
- ✅ Skips diff review
- ✅ Uses default commit message
- ✅ Automatically pushes to remote

**When to use `--auto`**:
- CI/CD pipeline automation
- Rapid iteration during development
- When you trust the automated process
- When you've already reviewed changes manually

**When NOT to use `--auto`**:
- First time using the script
- Major version releases
- When you need to write detailed NEWS.md entries
- When you're unsure about the changes

### Interactive Mode (Default)

```bash
bash .dev/release-version.sh 0.5.11
```

Prompts for confirmation at each step. Recommended for:
- First-time releases
- Important releases
- When you want to review each step

## Examples

### Standard Release
```bash
# Interactive release (recommended for first use)
bash .dev/release-version.sh 0.5.11

# Script will:
# 1. Update version files
# 2. Open NEWS.md for editing
# 3. Show diff
# 4. Ask for confirmation
# 5. Commit and tag
# 6. Ask to push
```

### Fully Automated Release
```bash
# Zero-prompt release
bash .dev/release-version.sh 0.5.11 --auto

# Script will:
# 1. Update version files
# 2. Auto-create NEWS.md template (no editor)
# 3. Show diff (no confirmation)
# 4. Commit with default message
# 5. Push automatically
# 6. Create/update PR automatically
```

### Development Version
```bash
# Create development version
bash .dev/release-version.sh 0.5.11.9001
```

### Manual Control (Don't Push)
```bash
# Run script but decline push
bash .dev/release-version.sh 0.5.11

# At "Push to remote?" prompt, answer: n

# Now you can:
# - Test locally
# - Make additional changes
# - Push manually later
```

### Custom Commit Message
```bash
bash .dev/release-version.sh 0.5.11

# At "Use default commit message?" prompt, answer: n
# Then enter custom message in editor
```

## Best Practices

1. **Always run from project root**
   ```bash
   cd /path/to/net_energy_equity
   bash .dev/release-version.sh 0.5.11
   ```

2. **Update NEWS.md thoughtfully**
   - Document all user-facing changes
   - Group related changes
   - Reference issues/PRs
   - Delete unused sections

3. **Review the diff**
   - Check version numbers are correct
   - Verify CITATION date updates
   - Ensure NEWS.md is complete

4. **Test before pushing**
   - Decline push option
   - Run local tests
   - Build package
   - Then push manually if needed

5. **Follow semantic versioning**
   - Patch (0.5.X): Bug fixes
   - Minor (0.X.0): New features (backwards compatible)
   - Major (X.0.0): Breaking changes

## Advanced Usage

### Dry Run
```bash
# Update version files without committing
Rscript .dev/bump-version.R 0.5.11
git diff
git checkout -- DESCRIPTION inst/CITATION .zenodo.json
```

### Batch Multiple Files
```bash
# If you need to update additional files
bash .dev/release-version.sh 0.5.11

# Before answering "y" to commit:
# Press Ctrl+C to abort
# Make additional changes
# Manually stage and commit all files together
```

### Skip NEWS.md Update
```bash
# Pre-populate NEWS.md before running
vim NEWS.md  # Add entry manually
bash .dev/release-version.sh 0.5.11
# Script will detect existing entry
```

## Comparison: Automated vs Manual

### With `release-version.sh` (Recommended)
```bash
bash .dev/release-version.sh 0.5.11
# → 8 steps automated, ~2 minutes
```

### Manual Process
```bash
Rscript .dev/bump-version.R 0.5.11
vim NEWS.md
git diff DESCRIPTION inst/CITATION .zenodo.json NEWS.md
git add DESCRIPTION inst/CITATION .zenodo.json NEWS.md
git commit -m "Bump version to 0.5.11"
git push scheier <branch>
gh pr create --base main
# [Wait for merge, then workflow creates tag]
# → 7 manual steps, ~5 minutes, error-prone
```

## Related Documentation

- [CRAN Submission Guide](.dev/CRAN-SUBMISSION-GUIDE.md)
- [Workflow Documentation](.github/workflows/README.md)
- [Version Consistency Checker](.dev/check-version-consistency.R)

## Support

For issues or questions:
1. Check this guide
2. Review `.dev/bump-version.R` comments
3. Inspect `.dev/release-version.sh` implementation
4. File an issue with clear reproduction steps
