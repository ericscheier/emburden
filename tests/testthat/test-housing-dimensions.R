# Tests for Housing Dimension Preservation Feature
# Tests that TEN, TEN-YBL6, TEN-BLD, and TEN-HFL columns are preserved
# during cohort data aggregation

library(testthat)

# Global variables to avoid R CMD check notes
geoid <- income_bracket <- TEN <- `TEN-YBL6` <- `TEN-BLD` <- `TEN-HFL` <- NULL
UNITS <- `HINCP.UNITS` <- `ELEP.UNITS` <- `GASP.UNITS` <- `FULP.UNITS` <- NULL


# Helper: Create test data with housing dimensions
create_housing_dimension_data <- function(n = 100, include_housing_cols = TRUE) {
  set.seed(42)

  data <- data.frame(
    FIP = rep(c("37001", "37003", "37005"), length.out = n),
    AMI = sample(c("very_low", "low_mod", "mid_high"), n, replace = TRUE),
    UNITS = rpois(n, 10),
    `HINCP.UNITS` = rpois(n, 500000),
    `ELEP.UNITS` = rpois(n, 1200),
    `GASP.UNITS` = rpois(n, 800),
    `FULP.UNITS` = rpois(n, 400),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  if (include_housing_cols) {
    data$TEN <- sample(c("1", "2", "3", "4"), n, replace = TRUE)
    data$`TEN-YBL6` <- sample(c("1-1", "1-2", "2-1", "2-2"), n, replace = TRUE)
    data$`TEN-BLD` <- sample(c("1-A", "1-B", "2-A", "2-B"), n, replace = TRUE)
    data$`TEN-HFL` <- sample(c("1-H1", "1-H2", "2-H1", "2-H2"), n, replace = TRUE)
  }

  return(data)
}


# ============================================================================
# TEST SUITE: Housing Dimension Column Preservation
# ============================================================================

test_that("aggregate_cohort_data preserves all housing dimension columns", {
  # Setup
  data <- create_housing_dimension_data(n = 200)

  # Execute - call internal function
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify all housing columns are present
  expect_true("TEN" %in% names(result))
  expect_true("TEN-YBL6" %in% names(result))
  expect_true("TEN-BLD" %in% names(result))
  expect_true("TEN-HFL" %in% names(result))
})


test_that("aggregate_cohort_data groups by housing dimensions", {
  # Setup - create data with known pattern
  data <- data.frame(
    FIP = rep("37001", 4),
    AMI = rep("low_mod", 4),
    TEN = c("1", "1", "2", "2"),
    `TEN-YBL6` = c("1-1", "1-1", "2-1", "2-1"),
    `TEN-BLD` = c("1-A", "1-A", "2-A", "2-A"),
    `TEN-HFL` = c("1-H1", "1-H1", "2-H1", "2-H1"),
    UNITS = c(10, 15, 20, 25),
    `HINCP.UNITS` = c(100, 150, 200, 250),
    `ELEP.UNITS` = c(50, 75, 100, 125),
    `GASP.UNITS` = c(30, 45, 60, 75),
    `FULP.UNITS` = c(20, 30, 40, 50),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify - should result in 2 rows (one for each TEN value)
  # because all other housing dimensions align with TEN
  expect_equal(nrow(result), 2)
  expect_equal(sum(result$UNITS), 70)  # 10+15+20+25

  # Check that distinct housing dimension combinations are preserved
  expect_setequal(result$TEN, c("1", "2"))
})


test_that("housing dimensions create separate aggregation groups", {
  # Setup - same FIP and income, but different housing dimensions
  data <- data.frame(
    FIP = rep("37001", 3),
    AMI = rep("low_mod", 3),
    TEN = c("1", "1", "1"),  # Same tenure
    `TEN-HFL` = c("1-H1", "1-H2", "1-H3"),  # Different heating fuel
    UNITS = c(100, 200, 300),
    `HINCP.UNITS` = c(1000, 2000, 3000),
    `ELEP.UNITS` = c(500, 1000, 1500),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify - should result in 3 rows (one per heating fuel)
  expect_equal(nrow(result), 3)
  expect_setequal(result$`TEN-HFL`, c("1-H1", "1-H2", "1-H3"))
})


test_that("aggregation sums correctly when grouped by housing dimensions", {
  # Setup
  data <- data.frame(
    FIP = rep("37001", 4),
    AMI = rep("very_low", 4),
    TEN = c("1", "1", "2", "2"),
    `TEN-HFL` = c("1-H1", "1-H1", "2-H1", "2-H1"),
    UNITS = c(10, 20, 30, 40),
    `HINCP.UNITS` = c(100, 200, 300, 400),
    `ELEP.UNITS` = c(50, 100, 150, 200),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify - two groups: TEN=1 and TEN=2
  expect_equal(nrow(result), 2)

  ten1_row <- result[result$TEN == "1", ]
  expect_equal(ten1_row$UNITS, 30)  # 10 + 20
  expect_equal(ten1_row$`HINCP.UNITS`, 300)  # 100 + 200
  expect_equal(ten1_row$`ELEP.UNITS`, 150)  # 50 + 100

  ten2_row <- result[result$TEN == "2", ]
  expect_equal(ten2_row$UNITS, 70)  # 30 + 40
  expect_equal(ten2_row$`HINCP.UNITS`, 700)  # 300 + 400
  expect_equal(ten2_row$`ELEP.UNITS`, 350)  # 150 + 200
})


test_that("backward compatibility: works without housing dimension columns", {
  # Setup - data without housing dimensions
  data <- create_housing_dimension_data(n = 100, include_housing_cols = FALSE)

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify - should still work, just without housing columns
  expect_false("TEN" %in% names(result))
  expect_false("TEN-YBL6" %in% names(result))
  expect_false("TEN-BLD" %in% names(result))
  expect_false("TEN-HFL" %in% names(result))

  # Should still have aggregation columns
  expect_true("UNITS" %in% names(result))
  expect_true("FIP" %in% names(result))
  expect_true("AMI" %in% names(result))
})


test_that("partial housing columns: some present, some missing", {
  # Setup - only TEN and TEN-HFL present
  data <- data.frame(
    FIP = rep("37001", 4),
    AMI = rep("low_mod", 4),
    TEN = c("1", "1", "2", "2"),
    `TEN-HFL` = c("1-H1", "1-H1", "2-H1", "2-H1"),
    # TEN-YBL6 and TEN-BLD intentionally missing
    UNITS = c(10, 20, 30, 40),
    `HINCP.UNITS` = c(100, 200, 300, 400),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify - only present housing columns are preserved
  expect_true("TEN" %in% names(result))
  expect_true("TEN-HFL" %in% names(result))
  expect_false("TEN-YBL6" %in% names(result))
  expect_false("TEN-BLD" %in% names(result))
})


# ============================================================================
# TEST SUITE: Integration with load_cohort_data
# ============================================================================

test_that("housing columns survive full data loading pipeline (mock test)", {
  skip("Requires real data or comprehensive mocking")

  # This test would verify that housing columns are preserved through
  # the entire load_cohort_data -> aggregate_cohort_data pipeline.
  # Skipped because it requires either:
  # 1. Real LEAD data files
  # 2. Complex mocking of the entire loading pipeline

  # Future enhancement: Mock the database/CSV loading to return data
  # with housing dimensions, then verify they survive to the final output
})


# ============================================================================
# TEST SUITE: Data Types and Edge Cases
# ============================================================================

test_that("housing dimension columns maintain character type", {
  # Setup
  data <- create_housing_dimension_data(n = 50)

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify column types
  expect_type(result$TEN, "character")
  expect_type(result$`TEN-YBL6`, "character")
  expect_type(result$`TEN-BLD`, "character")
  expect_type(result$`TEN-HFL`, "character")
})


test_that("NA values in housing dimensions are handled correctly", {
  # Setup - include some NA values
  data <- create_housing_dimension_data(n = 50)
  data$TEN[1:5] <- NA
  data$`TEN-HFL`[6:10] <- NA

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify - NA groups should be created (dplyr groups NAs together)
  expect_true(any(is.na(result$TEN)))
  expect_true(any(is.na(result$`TEN-HFL`)))
})


test_that("works with FPL dataset (different income bracket column)", {
  # Setup - FPL data uses FPL150 instead of AMI
  data <- data.frame(
    FIP = rep(c("37001", "37003"), each = 4),
    FPL150 = rep(c("0-100%", "100-150%"), 4),
    TEN = sample(c("1", "2"), 8, replace = TRUE),
    `TEN-HFL` = sample(c("1-H1", "2-H1"), 8, replace = TRUE),
    UNITS = rpois(8, 10),
    `HINCP.UNITS` = rpois(8, 50000),
    `ELEP.UNITS` = rpois(8, 1000),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "fpl", "2022", verbose = FALSE)

  # Verify housing columns are preserved with FPL data too
  expect_true("TEN" %in% names(result))
  expect_true("TEN-HFL" %in% names(result))
  expect_true("FPL150" %in% names(result))
})


test_that("large number of housing dimension combinations", {
  # Setup - create data with many unique housing dimension combinations
  n <- 500
  set.seed(123)
  data <- data.frame(
    FIP = sample(sprintf("37%03d", 1:20), n, replace = TRUE),
    AMI = sample(c("very_low", "low_mod", "mid_high"), n, replace = TRUE),
    TEN = sample(c("1", "2", "3", "4"), n, replace = TRUE),
    `TEN-YBL6` = sample(paste0(1:4, "-", 1:6), n, replace = TRUE),
    `TEN-BLD` = sample(paste0(1:4, "-", LETTERS[1:10]), n, replace = TRUE),
    `TEN-HFL` = sample(paste0(1:4, "-H", 1:8), n, replace = TRUE),
    UNITS = rpois(n, 5),
    `HINCP.UNITS` = rpois(n, 50000),
    `ELEP.UNITS` = rpois(n, 1000),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Execute
  result <- emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = FALSE)

  # Verify
  # Result should have fewer rows than input (aggregation happened)
  expect_lt(nrow(result), nrow(data))

  # But should preserve the variety of housing dimensions
  expect_gt(length(unique(result$TEN)), 1)
  expect_gt(length(unique(result$`TEN-HFL`)), 1)

  # All housing columns present
  expect_true(all(c("TEN", "TEN-YBL6", "TEN-BLD", "TEN-HFL") %in% names(result)))
})


# ============================================================================
# TEST SUITE: Verbose Output
# ============================================================================

test_that("verbose mode reports housing dimension preservation", {
  # Setup
  data <- create_housing_dimension_data(n = 50)

  # Execute with verbose = TRUE and capture messages
  expect_message(
    emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = TRUE),
    "Preserving housing dimensions"
  )

  # Verify the message contains column names
  expect_message(
    emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = TRUE),
    "TEN"
  )
})


test_that("verbose mode reports when housing dimensions are absent", {
  # Setup - no housing columns
  data <- create_housing_dimension_data(n = 50, include_housing_cols = FALSE)

  # Execute with verbose = TRUE
  expect_message(
    emburden:::aggregate_cohort_data(data, "ami", "2022", verbose = TRUE),
    "No housing dimension columns found"
  )
})
