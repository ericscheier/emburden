# North Carolina Energy Burden Comparison: 2018 vs 2022
# ===========================================================
#
# This script generates formatted results for email/presentations
# showing temporal changes in household energy burden for North Carolina
# between the 2018 and 2022 LEAD Tool data vintages.
#
# Usage: Rscript analysis/scripts/nc_comparison_for_email.R

# Load package
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  library(netenergyburden)
}

library(dplyr)

cat("\n")
cat("==================================================================\n")
cat("  North Carolina Energy Burden: 2018 vs 2022 Comparison\n")
cat("==================================================================\n\n")

# ------------------------------------------------------------------------------
# STATE-LEVEL COMPARISON
# ------------------------------------------------------------------------------

cat("Loading data and running comparison...\n\n")

comparison_state <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state",
  verbose = FALSE
)

# Calculate NEB properly via Nh for both years
comparison_state <- comparison_state %>%
  mutate(
    # Total energy spending for each year
    total_spend_2018 = total_electricity_spend_2018 +
                       coalesce(total_gas_spend_2018, 0) +
                       coalesce(total_other_spend_2018, 0),
    total_spend_2022 = total_electricity_spend_2022 +
                       coalesce(total_gas_spend_2022, 0) +
                       coalesce(total_other_spend_2022, 0),

    # Calculate Net Energy Return (Nh) for proper aggregation
    nh_2018 = (total_income_2018 - total_spend_2018) / total_spend_2018,
    nh_2022 = (total_income_2022 - total_spend_2022) / total_spend_2022,

    # Convert to Net Energy Burden (NEB)
    neb_2018 = 1 / (1 + nh_2018),
    neb_2022 = 1 / (1 + nh_2022),

    # Calculate changes
    neb_change_pp = neb_2022 - neb_2018,
    neb_change_pct = (neb_change_pp / neb_2018) * 100,
    households_change_pct = (households_2022 - households_2018) / households_2018 * 100
  )

cat("STATE-LEVEL RESULTS:\n")
cat("--------------------\n")
cat(sprintf("  2018 NEB: %.2f%%\n", comparison_state$neb_2018 * 100))
cat(sprintf("  2022 NEB: %.2f%%\n", comparison_state$neb_2022 * 100))
cat(sprintf("  Change:   %+.2f percentage points (%+.1f%% relative change)\n",
            comparison_state$neb_change_pp * 100,
            comparison_state$neb_change_pct))
cat(sprintf("\n  Households: %s → %s (%+.1f%%)\n",
            format(round(comparison_state$households_2018), big.mark = ","),
            format(round(comparison_state$households_2022), big.mark = ","),
            comparison_state$households_change_pct))

# ------------------------------------------------------------------------------
# BY INCOME BRACKET
# ------------------------------------------------------------------------------

cat("\n\nBY INCOME BRACKET:\n")
cat("------------------\n")

comparison_income <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "income_bracket",
  verbose = FALSE
)

# Calculate NEB for each income bracket
comparison_income <- comparison_income %>%
  mutate(
    # Total energy spending for each year
    total_spend_2018 = total_electricity_spend_2018 +
                       coalesce(total_gas_spend_2018, 0) +
                       coalesce(total_other_spend_2018, 0),
    total_spend_2022 = total_electricity_spend_2022 +
                       coalesce(total_gas_spend_2022, 0) +
                       coalesce(total_other_spend_2022, 0),

    # Calculate Nh and NEB
    nh_2018 = (total_income_2018 - total_spend_2018) / total_spend_2018,
    nh_2022 = (total_income_2022 - total_spend_2022) / total_spend_2022,
    neb_2018 = 1 / (1 + nh_2018),
    neb_2022 = 1 / (1 + nh_2022),

    # Changes
    neb_change_pp = neb_2022 - neb_2018,
    neb_change_pct = (neb_change_pp / neb_2018) * 100
  ) %>%
  arrange(income_bracket)

# Print formatted table
for (i in 1:nrow(comparison_income)) {
  row <- comparison_income[i, ]
  cat(sprintf("  %-12s  %.1f%% → %.1f%%  (%+.2fpp, %+.1f%%)\n",
              row$income_bracket,
              row$neb_2018 * 100,
              row$neb_2022 * 100,
              row$neb_change_pp * 100,
              row$neb_change_pct))
}

# ------------------------------------------------------------------------------
# SUMMARY FOR EMAIL
# ------------------------------------------------------------------------------

cat("\n\n==================================================================\n")
cat("  SUMMARY FOR EMAIL\n")
cat("==================================================================\n\n")

cat("Example text you can copy-paste:\n\n")
cat("---BEGIN---\n\n")

cat(sprintf("Using the netenergyburden R package, temporal analysis of North Carolina\n"))
cat(sprintf("shows household energy burden increased from %.2f%% (2018) to %.2f%% (2022),\n",
            comparison_state$neb_2018 * 100,
            comparison_state$neb_2022 * 100))
cat(sprintf("representing a %+.2f percentage point increase (%+.1f%% relative change).\n\n",
            comparison_state$neb_change_pp * 100,
            comparison_state$neb_change_pct))

# Find bracket with largest change
max_change_idx <- which.max(abs(comparison_income$neb_change_pct))
max_change_bracket <- comparison_income[max_change_idx, ]

cat(sprintf("The burden increase was not uniform across income groups. The %s bracket\n",
            max_change_bracket$income_bracket))
cat(sprintf("saw the largest relative change (%+.1f%%), while higher income households\n",
            max_change_bracket$neb_change_pct))
cat(sprintf("experienced smaller percentage increases.\n\n"))

cat(sprintf("Total NC households analyzed: %s (2018) → %s (2022)\n\n",
            format(round(sum(comparison_income$households_2018)), big.mark = ","),
            format(round(sum(comparison_income$households_2022)), big.mark = ",")))

cat("---END---\n\n")

# ------------------------------------------------------------------------------
# INSTALLATION INSTRUCTIONS
# ------------------------------------------------------------------------------

cat("==================================================================\n")
cat("  TO REPRODUCE THIS ANALYSIS\n")
cat("==================================================================\n\n")

cat("# Install the package\n")
cat("devtools::install_github(\"ericscheier/net_energy_burden\")\n\n")

cat("# Run this comparison script\n")
cat("Rscript analysis/scripts/nc_comparison_for_email.R\n\n")

cat("# Or use the comparison function directly\n")
cat("library(netenergyburden)\n")
cat("result <- compare_vintages(dataset = \"ami\", states = \"NC\", aggregate_by = \"state\")\n\n")

cat("Data downloads automatically from Zenodo on first use.\n")
cat("Uses proper Net Energy Return (Nh) aggregation methodology.\n\n")

cat("==================================================================\n\n")
