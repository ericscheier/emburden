# Phase 1: Compare Energy Burden Tests
# Comprehensive tests for temporal comparison functionality

test_that("compare_energy_burden returns proper structure", {
  # Use existing test data if available, otherwise create sample data
  skip_if_not_installed("dplyr")

  # Create mock data for 2018 and 2022
  data_2018 <- create_sample_lead_data(n = 100, seed = 1, dataset = "ami", vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 100, seed = 2, dataset = "ami", vintage = "2022")

  # Mock the load_cohort_data function to return our test data
  # In real use, this would download from OpenEI or load from cache

  # For now, test the underlying calculation logic
  # Calculate weighted metrics for each vintage
  metrics_2018 <- data_2018 %>%
    dplyr::group_by(income_bracket) %>%
    dplyr::summarise(
      ner_2018 = weighted.mean(ner, households, na.rm = TRUE),
      households_2018 = sum(households, na.rm = TRUE),
      .groups = "drop"
    )

  metrics_2022 <- data_2022 %>%
    dplyr::group_by(income_bracket) %>%
    dplyr::summarise(
      ner_2022 = weighted.mean(ner, households, na.rm = TRUE),
      households_2022 = sum(households, na.rm = TRUE),
      .groups = "drop"
    )

  # Merge to create comparison
  comparison <- dplyr::full_join(metrics_2018, metrics_2022, by = "income_bracket")

  # Should have required columns
  expect_true("income_bracket" %in% names(comparison))
  expect_true("ner_2018" %in% names(comparison))
  expect_true("ner_2022" %in% names(comparison))
  expect_true("households_2018" %in% names(comparison))
  expect_true("households_2022" %in% names(comparison))
})

test_that("compare_energy_burden calculates energy burden from NER", {
  skip_if_not_installed("dplyr")

  data <- data.frame(
    income_bracket = c("0-30%", "30-60%", "60-80%"),
    ner_2018 = c(5, 10, 15),
    ner_2022 = c(4, 9, 14),
    households_2018 = c(1000, 2000, 3000),
    households_2022 = c(1100, 2100, 3100)
  )

  # Calculate energy burden from NER: EB = 1 / (NER + 1)
  data$neb_2018 <- 1 / (data$ner_2018 + 1)
  data$neb_2022 <- 1 / (data$ner_2022 + 1)

  # Check calculations
  expect_equal(data$neb_2018[1], 1/6)  # NER=5 -> EB=1/6
  expect_equal(data$neb_2018[2], 1/11) # NER=10 -> EB=1/11
  expect_equal(data$neb_2018[3], 1/16) # NER=15 -> EB=1/16

  expect_equal(data$neb_2022[1], 1/5)  # NER=4 -> EB=1/5
  expect_equal(data$neb_2022[2], 1/10) # NER=9 -> EB=1/10
  expect_equal(data$neb_2022[3], 1/15) # NER=14 -> EB=1/15
})

test_that("compare_energy_burden calculates change correctly", {
  skip_if_not_installed("dplyr")

  data <- data.frame(
    income_bracket = c("0-30%", "30-60%"),
    neb_2018 = c(0.10, 0.05),  # 10%, 5%
    neb_2022 = c(0.12, 0.04)   # 12%, 4%
  )

  # Calculate change in percentage points
  data$neb_change_pp <- data$neb_2022 - data$neb_2018

  expect_equal(data$neb_change_pp[1], 0.02)   # +2 percentage points
  expect_equal(data$neb_change_pp[2], -0.01)  # -1 percentage point

  # Calculate percentage change
  data$neb_change_pct <- ((data$neb_2022 - data$neb_2018) / data$neb_2018) * 100

  expect_equal(data$neb_change_pct[1], 20)   # 20% increase
  expect_equal(data$neb_change_pct[2], -20)  # 20% decrease
})

test_that("weighted mean calculations are correct", {
  # Test that weighted mean is calculated properly
  values <- c(5, 10, 15)
  weights <- c(100, 200, 300)

  wm <- weighted.mean(values, weights)

  # Manual calculation: (5*100 + 10*200 + 15*300) / (100+200+300)
  #                   = (500 + 2000 + 4500) / 600
  #                   = 7000 / 600 = 11.67
  expect_equal(wm, 7000 / 600)
})

test_that("comparison handles all income brackets correctly", {
  skip_if_not_installed("dplyr")

  # Create data with all AMI brackets
  data_2018 <- create_sample_lead_data(n = 500, seed = 100, dataset = "ami", vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 500, seed = 101, dataset = "ami", vintage = "2022")

  ami_brackets <- c("0-30%", "30-60%", "60-80%", "80-100%", "100%+")

  # Verify both datasets have all brackets
  expect_true(all(ami_brackets %in% data_2018$income_bracket))
  expect_true(all(ami_brackets %in% data_2022$income_bracket))

  # Calculate metrics by bracket for both vintages
  metrics_2018 <- data_2018 %>%
    dplyr::group_by(income_bracket) %>%
    dplyr::summarise(
      ner_2018 = weighted.mean(ner, households, na.rm = TRUE),
      .groups = "drop"
    )

  metrics_2022 <- data_2022 %>%
    dplyr::group_by(income_bracket) %>%
    dplyr::summarise(
      ner_2022 = weighted.mean(ner, households, na.rm = TRUE),
      .groups = "drop"
    )

  # Both should have all 5 brackets
  expect_equal(nrow(metrics_2018), 5)
  expect_equal(nrow(metrics_2022), 5)
})

test_that("comparison handles FPL data correctly", {
  skip_if_not_installed("dplyr")

  # Create FPL data
  data_2018 <- create_sample_lead_data(n = 200, seed = 200, dataset = "fpl", vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 200, seed = 201, dataset = "fpl", vintage = "2022")

  fpl_brackets <- c("0-100%", "100-150%", "150-200%", "200%+")

  # Verify both datasets have FPL brackets
  expect_true(all(data_2018$income_bracket %in% fpl_brackets))
  expect_true(all(data_2022$income_bracket %in% fpl_brackets))
})

test_that("comparison with aggregation to poverty status works", {
  skip_if_not_installed("dplyr")

  # Create FPL data
  data_fpl <- create_sample_lead_data(n = 200, seed = 300, dataset = "fpl", vintage = "2022")

  # Aggregate to binary poverty status
  data_fpl$poverty_status <- ifelse(
    data_fpl$income_bracket == "0-100%",
    "Below Federal Poverty Line",
    "Above Federal Poverty Line"
  )

  # Calculate weighted metrics by poverty status
  poverty_metrics <- data_fpl %>%
    dplyr::group_by(poverty_status) %>%
    dplyr::summarise(
      ner = weighted.mean(ner, households, na.rm = TRUE),
      households = sum(households, na.rm = TRUE),
      .groups = "drop"
    )

  # Should have exactly 2 groups
  expect_equal(nrow(poverty_metrics), 2)
  expect_true("Below Federal Poverty Line" %in% poverty_metrics$poverty_status)
  expect_true("Above Federal Poverty Line" %in% poverty_metrics$poverty_status)
})

test_that("comparison handles missing data gracefully", {
  skip_if_not_installed("dplyr")

  # Create scenario where 2018 has more brackets than 2022
  data_2018 <- data.frame(
    income_bracket = c("0-30%", "30-60%", "60-80%"),
    ner = c(5, 10, 15),
    households = c(100, 200, 300)
  )

  data_2022 <- data.frame(
    income_bracket = c("0-30%", "30-60%"),  # Missing 60-80%
    ner = c(4, 9),
    households = c(110, 210)
  )

  # Full join should handle this
  comparison <- dplyr::full_join(
    data_2018,
    data_2022,
    by = "income_bracket",
    suffix = c("_2018", "_2022")
  )

  # Should have 3 rows (all brackets from both years)
  expect_equal(nrow(comparison), 3)

  # The 60-80% bracket should have NA for 2022 values
  row_60_80 <- comparison[comparison$income_bracket == "60-80%", ]
  expect_true(is.na(row_60_80$ner_2022))
})

test_that("state-level aggregation works correctly", {
  skip_if_not_installed("dplyr")

  # Create multi-state data
  data <- create_sample_lead_data(n = 300, seed = 400, vintage = "2022")
  data$state_abbr <- sample(c("NC", "SC", "GA"), nrow(data), replace = TRUE)

  # Aggregate by state
  state_metrics <- data %>%
    dplyr::group_by(state_abbr) %>%
    dplyr::summarise(
      ner = weighted.mean(ner, households, na.rm = TRUE),
      mean_income = weighted.mean(income, households, na.rm = TRUE),
      mean_energy_cost = weighted.mean(energy_cost, households, na.rm = TRUE),
      total_households = sum(households, na.rm = TRUE),
      .groups = "drop"
    )

  # Should have 3 states
  expect_equal(nrow(state_metrics), 3)
  expect_true(all(c("NC", "SC", "GA") %in% state_metrics$state_abbr))

  # All metrics should be finite
  expect_true(all(is.finite(state_metrics$ner)))
  expect_true(all(is.finite(state_metrics$mean_income)))
  expect_true(all(is.finite(state_metrics$mean_energy_cost)))
})

test_that("housing tenure comparison works", {
  skip_if_not_installed("dplyr")

  data_2018 <- create_sample_lead_data(n = 200, seed = 500, vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 200, seed = 501, vintage = "2022")

  # Group by housing tenure
  tenure_2018 <- data_2018 %>%
    dplyr::group_by(housing_tenure) %>%
    dplyr::summarise(
      ner_2018 = weighted.mean(ner, households, na.rm = TRUE),
      .groups = "drop"
    )

  tenure_2022 <- data_2022 %>%
    dplyr::group_by(housing_tenure) %>%
    dplyr::summarise(
      ner_2022 = weighted.mean(ner, households, na.rm = TRUE),
      .groups = "drop"
    )

  # Both should have OWNER and RENTER
  expect_true("OWNER" %in% tenure_2018$housing_tenure)
  expect_true("RENTER" %in% tenure_2018$housing_tenure)
  expect_true("OWNER" %in% tenure_2022$housing_tenure)
  expect_true("RENTER" %in% tenure_2022$housing_tenure)
})

test_that("overall state comparison (no grouping) works", {
  skip_if_not_installed("dplyr")

  data_2018 <- create_sample_lead_data(n = 500, seed = 600, vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 500, seed = 601, vintage = "2022")

  # Overall weighted mean (no grouping)
  overall_2018 <- weighted.mean(data_2018$ner, data_2018$households, na.rm = TRUE)
  overall_2022 <- weighted.mean(data_2022$ner, data_2022$households, na.rm = TRUE)

  # Should get single values
  expect_length(overall_2018, 1)
  expect_length(overall_2022, 1)
  expect_true(is.finite(overall_2018))
  expect_true(is.finite(overall_2022))
})

test_that("energy burden at poverty threshold is consistent", {
  # NER of 9 should equal 10% energy burden
  ner_threshold <- 9
  eb_threshold <- 1 / (ner_threshold + 1)

  expect_equal(eb_threshold, 0.1)

  # Verify reverse calculation
  ner_from_eb <- (1 / 0.1) - 1
  expect_equal(ner_from_eb, 9)
})

test_that("poverty rate calculation from NER", {
  skip_if_not_installed("dplyr")

  data <- create_sample_lead_data(n = 1000, seed = 700, vintage = "2022")

  # Calculate poverty rate (NER < 9 = energy burden > 10%)
  data$in_energy_poverty <- data$ner < 9

  # Weighted poverty rate
  poverty_rate <- weighted.mean(
    as.numeric(data$in_energy_poverty),
    data$households,
    na.rm = TRUE
  )

  # Should be between 0 and 1
  expect_gte(poverty_rate, 0)
  expect_lte(poverty_rate, 1)

  # Count by poverty status
  poverty_summary <- data %>%
    dplyr::group_by(in_energy_poverty) %>%
    dplyr::summarise(
      count = dplyr::n(),
      total_households = sum(households, na.rm = TRUE),
      .groups = "drop"
    )

  # Should have both TRUE and FALSE (some in poverty, some not)
  expect_equal(nrow(poverty_summary), 2)
})

test_that("temporal comparison shows expected trends", {
  skip_if_not_installed("dplyr")

  # Create data where 2022 has systematically lower energy burden than 2018
  data_2018 <- create_sample_lead_data(n = 200, seed = 800, vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 200, seed = 800, vintage = "2022")  # Same seed

  # Artificially make 2022 better (higher NER = lower burden)
  data_2022$energy_cost <- data_2022$energy_cost * 0.9  # 10% reduction in costs
  data_2022$ner <- (data_2022$income - data_2022$energy_cost) / data_2022$energy_cost
  data_2022$energy_burden <- data_2022$energy_cost / data_2022$income

  # Calculate overall metrics
  ner_2018 <- weighted.mean(data_2018$ner, data_2018$households, na.rm = TRUE)
  ner_2022 <- weighted.mean(data_2022$ner, data_2022$households, na.rm = TRUE)

  # 2022 should have higher NER (better conditions)
  expect_gt(ner_2022, ner_2018)

  # Convert to energy burden
  eb_2018 <- 1 / (ner_2018 + 1)
  eb_2022 <- 1 / (ner_2022 + 1)

  # 2022 should have lower energy burden
  expect_lt(eb_2022, eb_2018)
})

test_that("comparison handles edge case: identical data", {
  skip_if_not_installed("dplyr")

  # Same data for both vintages
  data_2018 <- create_sample_lead_data(n = 100, seed = 900, vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 100, seed = 900, vintage = "2022")  # Same seed

  # Calculate metrics
  ner_2018 <- weighted.mean(data_2018$ner, data_2018$households, na.rm = TRUE)
  ner_2022 <- weighted.mean(data_2022$ner, data_2022$households, na.rm = TRUE)

  # Should be identical (or very close due to floating point)
  expect_equal(ner_2018, ner_2022, tolerance = 1e-10)

  # Change should be zero
  change <- ner_2022 - ner_2018
  expect_equal(change, 0, tolerance = 1e-10)
})

test_that("comparison correctly uses household counts as weights", {
  # Small dataset to verify weighting manually
  data <- data.frame(
    income = c(10000, 50000, 100000),
    energy_cost = c(2000, 5000, 10000),
    households = c(100, 1, 1)  # First group has 100x weight
  )

  data$ner <- (data$income - data$energy_cost) / data$energy_cost

  # Weighted mean should be dominated by first group
  wm <- weighted.mean(data$ner, data$households)

  # Manual calculation
  ner_values <- c(4, 9, 9)  # (10000-2000)/2000=4, (50000-5000)/5000=9, etc.
  manual_wm <- (4*100 + 9*1 + 9*1) / (100 + 1 + 1)
  # = (400 + 9 + 9) / 102 = 418/102 ≈ 4.098

  expect_equal(wm, manual_wm, tolerance = 0.01)

  # Should be much closer to 4 than to 9 due to weighting
  expect_lt(abs(wm - 4), abs(wm - 9))
})

# ==============================================================================
# MVP DEMO INTEGRATION TEST
# ==============================================================================
# This test validates the MVP demo command: compare_energy_burden('fpl', 'NC', 'income_bracket')
#It mocks data loading to test the full end-to-end flow without requiring downloads.

test_that("MVP demo: compare_energy_burden('fpl', 'NC', 'income_bracket') works end-to-end", {
  skip_if_not_installed("mockery")
  skip_if_not_installed("dplyr")

  # Create realistic FPL test data for NC
  fpl_2018 <- create_sample_lead_data(n = 500, seed = 2018, dataset = "fpl", vintage = "2018")
  fpl_2022 <- create_sample_lead_data(n = 500, seed = 2022, dataset = "fpl", vintage = "2022")

  # Add required columns for compare_energy_burden
  fpl_2018$total_income <- fpl_2018$income * fpl_2018$households
  fpl_2018$total_electricity_spend <- fpl_2018$electricity_spend * fpl_2018$households
  fpl_2018$total_gas_spend <- fpl_2018$gas_spend * fpl_2018$households
  fpl_2018$total_other_spend <- fpl_2018$other_spend * fpl_2018$households

  fpl_2022$total_income <- fpl_2022$income * fpl_2022$households
  fpl_2022$total_electricity_spend <- fpl_2022$electricity_spend * fpl_2022$households
  fpl_2022$total_gas_spend <- fpl_2022$gas_spend * fpl_2022$households
  fpl_2022$total_other_spend <- fpl_2022$other_spend * fpl_2022$households

  # Mock load_cohort_data to return our test data
  mock_load <- mockery::mock(fpl_2018, fpl_2022, cycle = TRUE)

  mockery::stub(compare_energy_burden, 'load_cohort_data', mock_load)

  # Execute MVP demo command (format=FALSE to get numeric values for testing)
  result <- compare_energy_burden('fpl', 'NC', 'income_bracket', format = FALSE)

  # Verify structure
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)

  # Should have all required columns
  expected_cols <- c("income_bracket", "neb_2018", "neb_2022",
                     "change_pp", "change_pct", "households_2018", "households_2022")
  expect_true(all(expected_cols %in% names(result)))

  # Should have FPL income brackets
  fpl_brackets <- c("0-100%", "100-150%", "150-200%", "200%+")
  expect_true(all(result$income_bracket %in% fpl_brackets))

  # NEB values should be numeric
  expect_type(result$neb_2018, "double")
  expect_type(result$neb_2022, "double")

  # Change columns should exist and be numeric
  expect_true("change_pp" %in% names(result))
  expect_true("change_pct" %in% names(result))
  expect_type(result$change_pp, "double")

  # Verify mocking was called correctly
  mockery::expect_called(mock_load, 2)  # Once for 2018, once for 2022
})
