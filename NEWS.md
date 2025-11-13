# emburden 0.4.7

## Data Hosting Infrastructure

* **Implemented Zenodo data hosting** with OpenEI fallback:
  - New `R/zenodo.R` module for downloading from Zenodo repository
  - Faster downloads via Zenodo CDN vs OpenEI
  - MD5 checksum verification for data integrity
  - Gzip decompression support for smaller downloads
  - Automatic fallback to OpenEI if Zenodo unavailable

* **Updated download cascade** in `load_cohort_data()` and `load_census_tract_data()`:
  1. Database (SQLite) - fastest, local
  2. CSV (cached files) - fast, local
  3. **Zenodo (NEW!)** - faster, more reliable
  4. OpenEI (fallback) - original source

* **Added maintainer documentation**: `.dev/ZENODO_UPLOAD_GUIDE.md`
  - Complete workflow for preparing and uploading datasets
  - Compression and checksum procedures
  - Testing and versioning guidelines

**Benefits**: Nationwide data testing ready, package stays under CRAN 5MB limit (currently 1.9MB), improved download reliability

**Next steps**: Upload processed datasets to Zenodo, update DOI configuration, ready for CRAN submission

# emburden 0.4.6

## CRAN Preparation Fixes

* **Fixed R CMD check WARNINGs and NOTEs**:
  - Excluded JSON data files (579MB) from package build via .Rbuildignore
  - Excluded top-level presentation/poster files (25+ non-standard files)
  - Added vignette metadata to jss-emburden.Rmd (VignetteEngine, VignetteIndexEntry)
  - Package now builds cleanly under 5MB for CRAN submission

* **Next steps for CRAN**: Implement Zenodo data hosting to fully separate data from methods package

# emburden 0.4.5

## New Features

* **Metadata discovery functions** for easier data exploration:
  - `list_income_brackets(dataset, vintage)`: Show available income brackets
  - `list_states()`: Show all 51 available state abbreviations
  - `list_cohort_columns(dataset, vintage)`: Show column names, descriptions, and data types
  - `get_dataset_info()`: Show metadata about all available datasets
  - Enables programmatic discovery of data structure

# emburden 0.4.4

## Breaking Changes

* **Parameter reordering in `compare_energy_burden()`**: `group_by` now comes before `counties`
  - **New order**: `compare_energy_burden(dataset, states, group_by, counties, ...)`
  - Makes intuitive syntax work: `compare_energy_burden('fpl', 'NC', 'income_bracket')`
  - Named parameters unaffected: `compare_energy_burden(dataset='fpl', counties=c('Orange'))`

## New Features

* **Dynamic grouping in `compare_energy_burden()`**: `group_by` now accepts custom column names
  - Use keywords: "income_bracket", "state", "none" (as before)
  - OR custom columns: `group_by = "geoid"` for tract-level comparison
  - OR multiple columns: `group_by = c("state_abbr", "income_bracket")`
  - Enables flexible analysis patterns for full USA data

# emburden 0.4.3

## New Features

* **Dynamic filtering in `load_cohort_data()`**: Now accepts `...` parameter for flexible filtering
  - Filter by any column using tidyverse syntax
  - Example: `load_cohort_data("ami", states = "NC", households > 100, total_income > 50000)`
  - Complements existing `states`, `counties`, `income_brackets` parameters
  - First step toward full USA data package architecture

# emburden 0.4.2

## Bug Fixes

* Fixed confusing warnings when using `compare_energy_burden('fpl', 'NC', 'income_bracket')`
* Function now silently handles common mistake of passing 'income_bracket', 'state', or 'none' as counties argument
* Eliminates "County name 'income_bracket' not found" warnings while maintaining correct behavior

## Improvements

* Improved documentation with clearer examples distinguishing between `group_by` and `counties` parameters

# emburden 0.4.1

## Improvements

* Updated contact email from eric.scheier@gmail.com to eric@scheier.org across all documentation

# emburden 0.4.0

## New Features

### Fully Automated Release Workflow

* **Zero-touch releases**: GitHub releases now created automatically when version bumps are merged
  - Detects DESCRIPTION version changes automatically
  - Runs all quality checks (R CMD check, tests, coverage)
  - Generates release notes from NEWS.md
  - Creates git tags and GitHub releases with package tarball
  - No manual intervention required!

* **Workflow**: Simply bump version in DESCRIPTION, update NEWS.md, merge PR → release happens automatically

# emburden 0.3.0

## Major Improvements

### OpenEI Data Pipeline Fix (Critical)

* **Fixed critical bug** where MVP demo `compare_energy_burden('fpl', 'NC', 'income_bracket')` failed on fresh installs
  - Root cause: Raw OpenEI 2022 FPL data wasn't being processed correctly
  - OpenEI data uses period-based columns (`HINCP.UNITS`) not asterisk-based (`HINCP*UNITS`)
  - Raw data has ~588k rows (one per housing characteristic combination) requiring aggregation

* **New data processing pipeline**:
  - Added `aggregate_cohort_data()` function to aggregate raw data by census tract × income bracket
  - Updated detection logic to recognize both `.UNITS` and `*UNITS` column formats
  - Enhanced `standardize_cohort_columns()` to handle both `FPL150` (2022) and `FPL15` (2018)
  - Reduces 588k rows → ~3.6k cohort records for NC

* **Result**: Fresh installations now work perfectly - download from OpenEI → aggregate → standardize → ready!

### Orange County Sample Data

* **NEW**: Bundled sample data for instant demos and testing (94 KB)
  - `data(orange_county_sample)` - No download required!
  - Includes 4 datasets: `fpl_2018`, `fpl_2022`, `ami_2018`, `ami_2022`
  - 749 records across 42 census tracts (Orange County, NC)
  - Perfect for vignettes, examples, and quick analysis
  - Shows real data: 16.3% energy burden for lowest income vs 1.0% for highest

### Package Infrastructure

* **Renamed all internal references**: `emrgi` → `emburden` for consistency
  - `find_emrgi_db()` → `find_emburden_db()`
  - Database filename: `emrgi_db.sqlite` → `emburden_db.sqlite`

* **Release automation**:
  - Added `.dev/RELEASE-PROCESS.md` - Comprehensive release workflow guide
  - Added `.dev/create-release-tag.R` - Automated release tagging script

## Documentation

* Updated README with Orange County sample data section
* Added comprehensive documentation for `orange_county_sample`
* All examples now work out of the box with bundled sample data

## Testing

* All 494 tests pass
* Verified OpenEI download and processing pipeline with real data
* Tested sample data access and analysis

# emburden 0.2.0

## New Features

### JSS Manuscript Vignette

* Added Journal of Statistical Software (JSS) manuscript as package vignette
  - `vignettes/jss-emburden.Rmd` - Complete JSS article format
  - Demonstrates package usage with reproducible examples
  - Includes bibliography and proper JSS formatting
  - Test suite ensures vignette builds correctly in CI

* Created manuscript development infrastructure
  - `research/manuscripts/jss-draft/` - LaTeX build output
  - `research/manuscripts/build-jss.R` - Build script for PDF generation
  - Separate from vignettes for flexible editing workflow

### Enhanced Temporal Comparison

* Prominently featured `compare_energy_burden()` function across all documentation
  - README now includes temporal comparison section (Example 5)
  - Getting Started vignette has comprehensive temporal comparison section
  - JSS vignette demonstrates function instead of manual calculations
  - Replaces 37-line manual comparison with elegant 12-line function call

## Bug Fixes

* Fixed FPL (Federal Poverty Line) data loading (#15)
  - Added validation to skip files with missing or all-NA `income_bracket` columns
  - Loader now properly falls through to raw OpenEI files with complete data
  - Prevents "Element `income_bracket` doesn't exist" errors

## Documentation Improvements

* Emphasized `compare_energy_burden()` usage across 7 files
  - `README.md` - Added temporal comparison section
  - `vignettes/jss-emburden.Rmd` - Replaced manual code with function call
  - `vignettes/getting-started.Rmd` - Added comprehensive section
  - `analysis/scripts/nc_comparison_for_email.R` - Complete rewrite (179→144 lines)
  - `data-raw/README.md` - Fixed function references
  - `research/manuscripts/jss-draft/jss-emburden.Rmd` - Updated examples

* Added pkgdown configuration for JSS vignette
  - Vignette appears in website navigation
  - Organized under "Package Documentation" section

## Infrastructure

* Added pre-commit hook for running package tests
  - `.git/hooks/pre-commit` - Runs all 238 tests before each commit
  - Prevents committing broken code
  - Can be bypassed with `--no-verify` if needed

## Internal Changes

* Improved data validation in `load_cohort_data()`
  - Better handling of incomplete processed CSV files
  - More informative verbose messaging

# emburden 0.1.1

## Documentation and Infrastructure Improvements

This patch release improves documentation accessibility and workflow infrastructure, with no code changes.

### Documentation

* Improved README accessibility and tone
  - Simplified technical language with plain-language explanations
  - Replaced prescriptive language ("WRONG", "NEVER") with educational tone ("Recommended", "Note")
  - Added concrete examples explaining why simple averaging of ratios fails
* Added complete Nature Communications citation
  - Scheier, E., & Kittner, N. (2022). A measurement strategy to address disparities across household energy burdens
  - Includes BibTeX format for easy reference

### Infrastructure

* Changed git author in publish-to-public workflow from "GitHub Actions Bot" to "Eric Scheier"
  - Automated commits now appear as maintainer commits

# emburden 0.1.0

## Package Release

Initial formal release with package renamed from `netenergyequity` to `emburden` for clarity and CRAN compatibility.

This is the first release of the netenergyequity package, providing tools for household energy burden analysis using Net Energy Return methodology.

### Core Functionality

* Energy metric calculations
  - `energy_burden_func()` - Calculate energy burden (S/G)
  - `ner_func()` - Calculate Net Energy Return (Nh)
  - `eroi_func()` - Calculate Energy Return on Investment
  - `dear_func()` - Calculate Disposable Energy-Adjusted Resources

* Statistical analysis
  - `calculate_weighted_metrics()` - Weighted aggregation with proper Nh methodology
  - Automatic poverty rate calculations below specified thresholds
  - Support for grouped analysis by geographic/demographic categories

* Formatting utilities
  - `to_percent()`, `to_dollar()`, `to_big()` - Publication-ready formatting
  - `to_million()`, `to_billion_dollar()` - Compact number formats
  - `colorize()` - Output-aware color formatting for R Markdown

### Package Structure

* Separated package code (`R/`) from analysis scripts (`analysis/`)
* Comprehensive documentation with roxygen2
* Test suite with testthat
* Example analysis scripts for NC electric utilities

### Known Issues

* roxygen2 documentation generation requires manual NAMESPACE for now
* Large data files (1.1GB+) not included in package distribution
* Some analysis scripts need updating to use package functions

### Future Plans

* Add vignettes demonstrating methodology
* Setup pkgdown website
* Configure GitHub Actions for CI/CD
* Consider CRAN submission
* Create companion data package or external data hosting solution
