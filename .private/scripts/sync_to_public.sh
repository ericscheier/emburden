#!/bin/bash
# sync_to_public.sh
#
# Complete workflow to sync private development branch to public-release branch
# with cleaned commit history and removed private files.
#
# This script:
# 1. Creates/updates public-release branch from current branch
# 2. Removes private files from working tree
# 3. (Optional) Rewrites commit history to remove AI attributions
#
# Usage: bash .private/scripts/sync_to_public.sh

set -e  # Exit on error

PRIVATE_BRANCH=${PRIVATE_BRANCH:-"package-transformation"}
PUBLIC_BRANCH=${PUBLIC_BRANCH:-"public-release"}
FILTER_HISTORY=${FILTER_HISTORY:-"false"}  # Set to "true" to rewrite history

echo "================================================================"
echo "  Syncing to Public Release Branch"
echo "================================================================"
echo ""
echo "Private branch: $PRIVATE_BRANCH"
echo "Public branch:  $PUBLIC_BRANCH"
echo "Filter history: $FILTER_HISTORY"
echo ""

# Confirm we're in a git repository
if [ ! -d ".git" ]; then
  echo "Error: Not in a git repository root"
  exit 1
fi

# Confirm we're on the private branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$PRIVATE_BRANCH" ]; then
  echo "Warning: Currently on branch '$CURRENT_BRANCH', not '$PRIVATE_BRANCH'"
  echo "Continue anyway? (y/N)"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
  fi
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo "Error: You have uncommitted changes. Please commit or stash them first."
  git status --short
  exit 1
fi

echo ""
echo "Step 1: Creating/updating $PUBLIC_BRANCH branch from $CURRENT_BRANCH..."

# Check if public branch exists
if git show-ref --verify --quiet "refs/heads/$PUBLIC_BRANCH"; then
  echo "Branch $PUBLIC_BRANCH already exists."
  echo "Delete and recreate? (y/N)"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    git branch -D "$PUBLIC_BRANCH"
    echo "✓ Deleted existing $PUBLIC_BRANCH branch"
  else
    echo "Using existing branch. Checking out..."
    git checkout "$PUBLIC_BRANCH"
    git merge "$CURRENT_BRANCH" --no-edit
  fi
fi

# Create new public branch if it doesn't exist or was deleted
if ! git show-ref --verify --quiet "refs/heads/$PUBLIC_BRANCH"; then
  git checkout -b "$PUBLIC_BRANCH"
  echo "✓ Created new $PUBLIC_BRANCH branch"
fi

echo ""
echo "Step 2: Removing private files from working tree..."

# Remove .private/ directory
if [ -d ".private" ]; then
  rm -rf .private/
  git rm -rf --quiet .private/ 2>/dev/null || true
  echo "✓ Removed .private/ directory"
fi

# Remove log files
find . -name "*.log" -type f -delete 2>/dev/null || true
git rm --quiet *.log 2>/dev/null || true
echo "✓ Removed *.log files"

# Remove cache directories
find . -name "*_cache" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✓ Removed *_cache directories"

# Remove output directories
find . -name "*_files" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✓ Removed *_files directories"

# Commit the cleanup
if ! git diff-index --quiet HEAD --; then
  git add -A
  git commit -m "Clean repository for public release

Remove private development files:
- .private/ directory
- *.log files
- *_cache/ directories
- *_files/ directories

Ready for public distribution."
  echo "✓ Committed cleanup changes"
else
  echo "✓ No files to clean (already clean)"
fi

# Optional: Rewrite commit history
if [ "$FILTER_HISTORY" = "true" ]; then
  echo ""
  echo "Step 3: Rewriting commit history to remove AI attributions..."
  echo ""
  echo "WARNING: This will rewrite git history!"
  echo "Press Ctrl+C to cancel, or Enter to continue..."
  read -r

  # Check if git-filter-repo is installed
  if ! command -v git-filter-repo &> /dev/null; then
    echo "Error: git-filter-repo is not installed"
    echo "Install with: pip install git-filter-repo"
    exit 1
  fi

  # Create backup branch
  BACKUP_BRANCH="${PUBLIC_BRANCH}-backup-$(date +%Y%m%d-%H%M%S)"
  git branch "$BACKUP_BRANCH"
  echo "✓ Created backup branch: $BACKUP_BRANCH"

  # Create message filter callback
  cat > /tmp/message-filter.py <<'PYTHON_EOF'
#!/usr/bin/env python3
import re
import sys

# Read commit message from stdin
message = sys.stdin.read()

# Remove AI attribution lines
message = re.sub(r'\n\n🤖 Generated with.*?\n\nCo-Authored-By: Claude.*?\n', '\n', message)
message = re.sub(r'\n\n🤖 Generated with.*?\n', '\n', message)
message = re.sub(r'\nCo-Authored-By: Claude.*?\n', '\n', message)

# Remove multiple consecutive blank lines
message = re.sub(r'\n\n\n+', '\n\n', message)

# Output cleaned message
sys.stdout.write(message)
PYTHON_EOF

  chmod +x /tmp/message-filter.py

  # Run filter-repo
  git filter-repo --force \
    --message-callback "$(cat /tmp/message-filter.py)" \
    --refs "$PUBLIC_BRANCH"

  rm /tmp/message-filter.py

  echo "✓ Commit history rewritten"
  echo "  Backup branch: $BACKUP_BRANCH"
fi

echo ""
echo "================================================================"
echo "  Public Release Branch Ready!"
echo "================================================================"
echo ""
echo "Branch:         $PUBLIC_BRANCH"
echo "Original:       $CURRENT_BRANCH"
if [ "$FILTER_HISTORY" = "true" ]; then
  echo "History:        Rewritten (backup: $BACKUP_BRANCH)"
else
  echo "History:        Unchanged (set FILTER_HISTORY=true to rewrite)"
fi
echo ""
echo "Next steps:"
echo "  1. Review the public branch:"
echo "     git log --oneline -10"
echo "     git diff $CURRENT_BRANCH..$PUBLIC_BRANCH"
echo ""
echo "  2. Test the package:"
echo "     R CMD check ."
echo "     # or: devtools::check()"
echo ""
echo "  3. Push to public remote:"
echo "     git remote add public https://github.com/ericscheier/net_energy_burden.git"
echo "     git push public $PUBLIC_BRANCH:main"
echo ""
echo "  4. Return to private development:"
echo "     git checkout $CURRENT_BRANCH"
echo ""
