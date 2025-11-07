# Calculate Weighted Metrics for Energy Burden Analysis

Calculates weighted statistical metrics (mean, median, quantiles) for a
specified energy metric, with optional grouping by geographic or
demographic categories. This is the primary function for aggregating
household-level energy burden data using proper weighting by household
counts.

## Usage

``` r
calculate_weighted_metrics(
  graph_data,
  group_columns,
  metric_name,
  metric_cutoff_level,
  upper_quantile_view = 1,
  lower_quantile_view = 0
)
```

## Arguments

- graph_data:

  A data frame containing household energy burden data with columns for
  the metric of interest, household counts, and optional grouping
  variables

- group_columns:

  Character vector of column names to group by, or NULL for no grouping
  (calculates overall statistics)

- metric_name:

  Character string specifying the column name of the metric to analyze
  (e.g., "ner" for Net Energy Return)

- metric_cutoff_level:

  Numeric value defining the poverty threshold for the metric (e.g.,
  15.67 for Nh corresponding to 6% energy burden)

- upper_quantile_view:

  Numeric between 0 and 1 specifying the upper quantile to calculate
  (default: 1.0 for maximum)

- lower_quantile_view:

  Numeric between 0 and 1 specifying the lower quantile to calculate
  (default: 0.0 for minimum)

## Value

A data frame with one row per group (or one row if ungrouped)
containing:

- household_count:

  Total number of households in the group

- households_below_cutoff:

  Number of households below poverty threshold

- pct_in_group_below_cutoff:

  Proportion of group below threshold

- metric_mean:

  Weighted mean of the metric

- metric_median:

  Weighted median of the metric

- metric_upper:

  Upper quantile value

- metric_lower:

  Lower quantile value

- metric_max:

  Maximum value in group

- metric_min:

  Minimum value in group

## Details

This function requires the `spatstat` package for weighted quantile
calculations. It automatically handles missing values and ensures that
statistics are only calculated when sufficient data points exist (n \>=
3).

The function adds an "All" category row that aggregates across all
groups, in addition to the individual group statistics.

## Examples

``` r
if (FALSE) { # \dontrun{
# Calculate metrics for NC cooperatives using Nh
library(dplyr)

# Sample data
data <- data.frame(
  cooperative = rep(c("Coop A", "Coop B"), each = 3),
  ner = c(20, 15, 25, 18, 22, 12),
  households = c(1000, 500, 750, 900, 600, 400)
)

# Calculate weighted metrics by cooperative
results <- calculate_weighted_metrics(
  graph_data = data,
  group_columns = "cooperative",
  metric_name = "ner",
  metric_cutoff_level = 15.67,
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)
} # }
```
