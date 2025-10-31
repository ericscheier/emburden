# Net Energy Burden (NEB) Demonstration for North Carolina
#
# This script demonstrates why proper aggregation using Net Energy Return (Nh)
# is critical for accurate energy burden analysis, and introduces the NEB metric
# which makes this relationship explicit.
#
# Key insight: NEB = 1/(1+Nh) is mathematically equivalent to Energy Burden (Eb)
# at the household level, but emphasizes that aggregation must be done via Nh.

# Load package (use devtools::load_all() for development, or library() if installed)
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  library(netenergyburden)
}

library(dplyr)
library(ggplot2)

# ==============================================================================
# Load North Carolina Data
# ==============================================================================

cat("Loading North Carolina household energy burden data...\n")
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")

# Calculate mean columns from totals
nc_clean <- nc_ami %>%
  filter(!is.na(total_income), !is.na(total_electricity_spend), households > 0) %>%
  mutate(
    # Calculate means from totals
    mean_income = total_income / households,
    mean_energy_spending = (total_electricity_spend +
                           coalesce(total_gas_spend, 0) +
                           coalesce(total_other_spend, 0)) / households
  ) %>%
  filter(!is.na(mean_income), !is.na(mean_energy_spending))

cat("Loaded", nrow(nc_clean), "household cohorts\n")
cat("Total households represented:", scales::comma(sum(nc_clean$households)), "\n\n")

# ==============================================================================
# Calculate Energy Metrics
# ==============================================================================

nc_clean <- nc_clean %>%
  mutate(
    # Traditional Energy Burden
    eb = energy_burden_func(mean_income, mean_energy_spending),

    # Net Energy Return (for proper aggregation)
    nh = ner_func(mean_income, mean_energy_spending),

    # Net Energy Burden (equivalent to eb, but conceptually clearer)
    neb = neb_func(mean_income, mean_energy_spending)
  )

# Verify NEB = Eb at household level
cat("Verification that NEB = Eb at household level:\n")
cat("  Mean Eb:  ", mean(nc_clean$eb, na.rm = TRUE), "\n")
cat("  Mean NEB: ", mean(nc_clean$neb, na.rm = TRUE), "\n")
cat("  Identical:", all.equal(nc_clean$eb, nc_clean$neb), "\n\n")

# ==============================================================================
# Compare Aggregation Methods
# ==============================================================================

cat("==================== AGGREGATION COMPARISON ====================\n\n")

# METHOD 1: INCORRECT - Direct averaging of Energy Burden
eb_simple_mean <- mean(nc_clean$eb, na.rm = TRUE)
eb_weighted_mean <- weighted.mean(nc_clean$eb, nc_clean$households, na.rm = TRUE)

cat("INCORRECT Methods (DO NOT USE):\n")
cat("  Simple mean of Eb:          ", scales::percent(eb_simple_mean, accuracy = 0.01), "\n")
cat("  Weighted mean of Eb:        ", scales::percent(eb_weighted_mean, accuracy = 0.01), "\n\n")

# METHOD 2: CORRECT - NEB via Nh aggregation
nh_weighted_mean <- weighted.mean(nc_clean$nh, nc_clean$households, na.rm = TRUE)
neb_correct <- 1 / (1 + nh_weighted_mean)

cat("CORRECT Method (USE THIS):\n")
cat("  Weighted mean of Nh:        ", round(nh_weighted_mean, 2), "\n")
cat("  NEB = 1/(1 + Nh_mean):      ", scales::percent(neb_correct, accuracy = 0.01), "\n\n")

# METHOD 3: Verification - Harmonic mean of Eb
eb_harmonic <- 1 / weighted.mean(1/nc_clean$eb, nc_clean$households, na.rm = TRUE)

cat("Verification (Harmonic Mean):\n")
cat("  Harmonic mean of Eb:        ", scales::percent(eb_harmonic, accuracy = 0.01), "\n")
cat("  Matches NEB method:         ", abs(eb_harmonic - neb_correct) < 0.0001, "\n\n")

# Calculate errors
error_simple <- (eb_simple_mean - neb_correct) / neb_correct * 100
error_weighted <- (eb_weighted_mean - neb_correct) / neb_correct * 100

cat("ERRORS from incorrect methods:\n")
cat("  Simple mean error:          ", sprintf("%+.2f%%", error_simple), "relative error\n")
cat("  Weighted mean error:        ", sprintf("%+.2f%%", error_weighted), "relative error\n\n")

# ==============================================================================
# Analysis by Income Bracket
# ==============================================================================

cat("==================== BY INCOME BRACKET ====================\n\n")

income_analysis <- nc_clean %>%
  group_by(income_bracket) %>%
  summarise(
    households = sum(households, na.rm = TRUE),

    # INCORRECT: Weighted mean of Eb
    eb_wrong = weighted.mean(eb, households, na.rm = TRUE),

    # CORRECT: NEB via Nh
    nh_mean = weighted.mean(nh, households, na.rm = TRUE),
    neb_correct = 1 / (1 + nh_mean),

    # Error
    absolute_error = eb_wrong - neb_correct,
    relative_error_pct = (eb_wrong - neb_correct) / neb_correct * 100,

    .groups = "drop"
  ) %>%
  arrange(income_bracket)

print(income_analysis %>%
  mutate(
    households = scales::comma(households),
    eb_wrong = scales::percent(eb_wrong, accuracy = 0.1),
    neb_correct = scales::percent(neb_correct, accuracy = 0.1),
    absolute_error = scales::percent(absolute_error, accuracy = 0.01),
    relative_error = sprintf("%+.2f%%", relative_error_pct)
  ) %>%
  select(income_bracket, households, eb_wrong, neb_correct, absolute_error, relative_error))

# ==============================================================================
# High Energy Burden Analysis
# ==============================================================================

cat("\n==================== ENERGY BURDEN THRESHOLD ====================\n\n")

# 6% energy burden threshold
eb_threshold <- 0.06
nh_threshold <- (1 / eb_threshold) - 1  # 15.67

cat("Standard 6% Energy Burden Threshold:\n")
cat("  Eb ≤ ", scales::percent(eb_threshold), "\n")
cat("  Nh ≥ ", round(nh_threshold, 2), "\n\n")

# Count high burden households
high_burden <- nc_clean %>%
  mutate(is_high_burden = nh < nh_threshold) %>%
  summarise(
    total_households = sum(households, na.rm = TRUE),
    high_burden_households = sum(households[is_high_burden], na.rm = TRUE),
    high_burden_pct = high_burden_households / total_households * 100
  )

cat("High Burden Households (>6% energy burden):\n")
cat("  Count:      ", scales::comma(high_burden$high_burden_households), "\n")
cat("  Percentage: ", scales::percent(high_burden$high_burden_pct / 100, accuracy = 0.1), "\n")
cat("  Of total:   ", scales::comma(high_burden$total_households), "households\n\n")

# By income bracket
high_burden_by_income <- nc_clean %>%
  mutate(is_high_burden = nh < nh_threshold) %>%
  group_by(income_bracket) %>%
  summarise(
    total = sum(households, na.rm = TRUE),
    high_burden = sum(households[is_high_burden], na.rm = TRUE),
    high_burden_pct = high_burden / total * 100,
    .groups = "drop"
  )

cat("High Burden by Income Bracket:\n")
print(high_burden_by_income %>%
  mutate(
    total = scales::comma(total),
    high_burden = scales::comma(high_burden),
    pct = scales::percent(high_burden_pct / 100, accuracy = 0.1)
  ))

# ==============================================================================
# Summary
# ==============================================================================

cat("\n==================== SUMMARY ====================\n\n")
cat("For North Carolina households:\n")
cat("  Average NEB (correct):      ", scales::percent(neb_correct, accuracy = 0.01), "\n")
cat("  Households analyzed:        ", scales::comma(sum(nc_clean$households)), "\n")
cat("  High burden (>6%):          ", scales::percent(high_burden$high_burden_pct / 100, accuracy = 0.1), "\n\n")

cat("Key takeaway:\n")
cat("  Always aggregate via Nh, then convert: NEB = 1/(1 + Nh_mean)\n")
cat("  Direct averaging of Eb can introduce ~", round(abs(error_weighted), 1), "% error\n\n")

cat("For more details, see: vignette('neb-proper-aggregation')\n")
