## Test environments

* Local: Ubuntu 22.04.3 LTS, R 4.3.3
* GitHub Actions (on pull request and push to main):
  - macOS-latest (release)
  - Windows-latest (release)
  - Ubuntu-latest (devel)
  - Ubuntu-latest (release)
  - Ubuntu-latest (oldrel-1)

## R CMD check results

0 errors | 1 warning | 3 notes

### Warning

* checking PDF version of manual without hyperrefs or index ... WARNING
  - LaTeX errors when creating PDF version of manual.
  - This is related to qpdf compression and does not affect package functionality.

### Notes

* checking CRAN incoming feasibility ... NOTE
  - Maintainer: 'Eric Scheier <eric@scheier.org>'
  - New submission

* checking package dependencies ... NOTE
  - Package suggested but not available for checking: 'rticles'
  - This is expected as rticles is only used for vignette building and is available on CRAN.

* checking installed package size ... NOTE
  - installed size is [X]Mb
  - sub-directories of 1Mb or more: data
  - The package includes sample census tract data for North Carolina, which is necessary for vignettes and examples.

## Submission notes

This is a first submission to CRAN.

The package provides tools for calculating and analyzing household energy burden using the Net Energy Return (Nh) aggregation methodology, based on peer-reviewed research published in Nature Energy.

All tests pass on all platforms (614 tests across 7 platform configurations in GitHub Actions CI).
