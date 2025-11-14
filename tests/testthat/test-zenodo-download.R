# Test Zenodo Download Functionality
#
# These tests verify that Zenodo downloads work correctly WITHOUT
# touching the production database.

test_that("Zenodo configuration is valid", {
  config <- get_zenodo_config()

  # Check DOIs are configured
  expect_type(config$concept_doi, "character")
  expect_type(config$version_doi, "character")
  expect_true(grepl("^10\\.5281/zenodo\\.", config$concept_doi))

  # Check file configurations
  expect_true("ami_2022" %in% names(config$files))
  expect_true("fpl_2022" %in% names(config$files))
  expect_true("ami_2018" %in% names(config$files))
  expect_true("fpl_2018" %in% names(config$files))

  # Check file URLs are set
  expect_type(config$files$ami_2022$url, "character")
  expect_true(grepl("^https://zenodo\\.org/records/", config$files$ami_2022$url))
})

test_that("Zenodo URLs are accessible", {
  skip_on_cran()
  skip_if_offline()

  config <- get_zenodo_config()

  # Test one file URL is reachable
  url <- config$files$ami_2022$url

  # Just check HTTP status (don't download full file)
  response <- httr::HEAD(url)
  expect_equal(httr::status_code(response), 200)
})

test_that("Can download from Zenodo (test environment)", {
  skip_on_cran()
  skip_if_offline()
  skip("Manual test only - requires clean test environment")

  # This test should be run manually to verify Zenodo downloads
  # It uses a SEPARATE test database, never touching production

  # Clear test environment (safe - only touches test DB)
  withr::defer(clear_test_environment())

  # TODO: Implement test-specific data loading that uses test DB
  # data <- load_cohort_data_test('ami', 'NC', '2022')
  # expect_gt(nrow(data), 0)
})

test_that("Database protection prevents accidental deletion", {
  # Trying to delete production DB without confirmation should fail
  expect_error(
    delete_db(test = FALSE, confirm = FALSE),
    "Cannot delete production database"
  )

  # Test DB can be deleted safely
  test_db <- get_db_path(test = TRUE)
  if (file.exists(test_db)) {
    expect_true(delete_db(test = TRUE))
  }
})

test_that("Test and production databases are separate", {
  test_path <- get_db_path(test = TRUE)
  prod_path <- get_db_path(test = FALSE)

  # Paths must be different
  expect_false(test_path == prod_path)

  # Test DB should have 'test' in name
  expect_true(grepl("test", basename(test_path)))

  # Production DB should NOT have 'test' in name
  expect_false(grepl("test", basename(prod_path)))
})
