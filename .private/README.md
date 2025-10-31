# Private Development Workflow

This directory contains tools for managing the private-to-public translation of the `net_energy_burden` R package.

## Directory Structure

```
.private/
├── internal_docs/           # Internal documentation (moved here from root)
├── scripts/                 # Translation scripts
│   ├── clean_for_public.sh
│   ├── sync_to_public.sh
│   └── filters/
│       ├── remove_ai_attribution.py
│       └── clean_commit_messages.py
├── FILTER_CONFIG.yaml       # Configuration for what to filter
└── README.md               # This file
```

## Branch Strategy

- **package-transformation** (or main): Private development branch
  - Contains all AI attributions, internal docs, debug logs
  - Full development history preserved

- **public-release**: Clean public branch
  - No AI attributions in commits
  - No internal documentation
  - No debug logs or caches
  - Professional commit messages

## Quick Start

### 1. Normal Development (Private)

Work as usual on your private branch:

```bash
git checkout package-transformation

# Make changes, commit with AI attributions
git add R/new_feature.R
git commit -m "Add new feature

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 2. Prepare for Public Release

When ready to sync to public:

```bash
# Run the cleanup and sync script
bash .private/scripts/sync_to_public.sh

# Review the public-release branch
git checkout public-release
git log --oneline -10  # Verify cleaned commits

# Push to public remote
git push public-remote public-release:main
```

## What Gets Filtered

### From Git Commits:
- Lines containing `🤖 Generated with [Claude Code]`
- Lines containing `Co-Authored-By: Claude`
- Empty lines left by removals

### From Repository:
- `.private/` directory (entire)
- `*.log` files
- `*_cache/` directories
- `*_files/` directories
- Internal documentation files (now in `.private/internal_docs/`)

### Preserved:
- All R package code
- Public documentation (README.md, vignettes)
- Research files in `research/` directory
- All functionality and tests

## Manual Cleanup (Alternative to Scripts)

If you prefer manual control:

### Create Clean Public Branch

```bash
# 1. Create orphan branch from current state
git checkout package-transformation
git checkout --orphan public-release-temp

# 2. Remove private files
rm -rf .private
find . -name "*.log" -delete
find . -name "*_cache" -type d -exec rm -rf {} +

# 3. Commit clean state
git add -A
git commit -m "Initial public release of netenergyburden R package

R package for analyzing household energy burden using Net Energy Return (Nh) methodology.
"

# 4. Replace public-release branch
git branch -D public-release 2>/dev/null || true
git branch -m public-release
```

### Clean Commit Messages (Advanced)

Using `git filter-repo` (install: `pip install git-filter-repo`):

```bash
# Create backup first!
git branch backup-before-filter

# Filter commit messages
git filter-repo --message-callback '
  import re
  message = message.decode("utf-8")

  # Remove AI attribution lines
  message = re.sub(r"\n\n🤖 Generated with.*?\n\nCo-Authored-By: Claude.*?\n", "", message)
  message = re.sub(r"\n\n🤖 Generated with.*?\n", "", message)
  message = re.sub(r"\nCo-Authored-By: Claude.*?\n", "", message)

  return message.encode("utf-8")
'

# Force push (CAUTION: rewrites history)
git push --force origin public-release
```

## Configuration

Edit `.private/FILTER_CONFIG.yaml` to customize what gets filtered:

```yaml
commit_patterns:
  - "🤖 Generated with"
  - "Co-Authored-By: Claude"

file_patterns:
  - "*.log"
  - "*_cache/"
  - ".private/"

internal_docs:
  - "STATUS.md"
  - "CHECK_RESULTS.md"
  # ... etc
```

## Troubleshooting

### "Command not found: git-filter-repo"

Install it:
```bash
pip install git-filter-repo
```

### "Cannot force push to protected branch"

Make sure you're pushing to the correct remote and that the branch isn't protected on GitHub.

### "Package check fails after cleanup"

The cleanup scripts preserve all R/ code. If checks fail:
1. Verify `.gitignore` isn't excluding necessary files
2. Check that data/ directory has required files
3. Run `devtools::check()` to see specific issues

## Adding This to Polyglot Workspace

To make this reusable across projects, consider adding to polyglot_workspace:

```bash
# In polyglot_workspace repo
mkdir -p templates/private-to-public/
cp -r .private/* templates/private-to-public/

# Create installer script
cat > install_private_workflow.sh <<'EOF'
#!/bin/bash
cp -r templates/private-to-public/ "$1/.private/"
echo "✓ Private-to-public workflow installed"
EOF
```

## Resources

- **Git Filter-Repo docs**: https://github.com/newren/git-filter-repo
- **R Package docs**: http://r-pkgs.org/
- **Git rewriting history**: https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History

## Support

If you have questions or encounter issues:
1. Check this README
2. Review the script files in `.private/scripts/`
3. Consult git documentation for history rewriting

## License

Same as parent project: AGPL-3+
