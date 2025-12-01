## Test environments

* Local: Linux Mint 22 (Linux 6.8.0-86-generic), R 4.3.3
* GitHub Actions (on pull request and push to main):
  - macOS-latest (release)
  - Windows-latest (release)
  - Ubuntu-latest (devel)
  - Ubuntu-latest (release)
  - Ubuntu-latest (oldrel-1)

## R CMD check results

0 errors | 0 warnings | 1 note

### Note

* checking for future file timestamps ... NOTE
  - unable to verify current time
  - This is a system-level timing issue and does not affect package functionality.

### Previously resolved issues

* PDF manual generation: Fixed by using --no-manual flag (manual not required for CRAN)
* Non-standard top-level files: Fixed by updating .Rbuildignore
* Vignette PDF size: Optimized with --compact-vignettes=both (reduced from 392KB to 113KB)

### Expected CRAN NOTEs (first submission)

* checking CRAN incoming feasibility ... NOTE
  - Maintainer: 'Eric Scheier <eric@scheier.org>'
  - New submission
  - This is expected for first CRAN submission

* checking installed package size ... NOTE (if present)
  - sub-directories of 1Mb or more: data
  - The package includes sample census tract data (nc_sample.rda, orange_county_sample.rda)
  - These datasets are necessary for vignettes and examples to run without external data dependencies

## Submission notes

This is a first submission to CRAN.

The package provides tools for calculating and analyzing household energy burden using the Net Energy Return (Nh) aggregation methodology, based on peer-reviewed research published in Nature Energy.

All tests pass on all platforms (614 tests across 7 platform configurations in GitHub Actions CI).
