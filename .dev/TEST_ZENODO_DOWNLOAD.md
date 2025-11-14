# Testing Zenodo Downloads Safely

## Overview

This guide shows how to test Zenodo downloads WITHOUT touching your production database.

## Database Protection

The package now has **TWO separate databases**:

1. **Production Database** (`emburden_db.sqlite`)
   - Contains your real data
   - **PROTECTED** from accidental deletion
   - Located at: `~/.cache/emburden/emburden_db.sqlite`

2. **Test Database** (`emburden_test_db.sqlite`)
   - Used for testing only
   - Safe to delete anytime
   - Located at: `~/.cache/emburden/emburden_test_db.sqlite`

## Testing Zenodo Downloads

### Option 1: Manual Test Script (Recommended)

Create a test script that uses the test database:

```r
# test-zenodo.R
devtools::load_all()

# Clear test environment (SAFE - only touches test DB)
clear_test_environment()

# Test loading with verbose output
message("Testing Zenodo download...")
data <- load_cohort_data('ami', states = 'NC', vintage = '2022', verbose = TRUE)

message("\n✓ SUCCESS! Loaded ", nrow(data), " rows")
message("Sample data:")
print(head(data[, 1:5], 3))
```

Run with:
```bash
Rscript test-zenodo.R
```

### Option 2: Interactive R Session

```r
library(emburden)

# Clear only test data (production untouched)
clear_test_environment()

# Test a download
data <- load_cohort_data('fpl', 'NC', '2022', verbose = TRUE)
nrow(data)  # Should see data from Zenodo
```

### Option 3: Automated Tests

```r
devtools::test()  # Runs all tests including Zenodo tests
```

## Database Safety Features

### Protection Against Deletion

```r
# This FAILS (good!)
delete_db(test = FALSE)
# Error: Cannot delete production database without confirmation!

# This works (production DB deletion requires explicit confirm)
delete_db(test = FALSE, confirm = TRUE)  # DANGER!

# This is SAFE (test DB)
delete_db(test = TRUE)  # OK - deletes test DB only
```

### Backup Production Database

Before any risky operations:

```r
# Create timestamped backup
backup_db()
# Database backed up successfully!
#   Location: ~/.cache/emburden/backups/emburden_db_backup_20251114_001234.sqlite
#   Size: 42.5 MB
```

### Clear Test Environment

Safe function that NEVER touches production:

```r
clear_test_environment()
# Clearing test environment...
#   ✓ Deleted test database
#   ✓ Deleted 0 test cache files
# Test environment cleared (production data untouched)
```

## Verifying Zenodo Infrastructure

### Check Configuration

```r
config <- get_zenodo_config()

# View DOIs
config$concept_doi  # "10.5281/zenodo.17604955"
config$version_doi  # "10.5281/zenodo.17604956"

# View file URLs
config$files$ami_2022$url
# "https://zenodo.org/records/17604956/files/lead_ami_cohorts_2022_us.csv.gz"
```

### Test URL Accessibility

```r
# Check if Zenodo URL is reachable
url <- config$files$ami_2022$url
response <- httr::HEAD(url)
httr::status_code(response)  # Should be 200
```

### Test Download (Small File)

```r
# Test with smallest file (AMI 2022 = 3.3 MB)
clear_test_environment()  # Safe!

data <- load_cohort_data('ami', 'NC', '2022', verbose = TRUE)
# Should see: "Downloading from Zenodo repository..."
```

## Current Zenodo Status

- **Published**: ✅ Yes (2025-11-14)
- **Scope**: North Carolina only
- **Files**: 4 datasets (AMI/FPL 2018/2022)
- **Total Size**: 164 MB compressed
- **Public URL**: https://zenodo.org/records/17604956

## Development Workflow

### Before Making Changes

```r
# 1. Backup production database
backup_db()

# 2. Make your changes
# ...

# 3. Test with test database
clear_test_environment()
# ... run tests ...
```

### Testing New Features

```r
# Always use test environment for development
withr::with_envvar(
  c(EMBURDEN_TEST_MODE = "true"),
  {
    # Your tests here
    data <- load_cohort_data('ami', 'NC', '2022')
  }
)
```

## Troubleshooting

### "Can't find production database"

That's OK! It will be created automatically when you first download data.

### "Test is using production database"

Check that you're using `test = TRUE` in database functions:
```r
get_db_path(test = TRUE)   # Test DB
get_db_path(test = FALSE)  # Production DB
```

### "Want to completely reset"

```r
# Clear test data (SAFE)
clear_test_environment()

# Clear production data (REQUIRES BACKUP FIRST!)
backup_db()  # Creates backup
delete_db(test = FALSE, confirm = TRUE)  # Deletes production DB
```

## Summary

✅ **Safe Operations**:
- `clear_test_environment()` - Always safe
- `delete_db(test = TRUE)` - Safe, only deletes test DB
- `backup_db()` - Safe, creates backup

⚠️ **Dangerous Operations** (require explicit confirmation):
- `delete_db(test = FALSE, confirm = TRUE)` - Deletes production DB!
- Manual file deletion in `~/.cache/emburden/`

🔒 **Protected**:
- Production database cannot be deleted without `confirm = TRUE`
- All test functions use separate test database
- Clear warnings before any destructive operations
