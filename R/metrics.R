#' Calculate Weighted Metrics for Energy Burden Analysis
#'
#' Calculates weighted statistical metrics (mean, median, quantiles) for a
#' specified energy metric, with optional grouping by geographic or demographic
#' categories. This is the primary function for aggregating household-level
#' energy burden data using proper weighting by household counts.
#'
#' @param graph_data A data frame containing household energy burden data with
#'   columns for the metric of interest, household counts, and optional grouping
#'   variables
#' @param group_columns Character vector of column names to group by, or NULL
#'   for no grouping (calculates overall statistics)
#' @param metric_name Character string specifying the column name of the metric
#'   to analyze (e.g., "ner" for Net Energy Return)
#' @param metric_cutoff_level Numeric value defining the poverty threshold for
#'   the metric (e.g., 15.67 for Nh corresponding to 6% energy burden)
#' @param upper_quantile_view Numeric between 0 and 1 specifying the upper
#'   quantile to calculate (default: 1.0 for maximum)
#' @param lower_quantile_view Numeric between 0 and 1 specifying the lower
#'   quantile to calculate (default: 0.0 for minimum)
#'
#' @returns A data frame with one row per group (or one row if ungrouped)
#'   containing:
#'   \item{household_count}{Total number of households in the group}
#'   \item{households_below_cutoff}{Number of households below poverty threshold}
#'   \item{pct_in_group_below_cutoff}{Proportion of group below threshold}
#'   \item{metric_mean}{Weighted mean of the metric}
#'   \item{metric_median}{Weighted median of the metric}
#'   \item{metric_upper}{Upper quantile value}
#'   \item{metric_lower}{Lower quantile value}
#'   \item{metric_max}{Maximum value in group}
#'   \item{metric_min}{Minimum value in group}
#'
#' @details
#' This function requires the `spatstat` package for weighted quantile
#' calculations. It automatically handles missing values and ensures that
#' statistics are only calculated when sufficient data points exist (n >= 3).
#'
#' The function adds an "All" category row that aggregates across all groups,
#' in addition to the individual group statistics.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Calculate metrics for NC cooperatives using Nh
#' library(dplyr)
#'
#' # Sample data
#' data <- data.frame(
#'   cooperative = rep(c("Coop A", "Coop B"), each = 3),
#'   ner = c(20, 15, 25, 18, 22, 12),
#'   households = c(1000, 500, 750, 900, 600, 400)
#' )
#'
#' # Calculate weighted metrics by cooperative
#' results <- calculate_weighted_metrics(
#'   graph_data = data,
#'   group_columns = "cooperative",
#'   metric_name = "ner",
#'   metric_cutoff_level = 15.67,
#'   upper_quantile_view = 0.95,
#'   lower_quantile_view = 0.05
#' )
#' }
calculate_weighted_metrics <- function(graph_data,
                                       group_columns,
                                       metric_name,
                                       metric_cutoff_level,
                                       upper_quantile_view = 1.0,
                                       lower_quantile_view = 0.0) {
  weighted_metrics <- grouped_weighted_metrics(
    graph_data,
    group_columns = NULL,
    metric_name,
    metric_cutoff_level,
    upper_quantile_view,
    lower_quantile_view
  )

  if (!is.null(group_columns)) {
    all_groups <- as.data.frame(matrix(rep("All", length(group_columns)), nrow = 1))
    names(all_groups) <- group_columns
    weighted_metrics <- tibble::as_tibble(cbind(all_groups, weighted_metrics))

    grouped_weighted_metrics <- grouped_weighted_metrics(
      graph_data,
      group_columns = group_columns,
      metric_name,
      metric_cutoff_level,
      upper_quantile_view,
      lower_quantile_view
    ) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(dplyr::across(dplyr::all_of(group_columns), as.factor))

    weighted_metrics <- dplyr::bind_rows(grouped_weighted_metrics, weighted_metrics) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(dplyr::across(dplyr::all_of(group_columns), as.factor))
  } else {
    weighted_metrics <- data.frame(
      group = as.factor(rep("All", nrow(weighted_metrics))),
      weighted_metrics
    )
  }

  return(weighted_metrics)
}

#' Calculate Grouped Weighted Metrics (Internal)
#'
#' Internal function to calculate weighted statistics for grouped or ungrouped
#' data. Used by [calculate_weighted_metrics()].
#'
#' @inheritParams calculate_weighted_metrics
#'
#' @returns A data frame with weighted statistics for each group
#'
#' @keywords internal
#' @noRd
grouped_weighted_metrics <- function(graph_data,
                                     group_columns,
                                     metric_name,
                                     metric_cutoff_level,
                                     upper_quantile_view = 1.0,
                                     lower_quantile_view = 0.0) {
  weighted_metrics <- graph_data %>%
    dplyr::filter(is.finite(!!rlang::sym(metric_name)), .preserve = TRUE) %>%
    {
      if (!is.null(group_columns)) {
        dplyr::group_by(., dplyr::across(dplyr::all_of(group_columns)))
      } else {
        .
      }
    } %>%
    dplyr::summarise(
      household_count = sum(households),
      total_na = sum(is.na(!!rlang::sym(metric_name)) * households, na.rm = TRUE),
      households_below_cutoff =
        sum((!!rlang::sym(metric_name) < metric_cutoff_level) * households, na.rm = TRUE),
      metric_max = max(!!rlang::sym(metric_name), na.rm = TRUE),
      metric_min = min(!!rlang::sym(metric_name), na.rm = TRUE),
      metric_mean = if (sum(!is.na(households * !!rlang::sym(metric_name))) < 3 ||
        all(households == 0)) {
        NA
      } else {
        stats::weighted.mean(x = !!rlang::sym(metric_name), w = households, na.rm = TRUE)
      },
      metric_median = if (sum(!is.na(households * !!rlang::sym(metric_name))) < 3 ||
        all(households == 0)) {
        NA
      } else {
        spatstat.geom::weighted.quantile(
          x = !!rlang::sym(metric_name), w = households,
          probs = c(.5), na.rm = TRUE
        )
      },
      metric_upper = if (sum(!is.na(households * !!rlang::sym(metric_name))) < 3 ||
        all(households == 0)) {
        NA
      } else {
        spatstat.geom::weighted.quantile(
          x = !!rlang::sym(metric_name), w = households,
          probs = c(upper_quantile_view), na.rm = TRUE
        )
      },
      metric_lower = if (sum(!is.na(households * !!rlang::sym(metric_name))) < 3 ||
        all(households == 0)) {
        NA
      } else {
        spatstat.geom::weighted.quantile(
          x = !!rlang::sym(metric_name), w = households,
          probs = c(lower_quantile_view), na.rm = TRUE
        )
      },
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      households_pct = household_count / sum(household_count),
      pct_in_group_below_cutoff = households_below_cutoff / household_count,
      pct_total_below_cutoff = households_below_cutoff / sum(households_below_cutoff)
    )

  return(weighted_metrics)
}

#' Filter and Prepare Graph Data (Internal)
#'
#' Internal function to filter and add grouping metadata to energy burden data.
#' Used for preparing data before visualization or further analysis.
#'
#' @inheritParams calculate_weighted_metrics
#'
#' @returns A data frame with additional columns for group percentiles and weights
#'
#' @keywords internal
#' @noRd
filter_graph_data <- function(clean_data, group_columns, metric_name) {
  graph_data <- clean_data %>%
    {
      if (!is.null(group_columns)) {
        dplyr::group_by(., dplyr::across(dplyr::all_of(group_columns)))
      } else {
        .
      }
    } %>%
    dplyr::mutate(group_households = sum(households, na.rm = TRUE)) %>%
    dplyr::mutate(group_household_weights = ifelse(group_households == 0, 0, households / group_households)) %>%
    dplyr::arrange(!!rlang::sym(metric_name)) %>%
    dplyr::mutate(
      group_percentile = cumsum(households * group_household_weights),
      overall_percentile = cumsum(households) / sum(households)
    ) %>%
    {
      if (!is.null(group_columns)) {
        tidyr::unite(., "group_name", dplyr::all_of(group_columns), remove = FALSE, sep = "+", na.rm = FALSE)
      } else {
        dplyr::mutate(., group_name = "all")
      }
    } %>%
    dplyr::ungroup()

  return(graph_data)
}
