#!/usr/bin/env Rscript

# Pre-Tag CRAN Validation Script
# Run this script before creating a version tag to ensure CRAN readiness
#
# Usage:
#   Rscript .dev/pre-tag-cran-check.R [--submit-winbuilder]
#
# Options:
#   --submit-winbuilder  Also submit to Win-builder for Windows testing

library(devtools)
library(rcmdcheck)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
submit_winbuilder <- "--submit-winbuilder" %in% args

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  Pre-Tag CRAN Validation for emburden\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

# Track validation status
checks_passed <- TRUE
warnings <- character()

# Helper function to print status
print_status <- function(message, status = "INFO") {
  prefix <- switch(status,
    "OK" = "✅",
    "WARN" = "⚠️ ",
    "ERROR" = "❌",
    "INFO" = "ℹ️ "
  )
  cat(sprintf("%s %s\n", prefix, message))
}

# 1. Check version consistency
cat("\n[1/6] Checking version consistency across files...\n")
if (file.exists(".dev/check-version-consistency.R")) {
  tryCatch({
    source(".dev/check-version-consistency.R", local = TRUE)
    print_status("Version consistency validated", "OK")
  }, error = function(e) {
    print_status(paste("Version consistency check failed:", e$message), "ERROR")
    checks_passed <<- FALSE
  })
} else {
  print_status("Version consistency script not found", "WARN")
  warnings <<- c(warnings, "Missing .dev/check-version-consistency.R")
}

# 2. Check NEWS.md has been updated
cat("\n[2/6] Checking NEWS.md...\n")
if (file.exists("NEWS.md")) {
  news_content <- readLines("NEWS.md", warn = FALSE)

  # Get version from DESCRIPTION
  desc_version <- as.character(read.dcf("DESCRIPTION", fields = "Version"))

  # Check if version appears in NEWS.md
  version_in_news <- any(grepl(desc_version, news_content, fixed = TRUE))

  if (version_in_news) {
    print_status(sprintf("NEWS.md contains version %s", desc_version), "OK")
  } else {
    print_status(sprintf("NEWS.md does not mention version %s", desc_version), "ERROR")
    checks_passed <<- FALSE
  }
} else {
  print_status("NEWS.md not found", "ERROR")
  checks_passed <<- FALSE
}

# 3. Check git status
cat("\n[3/6] Checking git status...\n")
git_status <- system("git status --porcelain", intern = TRUE)
if (length(git_status) > 0) {
  print_status("Uncommitted changes detected:", "WARN")
  cat(paste("  ", git_status, collapse = "\n"), "\n")
  warnings <<- c(warnings, "Uncommitted changes")
} else {
  print_status("Working directory clean", "OK")
}

# 4. Build package
cat("\n[4/6] Building source package...\n")
tarball <- tryCatch({
  built <- devtools::build(quiet = FALSE)
  print_status(sprintf("Package built: %s", basename(built)), "OK")
  built
}, error = function(e) {
  print_status(paste("Build failed:", e$message), "ERROR")
  checks_passed <<- FALSE
  NULL
})

# 5. Run R CMD check --as-cran
if (!is.null(tarball)) {
  cat("\n[5/6] Running R CMD check --as-cran...\n")
  cat("This may take several minutes...\n\n")

  check_result <- tryCatch({
    rcmdcheck::rcmdcheck(
      path = tarball,
      args = c("--as-cran", "--no-manual"),
      error_on = "never",  # Don't error, we'll check manually
      check_dir = tempdir()
    )
  }, error = function(e) {
    print_status(paste("R CMD check failed to run:", e$message), "ERROR")
    checks_passed <<- FALSE
    NULL
  })

  if (!is.null(check_result)) {
    # Print summary
    cat("\n")
    print(check_result)
    cat("\n")

    # Check results
    if (length(check_result$errors) > 0) {
      print_status(sprintf("%d ERROR(s) found", length(check_result$errors)), "ERROR")
      checks_passed <<- FALSE
    }

    if (length(check_result$warnings) > 0) {
      print_status(sprintf("%d WARNING(s) found", length(check_result$warnings)), "ERROR")
      checks_passed <<- FALSE
    }

    if (length(check_result$notes) > 0) {
      print_status(sprintf("%d NOTE(s) found", length(check_result$notes)), "WARN")
      warnings <<- c(warnings, sprintf("%d NOTEs in R CMD check", length(check_result$notes)))
      cat("\nNOTEs should be reviewed, but may be acceptable for CRAN:\n")
      for (note in check_result$notes) {
        cat(sprintf("  • %s\n", note))
      }
    }

    if (length(check_result$errors) == 0 && length(check_result$warnings) == 0) {
      print_status("R CMD check passed!", "OK")
    }
  }
} else {
  cat("\n[5/6] Skipping R CMD check (build failed)\n")
}

# 6. Optional Win-builder submission
if (submit_winbuilder && !is.null(tarball)) {
  cat("\n[6/6] Submitting to Win-builder...\n")

  # Get email from environment or prompt
  cran_email <- Sys.getenv("CRAN_EMAIL")
  if (cran_email == "") {
    cat("Enter CRAN maintainer email: ")
    cran_email <- readLines("stdin", n = 1)
  }

  tryCatch({
    devtools::check_win_release(email = cran_email)
    print_status("Submitted to Win-builder", "OK")
    cat(sprintf("\n  Results will be emailed to %s within ~30 minutes\n", cran_email))
  }, error = function(e) {
    print_status(paste("Win-builder submission failed:", e$message), "WARN")
    warnings <<- c(warnings, "Win-builder submission failed")
  })
} else if (submit_winbuilder && is.null(tarball)) {
  cat("\n[6/6] Skipping Win-builder (build failed)\n")
} else {
  cat("\n[6/6] Skipping Win-builder (use --submit-winbuilder to enable)\n")
  print_status("Win-builder submission skipped", "INFO")
  print_status("Run with --submit-winbuilder flag for Windows testing", "INFO")
}

# Summary
cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  Validation Summary\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

if (checks_passed) {
  if (length(warnings) == 0) {
    print_status("All checks passed! ✨", "OK")
    cat("\n")
    cat("Your package is ready for CRAN submission.\n")
    cat("\n")
    cat("Next steps:\n")
    cat("  1. Create version tag: git tag -a vX.Y.Z -m 'Release vX.Y.Z'\n")
    cat("  2. Push tag: git push origin vX.Y.Z\n")
    cat("  3. GitHub Actions will run validation and wait for approval\n")
    cat("  4. After approval, package will be auto-submitted to CRAN\n")
    cat("\n")
  } else {
    print_status("Checks passed with warnings:", "WARN")
    for (w in warnings) {
      cat(sprintf("  • %s\n", w))
    }
    cat("\n")
    cat("Consider addressing warnings before creating version tag.\n")
    cat("\n")
  }
} else {
  print_status("Validation failed! ❌", "ERROR")
  cat("\n")
  cat("Please fix the errors above before creating a version tag.\n")
  cat("\n")
  quit(status = 1)
}

cat("\n")
