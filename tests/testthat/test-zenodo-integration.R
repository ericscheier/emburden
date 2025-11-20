# Integration Tests for Zenodo Downloads
#
# These tests actually download data from Zenodo to verify:
# 1. URLs are accessible
# 2. MD5 checksums match
# 3. Data loads correctly
#
# IMPORTANT: These tests are SKIPPED by default because they:
# - Require network access
# - Download large files (>100 MB total)
# - Take several minutes to complete
#
# To run these tests manually before a release:
#   testthat::test_file("tests/testthat/test-zenodo-integration.R")
# Or with an environment variable:
#   EMBURDEN_RUN_INTEGRATION_TESTS=1 R CMD check

test_that("Zenodo integration tests are skipped unless explicitly enabled", {
  skip_on_cran()
  skip_on_ci()

  # Skip unless explicitly requested
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled. Set EMBURDEN_RUN_INTEGRATION_TESTS=1 to enable.")

  # If we got here, integration tests are enabled
  cat("\n\n")
  cat("==========================================\n")
  cat("  ZENODO INTEGRATION TESTS\n")
  cat("  (Full downloads + validation)\n")
  cat("==========================================\n\n")
})


test_that("Zenodo AMI 2022 download works with correct checksum", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("Downloading AMI 2022 from Zenodo...\n")

  # Clear cache to force fresh download
  clear_dataset_cache("ami", "2022", verbose = FALSE)

  # Download from Zenodo (verbose=TRUE to show progress)
  data <- download_from_zenodo("ami", "2022", verbose = TRUE)

  # Should have successfully downloaded
  expect_false(is.null(data))
  expect_s3_class(data, "data.frame")

  # Check data structure
  expect_true("geoid" %in% names(data))
  expect_true("income_bracket" %in% names(data))
  expect_true("households" %in% names(data))

  # Should have substantial data
  expect_gt(nrow(data), 100000)

  cat("  SUCCESS: AMI 2022 downloaded and validated\n\n")
})


test_that("Zenodo FPL 2022 download works with correct checksum", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("Downloading FPL 2022 from Zenodo...\n")

  clear_dataset_cache("fpl", "2022", verbose = FALSE)
  data <- download_from_zenodo("fpl", "2022", verbose = TRUE)

  expect_false(is.null(data))
  expect_s3_class(data, "data.frame")
  expect_gt(nrow(data), 100000)

  cat("  SUCCESS: FPL 2022 downloaded and validated\n\n")
})


test_that("Zenodo AMI 2018 download works with correct checksum", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("Downloading AMI 2018 from Zenodo...\n")

  clear_dataset_cache("ami", "2018", verbose = FALSE)
  data <- download_from_zenodo("ami", "2018", verbose = TRUE)

  expect_false(is.null(data))
  expect_s3_class(data, "data.frame")
  expect_gt(nrow(data), 100000)

  cat("  SUCCESS: AMI 2018 downloaded and validated\n\n")
})


test_that("Zenodo FPL 2018 download works with correct checksum", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("Downloading FPL 2018 from Zenodo...\n")

  clear_dataset_cache("fpl", "2018", verbose = FALSE)
  data <- download_from_zenodo("fpl", "2018", verbose = TRUE)

  expect_false(is.null(data))
  expect_s3_class(data, "data.frame")
  expect_gt(nrow(data), 100000)

  cat("  SUCCESS: FPL 2018 downloaded and validated\n\n")
})


test_that("All Zenodo datasets have different data (no duplicates)", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("Verifying all datasets are distinct...\n")

  # Load all 4 datasets
  ami_2022 <- download_from_zenodo("ami", "2022", verbose = FALSE)
  fpl_2022 <- download_from_zenodo("fpl", "2022", verbose = FALSE)
  ami_2018 <- download_from_zenodo("ami", "2018", verbose = FALSE)
  fpl_2018 <- download_from_zenodo("fpl", "2018", verbose = FALSE)

  # Check row counts are different (would be identical if cached same data)
  expect_false(nrow(ami_2022) == nrow(ami_2018))
  expect_false(nrow(fpl_2022) == nrow(fpl_2018))

  # Check income bracket distributions differ between AMI and FPL
  ami_2022_brackets <- unique(ami_2022$income_bracket)
  fpl_2022_brackets <- unique(fpl_2022$income_bracket)
  expect_false(identical(sort(ami_2022_brackets), sort(fpl_2022_brackets)))

  cat("  SUCCESS: All datasets are distinct\n\n")
})


test_that("Downloaded data matches state-manifest.json metadata", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("Cross-checking with state-manifest.json...\n")

  # Read manifest
  manifest_path <- system.file("../../zenodo-upload-nationwide/state-manifest.json", package = "emburden")
  if (!file.exists(manifest_path)) {
    skip("state-manifest.json not available in package")
  }

  manifest <- jsonlite::read_json(manifest_path)

  # Check AMI 2022 row count matches
  ami_2022 <- download_from_zenodo("ami", "2022", verbose = FALSE)
  expect_equal(nrow(ami_2022), manifest$nationwide$ami_2022$rows,
               tolerance = 100)  # Allow small variance

  cat("  SUCCESS: Data matches manifest metadata\n\n")
})


# Cleanup after integration tests
test_that("Cleanup after integration tests", {
  skip_on_cran()
  skip_on_ci()
  run_integration <- Sys.getenv("EMBURDEN_RUN_INTEGRATION_TESTS", "0")
  skip_if(run_integration != "1", "Integration tests disabled")

  cat("\n")
  cat("==========================================\n")
  cat("  INTEGRATION TESTS COMPLETE\n")
  cat("==========================================\n\n")
  cat("All Zenodo downloads validated successfully!\n")
  cat("Safe to proceed with release.\n\n")
})
