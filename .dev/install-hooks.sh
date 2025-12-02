#!/bin/bash
#
# Git Hooks Installation Script
# Installs pre-push hook with CRAN validation checks
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

echo "================================================"
echo "  Installing Git Hooks for CRAN Validation"
echo "================================================"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Install pre-commit hook
echo "📦 Installing pre-commit hook..."
cp "$HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo "✅ pre-commit hook installed"

echo ""

# Install pre-push hook
echo "📦 Installing pre-push hook..."
cp "$HOOKS_DIR/pre-push" "$GIT_HOOKS_DIR/pre-push"
chmod +x "$GIT_HOOKS_DIR/pre-push"
echo "✅ pre-push hook installed"

echo ""
echo "================================================"
echo "  ✅ Git Hooks Installation Complete!"
echo "================================================"
echo ""
echo "The pre-commit hook will run before every commit:"
echo "  1. Version consistency check"
echo "  2. Check for debugger statements"
echo "  3. Quick R syntax validation"
echo ""
echo "The pre-push hook will run before every push:"
echo "  1. Version consistency check"
echo "  2. Spelling validation (blocking)"
echo "  3. CRAN-style R CMD check with --compact-vignettes=both"
echo ""
echo "To bypass hooks (not recommended):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo ""
