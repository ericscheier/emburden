test_that("calculate_weighted_metrics calculates basic statistics", {
  # Mock data
  data <- data.frame(
    ner = c(10, 15, 20, 25, 30),
    households = c(100, 150, 200, 250, 300)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 0.95,
    lower_quantile_view = 0.05
  )

  # Check required columns exist
  expect_true("household_count" %in% names(result))
  expect_true("households_below_cutoff" %in% names(result))
  expect_true("metric_mean" %in% names(result))
  expect_true("metric_median" %in% names(result))
  expect_true("metric_max" %in% names(result))
  expect_true("metric_min" %in% names(result))

  # Check values
  expect_equal(result$household_count, 1000)
  expect_equal(result$households_below_cutoff, 100)  # Only ner=10 (cutoff is <, not <=)
  expect_equal(result$metric_max, 30)
  expect_equal(result$metric_min, 10)
})

test_that("calculate_weighted_metrics groups by specified columns", {
  # Mock data with groups
  data <- data.frame(
    cooperative = rep(c("Coop A", "Coop B"), each = 3),
    ner = c(10, 15, 20, 12, 18, 25),
    households = c(100, 150, 200, 120, 180, 240)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = "cooperative",
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Should have 3 rows: "All" plus 2 cooperatives
  expect_equal(nrow(result), 3)

  # Check grouping column exists
  expect_true("cooperative" %in% names(result))

  # Check "All" row exists
  expect_true("All" %in% result$cooperative)

  # Check grouped rows exist
  expect_true("Coop A" %in% result$cooperative)
  expect_true("Coop B" %in% result$cooperative)

  # Verify household counts
  coop_a_row <- result[result$cooperative == "Coop A", ]
  coop_b_row <- result[result$cooperative == "Coop B", ]

  expect_equal(coop_a_row$household_count, 450)  # 100 + 150 + 200
  expect_equal(coop_b_row$household_count, 540)  # 120 + 180 + 240
})

test_that("calculate_weighted_metrics handles cutoff threshold correctly", {
  data <- data.frame(
    ner = c(5, 10, 15, 20, 25),  # 2 below 15, 1 at 15, 2 above
    households = c(100, 100, 100, 100, 100)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Cutoff is < not <=, so only values < 15 count
  expect_equal(result$households_below_cutoff, 200)  # 5 and 10 only

  # Check percentage
  expect_equal(result$pct_in_group_below_cutoff, 0.4)  # 200/500
})

test_that("calculate_weighted_metrics calculates weighted mean correctly", {
  # Data where weighted mean differs from unweighted
  # Need at least 3 data points for function to calculate mean
  data <- data.frame(
    ner = c(10, 20, 30),
    households = c(900, 50, 50)  # Heavily weighted toward 10
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 0,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Weighted mean should be close to 10
  expected_mean <- (10 * 900 + 20 * 50 + 30 * 50) / 1000  # = 11.5
  expect_equal(result$metric_mean, expected_mean)

  # Unweighted mean would be 20, so this confirms weighting works
  expect_true(result$metric_mean < 15)
})

test_that("calculate_weighted_metrics handles NA values", {
  data <- data.frame(
    ner = c(10, NA, 20, 30),
    households = c(100, 150, 200, 250)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Should calculate statistics excluding NA
  expect_false(is.na(result$metric_mean))
  expect_false(is.na(result$metric_median))

  # Function filters to finite values, so household count excludes NA rows
  expect_equal(result$household_count, 550)  # 100 + 200 + 250

  # total_na should be 0 since NA rows are filtered before summarise
  expect_equal(result$total_na, 0)
})

test_that("calculate_weighted_metrics requires minimum data points", {
  # Less than 3 non-NA data points
  data <- data.frame(
    ner = c(10, NA),
    households = c(100, 150)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # With < 3 data points, mean/median should be NA
  expect_true(is.na(result$metric_mean))
  expect_true(is.na(result$metric_median))

  # Household count only includes finite values (NA filtered out)
  expect_equal(result$household_count, 100)
})

test_that("calculate_weighted_metrics with multiple grouping columns", {
  data <- data.frame(
    state = rep(c("NC", "SC"), each = 4),
    fuel_type = rep(c("Gas", "Electric"), 4),
    ner = c(10, 15, 12, 18, 20, 25, 22, 28),
    households = rep(100, 8)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = c("state", "fuel_type"),
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Should have: 1 "All" + 4 combinations (NC/Gas, NC/Electric, SC/Gas, SC/Electric)
  expect_equal(nrow(result), 5)

  # Check all expected combinations exist
  expect_true(all(c("state", "fuel_type") %in% names(result)))

  # Check "All" row
  all_row <- result[result$state == "All" & result$fuel_type == "All", ]
  expect_equal(nrow(all_row), 1)
  expect_equal(all_row$household_count, 800)
})

test_that("calculate_weighted_metrics calculates quantiles correctly", {
  # Data with known quantiles
  data <- data.frame(
    ner = 1:100,
    households = rep(10, 100)  # Equal weights
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 0,
    upper_quantile_view = 0.95,
    lower_quantile_view = 0.05
  )

  # Check quantiles are reasonable
  expect_true(result$metric_upper > result$metric_median)
  expect_true(result$metric_lower < result$metric_median)
  expect_true(result$metric_upper <= 100)
  expect_true(result$metric_lower >= 1)

  # 95th percentile should be around 95
  expect_true(result$metric_upper > 90)

  # 5th percentile should be around 5
  expect_true(result$metric_lower < 10)
})

test_that("calculate_weighted_metrics handles infinite values", {
  data <- data.frame(
    ner = c(10, 15, Inf, -Inf, 20),
    households = c(100, 150, 200, 250, 300)
  )

  # Should filter out infinite values
  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Statistics should be calculated only on finite values
  expect_false(is.infinite(result$metric_mean))
  expect_false(is.infinite(result$metric_median))
  expect_false(is.infinite(result$metric_max))
  expect_false(is.infinite(result$metric_min))
})

test_that("calculate_weighted_metrics percentage calculations are correct", {
  data <- data.frame(
    group = c("A", "A", "B", "B"),
    ner = c(10, 20, 5, 15),
    households = c(100, 100, 100, 100)
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = "group",
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # Find group A row
  group_a <- result[result$group == "A", ]

  # Group A: 1 out of 2 records below cutoff (ner=10)
  expect_equal(group_a$households_below_cutoff, 100)
  expect_equal(group_a$pct_in_group_below_cutoff, 0.5)

  # Check households_pct (proportion of total)
  expect_equal(group_a$households_pct, 0.5)  # 200/400
})

test_that("calculate_weighted_metrics with zero households handled", {
  data <- data.frame(
    ner = c(10, 15, 20),
    households = c(0, 0, 0)  # All zero
  )

  result <- calculate_weighted_metrics(
    graph_data = data,
    group_columns = NULL,
    metric_name = "ner",
    metric_cutoff_level = 15,
    upper_quantile_view = 1.0,
    lower_quantile_view = 0.0
  )

  # With all zero households, statistics should be NA
  expect_true(is.na(result$metric_mean))
  expect_true(is.na(result$metric_median))

  # But household count can still be 0
  expect_equal(result$household_count, 0)
})
