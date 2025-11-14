# Tests for Metadata Functions

test_that("list_states returns correct number of states", {
  states <- list_states()

  expect_type(states, "character")
  expect_length(states, 51)  # 50 states + DC
})

test_that("list_states returns expected state abbreviations", {
  states <- list_states()

  # Check key states are included
  expect_true("NC" %in% states)
  expect_true("CA" %in% states)
  expect_true("TX" %in% states)
  expect_true("DC" %in% states)

  # Check PR is NOT included (as per documentation)
  expect_false("PR" %in% states)

  # All should be 2-character uppercase
  expect_true(all(nchar(states) == 2))
  expect_true(all(states == toupper(states)))
})

test_that("list_states has no duplicates", {
  states <- list_states()
  expect_equal(length(states), length(unique(states)))
})


# list_income_brackets tests -----

test_that("list_income_brackets works for all dataset/vintage combinations", {
  # AMI 2022
  ami_2022 <- list_income_brackets("ami", "2022")
  expect_type(ami_2022, "character")
  expect_length(ami_2022, 6)
  expect_true("0-30% AMI" %in% ami_2022)
  expect_true("120%+ AMI" %in% ami_2022)

  # AMI 2018
  ami_2018 <- list_income_brackets("ami", "2018")
  expect_type(ami_2018, "character")
  expect_length(ami_2018, 4)
  expect_true("very_low" %in% ami_2018)
  expect_true("above_mod" %in% ami_2018)

  # FPL 2022
  fpl_2022 <- list_income_brackets("fpl", "2022")
  expect_type(fpl_2022, "character")
  expect_length(fpl_2022, 5)
  expect_true("0-100%" %in% fpl_2022)
  expect_true("400%+" %in% fpl_2022)

  # FPL 2018
  fpl_2018 <- list_income_brackets("fpl", "2018")
  expect_type(fpl_2018, "character")
  expect_length(fpl_2018, 4)
  expect_true("0-100%" %in% fpl_2018)
  expect_true("200%+" %in% fpl_2018)
})

test_that("list_income_brackets validates input", {
  expect_error(
    list_income_brackets("ami", "2020"),
    "vintage must be '2018' or '2022'"
  )

  expect_error(
    list_income_brackets("invalid", "2022"),
    "'arg' should be one of"
  )
})

test_that("list_income_brackets defaults to 2022", {
  result <- list_income_brackets("ami")
  expect_equal(result, list_income_brackets("ami", "2022"))
})


# list_cohort_columns tests -----

test_that("list_cohort_columns returns data frame with correct structure", {
  cols <- list_cohort_columns()

  expect_s3_class(cols, "data.frame")
  expect_named(cols, c("column_name", "description", "data_type"))
  expect_true(nrow(cols) >= 7)  # At least core columns
})

test_that("list_cohort_columns includes core columns", {
  cols <- list_cohort_columns()

  core_columns <- c(
    "geoid",
    "income_bracket",
    "households",
    "total_income",
    "total_electricity_spend",
    "total_gas_spend",
    "total_other_spend"
  )

  expect_true(all(core_columns %in% cols$column_name))
})

test_that("list_cohort_columns data types are valid", {
  cols <- list_cohort_columns()

  valid_types <- c("character", "numeric", "integer", "logical")
  expect_true(all(cols$data_type %in% valid_types))
})


# get_dataset_info tests -----

test_that("get_dataset_info returns correct structure", {
  info <- get_dataset_info()

  expect_s3_class(info, "data.frame")
  expect_named(info, c(
    "dataset", "vintage", "full_name",
    "income_brackets", "states_available",
    "census_tracts", "source_url"
  ))
  expect_equal(nrow(info), 4)  # 2 datasets x 2 vintages
})

test_that("get_dataset_info has correct dataset combinations", {
  info <- get_dataset_info()

  # Should have all 4 combinations
  combos <- paste(info$dataset, info$vintage)
  expect_true("ami 2018" %in% combos)
  expect_true("ami 2022" %in% combos)
  expect_true("fpl 2018" %in% combos)
  expect_true("fpl 2022" %in% combos)
})

test_that("get_dataset_info has valid URLs", {
  info <- get_dataset_info()

  expect_true(all(grepl("^https://", info$source_url)))
  expect_true(all(grepl("openei.org", info$source_url)))
})

test_that("get_dataset_info shows 51 states available", {
  info <- get_dataset_info()

  expect_true(all(info$states_available == 51))
})

test_that("get_dataset_info income brackets match list_income_brackets", {
  info <- get_dataset_info()

  # Check each row
  for (i in 1:nrow(info)) {
    dataset <- info$dataset[i]
    vintage <- info$vintage[i]
    expected_count <- length(list_income_brackets(dataset, vintage))

    expect_equal(
      info$income_brackets[i],
      expected_count,
      info = paste("Mismatch for", dataset, vintage)
    )
  }
})
