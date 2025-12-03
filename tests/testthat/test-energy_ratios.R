test_that("energy_burden_func calculates correctly", {
  # Basic calculation
  expect_equal(energy_burden_func(50000, 3000), 0.06)
  expect_equal(energy_burden_func(100000, 4000), 0.04)

  # Vector inputs
  income <- c(50000, 75000, 100000)
  spending <- c(3000, 4500, 5000)
  result <- energy_burden_func(income, spending)
  expect_equal(result, c(0.06, 0.06, 0.05))

  # Zero income should give Inf
  expect_equal(energy_burden_func(0, 1000), Inf)

  # Zero spending should give 0
  expect_equal(energy_burden_func(50000, 0), 0)
})

test_that("ner_func calculates correctly", {
  # Basic calculation: (50000-3000)/3000 = 15.67
  expect_equal(ner_func(50000, 3000), (50000 - 3000) / 3000)

  # Verify relationship with energy burden
  g <- 50000
  s <- 3000
  nh <- ner_func(g, s)
  eb <- 1 / (nh + 1)
  expect_equal(eb, s / g)

  # Energy poverty line: 6% burden corresponds to Nh = 15.67
  nh_poverty <- ner_func(1, 0.06)
  expect_equal(round(nh_poverty, 2), 15.67)

  # Vector inputs
  income <- c(50000, 75000, 100000)
  spending <- c(3000, 4500, 5000)
  result <- ner_func(income, spending)
  expect_length(result, 3)
  expect_true(all(result > 0))
})

test_that("eroi_func calculates correctly", {
  # EROI = G / S
  expect_equal(eroi_func(50000, 3000), 50000 / 3000)
  expect_equal(eroi_func(100000, 4000), 25)

  # Relationship: EROI = Nh + 1
  g <- 50000
  s <- 3000
  nh <- ner_func(g, s)
  eroi <- eroi_func(g, s)
  expect_equal(eroi, nh + 1)
})

test_that("dear_func calculates correctly", {
  # DEAR = (G - S) / G
  expect_equal(dear_func(50000, 3000), (50000 - 3000) / 50000)
  expect_equal(dear_func(100000, 10000), 0.9)

  # Relationship with energy burden: DEAR = 1 - E_b
  g <- 50000
  s <- 3000
  eb <- energy_burden_func(g, s)
  dear <- dear_func(g, s)
  expect_equal(dear, 1 - eb)
})

test_that("energy metrics handle effective spending parameter", {
  g <- 50000
  s <- 3000
  se <- 2500 # Different effective spending

  # With se parameter
  eb_with_se <- energy_burden_func(g, s, se)
  nh_with_se <- ner_func(g, s, se)

  # Should use se in calculations
  expect_equal(eb_with_se, s / g) # Still uses s for numerator
  expect_equal(nh_with_se, (g - s) / se) # Uses se for denominator
})

test_that("energy metrics handle edge cases", {
  # NA values
  expect_true(is.na(energy_burden_func(NA, 1000)))
  expect_true(is.na(ner_func(50000, NA)))

  # Negative values (unrealistic but should compute)
  expect_true(energy_burden_func(50000, -1000) < 0)
})

test_that("neb_func works without aggregation (backwards compatible)", {
  # Individual household - should return vector identical to EB
  expect_equal(neb_func(50000, 3000), 0.06)
  expect_equal(neb_func(50000, 3000), energy_burden_func(50000, 3000))

  # Multiple households without weights - should return vector
  incomes <- c(30000, 50000, 75000)
  spending <- c(3000, 3500, 4000)
  result <- neb_func(incomes, spending)

  expect_length(result, 3)
  expect_equal(result, spending / incomes)
  expect_equal(result, energy_burden_func(incomes, spending))
})

test_that("neb_func aggregates correctly with weights (Nh method)", {
  # Test data
  incomes <- c(30000, 50000, 75000)
  spending <- c(3000, 3500, 4000)
  households <- c(100, 150, 200)

  # Calculate via neb_func with weights
  neb_aggregated <- neb_func(incomes, spending, weights = households)

  # Verify it's a single value
  expect_length(neb_aggregated, 1)

  # Verify it uses Nh method internally
  nh <- ner_func(incomes, spending)
  nh_mean <- weighted.mean(nh, households)
  neb_expected <- 1 / (1 + nh_mean)
  expect_equal(neb_aggregated, neb_expected)

  # Verify it avoids naive averaging error
  neb_naive <- weighted.mean(spending / incomes, households)
  expect_false(isTRUE(all.equal(neb_aggregated, neb_naive)))
  # Error should be small but present (1-5%)
  error_pct <- abs(neb_naive - neb_aggregated) / neb_aggregated * 100
  expect_gt(error_pct, 0.1)  # At least 0.1% difference
})

test_that("neb_func aggregates without weights when aggregate=TRUE", {
  incomes <- c(30000, 50000, 75000)
  spending <- c(3000, 3500, 4000)

  # Aggregate without weights
  neb_agg <- neb_func(incomes, spending, aggregate = TRUE)

  # Should return single value
  expect_length(neb_agg, 1)

  # Should use unweighted mean of Nh
  nh <- ner_func(incomes, spending)
  nh_mean <- mean(nh)
  neb_expected <- 1 / (1 + nh_mean)
  expect_equal(neb_agg, neb_expected)
})

test_that("neb_func handles effective spending with aggregation", {
  incomes <- c(30000, 50000)
  spending <- c(3000, 3500)
  se <- c(2500, 3000)  # Effective spending
  weights <- c(100, 150)

  # With weights and effective spending
  neb_agg <- neb_func(incomes, spending, se = se, weights = weights)

  # Should use se in Nh calculation
  nh <- ner_func(incomes, spending, se)
  nh_mean <- weighted.mean(nh, weights)
  neb_expected <- 1 / (1 + nh_mean)
  expect_equal(neb_agg, neb_expected)
})

test_that("neb_func demonstrates Nh method superiority", {
  # Realistic income distribution
  incomes <- c(25000, 35000, 50000, 75000, 100000)
  spending <- c(3500, 3800, 4000, 4500, 5000)
  households <- c(200, 300, 250, 150, 100)

  # CORRECT: Via neb_func (uses Nh method)
  neb_correct <- neb_func(incomes, spending, weights = households)

  # WRONG: Naive weighted mean
  neb_naive <- weighted.mean(spending / incomes, households)

  # Should be different
  expect_false(isTRUE(all.equal(neb_correct, neb_naive, tolerance = 0.001)))

  # Verify the correct method gives reasonable value
  expect_gt(neb_correct, 0)
  expect_lt(neb_correct, 1)

  # Verify relationship: correct = 1/(1 + weighted.mean(Nh))
  nh <- ner_func(incomes, spending)
  nh_mean <- weighted.mean(nh, households)
  expect_equal(neb_correct, 1 / (1 + nh_mean))
})

test_that("neb_func handles NA values in aggregation", {
  incomes <- c(30000, NA, 75000)
  spending <- c(3000, 3500, 4000)
  weights <- c(100, 150, 200)

  # With weights - should handle NA gracefully
  result <- neb_func(incomes, spending, weights = weights)
  expect_false(is.na(result))  # Should compute with non-NA values
  expect_length(result, 1)
})

test_that("neb_func with weights matches manual Nh aggregation (documentation test)", {
  # This test verifies examples from documentation work correctly
  # Simulates cohort data (pre-aggregated means)
  mean_incomes <- c(30000, 50000, 75000)
  mean_spending <- c(3000, 3500, 4000)
  households <- c(100, 150, 200)

  # Manual Nh method (documented approach)
  nh <- ner_func(mean_incomes, mean_spending)
  nh_mean <- weighted.mean(nh, households)
  neb_manual <- 1 / (1 + nh_mean)

  # Using neb_func() with weights (new approach)
  neb_auto <- neb_func(mean_incomes, mean_spending, weights = households)

  # Should be identical
  expect_equal(neb_auto, neb_manual)

  # Verify both differ from naive averaging (which is wrong)
  neb_naive <- weighted.mean(mean_spending / mean_incomes, households)
  expect_false(isTRUE(all.equal(neb_auto, neb_naive, tolerance = 0.001)))
})

test_that("neb_func aggregation works in dplyr workflows", {
  # Simulate grouped aggregation as in vignettes
  library(dplyr)

  cohort_data <- data.frame(
    group = rep(c("A", "B"), each = 3),
    mean_income = c(30000, 50000, 75000, 40000, 60000, 90000),
    mean_spending = c(3000, 3500, 4000, 3200, 3800, 4500),
    households = c(100, 150, 200, 120, 180, 150)
  )

  # Method 1: Manual Nh aggregation
  result_manual <- cohort_data %>%
    group_by(group) %>%
    summarise(
      nh_mean = weighted.mean(ner_func(mean_income, mean_spending), households),
      neb = 1 / (1 + nh_mean),
      .groups = "drop"
    )

  # Method 2: Using neb_func() with weights
  result_auto <- cohort_data %>%
    group_by(group) %>%
    summarise(
      neb = neb_func(mean_income, mean_spending, weights = households),
      .groups = "drop"
    )

  # Should give identical results
  expect_equal(result_auto$neb, result_manual$neb)
})
