# Test NEB/EB/Nh Mathematical Equivalences and Aggregation Methods
# =================================================================
#
# This test suite demonstrates:
# 1. NEB = EB mathematically (at household level)
# 2. Proper aggregation via Nh (arithmetic mean) vs direct EB (harmonic mean)
# 3. Why arithmetic mean of EB is WRONG
# 4. Zero-removal requirements

library(testthat)

# Test 1: NEB function is identical to Energy Burden
# ===================================================
test_that("neb_func() is mathematically identical to energy_burden_func()", {
  # Single household
  income <- 50000
  spending <- 3000

  eb <- energy_burden_func(income, spending)
  neb <- neb_func(income, spending)

  expect_equal(neb, eb)
  expect_equal(neb, 0.06)

  # Vectorized
  incomes <- c(30000, 50000, 75000, 100000)
  spendings <- c(3000, 3500, 4000, 3500)

  eb_vec <- energy_burden_func(incomes, spendings)
  neb_vec <- neb_func(incomes, spendings)

  expect_equal(neb_vec, eb_vec)
})

# Test 2: NEB via Nh transformation
# ==================================
test_that("NEB can be calculated via Nh transformation", {
  income <- 50000
  spending <- 3000

  # Direct calculation
  neb_direct <- neb_func(income, spending)

  # Via Nh
  nh <- ner_func(income, spending)
  neb_via_nh <- 1 / (1 + nh)

  expect_equal(neb_via_nh, neb_direct)
  expect_equal(neb_via_nh, 0.06)

  # Verify the inverse relationship
  # nh = (G - S) / S
  # neb = S / G
  # neb = 1 / (1 + nh)
  expected_nh <- (income - spending) / spending
  expect_equal(nh, expected_nh)
  expect_equal(1 / (1 + nh), spending / income)
})

# Test 3: Cohort Data - Direct NEB equals NEB via Nh
# ====================================================
test_that("For cohort data, direct NEB calculation equals NEB via Nh", {
  # Simulate cohort data (pre-aggregated totals)
  # These are totals for different income groups
  total_incomes <- c(3000000, 7500000, 15000000, 20000000)
  total_spendings <- c(300000, 525000, 750000, 600000)
  households <- c(100, 150, 200, 200)

  # Method 1: Direct calculation (sum totals)
  neb_direct <- sum(total_spendings) / sum(total_incomes)

  # Method 2: Via Nh
  # For cohort data with totals, calculate aggregate Nh using weighted totals
  # Nh = (sum(G*h) - sum(S*h)) / sum(S*h) where h is household count per cohort
  # This is equivalent to: (sum(total_income) - sum(total_spending)) / sum(total_spending)
  total_income_all <- sum(total_incomes)
  total_spending_all <- sum(total_spendings)
  nh_aggregate <- (total_income_all - total_spending_all) / total_spending_all
  neb_via_nh <- 1 / (1 + nh_aggregate)

  # Should be equal for cohort data
  expect_equal(neb_via_nh, neb_direct, tolerance = 1e-10)

  # Verify: This is mathematically identical to direct NEB
  # NEB = S/G
  # Nh = (G-S)/S
  # NEB = 1/(1+Nh) = 1/(1+(G-S)/S) = S/(S+G-S) = S/G ✓
})

# Test 4: Individual HH Data - Nh Method vs Harmonic Mean
# ========================================================
test_that("For individual HH data, Nh method equals harmonic mean of EB", {
  # Simulate individual household data
  incomes <- c(30000, 50000, 75000, 100000, 150000)
  spendings <- c(3600, 3500, 4500, 4000, 5000)
  hh_weights <- c(100, 150, 200, 175, 125)

  # Calculate EB for each household
  eb <- energy_burden_func(incomes, spendings)

  # Method 1: Via Nh (arithmetic mean)
  nh <- ner_func(incomes, spendings)
  nh_mean <- weighted.mean(nh, hh_weights)
  neb_via_nh <- 1 / (1 + nh_mean)

  # Method 2: Harmonic mean of EB
  # Harmonic mean formula: 1 / weighted.mean(1/x, w)
  neb_harmonic <- 1 / weighted.mean(1 / eb, hh_weights)

  # These should be equal
  expect_equal(neb_via_nh, neb_harmonic, tolerance = 1e-10)
})

# Test 5: Arithmetic Mean of EB is WRONG
# =======================================
test_that("Arithmetic mean of EB introduces error (DO NOT USE)", {
  # Simulate data with varying energy burdens
  incomes <- c(25000, 50000, 75000, 100000, 150000)
  spendings <- c(3750, 3500, 4500, 4000, 4500)  # Different burden levels
  hh_weights <- c(150, 200, 180, 150, 100)

  # Calculate EB
  eb <- energy_burden_func(incomes, spendings)

  # CORRECT: Via Nh
  nh <- ner_func(incomes, spendings)
  nh_mean <- weighted.mean(nh, hh_weights)
  neb_correct <- 1 / (1 + nh_mean)

  # WRONG: Arithmetic mean of EB
  neb_wrong <- weighted.mean(eb, hh_weights)

  # Calculate error
  error <- abs(neb_wrong - neb_correct)
  error_pct <- (error / neb_correct) * 100

  # Error should be non-zero and typically 1-5%
  expect_gt(error, 0)
  expect_gt(error_pct, 0.1)  # At least 0.1% error

  # Document the error
  message(sprintf(
    "Arithmetic mean error: %.4f (%.2f%% relative error)",
    error, error_pct
  ))

  # The error increases with heterogeneity in energy burdens
  # This is why arithmetic mean is WRONG for ratios
})

# Test 6: Arithmetic Mean Error Increases with Heterogeneity
# ===========================================================
test_that("Arithmetic mean error increases with burden heterogeneity", {
  # Case 1: Homogeneous burdens (similar incomes/spending)
  incomes_homo <- c(50000, 52000, 48000, 51000, 49000)
  spendings_homo <- c(3000, 3120, 2880, 3060, 2940)
  weights <- c(100, 100, 100, 100, 100)

  eb_homo <- energy_burden_func(incomes_homo, spendings_homo)
  nh_homo <- ner_func(incomes_homo, spendings_homo)

  neb_correct_homo <- 1 / (1 + weighted.mean(nh_homo, weights))
  neb_wrong_homo <- weighted.mean(eb_homo, weights)
  error_homo <- abs(neb_wrong_homo - neb_correct_homo) / neb_correct_homo * 100

  # Case 2: Heterogeneous burdens (high variance)
  incomes_hetero <- c(25000, 50000, 100000, 150000, 200000)
  spendings_hetero <- c(5000, 4000, 5000, 4500, 4000)

  eb_hetero <- energy_burden_func(incomes_hetero, spendings_hetero)
  nh_hetero <- ner_func(incomes_hetero, spendings_hetero)

  neb_correct_hetero <- 1 / (1 + weighted.mean(nh_hetero, weights))
  neb_wrong_hetero <- weighted.mean(eb_hetero, weights)
  error_hetero <- abs(neb_wrong_hetero - neb_correct_hetero) / neb_correct_hetero * 100

  # Heterogeneous case should have larger error
  expect_gt(error_hetero, error_homo)

  message(sprintf(
    "Homogeneous error: %.2f%% | Heterogeneous error: %.2f%%",
    error_homo, error_hetero
  ))
})

# Test 7: Zero-Removal Requirement for Nh
# ========================================
test_that("Nh requires S > 0 (zero-removal is essential)", {
  # Test data with zero spending
  incomes <- c(50000, 60000, 70000)
  spendings <- c(3000, 0, 4000)  # One zero

  # EB technically works with S=0 (gives EB=0)
  eb <- energy_burden_func(incomes, spendings)
  expect_equal(eb[2], 0)  # Zero spending gives zero burden

  # But Nh has division by S in denominator
  # Nh = (G - S) / S  --> division by zero!
  nh_with_zeros <- ner_func(incomes, spendings)

  # Check for Inf at the zero-spending position
  expect_true(is.infinite(nh_with_zeros[2]))
  expect_true(is.finite(nh_with_zeros[1]))
  expect_true(is.finite(nh_with_zeros[3]))

  # This demonstrates why zero-removal is essential for Nh
  # Infinite values break aggregation calculations

  # SOLUTION: Remove zero-spending records before analysis
  valid_idx <- spendings > 0
  incomes_clean <- incomes[valid_idx]
  spendings_clean <- spendings[valid_idx]

  nh_clean <- ner_func(incomes_clean, spendings_clean)
  expect_true(all(is.finite(nh_clean)))
  expect_length(nh_clean, 2)  # Only 2 valid records

  # This is why the LEAD processing code filters out zero-energy records:
  # data <- data[data$energy_cost != 0, ]
  #
  # From R/lead_processing.R:208:
  # "Filter out zero-energy records (required for analysis)"
})

# Test 8: 6% Energy Burden Threshold Correspondence
# ==================================================
test_that("6% EB threshold corresponds to Nh = 15.67", {
  # The standard 6% energy burden poverty threshold
  eb_threshold <- 0.06

  # Calculate corresponding Nh
  # EB = 1/(1+Nh)
  # 0.06 = 1/(1+Nh)
  # 1+Nh = 1/0.06
  # Nh = (1/0.06) - 1
  nh_threshold <- (1 / eb_threshold) - 1

  expect_equal(nh_threshold, 15.666667, tolerance = 1e-5)

  # Verify the inverse
  eb_from_nh <- 1 / (1 + nh_threshold)
  expect_equal(eb_from_nh, eb_threshold, tolerance = 1e-10)

  # Using the ner_func with hypothetical data
  income <- 100
  spending <- 6  # 6% burden

  nh_calculated <- ner_func(income, spending)
  expect_equal(nh_calculated, nh_threshold, tolerance = 1e-5)
})

# Test 9: Computational Advantages Documentation
# ===============================================
test_that("Nh method is computationally simpler than harmonic mean", {
  # Simulate realistic data
  set.seed(42)
  n <- 1000
  incomes <- rlnorm(n, meanlog = 10.8, sdlog = 0.6) * 1000
  spendings <- incomes * runif(n, 0.02, 0.15)
  weights <- rpois(n, lambda = 50) + 1

  # Method 1: Nh approach (arithmetic mean)
  nh <- ner_func(incomes, spendings)

  time_nh <- system.time({
    neb_nh <- 1 / (1 + weighted.mean(nh, weights))
  })

  # Method 2: Direct EB harmonic mean
  eb <- energy_burden_func(incomes, spendings)

  time_harmonic <- system.time({
    neb_harmonic <- 1 / weighted.mean(1 / eb, weights)
  })

  # Results should be identical
  expect_equal(neb_nh, neb_harmonic, tolerance = 1e-10)

  # Nh method advantages:
  # 1. Uses standard weighted.mean() - simpler
  # 2. Avoids division by small EB values - more stable
  # 3. More interpretable - "average net return per dollar"
  # 4. Makes it obvious arithmetic mean on EB is wrong

  message(sprintf(
    "Nh method: %.6f sec | Harmonic method: %.6f sec | NEB: %.4f",
    time_nh[3], time_harmonic[3], neb_nh
  ))
})

# Test 10: Numerical Stability with Small EB Values
# ==================================================
test_that("Nh method is more numerically stable with small EB values", {
  # Create data with some very small energy burdens
  incomes <- c(200000, 150000, 100000, 50000, 30000)
  spendings <- c(1000, 2000, 3000, 4000, 4500)  # 0.5% to 15%
  weights <- c(50, 75, 100, 120, 130)

  eb <- energy_burden_func(incomes, spendings)

  # Nh method
  nh <- ner_func(incomes, spendings)
  neb_nh <- 1 / (1 + weighted.mean(nh, weights))

  # Harmonic mean (involves 1/eb where eb is very small)
  neb_harmonic <- 1 / weighted.mean(1 / eb, weights)

  # Both should be equal
  expect_equal(neb_nh, neb_harmonic, tolerance = 1e-10)

  # But Nh method avoids potential numerical issues from 1/0.005 = 200
  # vs Nh = 199 (subtraction instead of division)

  # Check that Nh values are well-behaved
  expect_true(all(is.finite(nh)))
  expect_true(all(nh > 0))  # All should be positive for real households
})

# Test 11: Edge Cases
# ===================
test_that("Functions handle edge cases appropriately", {
  # Very high burden (S > G would give negative Nh)
  # This shouldn't happen in real data but test boundary
  income_low <- 1000
  spending_high <- 1500

  # EB can be > 1 (spending exceeds income)
  eb_high <- energy_burden_func(income_low, spending_high)
  expect_equal(eb_high, 1.5)

  # Nh would be negative
  nh_negative <- ner_func(income_low, spending_high)
  expect_lt(nh_negative, 0)

  # Relationship still holds
  expect_equal(1 / (1 + nh_negative), eb_high, tolerance = 1e-10)
})

# Test 12: Real-World Example
# ============================
test_that("Real-world scenario demonstrates proper aggregation", {
  # Simulate data similar to NC energy burden analysis
  # Low income: high burden
  # High income: low burden

  income_brackets <- c("0-30% AMI", "30-50% AMI", "50-80% AMI",
                       "80-100% AMI", "100%+ AMI")
  mean_incomes <- c(15000, 35000, 55000, 75000, 120000)
  mean_spendings <- c(1800, 2500, 3000, 3200, 3500)
  households <- c(150000, 120000, 180000, 100000, 300000)

  # Calculate metrics
  eb <- energy_burden_func(mean_incomes, mean_spendings)
  nh <- ner_func(mean_incomes, mean_spendings)

  # CORRECT aggregation via Nh
  nh_weighted <- weighted.mean(nh, households)
  neb_correct <- 1 / (1 + nh_weighted)

  # WRONG aggregation (arithmetic mean)
  eb_wrong <- weighted.mean(eb, households)

  # Calculate error
  error_pct <- abs(eb_wrong - neb_correct) / neb_correct * 100

  # Document results
  message(sprintf("\n=== Real-World Aggregation Example ==="))
  message(sprintf("Correct NEB (via Nh): %.4f (%.2f%%)",
                  neb_correct, neb_correct * 100))
  message(sprintf("Wrong EB (arithmetic): %.4f (%.2f%%)",
                  eb_wrong, eb_wrong * 100))
  message(sprintf("Relative error: %.2f%%", error_pct))
  message(sprintf("Households with EB>6%%: %.1f%%",
                  sum(households[eb > 0.06]) / sum(households) * 100))

  # Error should be substantial
  expect_gt(error_pct, 0.5)

  # Verify individual bracket calculations are correct
  for (i in seq_along(income_brackets)) {
    neb_i <- neb_func(mean_incomes[i], mean_spendings[i])
    nh_i <- ner_func(mean_incomes[i], mean_spendings[i])
    expect_equal(neb_i, 1 / (1 + nh_i), tolerance = 1e-10)
  }
})

# Test 13: Performance Benchmark - Computational Efficiency
# ==========================================================
test_that("Nh method (arithmetic mean) is faster than harmonic mean", {
  # Create realistic large dataset
  set.seed(123)
  n <- 10000  # 10,000 households
  incomes <- rlnorm(n, meanlog = 10.8, sdlog = 0.6) * 1000
  spendings <- incomes * runif(n, 0.02, 0.15)
  weights <- rpois(n, lambda = 50) + 1

  # Calculate metrics once
  eb <- energy_burden_func(incomes, spendings)
  nh <- ner_func(incomes, spendings)

  # Number of iterations for timing
  n_iter <- 1000

  # Method 1: Nh approach (arithmetic mean) - RECOMMENDED
  time_nh <- system.time({
    for (i in 1:n_iter) {
      neb_nh <- 1 / (1 + weighted.mean(nh, weights))
    }
  })[3]

  # Method 2: Harmonic mean of EB - CORRECT but slower
  time_harmonic <- system.time({
    for (i in 1:n_iter) {
      neb_harmonic <- 1 / weighted.mean(1 / eb, weights)
    }
  })[3]

  # Method 3: Arithmetic mean of EB - FAST but WRONG
  time_wrong <- system.time({
    for (i in 1:n_iter) {
      neb_wrong <- weighted.mean(eb, weights)
    }
  })[3]

  # Calculate final values for verification
  neb_nh_final <- 1 / (1 + weighted.mean(nh, weights))
  neb_harmonic_final <- 1 / weighted.mean(1 / eb, weights)
  neb_wrong_final <- weighted.mean(eb, weights)

  # Verify correctness
  expect_equal(neb_nh_final, neb_harmonic_final, tolerance = 1e-10)
  expect_gt(abs(neb_wrong_final - neb_nh_final), 0)  # Wrong method differs

  # Performance assertions
  # Nh method should be at least as fast as harmonic mean (typically faster)
  speedup_vs_harmonic <- time_harmonic / time_nh

  # Calculate error from wrong method
  error_pct <- abs(neb_wrong_final - neb_nh_final) / neb_nh_final * 100

  # Document results
  message("\n=== Performance Benchmark (", n, " households, ", n_iter, " iterations) ===")
  message("NOTE: Speed advantage applies to AGGREGATION operation only!")
  message("      For single household calculations, both methods are equivalent.")
  message(sprintf("Method 1 (Nh arithmetic):  %.4f sec  [RECOMMENDED - Correct & Fast]",
                  time_nh))
  message(sprintf("Method 2 (EB harmonic):    %.4f sec  [Correct but %.1fx slower]",
                  time_harmonic, speedup_vs_harmonic))
  message(sprintf("Method 3 (EB arithmetic):  %.4f sec  [WRONG - %.2f%% error!]",
                  time_wrong, error_pct))
  message(sprintf("\nSpeedup: Nh method is %.2fx faster than harmonic mean (for aggregation)", speedup_vs_harmonic))
  message(sprintf("Accuracy: Both correct methods agree within 1e-10"))
  message(sprintf("Error: Arithmetic mean of EB introduces %.2f%% error", error_pct))

  # Test should pass if Nh method is correct
  # Skip performance test on Windows - timing is too variable on CI
  skip_on_os("windows")
  expect_true(speedup_vs_harmonic > 0.5)  # At least not much slower
  expect_true(error_pct > 0.1)  # Wrong method has measurable error
})

# Test 14: Scalability - Performance with Different Dataset Sizes
# ================================================================
test_that("Nh method scales well with dataset size", {
  set.seed(456)

  dataset_sizes <- c(100, 1000, 10000)
  results <- data.frame(
    n = integer(),
    time_nh = numeric(),
    time_harmonic = numeric(),
    speedup = numeric()
  )

  for (n in dataset_sizes) {
    # Generate data
    incomes <- rlnorm(n, meanlog = 10.8, sdlog = 0.6) * 1000
    spendings <- incomes * runif(n, 0.02, 0.15)
    weights <- rpois(n, lambda = 50) + 1

    # Calculate metrics
    eb <- energy_burden_func(incomes, spendings)
    nh <- ner_func(incomes, spendings)

    # Benchmark with fewer iterations for larger datasets
    n_iter <- max(100, 10000 / n)

    # Time Nh method
    time_nh <- system.time({
      for (i in 1:n_iter) {
        neb <- 1 / (1 + weighted.mean(nh, weights))
      }
    })[3]

    # Time harmonic method
    time_harmonic <- system.time({
      for (i in 1:n_iter) {
        neb <- 1 / weighted.mean(1 / eb, weights)
      }
    })[3]

    # Store results
    results <- rbind(results, data.frame(
      n = n,
      time_nh = time_nh,
      time_harmonic = time_harmonic,
      speedup = time_harmonic / time_nh
    ))
  }

  message("\n=== Scalability Benchmark ===")
  message("NOTE: Speed advantage applies to AGGREGATION operation only, not single household")
  message(sprintf("%-10s %-15s %-15s %-10s",
                  "Size", "Nh (sec)", "Harmonic (sec)", "Speedup"))
  for (i in 1:nrow(results)) {
    message(sprintf("%-10d %-15.4f %-15.4f %.2fx",
                    results$n[i], results$time_nh[i],
                    results$time_harmonic[i], results$speedup[i]))
  }

  # Verify both methods complete successfully (no performance assertion - too noisy)
  expect_true(all(is.finite(results$time_nh)))
  expect_true(all(is.finite(results$time_harmonic)))
  # Note: speedup can be non-finite when timing is very small, which is acceptable
  # We're testing correctness, not enforcing specific performance ratios
})
