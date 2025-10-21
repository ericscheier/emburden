# Format All Utilities Energy Burden Results with Color Coding by Utility Type

# Define color schemes for different utility types
utility_type_colors <- list(
  "IOU" = list(
    latex = "blue!10",
    html = "#E3F2FD"  # Light blue
  ),
  "DistCoop" = list(
    latex = "green!10",
    html = "#E8F5E9"  # Light green
  ),
  "Coop" = list(
    latex = "green!15",
    html = "#C8E6C9"  # Medium green
  ),
  "Muni" = list(
    latex = "orange!10",
    html = "#FFF3E0"  # Light orange
  ),
  "Federal" = list(
    latex = "red!10",
    html = "#FFEBEE"  # Light red
  ),
  "State" = list(
    latex = "purple!10",
    html = "#F3E5F5"  # Light purple
  ),
  "Private" = list(
    latex = "gray!10",
    html = "#F5F5F5"  # Light gray
  ),
  "PSubdiv" = list(
    latex = "yellow!10",
    html = "#FFF9C4"  # Light yellow
  )
)

# Get color for a utility type
get_utility_color <- function(utility_type, format = "latex") {
  if(utility_type == "All") return(if(format == "latex") "white" else "#FFFFFF")

  colors <- utility_type_colors[[utility_type]]
  if(is.null(colors)) return(if(format == "latex") "white" else "#FFFFFF")

  return(colors[[format]])
}

# Format full table with all utilities
format_all_utilities_table <- function(results_data, latex=TRUE) {
  formatted_table <- results_data %>%
    mutate(
      `Type` = utility_type_full,
      `Utility` = as.character(utility_name),
      `Households` = to_big(household_count),
      `Below Poverty` = to_big(households_below_poverty_line),
      `% Below 6%` = to_percent(pct_below_poverty_line, latex=latex),
      `Mean E[b]` = to_percent(energy_burden_mean, latex=latex),
      `Median E[b]` = to_percent(energy_burden_median, latex=latex),
      `5th %ile` = to_percent(energy_burden_lower_05, latex=latex),
      `95th %ile` = to_percent(energy_burden_upper_95, latex=latex),
      `Median N[h]` = round(nh_median, 1)
    ) %>%
    select(`Type`, `Utility`, `Households`, `% Below 6%`,
           `Median E[b]`, `95th %ile`, `Median N[h]`)

  return(formatted_table)
}

# Format compact table grouped by utility type
format_utilities_by_type_table <- function(results_data, latex=TRUE) {
  formatted_table <- results_data %>%
    mutate(
      `Type` = utility_type_full,
      `Utility` = as.character(utility_name),
      `Households` = to_big(household_count),
      `% Below 6%` = to_percent(pct_below_poverty_line, latex=latex),
      `Median E[b]` = to_percent(energy_burden_median, latex=latex),
      `Median N[h]` = round(nh_median, 1)
    ) %>%
    select(`Type`, `Utility`, `Households`, `% Below 6%`, `Median E[b]`, `Median N[h]`)

  return(formatted_table)
}

# Create summary table by utility type
format_utility_type_summary <- function(results_data, latex=TRUE) {
  type_summary <- results_data %>%
    filter(utility_type != "All", utility_name != "All") %>%
    group_by(utility_type, utility_type_full) %>%
    summarise(
      n_utilities = n(),
      total_households = sum(household_count),
      total_below_poverty = sum(households_below_poverty_line),
      overall_poverty_rate = total_below_poverty / total_households,
      median_energy_burden = median(energy_burden_median, na.rm=TRUE),
      mean_energy_burden = weighted.mean(energy_burden_median, household_count, na.rm=TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(median_energy_burden))

  formatted_table <- type_summary %>%
    mutate(
      `Utility Type` = utility_type_full,
      `Count` = to_big(n_utilities),
      `Total Households` = to_big(total_households),
      `% Below 6%` = to_percent(overall_poverty_rate, latex=latex),
      `Median E[b]` = to_percent(median_energy_burden, latex=latex),
      `Weighted Mean E[b]` = to_percent(mean_energy_burden, latex=latex)
    ) %>%
    select(`Utility Type`, `Count`, `Total Households`, `% Below 6%`,
           `Median E[b]`, `Weighted Mean E[b]`)

  return(list(formatted = formatted_table, raw = type_summary))
}
