# Global variable bindings to satisfy R CMD check
utils::globalVariables(c(
  "total_electricity_spend", "total_gas_spend", "total_other_spend",
  "total_income", "total_spend", "geoid", "state_abbr", "nh",
  "vintage", "neb", ".data", "change_pp", "change_pct", "households"
))

#' Compare Energy Burden Between Years
#'
#' Compare household energy burden metrics across different data vintages,
#' using proper Net Energy Return (Nh) aggregation methodology.
#'
#' @param dataset Character, either "ami" or "fpl" for cohort data type
#' @param states Character vector of state abbreviations to filter by (optional)
#' @param group_by Character, grouping variable: "income_bracket" (default),
#'   "state", or "none" for overall comparison
#' @param vintage_1 Character, first vintage year: "2018" or "2022" (default "2018")
#' @param vintage_2 Character, second vintage year: "2018" or "2022" (default "2022")
#' @param format Logical, if TRUE returns formatted percentages (default TRUE)
#'
#' @return A data.frame with energy burden comparison showing:
#'   - neb_YYYY: Net Energy Burden for each vintage (where YYYY is the year)
#'   - change_pp: Absolute change in percentage points
#'   - change_pct: Relative percent change
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Compare NC energy burden by income bracket (2018 vs 2022)
#' compare_energy_burden(dataset = "ami", states = "NC")
#'
#' # State-level comparison
#' compare_energy_burden(dataset = "ami", states = "NC", group_by = "state")
#'
#' # Overall comparison (no grouping)
#' compare_energy_burden(dataset = "fpl", states = c("NC", "SC"), group_by = "none")
#'
#' # Custom vintage comparison
#' compare_energy_burden(dataset = "ami", states = "CA",
#'                      vintage_1 = "2018", vintage_2 = "2022")
#' }
compare_energy_burden <- function(dataset = c("ami", "fpl"),
                                  states = NULL,
                                  group_by = c("income_bracket", "state", "none"),
                                  vintage_1 = "2018",
                                  vintage_2 = "2022",
                                  format = TRUE) {

  # Validate inputs
  dataset <- match.arg(dataset)
  group_by <- match.arg(group_by)

  # Load both vintages
  message("Loading ", vintage_1, " data...")
  data_1 <- load_cohort_data(
    dataset = dataset,
    states = states,
    vintage = vintage_1,
    verbose = FALSE
  )

  message("Loading ", vintage_2, " data...")
  data_2 <- load_cohort_data(
    dataset = dataset,
    states = states,
    vintage = vintage_2,
    verbose = FALSE
  )

  # Select only required columns before combining
  # This ensures both datasets have matching column sets regardless of vintage
  required_cols <- c(
    "geoid",
    "income_bracket",
    "households",
    "total_income",
    "total_electricity_spend",
    "total_gas_spend",
    "total_other_spend"
  )

  data_1 <- data_1 |>
    dplyr::select(dplyr::all_of(required_cols))

  data_2 <- data_2 |>
    dplyr::select(dplyr::all_of(required_cols))

  # Combine datasets
  combined <- rbind(
    data_1 |> dplyr::mutate(vintage = vintage_1),
    data_2 |> dplyr::mutate(vintage = vintage_2)
  )

  # Calculate total spend for each row
  combined <- combined |>
    dplyr::mutate(
      total_spend = total_electricity_spend +
        dplyr::coalesce(total_gas_spend, 0) +
        dplyr::coalesce(total_other_spend, 0)
    )

  # Determine grouping variables
  if (group_by == "income_bracket") {
    group_vars <- c("vintage", "income_bracket")
  } else if (group_by == "state") {
    # Need to join with census tract data to get state
    tracts <- load_census_tract_data(states = states, verbose = FALSE)
    combined <- combined |>
      dplyr::left_join(
        tracts |> dplyr::select(geoid, state_abbr),
        by = "geoid"
      )
    group_vars <- c("vintage", "state_abbr")
  } else {
    # group_by == "none"
    group_vars <- "vintage"
  }

  # Aggregate by grouping variables
  # For aggregated cohort data, sum totals directly rather than using Nh
  aggregated <- combined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_vars))) |>
    dplyr::summarise(
      total_income_sum = sum(total_income, na.rm = TRUE),
      total_spend_sum = sum(total_spend, na.rm = TRUE),
      households = sum(households, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      neb = total_spend_sum / total_income_sum
    ) |>
    dplyr::select(-total_income_sum, -total_spend_sum)

  # Pivot to wide format for comparison
  result <- aggregated |>
    tidyr::pivot_wider(
      names_from = vintage,
      values_from = c(neb, households),
      names_glue = "{.value}_{vintage}"
    )

  # Calculate changes
  neb_col_1 <- paste0("neb_", vintage_1)
  neb_col_2 <- paste0("neb_", vintage_2)

  result <- result |>
    dplyr::mutate(
      change_pp = .data[[neb_col_2]] - .data[[neb_col_1]],
      change_pct = (change_pp / .data[[neb_col_1]]) * 100
    )

  # Format if requested
  if (format) {
    result <- result |>
      dplyr::mutate(
        dplyr::across(
          dplyr::starts_with("neb_"),
          ~ sprintf("%.2f%%", .x * 100)
        ),
        change_pp = sprintf("%+.2f pp", change_pp * 100),
        change_pct = sprintf("%+.1f%%", change_pct)
      )
  }

  # Rename state_abbr back to state if that was the grouping
  if (group_by == "state" && "state_abbr" %in% names(result)) {
    result <- result |>
      dplyr::rename(state = state_abbr)
  }

  # Add metadata as attributes
  attr(result, "dataset") <- dataset
  attr(result, "states") <- states
  attr(result, "group_by") <- group_by
  attr(result, "vintage_1") <- vintage_1
  attr(result, "vintage_2") <- vintage_2

  message("Comparison complete: ", vintage_1, " vs ", vintage_2)
  return(result)
}


#' Print Comparison Summary
#'
#' Pretty-print a comparison table from compare_energy_burden()
#'
#' @param x Comparison result from compare_energy_burden()
#' @param ... Additional arguments (not used)
#'
#' @export
print.energy_burden_comparison <- function(x, ...) {
  dataset <- attr(x, "dataset")
  states <- attr(x, "states")
  group_by <- attr(x, "group_by")
  v1 <- attr(x, "vintage_1")
  v2 <- attr(x, "vintage_2")

  cat("\n")
  cat("Energy Burden Comparison (", v1, " vs ", v2, ")\n", sep = "")
  cat(strrep("=", 60), "\n")
  cat("Dataset:  ", toupper(dataset), "\n", sep = "")
  cat("States:   ", paste(states, collapse = ", "), "\n", sep = "")
  cat("Group by: ", group_by, "\n", sep = "")
  cat(strrep("=", 60), "\n\n")

  print(as.data.frame(x), row.names = FALSE)

  cat("\n")
  invisible(x)
}
