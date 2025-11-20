#!/usr/bin/env Rscript
#
# Post-Process Zenodo Data (No Regeneration Required)
#
# This script applies post-processing fixes to already-generated Zenodo datasets
# WITHOUT requiring a full regeneration from OpenEI (saves time and bandwidth).
#
# Use this for:
#   - Column renaming (e.g., AMI150 → income_bracket)
#   - Adding derived columns
#   - Filtering/cleaning existing data
#   - Updating metadata/checksums
#
# DO NOT use this for:
#   - Changes to data loading logic
#   - New data sources or vintages
#   - Changes to aggregation/grouping
#   - Changes that require re-downloading from OpenEI
#
# Usage:
#   Rscript .dev/post-process-zenodo-data.R
#   Rscript .dev/post-process-zenodo-data.R --dataset ami_2022
#   Rscript .dev/post-process-zenodo-data.R --fix ami-column-rename
#

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tools)
})

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
specific_dataset <- NULL
specific_fix <- NULL

if ("--dataset" %in% args) {
  idx <- which(args == "--dataset")
  if (length(args) > idx) {
    specific_dataset <- args[idx + 1]
  }
}

if ("--fix" %in% args) {
  idx <- which(args == "--fix")
  if (length(args) > idx) {
    specific_fix <- args[idx + 1]
  }
}

cat("================================================================================\n")
cat("  Post-Processing Zenodo Datasets (No Regeneration)\n")
cat("================================================================================\n\n")

if (!is.null(specific_dataset)) {
  cat("Target dataset:", specific_dataset, "\n")
}
if (!is.null(specific_fix)) {
  cat("Specific fix:", specific_fix, "\n")
}
cat("\n")

# Base directory
base_dir <- "zenodo-upload-nationwide/nationwide"

if (!dir.exists(base_dir)) {
  stop("ERROR: Nationwide directory not found: ", base_dir, "\n",
       "       Please run prepare-zenodo-data-nationwide.R first to generate base datasets.")
}

# Find all .csv.gz files
all_files <- list.files(base_dir, pattern = "\\.csv\\.gz$", full.names = TRUE)

if (length(all_files) == 0) {
  stop("ERROR: No .csv.gz files found in ", base_dir)
}

cat("Found", length(all_files), "dataset(s) to process:\n")
for (f in all_files) {
  cat("  -", basename(f), "\n")
}
cat("\n")

# Define post-processing fixes
apply_ami_column_rename <- function(data, dataset_name) {
  # Fix AMI datasets that use AMI150 instead of income_bracket
  if (grepl("ami", dataset_name, ignore.case = TRUE) && "AMI150" %in% names(data)) {
    cat("  🔧 Applying fix: AMI150 → income_bracket\n")
    data <- data %>% rename(income_bracket = AMI150)
    cat("     ✓ Column renamed\n")
    return(list(data = data, modified = TRUE))
  }
  return(list(data = data, modified = FALSE))
}

apply_validation_checks <- function(data, dataset_name) {
  cat("  ✓ Validating dataset...\n")

  # Check required columns
  required_cols <- c("geoid", "income_bracket", "households",
                     "total_income", "total_electricity_spend")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop("    ❌ VALIDATION FAILED: Missing columns: ", paste(missing_cols, collapse = ", "))
  }

  # Check for state coverage
  if ("state_abbr" %in% names(data)) {
    n_states <- length(unique(data$state_abbr))
    cat("     States:", n_states, "\n")
    if (n_states < 51) {
      warning("    ⚠️  WARNING: Only ", n_states, " states found (expected 51)")
    }
  }

  # Check income_bracket has detailed values (not binary)
  if ("income_bracket" %in% names(data)) {
    unique_brackets <- unique(data$income_bracket)
    n_brackets <- length(unique_brackets)
    cat("     Income brackets:", n_brackets, "unique values\n")

    if (n_brackets < 5) {
      warning("    ⚠️  WARNING: Only ", n_brackets,
              " income brackets (expected detailed brackets, not binary)")
    }
  }

  cat("     Rows:", format(nrow(data), big.mark = ","), "\n")
  cat("     ✅ Validation passed\n")

  return(TRUE)
}

# Process each file
modified_files <- c()
skipped_files <- c()

for (gz_file in all_files) {
  dataset_name <- tools::file_path_sans_ext(tools::file_path_sans_ext(basename(gz_file)))

  # Check if we should process this file
  if (!is.null(specific_dataset) && !grepl(specific_dataset, dataset_name, ignore.case = TRUE)) {
    next
  }

  cat("================================================================================\n")
  cat("Processing:", dataset_name, "\n")
  cat("================================================================================\n\n")

  # Decompress
  cat("  📦 Decompressing...\n")
  csv_file <- tools::file_path_sans_ext(gz_file)
  system2("gunzip", args = c("-k", "-f", gz_file), stdout = FALSE, stderr = FALSE)

  # Read data
  cat("  📖 Reading data...\n")
  data <- read_csv(csv_file, show_col_types = FALSE)
  original_rows <- nrow(data)
  cat("     Loaded", format(original_rows, big.mark = ","), "rows\n\n")

  # Apply fixes
  modified <- FALSE

  # Fix 1: AMI column rename (if needed and requested)
  if (is.null(specific_fix) || specific_fix == "ami-column-rename") {
    result <- apply_ami_column_rename(data, dataset_name)
    data <- result$data
    modified <- modified || result$modified
  }

  # Validate
  cat("\n")
  apply_validation_checks(data, dataset_name)

  if (modified) {
    cat("\n  💾 Saving modified dataset...\n")

    # Write CSV
    write_csv(data, csv_file)

    # Compress
    cat("     Compressing...\n")
    system2("gzip", args = c("-9", "-f", csv_file), stdout = FALSE, stderr = FALSE)

    # Calculate new checksum
    new_md5 <- as.character(tools::md5sum(gz_file))
    new_size_mb <- round(file.size(gz_file) / 1024^2, 2)

    cat("     ✓ Updated successfully\n")
    cat("       Size:", new_size_mb, "MB\n")
    cat("       MD5:", new_md5, "\n")

    modified_files <- c(modified_files, dataset_name)
  } else {
    cat("\n  ⏭️  No modifications needed - skipping\n")

    # Remove decompressed file
    if (file.exists(csv_file)) {
      file.remove(csv_file)
    }

    skipped_files <- c(skipped_files, dataset_name)
  }

  cat("\n")
}

# Summary
cat("================================================================================\n")
cat("  Post-Processing Complete\n")
cat("================================================================================\n\n")

if (length(modified_files) > 0) {
  cat("✅ Modified", length(modified_files), "dataset(s):\n")
  for (f in modified_files) {
    cat("   -", f, "\n")
  }
  cat("\n")
}

if (length(skipped_files) > 0) {
  cat("⏭️  Skipped", length(skipped_files), "dataset(s) (no changes needed):\n")
  for (f in skipped_files) {
    cat("   -", f, "\n")
  }
  cat("\n")
}

cat("Next steps:\n")
cat("  1. Review changes: ls -lh", base_dir, "\n")
cat("  2. Update checksums in R/zenodo.R if needed\n")
cat("  3. Commit changes: git add . && git commit\n")
cat("  4. Upload to Zenodo when ready\n")
