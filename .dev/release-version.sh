#!/bin/bash

# release-version.sh
# Comprehensive version bump and release automation script
# Usage: bash .dev/release-version.sh <new_version> [--auto]
# Example: bash .dev/release-version.sh 0.5.11
# Example (fully automated): bash .dev/release-version.sh 0.5.11 --auto

set -euo pipefail

# Auto mode flag
AUTO_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${BLUE}$1${NC}"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    while true; do
        read -rp "$prompt" response
        response=${response:-$default}
        case "$response" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Check if we're in the project root
if [[ ! -f "DESCRIPTION" ]] || [[ ! -f "NEWS.md" ]]; then
    error "Must be run from project root (DESCRIPTION and NEWS.md not found)"
fi

# Parse arguments
if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
    error "Usage: $0 <new_version> [--auto]\nExample: $0 0.5.11\nExample (automated): $0 0.5.11 --auto"
fi

NEW_VERSION="$1"

# Check for --auto flag
if [[ $# -eq 2 ]]; then
    if [[ "$2" == "--auto" ]]; then
        AUTO_MODE=true
        info "Auto mode enabled: will run without interactive prompts"
    else
        error "Unknown flag: $2\nUsage: $0 <new_version> [--auto]"
    fi
fi

# Validate semantic versioning format
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]{4})?$ ]]; then
    error "Version must follow semantic versioning format (e.g., 0.5.11 or 0.5.11.9001)"
fi

info "============================================================"
info "Release Automation Script"
info "New version: $NEW_VERSION"
info "============================================================"
echo ""

# Check git status
info "[Step 1/9] Checking git repository status..."
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    warning "You have uncommitted changes:"
    git status --short
    echo ""
    if [[ "$AUTO_MODE" != "true" ]]; then
        if ! prompt_yes_no "Continue anyway?"; then
            error "Aborted by user"
        fi
        echo ""
    else
        info "Auto mode: continuing despite uncommitted changes"
        echo ""
    fi
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    warning "Not on main branch (currently on: $CURRENT_BRANCH)"
    if [[ "$AUTO_MODE" != "true" ]]; then
        if ! prompt_yes_no "Continue anyway?"; then
            error "Aborted by user"
        fi
        echo ""
    else
        info "Auto mode: continuing on branch $CURRENT_BRANCH"
        echo ""
    fi
fi

# Check if tag already exists
if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    error "Tag v$NEW_VERSION already exists!"
fi

success "Git repository check passed"
echo ""

# Run the R version bump script
info "[Step 2/9] Running version bump script..."
if ! Rscript .dev/bump-version.R "$NEW_VERSION"; then
    error "Version bump script failed"
fi
echo ""

# Update NEWS.md
info "[Step 3/9] Updating NEWS.md..."

# Check if NEWS.md already has this version
if grep -q "^# emburden $NEW_VERSION" NEWS.md; then
    success "NEWS.md already contains entry for version $NEW_VERSION"
else
    # Create NEWS template
    NEWS_TEMPLATE="# emburden $NEW_VERSION

## Changes

### New Features

* (Add new features here)

### Bug Fixes

* (Add bug fixes here)

### Enhancements

* (Add enhancements here)

---

"

    # Insert at top of NEWS.md (after first line if it's a title)
    if [[ -f NEWS.md ]]; then
        # Create temporary file with new entry
        {
            echo "$NEWS_TEMPLATE"
            cat NEWS.md
        } > NEWS.md.tmp
        mv NEWS.md.tmp NEWS.md
        success "Added template entry to NEWS.md"
    else
        echo "$NEWS_TEMPLATE" > NEWS.md
        success "Created NEWS.md with template"
    fi

    # Open in editor (skip in auto mode)
    if [[ "$AUTO_MODE" != "true" ]]; then
        if [[ -n "${EDITOR:-}" ]]; then
            info "Opening NEWS.md in $EDITOR for editing..."
            $EDITOR NEWS.md
        elif command -v nano >/dev/null 2>&1; then
            info "Opening NEWS.md in nano for editing..."
            nano NEWS.md
        elif command -v vi >/dev/null 2>&1; then
            info "Opening NEWS.md in vi for editing..."
            vi NEWS.md
        else
            warning "No editor found. Please manually edit NEWS.md"
            info "Press Enter when done editing..."
            read -r
        fi
    else
        info "Auto mode: skipping NEWS.md editing (using template)"
    fi
fi
echo ""

# Show changes
info "[Step 4/9] Review changes..."
echo ""
git diff DESCRIPTION inst/CITATION .zenodo.json NEWS.md || true
echo ""

if [[ "$AUTO_MODE" != "true" ]]; then
    if ! prompt_yes_no "Do the changes look correct?"; then
        error "Aborted by user"
    fi
    echo ""
else
    info "Auto mode: automatically accepting changes"
    echo ""
fi

# Stage files
info "[Step 5/9] Staging files..."
git add DESCRIPTION inst/CITATION .zenodo.json NEWS.md
success "Files staged"
echo ""

# Commit
info "[Step 6/9] Creating commit..."
COMMIT_MSG="Bump version to $NEW_VERSION"

if [[ "$AUTO_MODE" == "true" ]]; then
    info "Auto mode: using default commit message"
    git commit -m "$COMMIT_MSG"
else
    if prompt_yes_no "Use default commit message: '$COMMIT_MSG'?"; then
        git commit -m "$COMMIT_MSG"
    else
        info "Enter custom commit message (press Ctrl+D when done):"
        git commit
    fi
fi
success "Committed changes"
echo ""

# Create tag
info "[Step 7/9] Creating git tag..."
TAG_NAME="v$NEW_VERSION"
git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
success "Created tag: $TAG_NAME"
echo ""

# Push to remote
info "[Step 8/9] Push to remote..."
if [[ "$AUTO_MODE" == "true" ]] || prompt_yes_no "Push commit and tag to remote 'scheier'?"; then
    if [[ "$AUTO_MODE" == "true" ]]; then
        info "Auto mode: automatically pushing to remote"
    fi

    info "Pushing commit to $CURRENT_BRANCH..."
    git push scheier "$CURRENT_BRANCH"

    info "Pushing tag $TAG_NAME..."
    git push scheier "$TAG_NAME"

    success "Pushed to remote!"
    echo ""

    # Create or update PR
    info "[Step 9/9] Creating or updating pull request..."

    # Check if PR already exists from this branch to main
    EXISTING_PR=$(gh pr list --head "$CURRENT_BRANCH" --base main --json number --jq '.[0].number' 2>/dev/null || echo "")

    if [[ -n "$EXISTING_PR" ]]; then
        info "PR already exists: #$EXISTING_PR"
        PR_URL=$(gh pr view "$EXISTING_PR" --json url --jq '.url')
        success "Using existing PR: $PR_URL"
    else
        info "No existing PR found, creating new PR..."

        # Generate PR title from commit message
        LAST_COMMIT_MSG=$(git log -1 --pretty=%s)
        PR_TITLE="${LAST_COMMIT_MSG:-Release v$NEW_VERSION}"

        # Extract NEWS.md entry for this version
        NEWS_CONTENT=""
        if [[ -f NEWS.md ]]; then
            # Extract content between "# emburden $NEW_VERSION" and the next "# emburden" or "---"
            NEWS_CONTENT=$(awk "/^# emburden $NEW_VERSION/,/^(# emburden|---)/ {
                if (\$0 !~ /^(# emburden|---)/) print
            }" NEWS.md | sed 's/^## /### /' | sed 's/^### Changes/## Changes/')
        fi

        # Generate PR body with version info
        PR_BODY="## Version $NEW_VERSION Release
${NEWS_CONTENT:+
$NEWS_CONTENT
}
### Commits in this PR

$(git log main..HEAD --pretty=format:'- %s' --reverse)

### Version Files Updated

- \`DESCRIPTION\`
- \`inst/CITATION\`
- \`.zenodo.json\`
- \`NEWS.md\`

### Automated Release Process

This PR was created by \`release-version.sh\` and includes:
- Version bump to $NEW_VERSION
- Git tag: $TAG_NAME
- Updated NEWS.md with release notes

### Next Steps

After merging:
1. Auto-tag-on-version-bump workflow will trigger
2. Auto-release workflow creates GitHub release
3. Publish-to-public workflow syncs to public repo
4. CRAN release workflow runs on public repo (manual approval required)
"

        # Create the PR
        if PR_URL=$(gh pr create --base main --head "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" 2>&1); then
            success "Created PR: $PR_URL"
        else
            warning "Failed to create PR automatically"
            info "You can create it manually with:"
            info "  gh pr create --base main --head $CURRENT_BRANCH"
            PR_URL=""
        fi
    fi
    echo ""

    info "============================================================"
    info "Release automation complete!"
    info ""
    info "Version: $NEW_VERSION"
    info "Tag: $TAG_NAME"
    info "Branch: $CURRENT_BRANCH"
    if [[ -n "$PR_URL" ]]; then
        info "Pull Request: $PR_URL"
    fi
    info ""
    info "Next steps:"
    info "  1. Review and merge the pull request"
    info "  2. Monitor auto-tag-on-version-bump workflow"
    info "  3. Check auto-release workflow creates GitHub release"
    info "  4. Verify publish-to-public workflow syncs to public repo"
    info "  5. Monitor CRAN release workflow on public repo"
    info "============================================================"
else
    warning "Skipped push to remote"
    echo ""
    info "============================================================"
    info "Local release preparation complete!"
    info ""
    info "Version: $NEW_VERSION"
    info "Tag: $TAG_NAME (created locally)"
    info ""
    info "To push manually:"
    info "  git push scheier $CURRENT_BRANCH"
    info "  git push scheier $TAG_NAME"
    info "============================================================"
fi

exit 0
