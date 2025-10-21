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
