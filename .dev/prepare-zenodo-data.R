#!/usr/bin/env Rscript
# Prepare Analysis-Ready Datasets for Zenodo Upload
#
# This script generates PROCESSED, analysis-ready datasets for Zenodo hosting.
# These are NOT raw OpenEI data - they are pre-processed, aggregated, and
# include computed energy burden metrics.
#
# Output: 4 nationwide processed CSV files ready for Zenodo upload
#   - lead_ami_cohorts_2022_us.csv (processed, analysis-ready)
#   - lead_fpl_cohorts_2022_us.csv (processed, analysis-ready)
#   - lead_ami_cohorts_2018_us.csv (processed, analysis-ready)
#   - lead_fpl_cohorts_2018_us.csv (processed, analysis-ready)

library(emburden)
library(dplyr)
library(readr)

cat("\n")
cat("================================================================================\n")
cat("  Preparing Analysis-Ready Datasets for Zenodo Upload\n")
cat("================================================================================\n")
cat("\n")
cat("This script downloads RAW data from OpenEI, processes it into analysis-ready\n")
cat("format, and saves it for Zenodo upload. This ensures users download PROCESSED\n")
cat("data that's ready for immediate analysis.\n")
cat("\n")

# Output directory
output_dir <- "zenodo-upload"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("Output directory:", normalizePath(output_dir), "\n\n")

# Function to process and save a dataset
process_and_save <- function(dataset, vintage) {

  cat("================================================================================\n")
  cat("Processing:", toupper(dataset), vintage, "\n")
  cat("================================================================================\n\n")

  # Output filename
  output_file <- file.path(output_dir, paste0("lead_", dataset, "_cohorts_", vintage, "_us.csv"))

  # Check if already exists
  if (file.exists(output_file)) {
    cat("✓ File already exists:", basename(output_file), "\n")
    cat("  Size:", format(file.size(output_file) / 1024^2, digits = 2), "MB\n\n")
    return(invisible(TRUE))
  }

  # Load data (will download from OpenEI if not cached, then process)
  cat("Loading", dataset, vintage, "data from OpenEI...\n")
  cat("(This will download raw data if not cached, then process it)\n\n")

  data <- tryCatch({
    load_cohort_data(
      dataset = dataset,
      vintage = vintage,
      verbose = TRUE
    )
  }, error = function(e) {
    cat("\n❌ Error loading data:", e$message, "\n\n")
    return(NULL)
  })

  if (is.null(data)) {
    cat("\n❌ Failed to load data\n\n")
    return(invisible(FALSE))
  }

  cat("\n")
  cat("Data loaded successfully!\n")
  cat("  Rows:", format(nrow(data), big.mark = ","), "\n")
  cat("  Cols:", ncol(data), "\n")
  cat("  States:", length(unique(substr(data$geoid, 1, 2))), "\n")

  # Verify this is processed data (has computed metrics)
  required_cols <- c("geoid", "income_bracket", "households", "total_income",
                     "total_electricity_spend", "total_gas_spend")

  if (!all(required_cols %in% names(data))) {
    cat("\n❌ ERROR: Data missing required processed columns!\n")
    cat("  This appears to be raw data, not processed data.\n")
    cat("  Missing:", setdiff(required_cols, names(data)), "\n\n")
    return(invisible(FALSE))
  }

  cat("\n✓ Verified: Data contains processed metrics (energy burden, etc.)\n")

  # Save processed data
  cat("\nSaving processed data to:", basename(output_file), "\n")
  write_csv(data, output_file)

  # Report size
  size_mb <- file.size(output_file) / 1024^2
  cat("✓ Saved successfully!\n")
  cat("  Size:", format(size_mb, digits = 2), "MB uncompressed\n")
  cat("  Estimated compressed size:", format(size_mb * 0.2, digits = 2), "MB (gzip)\n\n")

  return(invisible(TRUE))
}

# Process all 4 datasets
cat("Starting data preparation...\n\n")

success_count <- 0

# 2022 data (latest)
if (process_and_save("ami", "2022")) success_count <- success_count + 1
if (process_and_save("fpl", "2022")) success_count <- success_count + 1

# 2018 data (historical comparison)
if (process_and_save("ami", "2018")) success_count <- success_count + 1
if (process_and_save("fpl", "2018")) success_count <- success_count + 1

# Summary
cat("================================================================================\n")
cat("  Data Preparation Complete\n")
cat("================================================================================\n\n")

cat("Successfully prepared", success_count, "of 4 datasets\n\n")

if (success_count == 4) {
  cat("✓ All datasets ready for Zenodo upload!\n\n")

  cat("Next steps:\n")
  cat("  1. Compress files:\n")
  cat("     cd", output_dir, "\n")
  cat("     gzip -9 -k *.csv\n\n")

  cat("  2. Calculate checksums:\n")
  cat("     md5sum *.csv.gz > checksums.txt\n\n")

  cat("  3. Upload to Zenodo following .dev/ZENODO_UPLOAD_GUIDE.md\n\n")

  cat("  4. Update R/zenodo.R with DOIs and URLs\n\n")

} else {
  cat("\n⚠ Some datasets failed to process. Check errors above.\n\n")
}

cat("Output directory:", normalizePath(output_dir), "\n")
cat("\n")
