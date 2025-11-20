#!/usr/bin/env Rscript
# Diagnostic script to understand data loading behavior
# Part of the emburden development toolkit

cat("\n==========================================\n")
cat("  Data Loading Diagnostic\n")
cat("==========================================\n\n")

library(emburden)

# Step 1: Check MD5 checksums in installed package
cat("Step 1: Checking MD5 checksums in installed package...\n")
config <- emburden:::get_zenodo_config()

cat("\nConfigured MD5 checksums:\n")
cat("  FPL 2022: ", config$files$fpl_2022$md5, "\n")
cat("  FPL 2018: ", config$files$fpl_2018$md5, "\n")
cat("  AMI 2022: ", config$files$ami_2022$md5, "\n")
cat("  AMI 2018: ", config$files$ami_2018$md5, "\n")

# Expected correct values from actual Zenodo files
expected <- list(
  fpl_2022 = "767f2ff27193116f61e893999eb8bcf1",
  fpl_2018 = "3da8be8c8628656b7772df4c4e7c4e04",
  ami_2022 = "d3b30d9d0009032ebb1b9228e44d0e2d",
  ami_2018 = "5aefd8e2ef0a63089b68977579d9df86"
)

cat("\nExpected MD5 checksums:\n")
cat("  FPL 2022: ", expected$fpl_2022, "\n")
cat("  FPL 2018: ", expected$fpl_2018, "\n")
cat("  AMI 2022: ", expected$ami_2022, "\n")
cat("  AMI 2018: ", expected$ami_2018, "\n")

cat("\nMD5 Verification:\n")
all_match <- TRUE
for (dataset in c("fpl_2022", "fpl_2018", "ami_2022", "ami_2018")) {
  actual <- config$files[[dataset]]$md5
  exp <- expected[[dataset]]
  match <- identical(actual, exp)
  if (!match) all_match <- FALSE
  status <- if (match) "✓ MATCH" else "✗ MISMATCH"
  cat(sprintf("  %s: %s (actual: %s, expected: %s)\n", dataset, status, actual, exp))
}

if (!all_match) {
  cat("\n❌ MD5 MISMATCH DETECTED!\n")
  cat("   This means R/zenodo.R has incorrect checksums.\n")
  cat("   Run: Rscript .dev/update-zenodo-config.R\n\n")
  quit(status = 1)
}

# Step 2: Clear all caches to force fresh downloads
cat("\n\nStep 2: Clearing all caches...\n")
emburden::clear_dataset_cache("fpl", "2022", verbose = TRUE)
emburden::clear_dataset_cache("fpl", "2018", verbose = TRUE)

# Step 3: Load FPL 2022 with verbose output
cat("\n\nStep 3: Loading FPL 2022 with verbose output...\n")
cat("==========================================\n")
fpl_2022 <- load_cohort_data("fpl", "2022", verbose = TRUE)

cat("\n\nFPL 2022 Data Summary:\n")
cat("  Rows: ", format(nrow(fpl_2022), big.mark = ","), "\n")
cat("  States: ", length(unique(substr(as.character(fpl_2022$geoid), 1, 2))), "\n")
cat("  Households (total): ", format(sum(fpl_2022$households), big.mark = ","), "\n")
cat("  Households (Above FPL): ", format(sum(fpl_2022$households[fpl_2022$income_bracket == "Above Federal Poverty Line"]), big.mark = ","), "\n")
cat("  Households (Below FPL): ", format(sum(fpl_2022$households[fpl_2022$income_bracket == "Below Federal Poverty Line"]), big.mark = ","), "\n")

# Step 4: Load FPL 2018 with verbose output
cat("\n\nStep 4: Loading FPL 2018 with verbose output...\n")
cat("==========================================\n")
fpl_2018 <- load_cohort_data("fpl", "2018", verbose = TRUE)

cat("\n\nFPL 2018 Data Summary:\n")
cat("  Rows: ", format(nrow(fpl_2018), big.mark = ","), "\n")
cat("  States: ", length(unique(substr(as.character(fpl_2018$geoid), 1, 2))), "\n")
cat("  Households (total): ", format(sum(fpl_2018$households), big.mark = ","), "\n")
cat("  Households (Above FPL): ", format(sum(fpl_2018$households[fpl_2018$income_bracket == "Above Federal Poverty Line"]), big.mark = ","), "\n")
cat("  Households (Below FPL): ", format(sum(fpl_2018$households[fpl_2018$income_bracket == "Below Federal Poverty Line"]), big.mark = ","), "\n")

# Step 5: Compare the datasets
cat("\n\nStep 5: Comparing datasets...\n")
cat("==========================================\n")

cat("\nRow counts:\n")
cat("  FPL 2022: ", format(nrow(fpl_2022), big.mark = ","), "\n")
cat("  FPL 2018: ", format(nrow(fpl_2018), big.mark = ","), "\n")
cat("  Identical? ", identical(nrow(fpl_2022), nrow(fpl_2018)), "\n")

cat("\nTotal households:\n")
cat("  FPL 2022: ", format(sum(fpl_2022$households), big.mark = ","), "\n")
cat("  FPL 2018: ", format(sum(fpl_2018$households), big.mark = ","), "\n")
cat("  Identical? ", identical(sum(fpl_2022$households), sum(fpl_2018$households)), "\n")

cat("\nSample of first 10 rows (FPL 2022):\n")
print(head(fpl_2022[, c("geoid", "income_bracket", "households", "mean_energy_cost", "mean_energy_burden")], 10))

cat("\nSample of first 10 rows (FPL 2018):\n")
print(head(fpl_2018[, c("geoid", "income_bracket", "households", "mean_energy_cost", "mean_energy_burden")], 10))

# Step 6: Check if data is bitwise identical
cat("\n\nStep 6: Checking if datasets are bitwise identical...\n")
if (identical(dim(fpl_2022), dim(fpl_2018))) {
  # Check a few key columns
  cols_to_check <- c("geoid", "income_bracket", "households", "mean_energy_burden")
  all_identical <- TRUE
  for (col in cols_to_check) {
    if (col %in% names(fpl_2022) && col %in% names(fpl_2018)) {
      is_identical <- identical(fpl_2022[[col]], fpl_2018[[col]])
      if (is_identical) all_identical <- FALSE  # We WANT them to be different
      cat(sprintf("  %s: %s\n", col, if (is_identical) "IDENTICAL ✗" else "DIFFERENT ✓"))
    }
  }

  if (all_identical) {
    cat("\n❌ DATA IS IDENTICAL - THIS IS A BUG!\n")
  }
} else {
  cat("  Dimensions differ - datasets are different ✓\n")
}

# Step 7: Run the comparison function
cat("\n\nStep 7: Running compare_energy_burden()...\n")
cat("==========================================\n")
comparison <- compare_energy_burden(dataset = "fpl", group_by = "income_bracket")
print(comparison)

cat("\n\n==========================================\n")
cat("  Diagnostic Complete\n")
cat("==========================================\n\n")

# Check data source
cat("Where did the data come from?\n")
cat("Check the verbose output above for:\n")
cat("  - 'Downloading from Zenodo' = Data from Zenodo\n")
cat("  - 'Zenodo download failed' + 'Falling back to OpenEI' = Data from OpenEI\n")
cat("  - 'Found in cache' = Data from cache\n")
cat("\nIf both vintages came from OpenEI, that's likely the problem.\n")
cat("If MD5 checksums don't match expected, that's the problem.\n")
cat("If datasets are identical, check the Zenodo files themselves.\n\n")
