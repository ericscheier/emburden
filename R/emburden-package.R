#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL

# Declare global variables used in NSE (tidyverse/data.table) operations
# to avoid R CMD check NOTEs
utils::globalVariables(c(
  # PUMS/Census variables (raw_to_lead, standardize_cohort_columns)
  "ABV", "BLD", "ELEP", "ELEP*UNITS", "FIP", "FPL150", "FULP", "FULP*UNITS",
  "GASP", "GASP*UNITS", "HFL", "HINCP", "HINCP*UNITS", "TEN", "UNITS", "YBL6",

  # Computed variables (process_lead_cohort_data, lead_to_poverty)
  "detached", "electricity_spend", "gas_spend", "income", "min_units", "other_spend",

  # Aggregation variables (compare_energy_burden)
  "total_income_sum", "total_spend_sum"
))
