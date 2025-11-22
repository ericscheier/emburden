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

# Parse arguments - version is now optional
NEW_VERSION=""
for arg in "$@"; do
    if [[ "$arg" == "--auto" ]]; then
        AUTO_MODE=true
    elif [[ -z "$NEW_VERSION" ]]; then
        NEW_VERSION="$arg"
    else
        error "Unknown argument: $arg\nUsage: $0 [new_version] [--auto]\nExample: $0 0.5.11\nExample (auto mode): $0 0.5.11 --auto\nExample (auto-increment): $0 --auto"
    fi
done

if [[ "$AUTO_MODE" == "true" ]]; then
    info "Auto mode enabled: will run without interactive prompts"
fi

# If no version specified, auto-increment patch version
if [[ -z "$NEW_VERSION" ]]; then
    info "No version specified - auto-incrementing patch version..."

    # Extract current version from DESCRIPTION
    CURRENT_VERSION=$(grep "^Version:" DESCRIPTION | sed 's/Version: //')

    if [[ -z "$CURRENT_VERSION" ]]; then
        error "Could not extract current version from DESCRIPTION"
    fi

    info "Current version: $CURRENT_VERSION"

    # Parse version components
    if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\..*)?$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"

        # Increment patch version
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

        success "Auto-incremented to: $NEW_VERSION (from $CURRENT_VERSION)"
    else
        error "Could not parse version from DESCRIPTION: $CURRENT_VERSION"
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

success "Git repository check passed"
echo ""

# Run the R version bump script
info "[Step 2/8] Running version bump script..."
if ! Rscript .dev/bump-version.R "$NEW_VERSION"; then
    error "Version bump script failed"
fi
echo ""

# Update NEWS.md
info "[Step 3/8] Updating NEWS.md..."

# Check if NEWS.md already has this version
if grep -q "^# emburden $NEW_VERSION" NEWS.md; then
    success "NEWS.md already contains entry for version $NEW_VERSION"
else
    # Generate NEWS content
    if [[ "$AUTO_MODE" == "true" ]]; then
        info "Auto mode: generating NEWS.md from git commits..."

        # Find the last version tag
        LAST_TAG=$(git tag -l "v*" | sort -V | tail -1)
        if [[ -z "$LAST_TAG" ]]; then
            warning "No previous version tag found, using all commits"
            COMMIT_RANGE="HEAD"
        else
            info "Extracting commits since $LAST_TAG..."
            COMMIT_RANGE="$LAST_TAG..HEAD"
        fi

        # Extract commits and categorize them
        FEATURES=""
        FIXES=""
        ENHANCEMENTS=""
        OTHER=""

        while IFS= read -r commit; do
            # Get commit message (first line only)
            msg=$(echo "$commit" | sed 's/^[a-f0-9]* //')

            # Skip version bump commits and merge commits
            if [[ "$msg" =~ ^(Bump version|Merge|Version bump) ]]; then
                continue
            fi

            # Remove PR numbers like (#60) from the end
            msg=$(echo "$msg" | sed 's/ (#[0-9]*)$//')

            # Categorize by conventional commit prefix
            if [[ "$msg" =~ ^feat(\(.*\))?:\ (.*)$ ]]; then
                # New feature
                feature_msg="${BASH_REMATCH[2]}"
                FEATURES="${FEATURES}* ${feature_msg}\n"
            elif [[ "$msg" =~ ^fix(\(.*\))?:\ (.*)$ ]]; then
                # Bug fix
                fix_msg="${BASH_REMATCH[2]}"
                FIXES="${FIXES}* ${fix_msg}\n"
            elif [[ "$msg" =~ ^(chore|docs|refactor|style|test|perf)(\(.*\))?:\ (.*)$ ]]; then
                # Enhancement/other improvement
                enh_msg="${BASH_REMATCH[3]}"
                ENHANCEMENTS="${ENHANCEMENTS}* ${enh_msg}\n"
            else
                # Other changes without conventional commit prefix
                OTHER="${OTHER}* ${msg}\n"
            fi
        done < <(git log "$COMMIT_RANGE" --oneline --no-merges)

        # Build NEWS template with actual content
        NEWS_TEMPLATE="# emburden $NEW_VERSION\n\n"

        if [[ -n "$FEATURES" ]]; then
            NEWS_TEMPLATE="${NEWS_TEMPLATE}## New Features\n\n${FEATURES}\n"
        fi

        if [[ -n "$FIXES" ]]; then
            NEWS_TEMPLATE="${NEWS_TEMPLATE}## Bug Fixes\n\n${FIXES}\n"
        fi

        if [[ -n "$ENHANCEMENTS" ]]; then
            NEWS_TEMPLATE="${NEWS_TEMPLATE}## Enhancements\n\n${ENHANCEMENTS}\n"
        fi

        if [[ -n "$OTHER" ]]; then
            NEWS_TEMPLATE="${NEWS_TEMPLATE}## Other Changes\n\n${OTHER}\n"
        fi

        # If no changes found, add a note
        if [[ -z "$FEATURES" && -z "$FIXES" && -z "$ENHANCEMENTS" && -z "$OTHER" ]]; then
            NEWS_TEMPLATE="${NEWS_TEMPLATE}## Changes\n\n* Minor updates and improvements\n\n"
        fi

        NEWS_TEMPLATE="${NEWS_TEMPLATE}---\n\n"

        success "Generated NEWS.md from $(git rev-list --count "$COMMIT_RANGE" --no-merges) commits"
    else
        # Manual mode: create template with placeholders
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
        success "Created NEWS.md template for manual editing"
    fi

    # Insert at top of NEWS.md
    if [[ -f NEWS.md ]]; then
        # Create temporary file with new entry
        {
            echo -e "$NEWS_TEMPLATE"
            cat NEWS.md
        } > NEWS.md.tmp
        mv NEWS.md.tmp NEWS.md
    else
        echo -e "$NEWS_TEMPLATE" > NEWS.md
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
    fi
fi
echo ""

# Show changes
info "[Step 4/8] Review changes..."
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
info "[Step 5/8] Staging files..."
git add DESCRIPTION inst/CITATION .zenodo.json NEWS.md
success "Files staged"
echo ""

# Commit
info "[Step 6/8] Creating commit..."
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

# Push to remote
info "[Step 7/8] Push to remote..."
if [[ "$AUTO_MODE" == "true" ]] || prompt_yes_no "Push commit to remote 'scheier'?"; then
    if [[ "$AUTO_MODE" == "true" ]]; then
        info "Auto mode: automatically pushing to remote"
    fi

    info "Pushing commit to $CURRENT_BRANCH..."
    git push scheier "$CURRENT_BRANCH"

    success "Pushed to remote!"
    echo ""

    # Create or update PR
    info "[Step 8/8] Creating or updating pull request..."

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
- Updated NEWS.md with release notes

### Next Steps

After merging:
1. Auto-tag-on-version-bump workflow will create git tag v$NEW_VERSION
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

    # Create auto-merge tag to trigger automated PR merge
    info "[Step 9/9] Creating auto-merge tag to trigger PR merge..."
    AUTO_MERGE_TAG="auto-merge/v$NEW_VERSION"

    # Check if tag already exists
    if git rev-parse "$AUTO_MERGE_TAG" >/dev/null 2>&1; then
        info "Auto-merge tag $AUTO_MERGE_TAG already exists, deleting and recreating..."
        git tag -d "$AUTO_MERGE_TAG" || true
        git push scheier ":refs/tags/$AUTO_MERGE_TAG" 2>/dev/null || true
    fi

    # Create and push the auto-merge tag
    info "Creating tag $AUTO_MERGE_TAG on current branch..."
    git tag "$AUTO_MERGE_TAG"
    git push scheier "$AUTO_MERGE_TAG"

    success "Auto-merge tag pushed!"
    echo ""
    info "The auto-merge workflow will now:"
    info "  1. Verify all PR checks are passing"
    info "  2. Automatically merge and squash the PR"
    info "  3. Delete the auto-merge tag"
    info "  4. Trigger auto-tag-on-version-bump to create v$NEW_VERSION on main"
    echo ""

    info "============================================================"
    info "Release automation complete!"
    info ""
    info "Version: $NEW_VERSION"
    info "Branch: $CURRENT_BRANCH"
    if [[ -n "$PR_URL" ]]; then
        info "Pull Request: $PR_URL"
    fi
    info "Auto-merge tag: $AUTO_MERGE_TAG"
    info ""
    info "Next steps (automated):"
    info "  1. Auto-merge workflow validates and merges PR"
    info "  2. Auto-tag-on-version-bump workflow creates tag v$NEW_VERSION"
    info "  3. Auto-release workflow creates GitHub release"
    info "  4. Publish-to-public workflow syncs to public repo"
    info "  5. CRAN release workflow runs on public repo (manual approval required)"
    info "============================================================"
else
    warning "Skipped push to remote"
    echo ""
    info "============================================================"
    info "Local release preparation complete!"
    info ""
    info "Version: $NEW_VERSION"
    info ""
    info "To push manually:"
    info "  git push scheier $CURRENT_BRANCH"
    info ""
    info "Note: Git tag will be created automatically by auto-tag-on-version-bump"
    info "      workflow after the PR is merged to main"
    info "============================================================"
fi

exit 0
