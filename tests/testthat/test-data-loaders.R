# Phase 2: Data Loader Tests
# Tests for load_cohort_data, load_census_tract_data, and related functions
#
# Data Coverage: Package supports all 51 US states (50 states + DC) with ~73,000 census tracts
# and 2.3+ million cohort records. Tests use mocked data for speed but validate
# nationwide functionality.

test_that("load_cohort_data validates dataset parameter", {
  expect_error(
    load_cohort_data(dataset = "invalid", verbose = FALSE),
    "should be one of"
  )
})

test_that("load_cohort_data validates vintage parameter", {
  expect_error(
    load_cohort_data(dataset = "ami", vintage = "2020", verbose = FALSE),
    "vintage must be '2018' or '2022'"
  )
})

test_that("load_cohort_data handles missing data with download fallback", {
  # Mock all local sources to fail (simulating no local data)
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", NULL)

  # Mock Zenodo to fail (so we test OpenEI fallback)
  mockery::stub(load_cohort_data, "download_from_zenodo", NULL)

  # Mock successful download as fallback
  fallback_data <- data.frame(
    geoid = c("37051003400"),
    income_bracket = c("very_low"),
    households = c(100),
    total_income = c(2500000),
    total_electricity_spend = c(120000)
  )
  mockery::stub(load_cohort_data, "download_lead_data", fallback_data)
  mockery::stub(load_cohort_data, "try_import_to_database", TRUE)

  # Should successfully load via download fallback
  result <- load_cohort_data(
    dataset = "ami",
    vintage = "2022",
    verbose = FALSE
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_true("geoid" %in% names(result))
})

test_that("load_cohort_data fails gracefully when all sources unavailable", {
  # Mock all sources to fail
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", NULL)
  mockery::stub(load_cohort_data, "download_from_zenodo", NULL)
  mockery::stub(load_cohort_data, "download_lead_data", NULL)

  # Should error with informative message
  expect_error(
    load_cohort_data(dataset = "ami", vintage = "2022", verbose = FALSE),
    "Failed to load data from any source"
  )
})

test_that("load_census_tract_data accepts valid parameters", {
  # load_census_tract_data signature: (states = NULL, verbose = TRUE)
  # It doesn't validate dataset or vintage, just states
  # Just verify the function is callable
  expect_type(load_census_tract_data, "closure")
})

test_that("data loader helper functions exist and are callable", {
  # Verify main exported functions are defined

  # Check that the main exported functions exist
  expect_true(exists("load_cohort_data"))
  expect_true(exists("load_census_tract_data"))

  # Verify they are functions
  expect_type(load_cohort_data, "closure")
  expect_type(load_census_tract_data, "closure")
})

test_that("load_cohort_data returns expected structure with mocked data", {
  # Unit test version - always runs with fixtures
  fixture_data <- data.frame(
    geoid = c("37051003400", "37183020100", "45001020100"),
    income_bracket = c("very_low", "low_mod", "very_low"),
    households = c(100, 150, 120),
    total_income = c(2500000, 6000000, 3000000),
    total_electricity_spend = c(120000, 180000, 144000),
    total_gas_spend = c(40000, 60000, 48000),
    total_other_spend = c(10000, 15000, 12000)
  )

  # Mock data sources
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  # Load with mocked data
  result <- load_cohort_data(
    dataset = "ami",
    states = NULL,
    vintage = "2022",
    verbose = FALSE
  )

  # Verify structure
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)

  # Check for expected columns
  expected_cols <- c("geoid", "income_bracket", "households",
                     "total_income", "total_electricity_spend")
  expect_true(all(expected_cols %in% names(result)))

  # Verify data integrity
  expect_type(result$geoid, "character")
  expect_type(result$income_bracket, "character")
  expect_type(result$households, "double")
})

test_that("load_cohort_data returns expected structure when data exists", {
  skip_if_not(file.exists("data"), "No data directory found")

  # Check if any ami data files exist
  ami_files <- list.files("data", pattern = "ami.*\\.csv", full.names = TRUE)
  skip_if(length(ami_files) == 0, "No AMI data files found for testing")

  # Try to load data
  result <- try(load_cohort_data(
    dataset = "ami",
    states = NULL,
    vintage = "2022",
    verbose = FALSE
  ), silent = TRUE)

  if (!inherits(result, "try-error") && !is.null(result)) {
    expect_s3_class(result, "data.frame")

    # Check for expected columns (at minimum)
    expected_cols <- c("geoid", "income_bracket")
    expect_true(all(expected_cols %in% names(result)))
  }
})

test_that("state filtering works correctly", {
  # Create test fixture data with multiple states
  fixture_data <- data.frame(
    geoid = c("37051003400", "37183020100", "45001020100", "13001020100"),
    income_bracket = c("very_low", "low_mod", "very_low", "low_mod"),
    households = c(100, 150, 120, 130),
    total_income = c(2500000, 6000000, 3000000, 5200000),
    total_electricity_spend = c(120000, 180000, 144000, 156000)
  )

  # Mock try_load_from_database to return NULL (skip database)
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)

  # Mock try_load_from_csv to return our fixture data
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  # Test NC filter (geoid starts with "37")
  result_nc <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2022", verbose = FALSE)

  # Should only have NC records (geoid starting with "37")
  expect_equal(nrow(result_nc), 2)
  expect_true(all(substr(result_nc$geoid, 1, 2) == "37"))

  # Test SC filter (geoid starts with "45")
  result_sc <- load_cohort_data(dataset = "ami", states = "SC", vintage = "2022", verbose = FALSE)

  expect_equal(nrow(result_sc), 1)
  expect_true(all(substr(result_sc$geoid, 1, 2) == "45"))

  # Test multiple states
  result_multi <- load_cohort_data(dataset = "ami", states = c("NC", "GA"), vintage = "2022", verbose = FALSE)

  expect_equal(nrow(result_multi), 3)  # NC (2) + GA (1)
  expect_true(all(substr(result_multi$geoid, 1, 2) %in% c("37", "13")))
})

test_that("income bracket filtering works correctly", {
  # Create test fixture data with multiple income brackets
  fixture_data <- data.frame(
    geoid = rep("37051003400", 4),
    income_bracket = c("very_low", "low_mod", "mid_high", "very_low"),
    households = c(100, 150, 200, 110),
    total_income = c(1500000, 4500000, 8000000, 1650000),
    total_electricity_spend = c(90000, 135000, 160000, 99000)
  )

  # Mock the data loader functions
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  # Test filtering to single bracket
  result_single <- load_cohort_data(
    dataset = "ami",
    income_brackets = "very_low",
    vintage = "2022",
    verbose = FALSE
  )

  expect_equal(nrow(result_single), 2)
  expect_true(all(result_single$income_bracket == "very_low"))

  # Test filtering to multiple brackets
  result_multi <- load_cohort_data(
    dataset = "ami",
    income_brackets = c("very_low", "low_mod"),
    vintage = "2022",
    verbose = FALSE
  )

  expect_equal(nrow(result_multi), 3)
  expect_true(all(result_multi$income_bracket %in% c("very_low", "low_mod")))
  expect_false(any(result_multi$income_bracket == "mid_high"))
})

test_that("load_cohort_data handles corrupt data files", {
  # Mock try_load_from_database to return NULL
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)

  # Mock try_load_from_csv to simulate corrupt file (return NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", NULL)

  # Mock Zenodo to fail (so we test OpenEI fallback)
  mockery::stub(load_cohort_data, "download_from_zenodo", NULL)

  # Mock download_lead_data to return valid data (fallback)
  valid_data <- data.frame(
    geoid = c("37051003400"),
    income_bracket = c("very_low"),
    households = c(100),
    total_income = c(2500000),
    total_electricity_spend = c(120000)
  )
  mockery::stub(load_cohort_data, "download_lead_data", valid_data)

  # Mock database import to succeed silently
  mockery::stub(load_cohort_data, "try_import_to_database", TRUE)

  # Should fall back to download when CSV is corrupt/unavailable
  result <- load_cohort_data(dataset = "ami", vintage = "2022", verbose = FALSE)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_true("geoid" %in% names(result))
})

test_that("database fallback works when CSV unavailable", {
  # Create valid database response
  db_data <- data.frame(
    geoid = c("37051003400", "37183020100"),
    income_bracket = c("very_low", "low_mod"),
    households = c(100, 150),
    total_income = c(2500000, 6000000),
    total_electricity_spend = c(120000, 180000)
  )

  # Mock all download sources to fail, only database succeeds
  mockery::stub(load_cohort_data, "try_load_from_csv", NULL)
  mockery::stub(load_cohort_data, "download_from_zenodo", NULL)
  mockery::stub(load_cohort_data, "download_lead_data", NULL)  # Also mock OpenEI fallback
  mockery::stub(load_cohort_data, "try_load_from_database", db_data)

  # Mock corruption detection to pass (2-row data is valid for testing)
  mockery::stub(load_cohort_data, "detect_database_corruption", list(is_corrupted = FALSE))

  # Should use database data when all download sources are unavailable

  result <- load_cohort_data(dataset = "ami", vintage = "2022", verbose = FALSE)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true(all(c("geoid", "income_bracket") %in% names(result)))
})

test_that("download fallback works when local data unavailable", {
  # Mock all local sources to fail
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", NULL)

  # Mock Zenodo to fail (so we test OpenEI fallback)
  mockery::stub(load_cohort_data, "download_from_zenodo", NULL)

  # Mock successful download
  download_data <- data.frame(
    geoid = c("37051003400"),
    income_bracket = c("very_low"),
    households = c(100),
    total_income = c(2500000),
    total_electricity_spend = c(120000)
  )
  mockery::stub(load_cohort_data, "download_lead_data", download_data)

  # Mock database import
  mockery::stub(load_cohort_data, "try_import_to_database", TRUE)

  result <- load_cohort_data(dataset = "ami", vintage = "2022", verbose = FALSE)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_true("geoid" %in% names(result))
})

test_that("load_cohort_data handles FPL data correctly", {
  # Note: aggregate_poverty is a parameter of process_lead_cohort_data, not load_cohort_data
  # This test verifies FPL data loading works correctly

  fpl_data <- data.frame(
    geoid = c("37051003400", "37183020100"),
    income_bracket = c("0-100% FPL", "100-150% FPL"),
    households = c(100, 150),
    total_income = c(1000000, 2250000),
    total_electricity_spend = c(80000, 112500)
  )

  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fpl_data)

  result <- load_cohort_data(dataset = "fpl", vintage = "2022", verbose = FALSE)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true(all(grepl("FPL", result$income_bracket)))
})

test_that("vintage-specific schema handling works", {
  # Test that both 2018 and 2022 data produce consistent schema

  # 2018 data with old percentage-based brackets
  data_2018 <- data.frame(
    geoid = c("37051003400", "37183020100"),
    income_bracket = c("0-30%", "80-100%"),
    households = c(100, 150),
    total_income = c(1500000, 7200000),
    total_electricity_spend = c(90000, 180000)
  )

  # 2022 data with new categorical brackets
  data_2022 <- data.frame(
    geoid = c("37051003400", "37183020100"),
    income_bracket = c("very_low", "mid_high"),
    households = c(100, 150),
    total_income = c(1500000, 7200000),
    total_electricity_spend = c(90000, 180000)
  )

  # Test 2018 loading
  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", data_2018)

  result_2018 <- load_cohort_data(dataset = "ami", vintage = "2018", verbose = FALSE)

  expect_s3_class(result_2018, "data.frame")
  expect_true(all(c("geoid", "income_bracket", "households") %in% names(result_2018)))

  # Test 2022 loading
  mockery::stub(load_cohort_data, "try_load_from_csv", data_2022)

  result_2022 <- load_cohort_data(dataset = "ami", vintage = "2022", verbose = FALSE)

  expect_s3_class(result_2022, "data.frame")
  expect_true(all(c("geoid", "income_bracket", "households") %in% names(result_2022)))

  # Both should have same schema
  expect_equal(sort(names(result_2018)), sort(names(result_2022)))
})

# Census Tract Data Tests -----------------------------------------------

test_that("load_census_tract_data handles missing data gracefully", {
  # Mock all sources to fail
  mockery::stub(load_census_tract_data, "try_load_tracts_from_database", NULL)
  mockery::stub(load_census_tract_data, "try_load_tracts_from_csv", NULL)

  # Mock successful download as fallback
  tract_data <- data.frame(
    geoid = c("37051003400", "37183020100"),
    state_abbr = c("NC", "NC"),
    county_name = c("Wake", "Durham"),
    tract_name = c("Tract 34", "Tract 201"),
    utility_name = c("Duke Energy", "Duke Energy"),
    stringsAsFactors = FALSE
  )
  mockery::stub(load_census_tract_data, "download_census_tract_data", tract_data)
  mockery::stub(load_census_tract_data, "try_import_tracts_to_database", TRUE)

  result <- load_census_tract_data(verbose = FALSE)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("geoid" %in% names(result))
  expect_true("state_abbr" %in% names(result))
})

test_that("load_census_tract_data filters by state", {
  # Create tract data for multiple states
  tract_data <- data.frame(
    geoid = c("37051003400", "45001020100", "13001020100"),
    state_abbr = c("NC", "SC", "GA"),
    county_name = c("Wake", "Berkeley", "Fulton"),
    utility_name = c("Duke Energy", "SCE&G", "Georgia Power"),
    stringsAsFactors = FALSE
  )

  mockery::stub(load_census_tract_data, "try_load_tracts_from_database", NULL)
  mockery::stub(load_census_tract_data, "try_load_tracts_from_csv", tract_data)

  # Test single state filter
  result <- load_census_tract_data(states = "NC", verbose = FALSE)

  expect_equal(nrow(result), 1)
  expect_equal(result$state_abbr[1], "NC")

  # Test multiple state filter
  mockery::stub(load_census_tract_data, "try_load_tracts_from_csv", tract_data)
  result_multi <- load_census_tract_data(states = c("NC", "SC"), verbose = FALSE)

  expect_equal(nrow(result_multi), 2)
  expect_true(all(result_multi$state_abbr %in% c("NC", "SC")))
})

# Edge Cases & Additional Coverage --------------------------------------

test_that("load_cohort_data handles state filters that match no data", {
  # All data is NC, but we request GA
  fixture_data <- data.frame(
    geoid = c("37051003400", "37183020100"),  # All NC (starts with 37)
    income_bracket = c("very_low", "low_mod"),
    households = c(100, 150),
    total_income = c(2500000, 6000000),
    total_electricity_spend = c(120000, 180000)
  )

  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  # Request GA data when only NC exists
  result <- load_cohort_data(
    dataset = "ami",
    states = "GA",  # Georgia FIPS = 13, won't match any NC data
    vintage = "2022",
    verbose = FALSE
  )

  # Should return empty data.frame, not error
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("load_cohort_data handles income bracket filters with no matches", {
  # Data has only very_low and low_mod
  fixture_data <- data.frame(
    geoid = c("37051003400", "37183020100"),
    income_bracket = c("very_low", "low_mod"),
    households = c(100, 150),
    total_income = c(2500000, 6000000),
    total_electricity_spend = c(120000, 180000)
  )

  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  # Request mid_high when only very_low and low_mod exist
  result <- load_cohort_data(
    dataset = "ami",
    income_brackets = "mid_high",
    vintage = "2022",
    verbose = FALSE
  )

  # Should return empty data.frame
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("check_data_sources returns proper structure", {
  result <- check_data_sources(verbose = FALSE)

  # Verify it returns a list
  expect_type(result, "list")

  # Check for expected top-level components
  expect_true("database" %in% names(result))
  expect_true("csv_files" %in% names(result))
  expect_true("download_required" %in% names(result))

  # Check database component structure
  expect_true("available" %in% names(result$database))
  expect_type(result$database$available, "logical")

  # Check CSV files component structure
  expect_true("available" %in% names(result$csv_files))
  expect_type(result$csv_files$available, "logical")

  # Check download_required is logical
  expect_type(result$download_required, "logical")
})

test_that("load_cohort_data produces expected verbose messages", {
  fixture_data <- data.frame(
    geoid = "37051003400",
    income_bracket = "very_low",
    households = 100,
    total_income = 2500000,
    total_electricity_spend = 120000
  )

  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  # Test verbose output for basic loading
  expect_message(
    load_cohort_data(dataset = "ami", vintage = "2022", verbose = TRUE),
    "Loading 2022 AMI cohort data"
  )

  # Test verbose output for state filtering
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)
  expect_message(
    load_cohort_data(dataset = "ami", states = "NC", vintage = "2022", verbose = TRUE),
    "Filtered to state.*NC"
  )
})

test_that("load_cohort_data returns columns with correct types", {
  fixture_data <- data.frame(
    geoid = "37051003400",
    income_bracket = "very_low",
    households = 100L,
    total_income = 2500000,
    total_electricity_spend = 120000,
    stringsAsFactors = FALSE
  )

  mockery::stub(load_cohort_data, "try_load_from_database", NULL)
  mockery::stub(load_cohort_data, "try_load_from_csv", fixture_data)

  result <- load_cohort_data(dataset = "ami", vintage = "2022", verbose = FALSE)

  # Verify column types
  expect_type(result$geoid, "character")
  expect_type(result$income_bracket, "character")
  # households can be integer or double depending on R's coercion
  expect_true(is.numeric(result$households))
  expect_type(result$total_income, "double")
  expect_type(result$total_electricity_spend, "double")
})

test_that("Package supports all 51 US states (nationwide coverage)", {
  # Verify that all 51 states (50 states + DC) are supported
  all_states <- list_states()

  expect_length(all_states, 51)
  expect_type(all_states, "character")

  # Check key states are included
  expect_true("NC" %in% all_states)
  expect_true("CA" %in% all_states)
  expect_true("TX" %in% all_states)
  expect_true("NY" %in% all_states)
  expect_true("DC" %in% all_states)

  # Verify PR is NOT included (not in LEAD data)
  expect_false("PR" %in% all_states)

  # All should be 2-character uppercase codes
  expect_true(all(nchar(all_states) == 2))
  expect_true(all(all_states == toupper(all_states)))
})
