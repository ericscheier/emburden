#!/bin/bash
# clean_for_public.sh
#
# Cleans the current working tree for public release by removing
# private development files. This script operates on files only,
# not git history.
#
# Usage: bash .private/scripts/clean_for_public.sh

set -e  # Exit on error

echo "================================================================"
echo "  Cleaning Repository for Public Release"
echo "================================================================"
echo ""

# Confirm we're in the right directory
if [ ! -d ".private" ]; then
  echo "Error: .private directory not found. Are you in the repository root?"
  exit 1
fi

# Safety check
echo "WARNING: This will delete private files from the working tree."
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

echo ""
echo "Step 1: Removing .private/ directory..."
rm -rf .private/
echo "✓ .private/ removed"

echo ""
echo "Step 2: Removing log files (*.log)..."
find . -name "*.log" -type f -delete
echo "✓ Log files removed"

echo ""
echo "Step 3: Removing cache directories (*_cache/)..."
find . -name "*_cache" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✓ Cache directories removed"

echo ""
echo "Step 4: Removing output directories (*_files/)..."
find . -name "*_files" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✓ Output directories removed"

echo ""
echo "================================================================"
echo "  Cleanup Complete!"
echo "================================================================"
echo ""
echo "Files removed:"
echo "  - .private/ directory and contents"
echo "  - *.log files"
echo "  - *_cache/ directories"
echo "  - *_files/ directories"
echo ""
echo "Next steps:"
echo "  1. Review changes: git status"
echo "  2. Test package: R CMD check or devtools::check()"
echo "  3. Commit and push to public remote"
echo ""
