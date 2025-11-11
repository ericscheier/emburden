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
