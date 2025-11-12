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
