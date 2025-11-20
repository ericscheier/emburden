#!/usr/bin/env Rscript
# Manual fix for FPL 2022: Add missing HI and IL states
# This script processes raw HI and IL data and merges with existing 49-state dataset

library(dplyr)
library(readr)

cat("================================================================================\n")
cat("  Manual FPL 2022 Fix: Adding HI and IL States\n")
cat("================================================================================\n\n")

# 1. Load existing 49-state dataset
cat("Step 1: Loading existing 49-state FPL 2022 dataset...\n")
existing_data <- read_csv(
  "zenodo-upload-nationwide/nationwide/lead_fpl_cohorts_2022_us.csv.gz",
  show_col_types = FALSE
)
cat("  ✓ Loaded", format(nrow(existing_data), big.mark=","), "rows\n")
cat("  ✓ States:", length(unique(existing_data$state_abbr)), "\n\n")

# 2. Process HI raw data
cat("Step 2: Processing Hawaii (HI) raw data...\n")
hi_raw <- read_csv("/tmp/fpl-fix/HI FPL Census Tracts 2022.csv", show_col_types = FALSE)
cat("  ✓ Loaded", format(nrow(hi_raw), big.mark=","), "raw rows\n")

hi_processed <- hi_raw %>%
  rename(
    geoid = FIP,
    income_bracket = FPL150
  ) %>%
  mutate(geoid = as.character(geoid)) %>%
  group_by(geoid, income_bracket) %>%
  summarize(
    households = sum(UNITS, na.rm = TRUE),
    total_income = sum(`HINCP*UNITS`, na.rm = TRUE),
    total_electricity_spend = sum(`ELEP*UNITS`, na.rm = TRUE),
    total_gas_spend = sum(`GASP*UNITS`, na.rm = TRUE),
    total_other_spend = sum(`FULP*UNITS`, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  select(geoid, income_bracket, households, total_income,
         total_electricity_spend, total_gas_spend, total_other_spend)

cat("  ✓ Aggregated to", format(nrow(hi_processed), big.mark=","), "cohort rows\n\n")

# 3. Process IL raw data
cat("Step 3: Processing Illinois (IL) raw data...\n")
il_raw <- read_csv("/tmp/fpl-fix/IL FPL Census Tracts 2022.csv", show_col_types = FALSE)
cat("  ✓ Loaded", format(nrow(il_raw), big.mark=","), "raw rows\n")

il_processed <- il_raw %>%
  rename(
    geoid = FIP,
    income_bracket = FPL150
  ) %>%
  mutate(geoid = as.character(geoid)) %>%
  group_by(geoid, income_bracket) %>%
  summarize(
    households = sum(UNITS, na.rm = TRUE),
    total_income = sum(`HINCP*UNITS`, na.rm = TRUE),
    total_electricity_spend = sum(`ELEP*UNITS`, na.rm = TRUE),
    total_gas_spend = sum(`GASP*UNITS`, na.rm = TRUE),
    total_other_spend = sum(`FULP*UNITS`, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  select(geoid, income_bracket, households, total_income,
         total_electricity_spend, total_gas_spend, total_other_spend)

cat("  ✓ Aggregated to", format(nrow(il_processed), big.mark=","), "cohort rows\n\n")

# 4. Merge all datasets
cat("Step 4: Merging all datasets...\n")
complete_data <- bind_rows(existing_data, hi_processed, il_processed)
cat("  ✓ Total rows:", format(nrow(complete_data), big.mark=","), "\n")

# 5. Validate
cat("\nStep 5: Validation...\n")
# Extract state FIPS from geoid (first 2 digits)
state_fips <- unique(substr(as.character(complete_data$geoid), 1, 2))
n_states <- length(state_fips)
cat("  States found:", n_states, "\n")
cat("  State FIPS codes:", paste(sort(state_fips), collapse=", "), "\n")

if (n_states == 51) {
  cat("  ✅ All 51 states present!\n\n")

  # 6. Save
  cat("Step 6: Saving complete dataset...\n")
  csv_file <- "zenodo-upload-nationwide/nationwide/lead_fpl_cohorts_2022_us.csv"
  write_csv(complete_data, csv_file)
  cat("  ✓ Saved CSV\n")

  system(sprintf("gzip -9 -f %s", csv_file))
  cat("  ✓ Compressed\n")

  file_info <- file.info(paste0(csv_file, ".gz"))
  size_mb <- round(file_info$size / 1024 / 1024, 2)
  cat("  ✓ Final size:", size_mb, "MB\n\n")

  cat("================================================================================\n")
  cat("  ✅ FPL 2022 COMPLETE: All 51 states merged successfully!\n")
  cat("================================================================================\n")
} else {
  all_fips <- sprintf("%02d", c(1:2, 4:6, 8:13, 15:42, 44:51, 53:56))
  state_fips <- unique(substr(as.character(complete_data$geoid), 1, 2))
  missing <- setdiff(all_fips, state_fips)
  cat("  ❌ Still missing states:", paste(missing, collapse=", "), "\n")
  stop("FPL 2022 merge incomplete")
}
