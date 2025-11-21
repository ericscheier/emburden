#!/bin/bash

# Validate GitHub Actions workflow files for YAML syntax errors
# This script can be called from pre-tag validation or run manually

set -e

echo "=================================="
echo "  Workflow File Validation"
echo "=================================="
echo ""

# Check if actionlint is installed
if ! command -v actionlint &> /dev/null; then
  echo "actionlint not found. Installing..."

  # Download and install actionlint
  bash <(curl -s https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)

  # Move to a location in PATH
  if [ -w "/usr/local/bin" ]; then
    sudo mv ./actionlint /usr/local/bin/
  else
    # Fallback to user bin if /usr/local/bin is not writable
    mkdir -p ~/.local/bin
    mv ./actionlint ~/.local/bin/
    export PATH="$HOME/.local/bin:$PATH"
  fi

  echo "✅ actionlint installed successfully"
  echo ""
fi

# Run actionlint on all workflow files
echo "Validating workflow files..."
echo ""

WORKFLOW_DIR=".github/workflows"

if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "❌ Error: $WORKFLOW_DIR directory not found"
  exit 1
fi

# Count workflow files
WORKFLOW_COUNT=$(find "$WORKFLOW_DIR" -name "*.yml" -o -name "*.yaml" | wc -l)

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo "⚠️  Warning: No workflow files found in $WORKFLOW_DIR"
  exit 0
fi

echo "Found $WORKFLOW_COUNT workflow file(s)"
echo ""

# Run actionlint
if actionlint -color "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml 2>/dev/null; then
  echo ""
  echo "✅ All workflow files passed validation"
  echo ""
  echo "Files validated:"
  find "$WORKFLOW_DIR" -name "*.yml" -o -name "*.yaml" | while read -r file; do
    echo "  - $(basename "$file")"
  done
  exit 0
else
  echo ""
  echo "❌ Workflow validation failed"
  echo ""
  echo "Please fix the errors above before proceeding with the release."
  echo "Common issues:"
  echo "  - YAML syntax errors (check indentation, quotes, special characters)"
  echo "  - Invalid workflow structure"
  echo "  - Bash heredoc conflicts with YAML (use ___ instead of --- or ***)"
  exit 1
fi
