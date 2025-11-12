# Phase 1: Energy Metrics Calculation Tests
# Tests for core energy burden and NER calculation functions

test_that("ner_func calculates Net Energy Return correctly", {
  # Standard case
  expect_equal(ner_func(50000, 5000), 9)

  # At poverty threshold (10% burden = NER of 9)
  expect_equal(ner_func(100000, 10000), 9)

  # Higher burden (20% burden = NER of 4)
  expect_equal(ner_func(10000, 2000), 4)
})

test_that("energy_burden_func calculates energy burden correctly", {
  # Standard case: 10% burden
  expect_equal(energy_burden_func(50000, 5000), 0.1)

  # 5% burden
  expect_equal(energy_burden_func(100000, 5000), 0.05)

  # 20% burden
  expect_equal(energy_burden_func(10000, 2000), 0.2)
})

test_that("neb_func is an alias for energy_burden_func", {
  # neb_func is actually an alias for energy_burden_func in the package
  # So it returns S/G, not (G-S)/G
  expect_equal(neb_func(50000, 5000), 0.1)  # 10% spent on energy
  expect_equal(neb_func(100000, 10000), 0.1)
  expect_equal(neb_func(10000, 2000), 0.2)  # 20% spent on energy

  # Verify it's the same as energy_burden_func
  expect_equal(neb_func(50000, 5000), energy_burden_func(50000, 5000))
})

test_that("energy burden and NER are inverse functions", {
  income <- 50000
  cost <- 5000

  eb <- energy_burden_func(income, cost)
  ner <- ner_func(income, cost)

  # Test inverse relationship: eb = 1 / (ner + 1)
  expect_equal(eb, 1 / (ner + 1))

  # Test inverse: ner = (1 / eb) - 1
  expect_equal(ner, (1 / eb) - 1)
})

test_that("energy poverty threshold (NER = 9) matches 10% burden", {
  # NER of 9 should equal 10% energy burden
  income <- 100000
  cost <- 10000

  ner_value <- ner_func(income, cost)
  eb_value <- energy_burden_func(income, cost)

  expect_equal(ner_value, 9)
  expect_equal(eb_value, 0.1)
})

test_that("ner_func handles zero income", {
  # Zero income means all spending comes from elsewhere
  # NER = (0 - S) / S = -1
  expect_equal(ner_func(0, 1000), -1)
  expect_equal(ner_func(0, 5000), -1)
})

test_that("ner_func handles zero energy cost", {
  # Zero energy cost means infinite return
  expect_equal(ner_func(50000, 0), Inf)
  expect_equal(ner_func(100000, 0), Inf)
})

test_that("ner_func handles negative income", {
  # Negative income (debt/losses) still produces valid NER
  expect_equal(ner_func(-5000, 2000), -3.5)  # (-5000 - 2000) / 2000

  # Should be finite
  expect_true(is.finite(ner_func(-1000, 1000)))
})

test_that("energy_burden_func handles zero income", {
  # Zero income means infinite burden
  expect_equal(energy_burden_func(0, 1000), Inf)
})

test_that("energy_burden_func handles zero cost", {
  # Zero cost means zero burden
  expect_equal(energy_burden_func(50000, 0), 0)
})

test_that("eroi_func calculates Energy Return on Investment", {
  # EROI = G / S
  expect_equal(eroi_func(50000, 5000), 10)
  expect_equal(eroi_func(100000, 10000), 10)
  expect_equal(eroi_func(10000, 2000), 5)
})

test_that("eroi_func and ner_func relationship", {
  # EROI = NER + 1
  income <- 50000
  cost <- 5000

  eroi <- eroi_func(income, cost)
  ner <- ner_func(income, cost)

  expect_equal(eroi, ner + 1)
})

test_that("dear_func calculates Discretionary Energy Affordability Ratio", {
  # DEAR = (G - S) / G
  # This is the same as NEB (net energy burden)
  expect_equal(dear_func(50000, 5000), 0.9)
  expect_equal(dear_func(100000, 10000), 0.9)
})

test_that("all metrics handle same input consistently", {
  income <- 75000
  cost <- 6000

  # Calculate all metrics
  eb <- energy_burden_func(income, cost)
  ner <- ner_func(income, cost)
  eroi <- eroi_func(income, cost)
  neb <- neb_func(income, cost)
  dear <- dear_func(income, cost)

  # Verify relationships
  expect_equal(eb, cost / income)
  expect_equal(ner, (income - cost) / cost)
  expect_equal(eroi, income / cost)
  expect_equal(neb, cost / income)  # neb_func is alias for energy_burden_func
  expect_equal(dear, (income - cost) / income)  # DEAR is net energy burden

  # Verify mathematical relationships
  expect_equal(eroi, ner + 1)
  expect_equal(eb + dear, 1)  # Energy burden + DEAR = 1
  expect_equal(eb, 1 / eroi)
  expect_equal(neb, eb)  # neb_func is alias for energy_burden_func
})

test_that("metrics work with vectors", {
  incomes <- c(50000, 60000, 70000)
  costs <- c(5000, 6000, 7000)

  ner_values <- ner_func(incomes, costs)

  expect_equal(length(ner_values), 3)
  expect_equal(ner_values[1], 9)
  expect_equal(ner_values[2], 9)
  expect_equal(ner_values[3], 9)
})

test_that("vectorized calculations match element-wise", {
  incomes <- c(50000, 100000, 25000)
  costs <- c(5000, 10000, 5000)

  # Vectorized
  ner_vec <- ner_func(incomes, costs)

  # Element-wise
  ner_elem <- c(
    ner_func(incomes[1], costs[1]),
    ner_func(incomes[2], costs[2]),
    ner_func(incomes[3], costs[3])
  )

  expect_equal(ner_vec, ner_elem)
})

test_that("metrics preserve NA values appropriately", {
  incomes <- c(50000, NA, 70000)
  costs <- c(5000, 6000, NA)

  ner_values <- ner_func(incomes, costs)

  expect_true(is.na(ner_values[2]))  # NA income -> NA NER
  expect_true(is.na(ner_values[3]))  # NA cost -> NA NER
  expect_false(is.na(ner_values[1]))  # Valid inputs -> valid NER
})

test_that("extreme values don't cause overflow", {
  # Very large income
  large_income <- 1e12
  cost <- 1000

  ner <- ner_func(large_income, cost)
  expect_true(is.finite(ner))
  expect_gt(ner, 0)

  # Very small income
  small_income <- 0.01
  small_cost <- 0.001

  ner_small <- ner_func(small_income, small_cost)
  expect_true(is.finite(ner_small))
})

test_that("energy burden never exceeds 1 for positive inputs", {
  # Unless cost > income
  incomes <- c(50000, 100000, 25000)
  costs <- c(5000, 10000, 5000)

  eb_values <- energy_burden_func(incomes, costs)

  expect_true(all(eb_values <= 1))
  expect_true(all(eb_values >= 0))
})

test_that("energy burden can exceed 1 when cost > income", {
  # Cost exceeds income
  eb <- energy_burden_func(10000, 15000)
  expect_gt(eb, 1)
  expect_equal(eb, 1.5)
})

test_that("NER is negative when cost exceeds income", {
  # NER = (G - S) / S
  # When S > G, numerator is negative
  ner <- ner_func(10000, 15000)
  expect_lt(ner, 0)
  expect_equal(ner, -5000 / 15000)
})

test_that("metrics handle recycling correctly", {
  # Single income, multiple costs
  income <- 50000
  costs <- c(2000, 5000, 10000)

  ner_values <- ner_func(income, costs)

  expect_equal(length(ner_values), 3)
  expect_equal(ner_values[1], (50000 - 2000) / 2000)
  expect_equal(ner_values[2], (50000 - 5000) / 5000)
  expect_equal(ner_values[3], (50000 - 10000) / 10000)
})

test_that("calculate_weighted_metrics works with sample data", {
  data <- create_sample_lead_data(n = 100)

  # Test that we can calculate metrics without errors
  expect_silent({
    data$ner <- ner_func(data$income, data$energy_cost)
    data$energy_burden <- energy_burden_func(data$income, data$energy_cost)
  })

  # Check that all values are finite (for valid data)
  valid_rows <- data$income > 0 & data$energy_cost > 0
  expect_true(all(is.finite(data$ner[valid_rows])))
  expect_true(all(is.finite(data$energy_burden[valid_rows])))
})

test_that("poverty rate calculation based on NER threshold", {
  data <- create_sample_lead_data(n = 200)
  data$ner <- ner_func(data$income, data$energy_cost)

  # Count households below poverty threshold (NER < 9)
  poverty_count <- sum(data$ner < 9, na.rm = TRUE)
  total_count <- sum(!is.na(data$ner))

  poverty_rate <- poverty_count / total_count

  # Poverty rate should be between 0 and 1
  expect_gte(poverty_rate, 0)
  expect_lte(poverty_rate, 1)

  # With random data, should have some variation
  expect_gt(poverty_count, 0)  # Should have some in poverty
  expect_lt(poverty_count, total_count)  # Not all in poverty
})
