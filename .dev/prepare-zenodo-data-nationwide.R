#!/usr/bin/env Rscript
# Prepare Nationwide Analysis-Ready Datasets for Zenodo Upload
#
# This script generates PROCESSED, analysis-ready datasets organized by state
# and as combined nationwide datasets. Users can download individual states
# or the full nationwide dataset.
#
# Output structure:
#   zenodo-upload-nationwide/
#     by-state/
#       NC/
#         lead_ami_cohorts_2022_nc.csv.gz
#         lead_fpl_cohorts_2022_nc.csv.gz
#         lead_ami_cohorts_2018_nc.csv.gz
#         lead_fpl_cohorts_2018_nc.csv.gz
#       CA/
#         ...
#       [all 51 states/territories]
#     nationwide/
#       lead_ami_cohorts_2022_us.csv.gz
#       lead_fpl_cohorts_2022_us.csv.gz
#       lead_ami_cohorts_2018_us.csv.gz
#       lead_fpl_cohorts_2018_us.csv.gz
#     checksums.txt
#     state-manifest.json

library(emburden)
library(dplyr)
library(readr)
library(jsonlite)

cat("\n")
cat("================================================================================\n")
cat("  Preparing Nationwide Analysis-Ready Datasets for Zenodo Upload\n")
cat("================================================================================\n")
cat("\n")
cat("This script downloads RAW data from OpenEI, processes it into analysis-ready\n")
cat("format, and organizes it by state AND as nationwide datasets.\n")
cat("\n")

# Configuration
args <- commandArgs(trailingOnly = TRUE)
states_only <- "--states-only" %in% args
nationwide_only <- "--nationwide-only" %in% args
quick_test <- "--quick-test" %in% args  # Just a few states for testing

# Output directories
base_dir <- "zenodo-upload-nationwide"
state_dir <- file.path(base_dir, "by-state")
nationwide_dir <- file.path(base_dir, "nationwide")

dir.create(base_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(state_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(nationwide_dir, showWarnings = FALSE, recursive = TRUE)

cat("Output directories:\n")
cat("  Base:", normalizePath(base_dir), "\n")
cat("  By-state:", normalizePath(state_dir), "\n")
cat("  Nationwide:", normalizePath(nationwide_dir), "\n\n")

# Get all available states (51 total: 50 states + DC)
# Note: PR excluded as it's often not in the OpenEI data
all_states <- list_states()

if (quick_test) {
  cat("QUICK TEST MODE: Using only 3 states (NC, CA, TX)\n\n")
  all_states <- c("NC", "CA", "TX")
}

cat("States to process:", length(all_states), "\n")
cat("States:", paste(all_states, collapse = ", "), "\n\n")

# Dataset configurations
datasets <- list(
  list(name = "ami", vintage = "2022"),
  list(name = "fpl", vintage = "2022"),
  list(name = "ami", vintage = "2018"),
  list(name = "fpl", vintage = "2018")
)

# Manifest to track all files
manifest <- list(
  generated = Sys.time(),
  emburden_version = as.character(packageVersion("emburden")),
  states = list(),
  nationwide = list(),
  statistics = list()
)

# Function to compress and save
compress_and_save <- function(data, output_file, desc) {
  cat("  Saving:", basename(output_file), "\n")

  # Save uncompressed
  write_csv(data, output_file)

  # Compress
  system2("gzip", args = c("-9", "-f", output_file))
  gz_file <- paste0(output_file, ".gz")

  # Get file info
  size_bytes <- file.size(gz_file)
  size_mb <- round(size_bytes / 1024^2, 2)
  md5 <- as.character(tools::md5sum(gz_file))

  cat("    Size:", size_mb, "MB (compressed)\n")
  cat("    Rows:", format(nrow(data), big.mark = ","), "\n")
  cat("    MD5:", md5, "\n")

  return(list(
    filename = basename(gz_file),
    path = normalizePath(gz_file),
    size_mb = size_mb,
    rows = nrow(data),
    md5 = md5,
    description = desc
  ))
}

# Initialize nationwide data collectors
if (!nationwide_only) {

  cat("================================================================================\n")
  cat("  Phase 1: Processing State-by-State Datasets\n")
  cat("================================================================================\n\n")

  for (state in all_states) {
    cat("================================================================================\n")
    cat("Processing State:", state, "\n")
    cat("================================================================================\n\n")

    # Create state directory
    state_output_dir <- file.path(state_dir, state)
    dir.create(state_output_dir, showWarnings = FALSE, recursive = TRUE)

    state_manifest <- list(
      state = state,
      datasets = list()
    )

    for (ds in datasets) {
      dataset_name <- ds$name
      vintage <- ds$vintage

      cat("  Dataset:", toupper(dataset_name), vintage, "\n")

      # Load state data
      data <- tryCatch({
        load_cohort_data(
          dataset = dataset_name,
          vintage = vintage,
          states = state,
          verbose = FALSE
        )
      }, error = function(e) {
        cat("    ERROR:", e$message, "\n\n")
        return(NULL)
      })

      if (is.null(data) || nrow(data) == 0) {
        cat("    SKIPPED: No data available\n\n")
        next
      }

      # Save state-specific dataset
      state_file <- file.path(
        state_output_dir,
        sprintf("lead_%s_cohorts_%s_%s.csv", dataset_name, vintage, tolower(state))
      )

      file_info <- compress_and_save(
        data,
        state_file,
        sprintf("%s %s cohort data for %s", vintage, toupper(dataset_name), state)
      )

      state_manifest$datasets[[paste0(dataset_name, "_", vintage)]] <- file_info

      cat("\n")
    }

    # Save state manifest
    manifest$states[[state]] <- state_manifest

    cat("✓ State", state, "complete\n\n")
  }
}

# Phase 2: Create nationwide combined datasets
if (!states_only) {

  cat("================================================================================\n")
  cat("  Phase 2: Creating Nationwide Combined Datasets\n")
  cat("================================================================================\n\n")

  for (ds in datasets) {
    dataset_name <- ds$name
    vintage <- ds$vintage

    cat("================================================================================\n")
    cat("Nationwide Dataset:", toupper(dataset_name), vintage, "\n")
    cat("================================================================================\n\n")

    cat("  Loading all states...\n")

    # Load all states
    all_data <- tryCatch({
      load_cohort_data(
        dataset = dataset_name,
        vintage = vintage,
        states = all_states,
        verbose = TRUE
      )
    }, error = function(e) {
      cat("  ERROR:", e$message, "\n\n")
      return(NULL)
    })

    if (is.null(all_data) || nrow(all_data) == 0) {
      cat("  SKIPPED: No data available\n\n")
      next
    }

    cat("\n  Combined data loaded successfully!\n")
    cat("    Total rows:", format(nrow(all_data), big.mark = ","), "\n")
    cat("    Total states:", length(unique(all_data$state_abbr)), "\n\n")

    # Save nationwide dataset
    nationwide_file <- file.path(
      nationwide_dir,
      sprintf("lead_%s_cohorts_%s_us.csv", dataset_name, vintage)
    )

    file_info <- compress_and_save(
      all_data,
      nationwide_file,
      sprintf("%s %s cohort data (all US states)", vintage, toupper(dataset_name))
    )

    manifest$nationwide[[paste0(dataset_name, "_", vintage)]] <- file_info

    cat("\n")
  }
}

# Phase 3: Generate checksums and manifest
cat("================================================================================\n")
cat("  Phase 3: Generating Checksums and Manifest\n")
cat("================================================================================\n\n")

# Find all .gz files
all_gz_files <- list.files(
  base_dir,
  pattern = "\\.csv\\.gz$",
  recursive = TRUE,
  full.names = TRUE
)

cat("Total compressed files:", length(all_gz_files), "\n\n")

# Calculate checksums
cat("Calculating checksums...\n")
checksums_file <- file.path(base_dir, "checksums.txt")
checksums <- tools::md5sum(all_gz_files)

# Write checksums with relative paths
writeLines(
  paste(checksums, sub(paste0("^", normalizePath(base_dir), "/"), "", names(checksums))),
  checksums_file
)

cat("✓ Checksums saved to:", basename(checksums_file), "\n\n")

# Calculate statistics
total_size_mb <- sum(sapply(all_gz_files, function(f) file.size(f) / 1024^2))
total_rows <- 0

for (state_data in manifest$states) {
  for (ds_data in state_data$datasets) {
    total_rows <- total_rows + ds_data$rows
  }
}

for (nationwide_data in manifest$nationwide) {
  # Don't double-count (nationwide is combination of states)
}

manifest$statistics <- list(
  total_files = length(all_gz_files),
  total_size_mb = round(total_size_mb, 2),
  total_rows_by_state = total_rows,
  states_processed = length(manifest$states),
  nationwide_datasets = length(manifest$nationwide)
)

# Save manifest
manifest_file <- file.path(base_dir, "state-manifest.json")
write_json(manifest, manifest_file, pretty = TRUE, auto_unbox = TRUE)

cat("✓ Manifest saved to:", basename(manifest_file), "\n\n")

# Summary
cat("================================================================================\n")
cat("  Data Preparation Complete\n")
cat("================================================================================\n\n")

cat("Statistics:\n")
cat("  States processed:", manifest$statistics$states_processed, "\n")
cat("  Total files:", manifest$statistics$total_files, "\n")
cat("  Total size:", manifest$statistics$total_size_mb, "MB (compressed)\n")
cat("  Total rows (by-state):", format(manifest$statistics$total_rows_by_state, big.mark = ","), "\n\n")

cat("Output directory:", normalizePath(base_dir), "\n\n")

cat("Next steps:\n")
cat("  1. Review the manifest: cat", manifest_file, "\n")
cat("  2. Upload to Zenodo using .dev/upload-to-zenodo-nationwide.sh\n")
cat("  3. Update R/zenodo.R with DOIs and URLs\n\n")

cat("Options for Zenodo upload strategy:\n")
cat("  A. Upload all states + nationwide (complete, large upload)\n")
cat("  B. Upload just nationwide datasets (simpler, good for full-scale analysis)\n")
cat("  C. Upload select states + nationwide (flexible, medium size)\n\n")

cat("To prepare different subsets, re-run with:\n")
cat("  --states-only      Only generate state-by-state datasets\n")
cat("  --nationwide-only  Only generate nationwide combined datasets\n")
cat("  --quick-test       Just NC, CA, TX for testing\n\n")
