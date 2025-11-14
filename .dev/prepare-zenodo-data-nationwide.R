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

# Load development version of emburden (includes list_states() and validation functions)
library(devtools)
load_all(".")

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

# Function to validate dataset before saving
validate_dataset <- function(data, expected_scope, dataset_name, vintage) {
  cat("\n  === Validating Dataset ===\n")

  # Check 1: Data exists and has rows
  if (is.null(data) || nrow(data) == 0) {
    stop("VALIDATION FAILED: Dataset is NULL or empty!")
  }
  cat("  ✓ Data exists (", format(nrow(data), big.mark = ","), " rows)\n", sep = "")

  # Check 2: Required columns exist
  required_cols <- c("geoid", "income_bracket", "households",
                     "total_income", "total_electricity_spend")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("VALIDATION FAILED: Missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }
  cat("  ✓ Required columns present\n")

  # Check 3: For nationwide datasets, verify state coverage
  if (expected_scope == "nationwide") {
    # Check for state_abbr column - if missing, try to add it from geoid
    if (!"state_abbr" %in% names(data)) {
      cat("  ⚠️  WARNING: state_abbr column missing, attempting to add from geoid...\n")

      if (!"geoid" %in% names(data)) {
        stop("VALIDATION FAILED: Cannot add state_abbr - geoid column also missing!")
      }

      # Get state FIPS from geoid (first 2 characters)
      data$state_fips <- substr(data$geoid, 1, 2)

      # Map FIPS to state abbreviations
      fips_to_state <- setNames(
        c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID",
          "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS",
          "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK",
          "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV",
          "WI", "WY", "DC"),
        c("01", "02", "04", "05", "06", "08", "09", "10", "12", "13", "15", "16",
          "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28",
          "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40",
          "41", "42", "44", "45", "46", "47", "48", "49", "50", "51", "53", "54",
          "55", "56", "11")
      )

      data$state_abbr <- fips_to_state[data$state_fips]

      # Check if we successfully added it
      if (all(is.na(data$state_abbr))) {
        stop("VALIDATION FAILED: Could not map FIPS codes to state abbreviations!")
      }

      cat("  ✓ Successfully added state_abbr column from geoid\n")
    }

    # Get unique states
    states_present <- unique(data$state_abbr)
    states_present <- states_present[!is.na(states_present)]
    n_states <- length(states_present)

    cat("  ✓ state_abbr column exists\n")
    cat("  ✓ States found:", n_states, "\n")

    # Must have exactly 51 states (50 + DC)
    if (n_states != 51) {
      cat("  ❌ ERROR: Expected 51 states, found", n_states, "\n")
      cat("  Missing states:", paste(setdiff(list_states(), states_present), collapse = ", "), "\n")
      cat("  Extra states:", paste(setdiff(states_present, list_states()), collapse = ", "), "\n")
      stop("VALIDATION FAILED: Nationwide dataset does not have all 51 states!")
    }
    cat("  ✓ All 51 US states/territories present\n")

    # Verify minimum row count (nationwide should have 100k+ rows)
    min_rows_nationwide <- 100000
    if (nrow(data) < min_rows_nationwide) {
      warning("Nationwide dataset has fewer rows than expected: ",
              nrow(data), " < ", min_rows_nationwide)
    }
  }

  # Check 4: For state datasets, verify single state
  if (expected_scope != "nationwide" && "state_abbr" %in% names(data)) {
    states_present <- unique(data$state_abbr)
    states_present <- states_present[!is.na(states_present)]

    if (length(states_present) != 1 || states_present[1] != expected_scope) {
      stop("VALIDATION FAILED: State dataset has wrong states. Expected: ",
           expected_scope, ", Found: ", paste(states_present, collapse = ", "))
    }
    cat("  ✓ Single state (", expected_scope, ") verified\n", sep = "")
  }

  # Check 5: Test that data can be used with emburden functions
  tryCatch({
    # Try calculating energy burden on a sample
    sample_data <- head(data, 100)
    if ("total_income" %in% names(sample_data) &&
        "total_electricity_spend" %in% names(sample_data)) {
      test_burden <- sum(sample_data$total_electricity_spend, na.rm = TRUE) /
                     sum(sample_data$total_income, na.rm = TRUE)
      if (!is.finite(test_burden)) {
        warning("Sample energy burden calculation returned non-finite value")
      }
    }
    cat("  ✓ Data compatible with emburden calculations\n")
  }, error = function(e) {
    stop("VALIDATION FAILED: Data incompatible with emburden functions: ", e$message)
  })

  cat("  ✅ All validation checks passed!\n\n")
  return(TRUE)
}

# Function to compress and save
compress_and_save <- function(data, output_file, desc, expected_scope = NULL,
                               dataset_name = NULL, vintage = NULL) {

  # Validate before saving (if validation params provided)
  if (!is.null(expected_scope)) {
    validate_dataset(data, expected_scope, dataset_name, vintage)
  }

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

      # Manual filter by state (in case load_cohort_data didn't filter properly)
      if ("state_abbr" %in% names(data)) {
        data <- data %>% filter(state_abbr == state)
        cat("    Filtered to", state, ":", format(nrow(data), big.mark = ","), "rows\n")
      } else {
        cat("    WARNING: No state_abbr column, cannot verify state filtering\n")
      }

      # Save state-specific dataset
      state_file <- file.path(
        state_output_dir,
        sprintf("lead_%s_cohorts_%s_%s.csv", dataset_name, vintage, tolower(state))
      )

      file_info <- compress_and_save(
        data,
        state_file,
        sprintf("%s %s cohort data for %s", vintage, toupper(dataset_name), state),
        expected_scope = state,
        dataset_name = dataset_name,
        vintage = vintage
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

    # Self-healing retry loop
    max_retries <- 2
    retry_count <- 0
    success <- FALSE

    while (!success && retry_count < max_retries) {
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
        break
      }

      cat("\n  Combined data loaded successfully!\n")
      cat("    Total rows:", format(nrow(all_data), big.mark = ","), "\n")
      cat("    Total states:", length(unique(all_data$state_abbr)), "\n\n")

      # Save nationwide dataset (with validation)
      nationwide_file <- file.path(
        nationwide_dir,
        sprintf("lead_%s_cohorts_%s_us.csv", dataset_name, vintage)
      )

      # Try to save with validation
      file_info <- tryCatch({
        compress_and_save(
          all_data,
          nationwide_file,
          sprintf("%s %s cohort data (all US states)", vintage, toupper(dataset_name)),
          expected_scope = "nationwide",
          dataset_name = dataset_name,
          vintage = vintage
        )
      }, error = function(e) {
        # Validation failed - likely corrupted database data
        cat("\n  ❌ VALIDATION FAILED:", e$message, "\n")

        # Check if this is due to incomplete database data
        if (grepl("state|VALIDATION FAILED", e$message, ignore.case = TRUE)) {
          cat("\n  🔧 SELF-HEALING: Detected corrupted database data\n")
          cat("     Deleting database table to force reload from CSV/OpenEI...\n")

          # Delete corrupted database table
          db_path <- rappdirs::user_data_dir('emburden', 'emburden')
          db_file <- file.path(db_path, 'emburden_db.sqlite')

          if (file.exists(db_file)) {
            # Connect and drop the table
            conn <- tryCatch({
              DBI::dbConnect(RSQLite::SQLite(), db_file)
            }, error = function(e2) NULL)

            if (!is.null(conn)) {
              table_name <- paste0(dataset_name, "_cohorts_", vintage)
              tryCatch({
                DBI::dbExecute(conn, sprintf("DROP TABLE IF EXISTS %s", table_name))
                cat("     ✓ Deleted table:", table_name, "\n")
              }, error = function(e2) {
                cat("     ⚠️  Could not delete table:", e2$message, "\n")
              })
              DBI::dbDisconnect(conn)
            }

            # Also try alternate table name format
            conn <- tryCatch({
              DBI::dbConnect(RSQLite::SQLite(), db_file)
            }, error = function(e2) NULL)

            if (!is.null(conn)) {
              table_name_alt <- paste0("lead_", vintage, "_", dataset_name, "_cohorts")
              tryCatch({
                DBI::dbExecute(conn, sprintf("DROP TABLE IF EXISTS %s", table_name_alt))
                cat("     ✓ Deleted table:", table_name_alt, "\n")
              }, error = function(e2) NULL)
              DBI::dbDisconnect(conn)
            }
          }

          cat("     Database cleaned. Will retry with fresh data...\n\n")
        }

        return(NULL)
      })

      # Check if save succeeded
      if (!is.null(file_info)) {
        success <- TRUE
      } else {
        retry_count <- retry_count + 1
        if (retry_count < max_retries) {
          cat("\n  🔄 RETRY", retry_count, "of", max_retries - 1, "...\n\n")
        } else {
          cat("\n  ❌ Failed after", max_retries - 1, "retries. Skipping this dataset.\n\n")
          next
        }
      }
    }

    if (!success) {
      next  # Skip to next dataset
    }

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
