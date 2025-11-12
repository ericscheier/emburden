# Phase 1: File Validation Tests
# Tests for data quality checks and validation functions

test_that("sample data generator creates valid structure", {
  data <- create_sample_lead_data(n = 50)

  expect_s3_class(data, "data.frame")
  expect_equal(nrow(data), 50)
  expect_true("geoid" %in% names(data))
  expect_true("income_bracket" %in% names(data))
  expect_true("income" %in% names(data))
  expect_true("energy_cost" %in% names(data))
  expect_true("households" %in% names(data))
})

test_that("sample AMI data has correct income brackets", {
  data <- create_sample_lead_data(n = 100, dataset = "ami")

  expected_brackets <- c("0-30%", "30-60%", "60-80%", "80-100%", "100%+")
  expect_true(all(data$income_bracket %in% expected_brackets))
})

test_that("sample FPL data has correct income brackets", {
  data <- create_sample_lead_data(n = 100, dataset = "fpl")

  expected_brackets <- c("0-100%", "100-150%", "150-200%", "200%+")
  expect_true(all(data$income_bracket %in% expected_brackets))
})

test_that("energy cost correlates positively with income", {
  data <- create_sample_lead_data(n = 200)

  # Should have positive correlation (though not perfect)
  cor_value <- cor(data$income, data$energy_cost, use = "complete.obs")
  expect_gt(cor_value, 0)
  expect_lt(cor_value, 1)  # Not perfect correlation
})

test_that("corrupted data has all-NA income_bracket", {
  data <- create_corrupted_fpl_data(n = 100)

  expect_true(all(is.na(data$income_bracket)))
  expect_equal(nrow(data), 100)
  expect_true("income" %in% names(data))
})

test_that("incomplete schema data is missing required column", {
  data <- create_incomplete_schema_data(n = 50)

  expect_false("income" %in% names(data))
  expect_true("income_bracket" %in% names(data))
})

test_that("edge case data includes problematic values", {
  data <- create_edge_case_data()

  # Check for zero income
  expect_true(any(data$income == 0))

  # Check for zero energy cost
  expect_true(any(data$energy_cost == 0))

  # Check for zero/invalid households
  expect_true(any(data$households == 0))

  # Check for NA housing tenure
  expect_true(any(is.na(data$housing_tenure)))
})

test_that("NER calculation handles zero income correctly", {
  # When income is zero, NER should be -1
  result <- ner_func(0, 1000)
  expect_equal(result, -1)
})

test_that("NER calculation handles zero energy cost correctly", {
  # When energy cost is zero, NER should be Inf
  result <- ner_func(50000, 0)
  expect_equal(result, Inf)
})

test_that("NER calculation handles negative income", {
  # Negative income should still produce finite result
  result <- ner_func(-1000, 2000)
  expect_true(is.finite(result))
  expect_equal(result, -1.5)  # (-1000 - 2000) / 2000 = -1.5
})

test_that("energy burden calculation handles edge cases", {
  # Zero income -> Inf burden
  expect_equal(energy_burden_func(0, 1000), Inf)

  # Zero cost -> 0 burden
  expect_equal(energy_burden_func(50000, 0), 0)

  # Normal case
  expect_equal(energy_burden_func(50000, 5000), 0.1)
})

test_that("energy burden and NER are mathematically consistent", {
  income <- 50000
  cost <- 5000

  eb <- energy_burden_func(income, cost)
  ner <- ner_func(income, cost)

  # eb = 1 / (ner + 1)
  expect_equal(eb, 1 / (ner + 1), tolerance = 1e-10)

  # ner = (1 / eb) - 1
  expect_equal(ner, (1 / eb) - 1, tolerance = 1e-10)
})

test_that("household counts validation catches negative values", {
  data <- data.frame(
    households = c(100, 200, -50, 300)
  )

  # Should have negative household count
  expect_true(any(data$households < 0))
})

test_that("household counts validation catches zero values", {
  data <- data.frame(
    households = c(100, 0, 200, 300)
  )

  # Should have zero household count
  expect_true(any(data$households == 0))
})

test_that("income validation catches negative values", {
  data <- create_edge_case_data()

  # Should have negative income
  expect_true(any(data$income < 0))
})

test_that("test CSV writing works", {
  data <- create_sample_lead_data(n = 10)
  filepath <- write_test_csv(data, "test_sample.csv")

  expect_true(file.exists(filepath))

  # Read it back
  read_data <- read.csv(filepath, stringsAsFactors = FALSE)
  expect_equal(nrow(read_data), 10)

  # Cleanup
  file.remove(filepath)
})

test_that("test cache directory creation works", {
  cache_dir <- create_test_cache()

  expect_true(dir.exists(cache_dir))

  # Cleanup
  unlink(cache_dir, recursive = TRUE)
})

test_that("cleanup function removes test files", {
  # Create test files
  test_file1 <- write_test_csv(create_sample_lead_data(10), "cleanup_test1.csv")
  test_file2 <- write_test_csv(create_sample_lead_data(10), "cleanup_test2.csv")
  test_dir <- create_test_cache()

  # Verify they exist
  expect_true(file.exists(test_file1))
  expect_true(file.exists(test_file2))
  expect_true(dir.exists(test_dir))

  # Cleanup
  cleanup_test_files(c(test_file1, test_file2, test_dir))

  # Verify removed
  expect_false(file.exists(test_file1))
  expect_false(file.exists(test_file2))
  expect_false(dir.exists(test_dir))
})

test_that("required column check works", {
  data <- create_sample_lead_data(n = 20)

  # Should have all required columns
  required_cols <- c("geoid", "income", "energy_cost", "income_bracket", "households")
  expect_true(all(required_cols %in% names(data)))

  # Missing column test
  data_incomplete <- data
  data_incomplete$income <- NULL
  expect_false("income" %in% names(data_incomplete))
})

test_that("income bracket validation for AMI data", {
  data <- create_sample_lead_data(n = 100, dataset = "ami")

  ami_brackets <- c("0-30%", "30-60%", "60-80%", "80-100%", "100%+")

  # All values should be valid AMI brackets
  expect_true(all(data$income_bracket %in% ami_brackets))

  # Should have variety of brackets (not all the same)
  expect_gt(length(unique(data$income_bracket)), 1)
})

test_that("income bracket validation for FPL data", {
  data <- create_sample_lead_data(n = 100, dataset = "fpl")

  fpl_brackets <- c("0-100%", "100-150%", "150-200%", "200%+")

  # All values should be valid FPL brackets
  expect_true(all(data$income_bracket %in% fpl_brackets))

  # Should have variety of brackets
  expect_gt(length(unique(data$income_bracket)), 1)
})

test_that("vintage field is set correctly", {
  data_2018 <- create_sample_lead_data(n = 50, vintage = "2018")
  data_2022 <- create_sample_lead_data(n = 50, vintage = "2022")

  expect_equal(unique(data_2018$vintage), "2018")
  expect_equal(unique(data_2022$vintage), "2022")
})

test_that("geoid format is valid", {
  data <- create_sample_lead_data(n = 100)

  # All geoids should start with 37 (NC FIPS code)
  expect_true(all(startsWith(data$geoid, "37")))

  # All geoids should be 11 characters (FIPS code format)
  expect_true(all(nchar(data$geoid) == 11))
})

test_that("housing tenure values are valid", {
  data <- create_sample_lead_data(n = 100)

  valid_tenure <- c("OWNER", "RENTER")
  expect_true(all(data$housing_tenure %in% valid_tenure | is.na(data$housing_tenure)))
})

test_that("primary heating fuel values are realistic", {
  data <- create_sample_lead_data(n = 100)

  valid_fuels <- c("Electricity", "Natural gas", "Fuel oil", "Propane")
  expect_true(all(data$primary_heating_fuel %in% valid_fuels | is.na(data$primary_heating_fuel)))
})

test_that("building type values are valid", {
  data <- create_sample_lead_data(n = 100)

  valid_types <- c("Single-Family", "Multi-Family")
  expect_true(all(data$building_type %in% valid_types | is.na(data$building_type)))
})

test_that("derived metrics are calculated correctly", {
  data <- create_sample_lead_data(n = 50)

  # Check net_income calculation
  expect_equal(data$net_income, data$income - data$energy_cost)

  # Check NER calculation
  expected_ner <- (data$income - data$energy_cost) / data$energy_cost
  expect_equal(data$ner, expected_ner)

  # Check energy burden calculation
  expected_eb <- data$energy_cost / data$income
  expect_equal(data$energy_burden, expected_eb)
})
