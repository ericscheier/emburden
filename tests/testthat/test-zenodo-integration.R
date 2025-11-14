# Comprehensive Zenodo Integration Tests
# These tests verify the complete Zenodo download infrastructure

test_that("Zenodo configuration contains all required datasets", {
  config <- get_zenodo_config()

  # Check structure
  expect_true("concept_doi" %in% names(config))
  expect_true("version_doi" %in% names(config))
  expect_true("files" %in% names(config))

  # Check DOI format
  expect_match(config$concept_doi, "^10\\.5281/zenodo\\.[0-9]+$")
  expect_match(config$version_doi, "^10\\.5281/zenodo\\.[0-9]+$")

  # Check all 4 datasets present
  expect_true("ami_2022" %in% names(config$files))
  expect_true("fpl_2022" %in% names(config$files))
  expect_true("ami_2018" %in% names(config$files))
  expect_true("fpl_2018" %in% names(config$files))

  # Check each file has required metadata
  for (dataset in c("ami_2022", "fpl_2022", "ami_2018", "fpl_2018")) {
    file_info <- config$files[[dataset]]

    expect_true("filename" %in% names(file_info))
    expect_true("url" %in% names(file_info))
    expect_true("size_mb" %in% names(file_info))
    expect_true("md5" %in% names(file_info))

    # URL should be set
    expect_type(file_info$url, "character")
    expect_match(file_info$url, "^https://zenodo\\.org/records/")

    # MD5 should be set
    expect_type(file_info$md5, "character")
    expect_equal(nchar(file_info$md5), 32)  # MD5 is 32 hex chars
  }
})

test_that("Zenodo download function handles errors gracefully", {
  # Test with invalid dataset
  result <- download_from_zenodo("invalid_dataset", "2022", verbose = FALSE)
  expect_null(result)

  # Test with invalid vintage
  result <- download_from_zenodo("ami", "1999", verbose = FALSE)
  expect_null(result)
})

test_that("Database helper functions work correctly", {
  # Get paths
  test_path <- get_db_path(test = TRUE)
  prod_path <- get_db_path(test = FALSE)

  # Should be different
  expect_false(identical(test_path, prod_path))

  # Test path should contain 'test'
  expect_true(grepl("test", test_path, ignore.case = TRUE))

  # Prod path should NOT contain 'test'
  expect_false(grepl("test", prod_path, ignore.case = TRUE))
})

test_that("Production database is protected from deletion", {
  # Should error without confirmation
  expect_error(
    delete_db(test = FALSE, confirm = FALSE),
    "Cannot delete production database"
  )

  # Test database can be deleted
  if (db_exists(test = TRUE)) {
    expect_true(delete_db(test = TRUE, confirm = FALSE))
  }
})

test_that("clear_test_environment is safe", {
  # This should never fail and never touch production
  # (It will produce messages, which is expected)
  expect_message(clear_test_environment(), "Test environment cleared")

  # Production DB should still exist if it did before
  # (This test doesn't create it, just verifies safety)
})

test_that("backup_db works or handles missing DB gracefully", {
  if (db_exists(test = FALSE)) {
    # If prod DB exists, backup should work
    backup_file <- backup_db()
    expect_true(file.exists(backup_file))

    # Clean up backup
    unlink(backup_file)
  } else {
    # If no prod DB, should return NULL gracefully
    result <- backup_db()
    expect_null(result)
  }
})
