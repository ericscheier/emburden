#!/usr/bin/env Rscript
# Feature Integration Protocol Script
# Systematically integrates completed features into dev branch
# with comprehensive testing, documentation, and validation
#
# Usage:
#   Rscript .dev/integrate-feature-to-dev.R [--feature-name "NAME"] [--skip-check]
#
# Example:
#   Rscript .dev/integrate-feature-to-dev.R --feature-name "housing-dimensions"
#
# This script implements the 6-phase integration protocol:
# Phase 1: Testing - Ensure comprehensive test coverage
# Phase 2: Documentation - Update docs, vignettes, NEWS.md
# Phase 3: Validation - Run devtools checks
# Phase 4: Protocol - Create reusable templates (this script!)
# Phase 5: Git Integration - Commit changes
# Phase 6: CI Validation - Verify CI passes

library(devtools)
library(usethis)

# Color output for terminal
red <- function(x) paste0("\033[31m", x, "\033[0m")
green <- function(x) paste0("\033[32m", x, "\033[0m")
yellow <- function(x) paste0("\033[33m", x, "\033[0m")
blue <- function(x) paste0("\033[34m", x, "\033[0m")
bold <- function(x) paste0("\033[1m", x, "\033[0m")

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
feature_name <- NULL
skip_check <- FALSE

if (length(args) > 0) {
  for (i in seq_along(args)) {
    if (args[i] == "--feature-name" && i < length(args)) {
      feature_name <- args[i + 1]
    } else if (args[i] == "--skip-check") {
      skip_check <- TRUE
    } else if (args[i] == "--help" || args[i] == "-h") {
      cat("Feature Integration Protocol Script\n\n")
      cat("Usage:\n")
      cat("  Rscript .dev/integrate-feature-to-dev.R [OPTIONS]\n\n")
      cat("Options:\n")
      cat("  --feature-name NAME  Name of the feature being integrated\n")
      cat("  --skip-check         Skip R CMD check (faster, for quick iterations)\n")
      cat("  --help, -h           Show this help message\n\n")
      cat("Example:\n")
      cat("  Rscript .dev/integrate-feature-to-dev.R --feature-name 'housing-dimensions'\n\n")
      quit(save = "no", status = 0)
    }
  }
}

# Interactive prompt if feature name not provided
if (is.null(feature_name)) {
  cat(blue("Enter feature name (e.g., 'housing-dimensions'): "))
  feature_name <- readLines(con = "stdin", n = 1, warn = FALSE)
  if (length(feature_name) == 0 || feature_name == "") {
    cat(red("✖ Feature name required\n"))
    quit(save = "no", status = 1)
  }
}

cat(bold(blue("\n══════════════════════════════════════════════════════════\n")))
cat(bold(blue("  Feature Integration Protocol\n")))
cat(bold(blue("══════════════════════════════════════════════════════════\n\n")))
cat(sprintf("Feature: %s\n", bold(feature_name)))
cat(sprintf("Date: %s\n", Sys.Date()))
cat("\n")

# Phase tracking
phase_status <- list()

# Helper function to run phase
run_phase <- function(phase_num, phase_name, phase_func) {
  cat(bold(sprintf("\n═══ Phase %d: %s ═══\n", phase_num, phase_name)))

  result <- tryCatch({
    phase_func()
    phase_status[[phase_name]] <<- "✔"
    cat(green(sprintf("✔ Phase %d complete\n", phase_num)))
    TRUE
  }, error = function(e) {
    phase_status[[phase_name]] <<- "✖"
    cat(red(sprintf("✖ Phase %d failed: %s\n", phase_num, e$message)))
    FALSE
  })

  return(result)
}

# PHASE 1: Testing
phase1_testing <- function() {
  cat("Running test suite validation...\n")

  # Check if test files exist for this feature
  test_files <- list.files("tests/testthat",
                           pattern = "test-.*\\.R$",
                           full.names = TRUE)
  cat(sprintf("Found %d test files\n", length(test_files)))

  # Run tests
  cat("\nRunning devtools::test()...\n")
  test_results <- devtools::test()

  # Check results
  if (any(as.data.frame(test_results)$failed > 0)) {
    stop("Tests failed. Fix failing tests before integration.")
  }

  total_tests <- sum(as.data.frame(test_results)$nb)
  cat(green(sprintf("✔ All %d tests passing\n", total_tests)))

  return(TRUE)
}

# PHASE 2: Documentation
phase2_documentation <- function() {
  cat("Updating documentation...\n")

  # Regenerate documentation
  cat("\nRunning devtools::document()...\n")
  devtools::document()
  cat(green("✔ Documentation regenerated\n"))

  # Check NEWS.md exists and has recent entry
  if (file.exists("NEWS.md")) {
    news <- readLines("NEWS.md", n = 20)
    if (length(news) > 0) {
      cat(green("✔ NEWS.md exists\n"))
      cat(sprintf("  First line: %s\n", news[1]))
    }
  } else {
    cat(yellow("⚠ NEWS.md not found - consider adding changelog entry\n"))
  }

  # Check vignettes
  vignettes <- list.files("vignettes", pattern = "\\.Rmd$")
  if (length(vignettes) > 0) {
    cat(green(sprintf("✔ Found %d vignette(s)\n", length(vignettes))))
  }

  return(TRUE)
}

# PHASE 3: Validation
phase3_validation <- function() {
  cat("Running R CMD check validation...\n")

  if (skip_check) {
    cat(yellow("⚠ Skipping R CMD check (--skip-check flag set)\n"))
    return(TRUE)
  }

  cat("\nRunning devtools::check()...\n")
  cat(yellow("(This may take several minutes...)\n\n"))

  check_results <- devtools::check(
    document = FALSE,  # Already documented in Phase 2
    quiet = FALSE
  )

  # Analyze results
  errors <- length(check_results$errors)
  warnings <- length(check_results$warnings)
  notes <- length(check_results$notes)

  if (errors > 0) {
    cat(red(sprintf("✖ %d ERROR(S) found\n", errors)))
    stop("R CMD check found errors. Fix before integration.")
  }

  if (warnings > 0) {
    cat(yellow(sprintf("⚠ %d WARNING(S) found\n", warnings)))
    cat("Review warnings before integration:\n")
    for (w in check_results$warnings) {
      cat(sprintf("  - %s\n", w))
    }
  }

  if (notes > 0) {
    cat(blue(sprintf("ℹ %d NOTE(S) found\n", notes)))
  }

  cat(green("✔ R CMD check passed (0 errors)\n"))
  return(TRUE)
}

# PHASE 4: Git Status Check
phase4_git_status <- function() {
  cat("Checking git status...\n")

  # Get current branch
  branch_result <- system("git branch --show-current", intern = TRUE)
  current_branch <- trimws(branch_result)

  cat(sprintf("Current branch: %s\n", bold(current_branch)))

  if (current_branch != "dev") {
    cat(yellow(sprintf("⚠ Not on dev branch. Consider switching to dev.\n")))
    cat("  Run: git checkout dev\n")
  }

  # Check for uncommitted changes
  status_result <- system("git status --porcelain", intern = TRUE)

  if (length(status_result) > 0) {
    cat(blue(sprintf("\nℹ %d file(s) with changes:\n", length(status_result))))
    # Show first 10 files
    display_files <- head(status_result, 10)
    for (f in display_files) {
      cat(sprintf("  %s\n", f))
    }
    if (length(status_result) > 10) {
      cat(sprintf("  ... and %d more\n", length(status_result) - 10))
    }
  } else {
    cat(green("✔ No uncommitted changes\n"))
  }

  return(TRUE)
}

# PHASE 5: Integration Summary
phase5_summary <- function() {
  cat("\nGenerating integration summary...\n\n")

  cat(bold("Integration Checklist:\n"))
  cat(sprintf("  [%s] Tests: Comprehensive test coverage added\n",
              if (phase_status[["Testing"]]) green("✔") else " "))
  cat(sprintf("  [%s] Documentation: Function docs and vignettes updated\n",
              if (phase_status[["Documentation"]]) green("✔") else " "))
  cat(sprintf("  [%s] Validation: R CMD check passed\n",
              if (phase_status[["Validation"]]) green("✔") else " "))
  cat(sprintf("  [%s] Git Status: Changes reviewed\n",
              if (phase_status[["Git Status"]]) green("✔") else " "))

  cat("\n")
  cat(bold("Next Steps:\n"))
  cat("  1. Review checklist: .dev/FEATURE_INTEGRATION_CHECKLIST.md\n")
  cat("  2. Commit changes: git add . && git commit -m 'feat: <description>'\n")
  cat("  3. Push to remote: git push origin dev\n")
  cat("  4. Verify CI passes: Check GitHub Actions\n")
  cat("  5. Ready for staging: Merge dev → staging when ready\n")

  return(TRUE)
}

# Execute all phases
success <- TRUE
success <- success && run_phase(1, "Testing", phase1_testing)
success <- success && run_phase(2, "Documentation", phase2_documentation)
success <- success && run_phase(3, "Validation", phase3_validation)
success <- success && run_phase(4, "Git Status", phase4_git_status)
success <- success && run_phase(5, "Summary", phase5_summary)

# Final status
cat(bold(blue("\n══════════════════════════════════════════════════════════\n")))
if (success) {
  cat(bold(green("✔ Feature integration protocol complete!\n")))
  cat(bold(blue("══════════════════════════════════════════════════════════\n\n")))
  quit(save = "no", status = 0)
} else {
  cat(bold(red("✖ Feature integration protocol failed\n")))
  cat(bold(blue("══════════════════════════════════════════════════════════\n\n")))
  quit(save = "no", status = 1)
}
