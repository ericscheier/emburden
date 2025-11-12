test_that("get_state_fips converts valid state abbreviations", {
  # Single state
  expect_equal(get_state_fips("NC"), "37")
  expect_equal(get_state_fips("CA"), "06")
  expect_equal(get_state_fips("NY"), "36")

  # Multiple states
  result <- get_state_fips(c("NC", "SC", "VA"))
  expect_equal(result, c("37", "45", "51"))

  # Case insensitive
  expect_equal(get_state_fips("nc"), "37")
  expect_equal(get_state_fips("Nc"), "37")

  # DC and territories
  expect_equal(get_state_fips("DC"), "11")
  expect_equal(get_state_fips("PR"), "72")
})

test_that("get_state_fips returns unnamed vector", {
  result <- get_state_fips(c("NC", "SC"))

  # Should be unnamed
  expect_null(names(result))
  expect_equal(length(result), 2)
})

test_that("get_state_fips handles all 50 states plus DC and PR", {
  # Test a sample of states across different FIPS codes
  states <- c("AL", "AK", "AZ", "AR", "CA", "FL", "GA", "HI", "IL", "TX")
  fips <- c("01", "02", "04", "05", "06", "12", "13", "15", "17", "48")

  result <- get_state_fips(states)
  expect_equal(result, fips)
})

test_that("get_state_fips errors on invalid state abbreviation", {
  expect_error(
    get_state_fips("XX"),
    "Invalid state abbreviation.*XX"
  )

  expect_error(
    get_state_fips(c("NC", "INVALID", "SC")),
    "Invalid state abbreviation.*INVALID"
  )

  # Multiple invalid
  expect_error(
    get_state_fips(c("XX", "YY")),
    "Invalid state abbreviation"
  )
})

test_that("standardize_cohort_columns renames FIP to geoid", {
  data <- data.frame(
    FIP = c("37183020100", "37051003400"),
    income_bracket = c("very_low", "low_mod"),
    households = c(100, 150),
    total_income = c(2500000, 6000000),
    total_electricity_spend = c(120000, 180000)
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  expect_true("geoid" %in% names(result))
  expect_false("FIP" %in% names(result))
  expect_equal(result$geoid, c("37183020100", "37051003400"))
})

test_that("standardize_cohort_columns ensures geoid is character", {
  data <- data.frame(
    geoid = c(37183020100, 37051003400),  # Numeric
    income_bracket = c("very_low", "low_mod"),
    households = c(100, 150),
    total_income = c(2500000, 6000000),
    total_electricity_spend = c(120000, 180000)
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  expect_type(result$geoid, "character")
  expect_equal(result$geoid, c("37183020100", "37051003400"))
})

test_that("standardize_cohort_columns renames aggregated cohort columns", {
  data <- data.frame(
    geoid = c("37183020100", "37051003400"),
    FPL150 = c("Below", "Above"),
    UNITS = c(100, 150),
    `HINCP*UNITS` = c(5000000, 7500000),
    `ELEP*UNITS` = c(120000, 180000),
    `GASP*UNITS` = c(80000, 90000),
    `FULP*UNITS` = c(10000, 15000),
    check.names = FALSE
  )

  result <- standardize_cohort_columns(data, "fpl", "2022")

  # Check renamed columns
  expect_true("income_bracket" %in% names(result))
  expect_true("households" %in% names(result))
  expect_true("total_income" %in% names(result))
  expect_true("total_electricity_spend" %in% names(result))
  expect_true("total_gas_spend" %in% names(result))
  expect_true("total_other_spend" %in% names(result))

  # Check old names removed
  expect_false("FPL150" %in% names(result))
  expect_false("UNITS" %in% names(result))
})

test_that("standardize_cohort_columns renames dataset-specific income columns", {
  # AMI dataset
  ami_data <- data.frame(
    geoid = "37183020100",
    ami_bracket = "very_low",
    households = 100,
    total_income = 2500000,
    total_electricity_spend = 120000
  )

  ami_result <- standardize_cohort_columns(ami_data, "ami", "2022")
  expect_true("income_bracket" %in% names(ami_result))
  expect_false("ami_bracket" %in% names(ami_result))
  expect_equal(ami_result$income_bracket, "very_low")

  # FPL dataset
  fpl_data <- data.frame(
    geoid = "37183020100",
    fpl_bracket = "0-100%",
    households = 100,
    total_income = 2500000,
    total_electricity_spend = 120000
  )

  fpl_result <- standardize_cohort_columns(fpl_data, "fpl", "2022")
  expect_true("income_bracket" %in% names(fpl_result))
  expect_false("fpl_bracket" %in% names(fpl_result))
  expect_equal(fpl_result$income_bracket, "0-100%")
})

test_that("standardize_cohort_columns maps 2018 AMI brackets to standard categories", {
  data <- data.frame(
    geoid = rep("37183020100", 5),
    income_bracket = c("0-30%", "30-60%", "60-80%", "80-100%", "100%+"),
    households = c(50, 60, 70, 80, 90),
    total_income = c(750000, 2400000, 4200000, 6400000, 9000000),
    total_electricity_spend = c(60000, 72000, 84000, 96000, 108000)
  )

  result <- standardize_cohort_columns(data, "ami", "2018")

  # Check mappings
  expect_equal(result$income_bracket[1], "very_low")     # 0-30%
  expect_equal(result$income_bracket[2], "low_mod")      # 30-60%
  expect_equal(result$income_bracket[3], "low_mod")      # 60-80%
  expect_equal(result$income_bracket[4], "mid_high")     # 80-100%
  expect_equal(result$income_bracket[5], "mid_high")     # 100%+
})

test_that("standardize_cohort_columns preserves 2022 AMI brackets", {
  data <- data.frame(
    geoid = rep("37183020100", 3),
    income_bracket = c("very_low", "low_mod", "mid_high"),
    households = c(50, 60, 70),
    total_income = c(750000, 2400000, 4200000),
    total_electricity_spend = c(60000, 72000, 84000)
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  # Should remain unchanged
  expect_equal(result$income_bracket, c("very_low", "low_mod", "mid_high"))
})

test_that("standardize_cohort_columns creates total_* columns from per-household columns", {
  data <- data.frame(
    geoid = rep("37183020100", 2),
    income_bracket = c("very_low", "low_mod"),
    households = c(100, 150),
    income = c(25000, 40000),
    electricity_spend = c(1200, 1500),
    gas_spend = c(800, 900),
    other_spend = c(100, 150)
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  # Check total_* columns were created
  expect_true("total_income" %in% names(result))
  expect_true("total_electricity_spend" %in% names(result))
  expect_true("total_gas_spend" %in% names(result))
  expect_true("total_other_spend" %in% names(result))

  # Check calculations
  expect_equal(result$total_income[1], 25000 * 100)
  expect_equal(result$total_income[2], 40000 * 150)
  expect_equal(result$total_electricity_spend[1], 1200 * 100)
  expect_equal(result$total_electricity_spend[2], 1500 * 150)
})

test_that("standardize_cohort_columns does not overwrite existing total_* columns", {
  data <- data.frame(
    geoid = "37183020100",
    income_bracket = "very_low",
    households = 100,
    income = 25000,
    total_income = 3000000,  # Pre-existing, different value
    total_electricity_spend = 120000
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  # Should keep the existing value
  expect_equal(result$total_income, 3000000)
})

test_that("standardize_cohort_columns warns about missing required columns", {
  # Data missing several required columns
  data <- data.frame(
    geoid = "37183020100",
    households = 100
    # Missing: income_bracket, total_income, total_electricity_spend
  )

  expect_warning(
    standardize_cohort_columns(data, "ami", "2022"),
    "Missing expected columns"
  )
})

test_that("standardize_cohort_columns handles complete valid input silently", {
  data <- data.frame(
    geoid = "37183020100",
    income_bracket = "very_low",
    households = 100,
    total_income = 2500000,
    total_electricity_spend = 120000,
    total_gas_spend = 80000,
    total_other_spend = 10000
  )

  # Should not warn or error
  expect_silent(standardize_cohort_columns(data, "ami", "2022"))
})

test_that("standardize_cohort_columns handles empty dataframe", {
  data <- data.frame(
    geoid = character(),
    income_bracket = character(),
    households = numeric(),
    total_income = numeric(),
    total_electricity_spend = numeric()
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  expect_equal(nrow(result), 0)
  expect_true("geoid" %in% names(result))
})

test_that("standardize_cohort_columns preserves non-target columns", {
  data <- data.frame(
    geoid = "37183020100",
    income_bracket = "very_low",
    households = 100,
    total_income = 2500000,
    total_electricity_spend = 120000,
    custom_column = "test_value",
    another_col = 42
  )

  result <- standardize_cohort_columns(data, "ami", "2022")

  # Custom columns should be preserved
  expect_true("custom_column" %in% names(result))
  expect_true("another_col" %in% names(result))
  expect_equal(result$custom_column, "test_value")
  expect_equal(result$another_col, 42)
})
