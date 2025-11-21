# Changelog

## emburden 0.5.10

### Workflow Organization

This release reorganizes the CRAN release workflows between private and
public repositories.

#### Changes

- **Workflow documentation**:
  - Added comprehensive deployment guide for public repository CRAN
    workflow
  - Updated workflow README to clarify automatic triggering and approval
    gates
  - Prepared controlled-release workflow for public repository
    deployment
- **Repository architecture**:
  - Private repo focuses on fast GitHub releases via auto-release
  - Public repo handles CRAN validation with automatic triggering and
    dual approval gates
  - Eliminates workflow conflicts by sequential execution

------------------------------------------------------------------------

## emburden 0.5.9

### CI/CD Improvements

This release focuses on improving the robustness and reliability of the
CI/CD pipeline.

#### New Features

- **Workflow validation system**:
  - Added `.github/workflows/validate-workflows.yml` for PR validation
  - Pre-tag validation gate in auto-tag workflow prevents creating tags
    when workflow files have syntax errors
  - Manual validation script `.dev/validate-workflows.sh` for local
    checks
  - Prevents misordering of workflow fixes and version bumps

#### Bug Fixes

- **Fixed Windows CI TinyTeX failures**:
  - Added `tlmgr_update()` before installing LaTeX packages
  - Resolves “outdated CTAN mirror” errors on Windows runners
  - Ensures consistent vignette building across all platforms (Windows,
    macOS, Linux)

------------------------------------------------------------------------

## emburden 0.5.8

### CRAN Automation and Submission

This release introduces comprehensive automation for CRAN submissions.

#### New Features

- **Automated CRAN submission pipeline**:
  - Multi-layer validation (local → GitHub Actions → Win-builder →
    manual approval → auto-submit)
  - Win-builder integration for Windows testing
  - Manual approval gate via GitHub environment
  - Automatic submission using `devtools::submit_cran()`
- **Pre-tag validation script** (`.dev/pre-tag-cran-check.R`):
  - Local validation before creating version tags
  - Comprehensive CRAN checks with `--as-cran` flag
  - Optional Win-builder submission
  - Version consistency validation
- **Complete workflow documentation** (`.dev/CRAN-SUBMISSION-GUIDE.md`):
  - Full CRAN submission process guide
  - Multi-repository setup explanation
  - Troubleshooting tips and best practices

#### Bug Fixes

- Fixed R-CMD-check badge URL in README (`.yaml` → `.yml`)

------------------------------------------------------------------------

## emburden 0.5.7

### CRAN Readiness - Final Fixes

This patch release completes CRAN readiness with final compliance fixes.

#### Bug Fixes

- **Package build exclusions**: Excluded
  `data/zenodo-upload-nationwide/` directory from package tarball (fixes
  CRAN data directory WARNING)
- **Spelling whitelist**: Added `inst/WORDLIST` with 85 technical terms
  and acronyms to prevent false-positive spelling errors
- **Public repository sync**: Fixed `publish-to-public` workflow to
  properly remove private-only workflow files before syncing to public
  repository

------------------------------------------------------------------------

## emburden 0.5.6

### CRAN Quality-of-Life Improvements

This release focuses on CRAN compliance and automation improvements.

#### Enhancements

- **Auto-release workflow**: Automated GitHub release creation on
  version tags
- **CRAN compliance improvements**:
  - Added `Language: en-US` field to DESCRIPTION
  - Added `jsonlite` to Suggests (used in tests)
  - Replaced all non-ASCII Unicode characters with escape sequences
  - Added missing global variable bindings (AMI150, AMI68)

#### Bug Fixes

- Fixed auto-release workflow heredoc syntax issue
- All Unicode characters now use `\uxxxx` escape format for portability

------------------------------------------------------------------------

## emburden 0.5.5

### Data Integrity Fix - New Zenodo Record

This patch release deploys corrected datasets to a new Zenodo record to
ensure data integrity.

#### Bug Fixes

- **New Zenodo record with verified correct data**
  - Deployed new Zenodo record
    [10.5281/zenodo.17656637](https://zenodo.org/records/17656637)
  - Updated MD5 checksums to match re-uploaded files with verified
    correct data
  - Verified FPL 2022 checksum: `767f2ff27193116f61e893999eb8bcf1`
  - **Impact**: Ensures users download validated, correct data for all 4
    datasets

------------------------------------------------------------------------

## emburden 0.5.4

### Critical Bugfix - Zenodo MD5 Checksums

This patch release fixes incorrect MD5 checksums that caused data
loading failures.

#### Bug Fixes

- **Fixed MD5 checksums for Zenodo downloads**
  - Corrected AMI 2022 checksum: `cc847d89119a374bede6ee7f41060506`
  - Corrected AMI 2018 checksum: `4941e3566daec1badc53eb44f34d95a8`
  - Corrected FPL 2018 checksum: `85ef6b7b4de244e80ff700f3d5becf3a`
  - Updated file sizes to match actual generated files
  - **Impact**: Previously, 3 out of 4 datasets failed checksum
    verification and fell back to cached/OpenEI data, causing incorrect
    data comparisons (e.g., 2018 and 2022 appearing identical)

------------------------------------------------------------------------

## emburden 0.5.3

### Zenodo Integration - US Nationwide Datasets

This patch release enables Zenodo downloads for US nationwide datasets
with improved reliability and performance.

#### Data Infrastructure

- **Enabled Zenodo downloads for US nationwide datasets** (PR
  [\#35](https://github.com/ericscheier/emburden/issues/35))
  - Deployed Zenodo record
    [10.5281/zenodo.17653871](https://zenodo.org/records/17653871) with
    4 datasets
  - AMI cohorts 2022 (499,234 records, 51 states)
  - FPL cohorts 2022 (416,054 records, 51 states)
  - AMI cohorts 2018 (361,095 records, 51 states)
  - FPL cohorts 2018 (361,085 records, 51 states)
  - Updated MD5 checksums for all datasets
  - Removed temporary Zenodo bypass code

#### Bug Fixes

- **Fixed test mocking for database fallback** (PR
  [\#35](https://github.com/ericscheier/emburden/issues/35))
  - Database fallback test now properly mocks all download sources
  - Added mock for
    [`download_lead_data()`](https://ericscheier.github.io/emburden/reference/download_lead_data.md)
    to prevent OpenEI fallback
  - Added mock for
    [`detect_database_corruption()`](https://ericscheier.github.io/emburden/reference/detect_database_corruption.md)
    to allow test data

#### Testing

- All 614 tests passing across 7 platforms
- Clean R CMD check: 0 ERRORS, 0 FAILURES

------------------------------------------------------------------------

## emburden 0.5.2

### CRAN Submission Fix - LaTeX Compatibility

This patch release fixes a LaTeX compatibility issue blocking CRAN
submission.

#### Bug Fixes

- **Fixed LaTeX Unicode error in documentation** (PR
  [\#32](https://github.com/ericscheier/emburden/issues/32))
  - Replaced Unicode ≥ character (U+2265) with LaTeX-compatible
    `\eqn{\ge}` macro
  - Fixed in `R/energy_ratios.R` documentation for
    [`ner_func()`](https://ericscheier.github.io/emburden/reference/ner_func.md)
    function
  - All R CMD check tests passing with 0 ERRORS

#### CRAN Readiness

- Clean R CMD check results: 0 ERRORS, 1 WARNING (qpdf - non-critical),
  3 NOTEs (all acceptable)
- All 614 tests passing across 7 platforms (ubuntu, windows, macos,
  multiple R versions)
- Package ready for CRAN submission

------------------------------------------------------------------------

## emburden 0.5.1

### Critical Data Fix - Corrected Zenodo Repository

This patch release fixes critical data corruption in the v0.5.0 Zenodo
repository.

#### Bug Fixes

- **Fixed corrupted Zenodo data** (PR
  [\#28](https://github.com/ericscheier/emburden/issues/28))
  - v0.5.0 Zenodo record (17605603) contained incorrect FPL data files
  - FPL files only included NC state data (52MB) instead of full
    nationwide data (306MB)
  - AMI files were correct (nationwide data, 148MB)
  - New Zenodo record (17613104) uploaded with all 4 corrected datasets
  - All datasets now contain complete US nationwide data (51 states,
    ~73K census tracts)
- **Updated Zenodo configuration**
  - New concept DOI: 10.5281/zenodo.17613103
  - New version DOI: 10.5281/zenodo.17613104
  - Updated all file URLs and MD5 checksums in `R/zenodo.R`
  - Updated test patterns to accept new Zenodo API endpoint format

#### Verified Data Integrity

All 4 nationwide datasets verified and working correctly: -
`lead_ami_cohorts_2022_us.csv.gz` - 148 MB ✓ -
`lead_fpl_cohorts_2022_us.csv.gz` - 305 MB ✓ -
`lead_ami_cohorts_2018_us.csv.gz` - 148 MB ✓ -
`lead_fpl_cohorts_2018_us.csv.gz` - 305 MB ✓

All tests passing (614 tests, 0 failures).

------------------------------------------------------------------------

## emburden 0.5.0

### CRAN Submission Ready - Nationwide Energy Burden Analysis

This major release marks the completion of the nationwide expansion and
prepares the package for CRAN submission. The package now
comprehensively showcases nationwide US capability across all
documentation, with 648 tests passing and clean R CMD check results.

#### Nationwide Expansion Complete

- **Full nationwide focus** achieved across all documentation
  - README features nationwide data from introduction: “All 51 US
    states…2.3+ million records”
  - All function examples demonstrate single-state → multi-state →
    nationwide progression
  - Both vignettes showcase nationwide capability alongside learning
    examples
  - Dual focus strategy: NC examples for learning (small, fast),
    nationwide for production use
- **Comprehensive test coverage** validates nationwide functionality
  - 648 tests passing (0 failures)
  - Multi-state regional filtering (Southeast, top 10 states,
    cross-regional)
  - Data integrity validation across all 51 states
  - All major US regions tested (Northeast, Southeast, Midwest,
    Southwest, West)
- **CRAN readiness verified**
  - R CMD check: 0 errors, 1 acceptable warning (qpdf), 1 acceptable
    note (httptest2)
  - Package size: Under 5MB CRAN limit (~1.9MB)
  - Multi-platform CI validation (macOS, Windows, Ubuntu × 5 R versions)
  - External data hosting on Zenodo (DOI: 10.5281/zenodo.17605603)

#### Documentation Enhancements

- **Nationwide vignette content**
  - `vignettes/getting-started.Rmd`: Comprehensive nationwide examples
    (v0.4.10)
  - `vignettes/jss-emburden.Rmd`: Nationwide data availability note
    added
  - Performance guidance for large dataset queries (30-120 seconds,
    ~500MB RAM)
  - Metadata discovery functions showcased
    ([`list_states()`](https://ericscheier.github.io/emburden/reference/list_states.md),
    [`list_income_brackets()`](https://ericscheier.github.io/emburden/reference/list_income_brackets.md),
    etc.)
- **Language cleanup**
  - Removed “proof of concept” references from documentation
  - Professional, production-ready messaging throughout
  - Clear data coverage statements: 2.3M+ household records, ~73k census
    tracts, all 51 states

#### Data Infrastructure

- **Zenodo data hosting** (established in v0.4.7-0.4.8)
  - 4 nationwide datasets published (AMI/FPL 2018/2022, 307 MB
    compressed)
  - MD5 checksum verification for data integrity
  - Automatic download cascade: Database → CSV → Zenodo → OpenEI
    fallback
  - Package stays under CRAN 5MB limit

#### Package Quality Metrics

- **Test coverage**: 648 comprehensive tests
  - 99 multi-state and nationwide tests
  - 48 metadata discovery tests
  - 62 Zenodo integration tests
  - Complete data loader and comparison function coverage
- **CI/CD infrastructure**
  - Multi-platform R CMD check (5 environments)
  - Test coverage reporting
  - Automated release workflow on version bumps
  - Pre-commit and pre-push hooks for local validation

**Breaking changes**: None. All existing NC-focused code continues to
work. Nationwide capability is additive.

**Next milestone**: CRAN submission! 🚀

## emburden 0.4.9

### Documentation Transition & Infrastructure

- **NC→Nationwide transition (Phase 1)**: Package documentation now
  showcases nationwide US capability
  - Updated `README.md` with multi-state and nationwide examples
    alongside NC examples
  - Updated all function examples
    ([`compare_energy_burden()`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md),
    [`load_cohort_data()`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md),
    [`load_census_tract_data()`](https://ericscheier.github.io/emburden/reference/load_census_tract_data.md))
  - Added test validating all 51 US states are supported (614 tests
    passing)
  - **Data coverage**: 2.3M household cohort records, ~73k census
    tracts, all 51 states
  - Follows “dual focus” strategy: NC examples for learning, nationwide
    examples for production use
  - See `.dev/NC-TO-NATIONWIDE-TRANSITION.md` for comprehensive
    transition plan
- **pkgdown build fix**: Resolved recurring CI failure
  - Changed
    [`backup_db()`](https://ericscheier.github.io/emburden/reference/backup_db.md)
    and
    [`clear_test_environment()`](https://ericscheier.github.io/emburden/reference/clear_test_environment.md)
    from `@export` to `@keywords internal`
  - Added pkgdown reference index check to pre-commit hook to prevent
    recurrence
  - Hook provides helpful hints about `@export` vs `@keywords internal`

**No breaking changes**: All NC-focused examples continue to work.
Nationwide data access is additive.

## emburden 0.4.8

### Database Protection & Testing Infrastructure

- **Production database protection** to prevent accidental data loss:
  - New `R/database-helpers.R` module with safe database operations
  - [`delete_db()`](https://ericscheier.github.io/emburden/reference/delete_db.md)
    requires explicit `confirm = TRUE` for production database
  - [`backup_db()`](https://ericscheier.github.io/emburden/reference/backup_db.md)
    creates timestamped backups before risky operations
  - [`clear_test_environment()`](https://ericscheier.github.io/emburden/reference/clear_test_environment.md)
    safely clears only test data
  - Separate test (`emburden_test_db.sqlite`) and production
    (`emburden_db.sqlite`) databases
  - All database helpers fully documented with roxygen2
- **Zenodo integration completed** with NATIONWIDE data publication:
  - Updated `R/zenodo.R` with published Zenodo record (DOI:
    10.5281/zenodo.17605603)
  - **4 NATIONWIDE datasets uploaded** (AMI/FPL 2018/2022, 307 MB
    compressed, all 51 US states)
  - 2.3+ million cohort records covering ~73,000 census tracts
  - All download functions now use real Zenodo URLs
  - MD5 checksum verification for all downloads
  - Automated Zenodo upload and R code update scripts
  - Comprehensive test suite (48 new metadata tests + 62 zenodo tests =
    604 total tests)
- **Comprehensive test coverage** for Zenodo infrastructure:
  - `tests/testthat/test-zenodo-integration.R`: Configuration and
    database protection tests
  - `tests/testthat/test-zenodo-download.R`: Download functionality
    tests
  - Fixed `tests/testthat/test-data-loaders.R` for Zenodo download
    cascade
  - All 556 tests passing (0 failures, 3 expected offline skips)
- **Development tools** for data management:
  - `.dev/upload-to-zenodo-nationwide.sh`: Automated nationwide Zenodo
    upload via REST API
  - `.dev/update-zenodo-config.R`: Auto-update R/zenodo.R from upload
    output
  - `.dev/prepare-zenodo-data-nationwide.R`: Script for preparing all 51
    states
  - `.dev/NC-TO-NATIONWIDE-TRANSITION.md`: Comprehensive transition plan
  - `.dev/TEST_ZENODO_DOWNLOAD.md`: Complete testing guide
  - Updated `.gitignore` for build artifacts
- **Metadata discovery functions** with comprehensive tests:
  - [`list_states()`](https://ericscheier.github.io/emburden/reference/list_states.md):
    Returns all 51 US state abbreviations
  - [`list_income_brackets()`](https://ericscheier.github.io/emburden/reference/list_income_brackets.md):
    Income brackets by dataset/vintage
  - [`list_cohort_columns()`](https://ericscheier.github.io/emburden/reference/list_cohort_columns.md):
    Column names and descriptions
  - [`get_dataset_info()`](https://ericscheier.github.io/emburden/reference/get_dataset_info.md):
    Complete dataset metadata
  - 48 new tests in `tests/testthat/test-metadata.R`

**Testing workflow**: Safe TDD workflow established with test database
isolation

**Next steps**: Transition documentation from NC-focused to nationwide
(see `.dev/NC-TO-NATIONWIDE-TRANSITION.md`), ready for CRAN submission

## emburden 0.4.7

### Data Hosting Infrastructure

- **Implemented Zenodo data hosting** with OpenEI fallback:
  - New `R/zenodo.R` module for downloading from Zenodo repository
  - Faster downloads via Zenodo CDN vs OpenEI
  - MD5 checksum verification for data integrity
  - Gzip decompression support for smaller downloads
  - Automatic fallback to OpenEI if Zenodo unavailable
- **Updated download cascade** in
  [`load_cohort_data()`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md)
  and
  [`load_census_tract_data()`](https://ericscheier.github.io/emburden/reference/load_census_tract_data.md):
  1.  Database (SQLite) - fastest, local
  2.  CSV (cached files) - fast, local
  3.  **Zenodo (NEW!)** - faster, more reliable
  4.  OpenEI (fallback) - original source
- **Added maintainer documentation**: `.dev/ZENODO_UPLOAD_GUIDE.md`
  - Complete workflow for preparing and uploading datasets
  - Compression and checksum procedures
  - Testing and versioning guidelines

**Benefits**: Nationwide data testing ready, package stays under CRAN
5MB limit (currently 1.9MB), improved download reliability

**Next steps**: Upload processed datasets to Zenodo, update DOI
configuration, ready for CRAN submission

## emburden 0.4.6

### CRAN Preparation Fixes

- **Fixed R CMD check WARNINGs and NOTEs**:
  - Excluded JSON data files (579MB) from package build via
    .Rbuildignore
  - Excluded top-level presentation/poster files (25+ non-standard
    files)
  - Added vignette metadata to jss-emburden.Rmd (VignetteEngine,
    VignetteIndexEntry)
  - Package now builds cleanly under 5MB for CRAN submission
- **Next steps for CRAN**: Implement Zenodo data hosting to fully
  separate data from methods package

## emburden 0.4.5

### New Features

- **Metadata discovery functions** for easier data exploration:
  - `list_income_brackets(dataset, vintage)`: Show available income
    brackets
  - [`list_states()`](https://ericscheier.github.io/emburden/reference/list_states.md):
    Show all 51 available state abbreviations
  - `list_cohort_columns(dataset, vintage)`: Show column names,
    descriptions, and data types
  - [`get_dataset_info()`](https://ericscheier.github.io/emburden/reference/get_dataset_info.md):
    Show metadata about all available datasets
  - Enables programmatic discovery of data structure

## emburden 0.4.4

### Breaking Changes

- **Parameter reordering in
  [`compare_energy_burden()`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md)**:
  `group_by` now comes before `counties`
  - **New order**:
    `compare_energy_burden(dataset, states, group_by, counties, ...)`
  - Makes intuitive syntax work:
    `compare_energy_burden('fpl', 'NC', 'income_bracket')`
  - Named parameters unaffected:
    `compare_energy_burden(dataset='fpl', counties=c('Orange'))`

### New Features

- **Dynamic grouping in
  [`compare_energy_burden()`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md)**:
  `group_by` now accepts custom column names
  - Use keywords: “income_bracket”, “state”, “none” (as before)
  - OR custom columns: `group_by = "geoid"` for tract-level comparison
  - OR multiple columns: `group_by = c("state_abbr", "income_bracket")`
  - Enables flexible analysis patterns for full USA data

## emburden 0.4.3

### New Features

- **Dynamic filtering in
  [`load_cohort_data()`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md)**:
  Now accepts `...` parameter for flexible filtering
  - Filter by any column using tidyverse syntax
  - Example:
    `load_cohort_data("ami", states = "NC", households > 100, total_income > 50000)`
  - Complements existing `states`, `counties`, `income_brackets`
    parameters
  - First step toward full USA data package architecture

## emburden 0.4.2

### Bug Fixes

- Fixed confusing warnings when using
  `compare_energy_burden('fpl', 'NC', 'income_bracket')`
- Function now silently handles common mistake of passing
  ‘income_bracket’, ‘state’, or ‘none’ as counties argument
- Eliminates “County name ‘income_bracket’ not found” warnings while
  maintaining correct behavior

### Improvements

- Improved documentation with clearer examples distinguishing between
  `group_by` and `counties` parameters

## emburden 0.4.1

### Improvements

- Updated contact email from <eric.scheier@gmail.com> to
  <eric@scheier.org> across all documentation

## emburden 0.4.0

### New Features

#### Fully Automated Release Workflow

- **Zero-touch releases**: GitHub releases now created automatically
  when version bumps are merged
  - Detects DESCRIPTION version changes automatically
  - Runs all quality checks (R CMD check, tests, coverage)
  - Generates release notes from NEWS.md
  - Creates git tags and GitHub releases with package tarball
  - No manual intervention required!
- **Workflow**: Simply bump version in DESCRIPTION, update NEWS.md,
  merge PR → release happens automatically

## emburden 0.3.0

### Major Improvements

#### OpenEI Data Pipeline Fix (Critical)

- **Fixed critical bug** where MVP demo
  `compare_energy_burden('fpl', 'NC', 'income_bracket')` failed on fresh
  installs
  - Root cause: Raw OpenEI 2022 FPL data wasn’t being processed
    correctly
  - OpenEI data uses period-based columns (`HINCP.UNITS`) not
    asterisk-based (`HINCP*UNITS`)
  - Raw data has ~588k rows (one per housing characteristic combination)
    requiring aggregation
- **New data processing pipeline**:
  - Added
    [`aggregate_cohort_data()`](https://ericscheier.github.io/emburden/reference/aggregate_cohort_data.md)
    function to aggregate raw data by census tract × income bracket
  - Updated detection logic to recognize both `.UNITS` and `*UNITS`
    column formats
  - Enhanced
    [`standardize_cohort_columns()`](https://ericscheier.github.io/emburden/reference/standardize_cohort_columns.md)
    to handle both `FPL150` (2022) and `FPL15` (2018)
  - Reduces 588k rows → ~3.6k cohort records for NC
- **Result**: Fresh installations now work perfectly - download from
  OpenEI → aggregate → standardize → ready!

#### Orange County Sample Data

- **NEW**: Bundled sample data for instant demos and testing (94 KB)
  - `data(orange_county_sample)` - No download required!
  - Includes 4 datasets: `fpl_2018`, `fpl_2022`, `ami_2018`, `ami_2022`
  - 749 records across 42 census tracts (Orange County, NC)
  - Perfect for vignettes, examples, and quick analysis
  - Shows real data: 16.3% energy burden for lowest income vs 1.0% for
    highest

#### Package Infrastructure

- **Renamed all internal references**: `emrgi` → `emburden` for
  consistency
  - `find_emrgi_db()` →
    [`find_emburden_db()`](https://ericscheier.github.io/emburden/reference/find_emburden_db.md)
  - Database filename: `emrgi_db.sqlite` → `emburden_db.sqlite`
- **Release automation**:
  - Added `.dev/RELEASE-PROCESS.md` - Comprehensive release workflow
    guide
  - Added `.dev/create-release-tag.R` - Automated release tagging script

### Documentation

- Updated README with Orange County sample data section
- Added comprehensive documentation for `orange_county_sample`
- All examples now work out of the box with bundled sample data

### Testing

- All 494 tests pass
- Verified OpenEI download and processing pipeline with real data
- Tested sample data access and analysis

## emburden 0.2.0

### New Features

#### JSS Manuscript Vignette

- Added Journal of Statistical Software (JSS) manuscript as package
  vignette
  - `vignettes/jss-emburden.Rmd` - Complete JSS article format
  - Demonstrates package usage with reproducible examples
  - Includes bibliography and proper JSS formatting
  - Test suite ensures vignette builds correctly in CI
- Created manuscript development infrastructure
  - `research/manuscripts/jss-draft/` - LaTeX build output
  - `research/manuscripts/build-jss.R` - Build script for PDF generation
  - Separate from vignettes for flexible editing workflow

#### Enhanced Temporal Comparison

- Prominently featured
  [`compare_energy_burden()`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md)
  function across all documentation
  - README now includes temporal comparison section (Example 5)
  - Getting Started vignette has comprehensive temporal comparison
    section
  - JSS vignette demonstrates function instead of manual calculations
  - Replaces 37-line manual comparison with elegant 12-line function
    call

### Bug Fixes

- Fixed FPL (Federal Poverty Line) data loading
  ([\#15](https://github.com/ericscheier/emburden/issues/15))
  - Added validation to skip files with missing or all-NA
    `income_bracket` columns
  - Loader now properly falls through to raw OpenEI files with complete
    data
  - Prevents “Element `income_bracket` doesn’t exist” errors

### Documentation Improvements

- Emphasized
  [`compare_energy_burden()`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md)
  usage across 7 files
  - `README.md` - Added temporal comparison section
  - `vignettes/jss-emburden.Rmd` - Replaced manual code with function
    call
  - `vignettes/getting-started.Rmd` - Added comprehensive section
  - `analysis/scripts/nc_comparison_for_email.R` - Complete rewrite
    (179→144 lines)
  - `data-raw/README.md` - Fixed function references
  - `research/manuscripts/jss-draft/jss-emburden.Rmd` - Updated examples
- Added pkgdown configuration for JSS vignette
  - Vignette appears in website navigation
  - Organized under “Package Documentation” section

### Infrastructure

- Added pre-commit hook for running package tests
  - `.git/hooks/pre-commit` - Runs all 238 tests before each commit
  - Prevents committing broken code
  - Can be bypassed with `--no-verify` if needed

### Internal Changes

- Improved data validation in
  [`load_cohort_data()`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md)
  - Better handling of incomplete processed CSV files
  - More informative verbose messaging

## emburden 0.1.1

### Documentation and Infrastructure Improvements

This patch release improves documentation accessibility and workflow
infrastructure, with no code changes.

#### Documentation

- Improved README accessibility and tone
  - Simplified technical language with plain-language explanations
  - Replaced prescriptive language (“WRONG”, “NEVER”) with educational
    tone (“Recommended”, “Note”)
  - Added concrete examples explaining why simple averaging of ratios
    fails
- Added complete Nature Communications citation
  - Scheier, E., & Kittner, N. (2022). A measurement strategy to address
    disparities across household energy burdens
  - Includes BibTeX format for easy reference

#### Infrastructure

- Changed git author in publish-to-public workflow from “GitHub Actions
  Bot” to “Eric Scheier”
  - Automated commits now appear as maintainer commits

## emburden 0.1.0

### Package Release

Initial formal release with package renamed from `netenergyequity` to
`emburden` for clarity and CRAN compatibility.

This is the first release of the netenergyequity package, providing
tools for household energy burden analysis using Net Energy Return
methodology.

#### Core Functionality

- Energy metric calculations
  - [`energy_burden_func()`](https://ericscheier.github.io/emburden/reference/energy_burden_func.md) -
    Calculate energy burden (S/G)
  - [`ner_func()`](https://ericscheier.github.io/emburden/reference/ner_func.md) -
    Calculate Net Energy Return (Nh)
  - [`eroi_func()`](https://ericscheier.github.io/emburden/reference/eroi_func.md) -
    Calculate Energy Return on Investment
  - [`dear_func()`](https://ericscheier.github.io/emburden/reference/dear_func.md) -
    Calculate Disposable Energy-Adjusted Resources
- Statistical analysis
  - [`calculate_weighted_metrics()`](https://ericscheier.github.io/emburden/reference/calculate_weighted_metrics.md) -
    Weighted aggregation with proper Nh methodology
  - Automatic poverty rate calculations below specified thresholds
  - Support for grouped analysis by geographic/demographic categories
- Formatting utilities
  - [`to_percent()`](https://ericscheier.github.io/emburden/reference/to_percent.md),
    [`to_dollar()`](https://ericscheier.github.io/emburden/reference/to_dollar.md),
    [`to_big()`](https://ericscheier.github.io/emburden/reference/to_big.md) -
    Publication-ready formatting
  - [`to_million()`](https://ericscheier.github.io/emburden/reference/to_million.md),
    [`to_billion_dollar()`](https://ericscheier.github.io/emburden/reference/to_billion_dollar.md) -
    Compact number formats
  - [`colorize()`](https://ericscheier.github.io/emburden/reference/colorize.md) -
    Output-aware color formatting for R Markdown

#### Package Structure

- Separated package code (`R/`) from analysis scripts (`analysis/`)
- Comprehensive documentation with roxygen2
- Test suite with testthat
- Example analysis scripts for NC electric utilities

#### Known Issues

- roxygen2 documentation generation requires manual NAMESPACE for now
- Large data files (1.1GB+) not included in package distribution
- Some analysis scripts need updating to use package functions

#### Future Plans

- Add vignettes demonstrating methodology
- Setup pkgdown website
- Configure GitHub Actions for CI/CD
- Consider CRAN submission
- Create companion data package or external data hosting solution
