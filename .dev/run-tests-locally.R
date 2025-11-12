#!/usr/bin/env Rscript
# Local test runner that replicates GitHub Actions R-CMD-check
#
# Usage:
#   Rscript tests/run-tests-locally.R
#
# Or from R console:
#   source("tests/run-tests-locally.R")

cat("\n")
cat("========================================\n")
cat("  LOCAL TEST SUITE FOR EMBURDEN PACKAGE\n")
cat("========================================\n")
cat("\n")

# Check if we're in the package root
if (!file.exists("DESCRIPTION")) {
  stop("Must be run from package root directory")
}

# Load required packages
required_pkgs <- c("testthat", "devtools", "covr")
missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

if (length(missing_pkgs) > 0) {
  cat("Installing missing packages:", paste(missing_pkgs, collapse = ", "), "\n")
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
}

library(testthat)
library(devtools)

# Configuration
options(
  testthat.summary.max_reports = 10,
  testthat.output_file = "test-results.txt"
)

cat("\n")
cat("Step 1: Loading package...\n")
cat("----------------------------------------\n")
tryCatch({
  devtools::load_all(".", quiet = FALSE)
  cat("✓ Package loaded successfully\n")
}, error = function(e) {
  cat("✗ Failed to load package:\n")
  cat("  ", conditionMessage(e), "\n")
  quit(status = 1)
})

cat("\n")
cat("Step 2: Running tests...\n")
cat("----------------------------------------\n")

# Run tests with detailed output
test_results <- tryCatch({
  devtools::test(reporter = "progress")
}, error = function(e) {
  cat("✗ Test execution failed:\n")
  cat("  ", conditionMessage(e), "\n")
  quit(status = 1)
})

cat("\n")
cat("Step 3: Test coverage analysis...\n")
cat("----------------------------------------\n")

coverage_results <- tryCatch({
  covr::package_coverage(
    type = c("tests", "examples"),
    quiet = FALSE
  )
}, error = function(e) {
  cat("⚠ Coverage analysis failed (non-critical):\n")
  cat("  ", conditionMessage(e), "\n")
  NULL
})

if (!is.null(coverage_results)) {
  cat("\n")
  print(coverage_results)

  # Calculate overall coverage percentage
  coverage_pct <- covr::percent_coverage(coverage_results)
  cat("\n")
  cat(sprintf("Overall test coverage: %.1f%%\n", coverage_pct))

  # Flag if coverage is too low
  if (coverage_pct < 75) {
    cat("⚠ WARNING: Coverage is below 75% target\n")
  } else if (coverage_pct < 85) {
    cat("⚠ Coverage is below 85% goal but above minimum\n")
  } else {
    cat("✓ Coverage meets 85% goal\n")
  }

  # Generate HTML coverage report
  coverage_html <- file.path("tests", "coverage-report.html")
  tryCatch({
    covr::report(coverage_results, file = coverage_html, browse = FALSE)
    cat(sprintf("✓ HTML coverage report: %s\n", coverage_html))
  }, error = function(e) {
    cat("⚠ Could not generate HTML report\n")
  })
}

cat("\n")
cat("Step 4: R CMD check (if requested)...\n")
cat("----------------------------------------\n")

# Check if user wants full R CMD check
run_cmd_check <- Sys.getenv("RUN_CMD_CHECK", "false") == "true"

if (run_cmd_check) {
  cat("Running full R CMD check...\n")
  check_results <- tryCatch({
    devtools::check(
      document = TRUE,
      args = c("--no-manual", "--as-cran"),
      error_on = "warning"
    )
  }, error = function(e) {
    cat("✗ R CMD check failed:\n")
    cat("  ", conditionMessage(e), "\n")
    quit(status = 1)
  })

  cat("✓ R CMD check passed\n")
} else {
  cat("Skipping R CMD check (set RUN_CMD_CHECK=true to enable)\n")
}

cat("\n")
cat("========================================\n")
cat("  TEST SUITE COMPLETE\n")
cat("========================================\n")
cat("\n")

# Summary
if (all(test_results$failed == 0)) {
  cat("✓ All tests passed!\n")
  cat(sprintf("  - %d tests run\n", sum(test_results$passed)))
  cat(sprintf("  - %d expectations checked\n", sum(test_results$passed)))

  if (!is.null(coverage_results)) {
    cat(sprintf("  - %.1f%% code coverage\n", coverage_pct))
  }

  cat("\n")
  quit(status = 0)
} else {
  cat("✗ Some tests failed!\n")
  cat(sprintf("  - %d tests passed\n", sum(test_results$passed)))
  cat(sprintf("  - %d tests failed\n", sum(test_results$failed)))
  cat(sprintf("  - %d tests skipped\n", sum(test_results$skipped)))
  cat("\n")
  cat("Review test output above for details.\n")
  cat("\n")
  quit(status = 1)
}
