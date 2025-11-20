#!/usr/bin/env Rscript
# Validate Zenodo MD5 Checksums
#
# This script compares MD5 checksums between:
# 1. state-manifest.json (actual generated files)
# 2. R/zenodo.R (configured in package code)
#
# Usage:
#   Rscript .dev/validate-zenodo-checksums.R
#
# Exit codes:
#   0 = All checksums match
#   1 = Mismatches found or validation failed

cat("\n")
cat("==========================================\n")
cat("  Zenodo MD5 Checksum Validation\n")
cat("==========================================\n\n")

# Load required packages
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' required. Install with: install.packages('jsonlite')")
}

# Read state manifest
manifest_path <- "zenodo-upload-nationwide/state-manifest.json"

if (!file.exists(manifest_path)) {
  cat("❌ ERROR: state-manifest.json not found at:", manifest_path, "\n")
  cat("   Have you generated the Zenodo data yet?\n\n")
  quit(status = 1)
}

cat("📄 Reading state-manifest.json...\n")
manifest <- jsonlite::read_json(manifest_path)

# Source R/zenodo.R to get configuration
cat("📄 Reading R/zenodo.R configuration...\n")
source("R/zenodo.R")
config <- get_zenodo_config()

# Datasets to validate
datasets <- c("ami_2022", "fpl_2022", "ami_2018", "fpl_2018")

# Track validation results
all_valid <- TRUE
mismatches <- list()

cat("\n🔍 Validating checksums...\n\n")

for (dataset in datasets) {
  # Get checksums
  manifest_md5 <- manifest$nationwide[[dataset]]$md5
  config_md5 <- config$files[[dataset]]$md5

  manifest_size <- manifest$nationwide[[dataset]]$size_mb
  config_size <- config$files[[dataset]]$size_mb

  # Check MD5
  md5_match <- identical(manifest_md5, config_md5)

  # Check file size (allow 0.1 MB tolerance for rounding)
  size_match <- abs(manifest_size - config_size) < 0.1

  if (md5_match && size_match) {
    cat(sprintf("✅ %s: MD5 and size match\n", dataset))
  } else {
    all_valid <- FALSE
    cat(sprintf("❌ %s: MISMATCH DETECTED!\n", dataset))

    if (!md5_match) {
      cat(sprintf("   MD5 manifest:  %s\n", manifest_md5))
      cat(sprintf("   MD5 R/zenodo:  %s\n", config_md5))
    }

    if (!size_match) {
      cat(sprintf("   Size manifest: %.2f MB\n", manifest_size))
      cat(sprintf("   Size R/zenodo: %.2f MB\n", config_size))
    }

    cat("\n")

    mismatches[[dataset]] <- list(
      manifest_md5 = manifest_md5,
      config_md5 = config_md5,
      manifest_size = manifest_size,
      config_size = config_size
    )
  }
}

cat("\n==========================================\n")

if (all_valid) {
  cat("✅ SUCCESS: All checksums and sizes match!\n")
  cat("==========================================\n\n")
  quit(status = 0)
} else {
  cat("❌ FAILURE: Checksum/size mismatches found\n")
  cat("==========================================\n\n")

  cat("TO FIX:\n")
  cat("  1. Update R/zenodo.R with the correct values from state-manifest.json\n")
  cat("  2. Re-run this validation script to confirm\n")
  cat("  3. Commit the corrected R/zenodo.R\n\n")

  cat("AUTOMATED FIX (copy-paste to terminal):\n")
  cat("----------------------------------------\n")
  for (dataset in names(mismatches)) {
    m <- mismatches[[dataset]]
    cat(sprintf("# Fix %s:\n", dataset))
    cat(sprintf("# Update md5 to: %s\n", m$manifest_md5))
    cat(sprintf("# Update size_mb to: %.2f\n\n", m$manifest_size))
  }

  quit(status = 1)
}
