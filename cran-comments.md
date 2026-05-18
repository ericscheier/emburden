## Resubmission (0.6.2)

This release addresses the check failure reported by CRAN on 2026-05-18
on `r-devel-linux-x86_64-fedora-clang` (the only platform that failed;
all 12 other CRAN check platforms passed):

> test-neb-equivalence.R:458:3: error
> Nh method (arithmetic mean) is faster than harmonic mean
> `speedup_vs_harmonic > 0.5` is not TRUE

That assertion compared wall-clock times for two micro-benchmarks
(1,000 iterations of `weighted.mean()` on a 10,000-element vector).
The ratio is sensitive to check-machine load and was unreliable on
the failing platform.

Fix: the two performance-benchmark tests in
`tests/testthat/test-neb-equivalence.R` (Test 13: "Nh method
(arithmetic mean) is faster than harmonic mean"; Test 14: "Nh method
scales well with dataset size") now call `skip_on_cran()`. This
matches the established pattern already used elsewhere in the suite
(`test-ecosystem-integration.R`, `test-visualizations.R`,
`test-zenodo-*.R`, `test-jss-vignette.R`). The underlying correctness
assertions (1e-10 agreement between the Nh and harmonic-mean methods,
non-zero error from the arithmetic-mean-of-burden method) remain in
the tests and run on local development and CI.

No other source changes.

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
