# Format NC Cooperatives Energy Burden Results for LaTeX/kable output
# Uses existing helper functions for consistent formatting

format_nc_cooperatives_table <- function(results_data, latex=TRUE) {
  # Format the table with proper column names and formatted values
  formatted_table <- results_data %>%
    mutate(
      # Format the columns using existing helper functions
      `Cooperative` = as.character(cooperative),
      `Households` = to_big(household_count),
      `Below Poverty Line` = to_big(households_below_poverty_line),
      `% Below Poverty` = to_percent(pct_below_poverty_line, latex=latex),
      `Mean E[b]` = to_percent(energy_burden_mean, latex=latex),
      `Median E[b]` = to_percent(energy_burden_median, latex=latex),
      `5th %ile E[b]` = to_percent(energy_burden_lower_05, latex=latex),
      `95th %ile E[b]` = to_percent(energy_burden_upper_95, latex=latex),
      `Mean N[h]` = round(nh_mean, 1),
      `Median N[h]` = round(nh_median, 1)
    ) %>%
    select(`Cooperative`, `Households`, `Below Poverty Line`, `% Below Poverty`,
           `Mean E[b]`, `Median E[b]`, `5th %ile E[b]`, `95th %ile E[b]`,
           `Mean N[h]`, `Median N[h]`)

  return(formatted_table)
}

# Create a compact version with fewer columns for readability
format_nc_cooperatives_table_compact <- function(results_data, latex=TRUE) {
  formatted_table <- results_data %>%
    mutate(
      `Cooperative` = as.character(cooperative),
      `Households` = to_big(household_count),
      `% Below 6%` = to_percent(pct_below_poverty_line, latex=latex),
      `Median E[b]` = to_percent(energy_burden_median, latex=latex),
      `95th %ile E[b]` = to_percent(energy_burden_upper_95, latex=latex),
      `Median N[h]` = round(nh_median, 1)
    ) %>%
    select(`Cooperative`, `Households`, `% Below 6%`,
           `Median E[b]`, `95th %ile E[b]`, `Median N[h]`)

  return(formatted_table)
}
