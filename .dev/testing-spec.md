# Comprehensive Testing Specification for Data Functions

## Overview

This document specifies a comprehensive testing strategy for the emburden package's data loading and processing functions. The goal is to achieve robust test coverage with proper mocking of external dependencies (HTTP APIs, databases, file systems).

## Testing Infrastructure

### Required Packages

```r
# In DESCRIPTION Suggests section:
- testthat (>= 3.0.0)  # Already present
- DBI                    # Already present
- RSQLite                # Already present
- httptest2              # For HTTP mocking
- withr                  # For temporary file/env management
- mockery                # For function mocking
```

### Test File Organization

```
tests/
├── testthat/
│   ├── helper-mocks.R              # Mocking utilities
│   ├── helper-fixtures.R           # Test data generators
│   ├── test-data-loaders.R         # Data loading tests
│   ├── test-data-processing.R      # Data processing tests
│   ├── test-database-access.R      # Database interaction tests
│   ├── test-http-requests.R        # HTTP/API tests
│   ├── test-file-validation.R      # File validation tests
│   └── test-schema-normalization.R # Schema transformation tests
├── fixtures/
│   ├── sample_ami_2018.csv         # Sample AMI 2018 data
│   ├── sample_ami_2022.csv         # Sample AMI 2022 data
│   ├── sample_fpl_2018.csv         # Sample FPL 2018 data
│   ├── sample_fpl_2022.csv         # Sample FPL 2022 data
│   ├── corrupted_data.csv          # File with all-NA income_bracket
│   ├── incomplete_schema.csv       # File missing required columns
│   └── sample_database.db          # SQLite database for testing
└── testthat.R                      # Test runner
```

## 1. Data Loading Functions Tests

### 1.1 `load_census_tract_data()` Tests

**File**: `tests/testthat/test-data-loaders.R`

#### Test Cases:

```r
test_that("load_census_tract_data loads data successfully", {
  # Mock HTTP GET request to OpenEI
  with_mock_api({
    data <- load_census_tract_data(
      states = "NC",
      vintage = "2022",
      dataset = "ami"
    )

    expect_s3_class(data, "data.frame")
    expect_true(nrow(data) > 0)
    expect_true("geoid" %in% names(data))
    expect_true("income" %in% names(data))
    expect_true("energy_cost" %in% names(data))
  })
})

test_that("load_census_tract_data handles multiple states", {
  with_mock_api({
    data <- load_census_tract_data(
      states = c("NC", "SC"),
      vintage = "2022"
    )

    expect_true(all(c("NC", "SC") %in% data$state_abbr))
  })
})

test_that("load_census_tract_data fails gracefully on network error", {
  # Mock network failure
  with_mock_api({
    httptest2::expect_GET(
      load_census_tract_data(states = "NC"),
      "https://data.openei.org/.*",
      status_code = 404
    )
  })

  expect_error(
    load_census_tract_data(states = "NC"),
    "Failed to download"
  )
})

test_that("load_census_tract_data uses cached data", {
  # Create temporary cache directory
  withr::with_tempdir({
    # First call downloads
    data1 <- load_census_tract_data(states = "NC")

    # Second call should use cache (no HTTP request)
    data2 <- load_census_tract_data(states = "NC")

    expect_identical(data1, data2)
  })
})

test_that("load_census_tract_data validates state codes", {
  expect_error(
    load_census_tract_data(states = "INVALID"),
    "Invalid state code"
  )
})

test_that("load_census_tract_data handles vintage parameter", {
  with_mock_api({
    data_2018 <- load_census_tract_data(states = "NC", vintage = "2018")
    data_2022 <- load_census_tract_data(states = "NC", vintage = "2022")

    # Expect different data for different vintages
    expect_false(identical(data_2018, data_2022))
  })
})
```

### 1.2 `load_cohort_data()` Tests

```r
test_that("load_cohort_data loads AMI data", {
  data <- load_cohort_data(
    dataset = "ami",
    states = "NC",
    vintage = "2022"
  )

  expect_s3_class(data, "data.frame")
  expect_true("income_bracket" %in% names(data))
  expect_true(all(data$income_bracket %in% c(
    "0-30%", "30-60%", "60-80%", "80-100%", "100%+"
  )))
})

test_that("load_cohort_data loads FPL data", {
  data <- load_cohort_data(
    dataset = "fpl",
    states = "NC",
    vintage = "2022"
  )

  expect_s3_class(data, "data.frame")
  expect_true("income_bracket" %in% names(data))
})

test_that("load_cohort_data handles aggregate_poverty flag", {
  data <- load_cohort_data(
    dataset = "fpl",
    states = "NC",
    aggregate_poverty = TRUE
  )

  expect_true(all(data$income_bracket %in% c(
    "Below Federal Poverty Line",
    "Above Federal Poverty Line"
  )))
})

test_that("load_cohort_data skips corrupted files", {
  # Create corrupted file with all-NA income_bracket
  withr::with_tempfile("corrupted", {
    corrupt_data <- data.frame(
      geoid = "37001",
      income_bracket = rep(NA_character_, 100),
      income = 50000,
      energy_cost = 2000
    )
    write.csv(corrupt_data, corrupted, row.names = FALSE)

    # Should skip corrupted file and fall back to raw data
    expect_message(
      load_cohort_data(dataset = "fpl", states = "NC"),
      "Skipping file.*income_bracket all NA"
    )
  })
})

test_that("load_cohort_data validates dataset parameter", {
  expect_error(
    load_cohort_data(dataset = "invalid"),
    "dataset must be either 'ami' or 'fpl'"
  )
})
```

### 1.3 `check_data_sources()` Tests

```r
test_that("check_data_sources detects available CSV files", {
  withr::with_tempdir({
    # Create dummy CSV file
    write.csv(
      data.frame(x = 1:10),
      "data_ami_census_tracts_2022_NC.csv"
    )

    sources <- check_data_sources(
      dataset = "ami",
      states = "NC",
      vintage = "2022"
    )

    expect_true(sources$csv_available)
  })
})

test_that("check_data_sources detects available database", {
  # Create temporary SQLite database
  withr::with_tempfile("db", fileext = ".db", {
    con <- DBI::dbConnect(RSQLite::SQLite(), db)
    DBI::dbWriteTable(con, "ami_2022", data.frame(x = 1:10))
    DBI::dbDisconnect(con)

    sources <- check_data_sources(
      dataset = "ami",
      vintage = "2022",
      db_path = db
    )

    expect_true(sources$db_available)
  })
})
```

## 2. Database Access Tests

**File**: `tests/testthat/test-database-access.R`

```r
test_that("database connection succeeds with valid path", {
  withr::with_tempfile("db", fileext = ".db", {
    con <- DBI::dbConnect(RSQLite::SQLite(), db)
    DBI::dbWriteTable(con, "test", data.frame(x = 1:10))
    DBI::dbDisconnect(con)

    # Test package function that connects to DB
    result <- query_database(db, "SELECT * FROM test")
    expect_equal(nrow(result), 10)
  })
})

test_that("database connection fails gracefully", {
  expect_error(
    query_database("/nonexistent/path.db", "SELECT * FROM test"),
    "Failed to connect to database"
  )
})

test_that("database query falls back to CSV on failure", {
  # Mock database failure
  mockery::stub(
    load_cohort_data,
    "query_database",
    stop("DB connection failed")
  )

  # Should fall back to CSV
  expect_message(
    load_cohort_data(dataset = "ami", states = "NC"),
    "Falling back to CSV"
  )
})
```

## 3. HTTP/API Request Tests

**File**: `tests/testthat/test-http-requests.R`

```r
test_that("HTTP request succeeds with valid URL", {
  httptest2::with_mock_api({
    response <- download_lead_data(
      dataset = "ami",
      state = "NC",
      vintage = "2022"
    )

    expect_s3_class(response, "response")
    expect_equal(httr::status_code(response), 200)
  })
})

test_that("HTTP request handles 404 error", {
  httptest2::with_mock_api({
    expect_error(
      download_lead_data(dataset = "invalid"),
      "404"
    )
  })
})

test_that("HTTP request handles timeout", {
  # Mock timeout
  mockery::stub(
    download_lead_data,
    "httr::GET",
    stop("Timeout")
  )

  expect_error(
    download_lead_data(dataset = "ami"),
    "Timeout"
  )
})

test_that("HTTP request retries on failure", {
  # Mock: fail twice, succeed third time
  retry_count <- 0
  mockery::stub(
    download_lead_data,
    "httr::GET",
    function(...) {
      retry_count <<- retry_count + 1
      if (retry_count < 3) stop("Failed")
      list(status_code = 200, content = "success")
    }
  )

  result <- download_lead_data(dataset = "ami")
  expect_equal(retry_count, 3)
})
```

## 4. File Validation Tests

**File**: `tests/testthat/test-file-validation.R`

```r
test_that("validates required columns exist", {
  data <- data.frame(
    geoid = "37001",
    income = 50000,
    energy_cost = 2000
  )

  expect_true(validate_required_columns(
    data,
    c("geoid", "income", "energy_cost")
  ))

  expect_error(
    validate_required_columns(data, c("missing_column")),
    "Missing required columns"
  )
})

test_that("skips files with all-NA income_bracket", {
  data <- data.frame(
    geoid = "37001",
    income_bracket = rep(NA_character_, 100),
    income = 50000
  )

  expect_false(validate_income_bracket(data))
})

test_that("validates positive household counts", {
  data <- data.frame(households = c(100, 200, -50))

  expect_error(
    validate_household_counts(data),
    "Negative household counts found"
  )
})

test_that("validates income and energy_cost ranges", {
  data <- data.frame(
    income = c(50000, -1000),  # Negative income
    energy_cost = c(2000, 5000)
  )

  expect_warning(
    validate_ranges(data),
    "Negative income values found"
  )
})
```

## 5. Data Processing Tests

**File**: `tests/testthat/test-data-processing.R`

```r
test_that("process_lead_cohort_data aggregates correctly", {
  raw_data <- data.frame(
    geoid = rep("37001", 5),
    income_bracket = rep("0-30%", 5),
    income = c(10000, 15000, 20000, 25000, 30000),
    energy_cost = c(1500, 1800, 2000, 2200, 2400),
    households = c(100, 150, 200, 250, 300)
  )

  result <- process_lead_cohort_data(raw_data)

  # Check weighted means calculated correctly
  expected_mean_income <- weighted.mean(
    raw_data$income,
    raw_data$households
  )
  expect_equal(result$mean_income[1], expected_mean_income)
})

test_that("lead_to_poverty aggregates to binary", {
  data <- data.frame(
    income_bracket = c("0-100%", "100-150%", "150-200%"),
    income = c(10000, 15000, 25000),
    energy_cost = c(1500, 1800, 2000),
    households = c(100, 200, 300)
  )

  result <- lead_to_poverty(data, dataset = "fpl")

  expect_equal(nrow(result), 2)  # Binary: below/above poverty
  expect_true(all(result$income_bracket %in% c(
    "Below Federal Poverty Line",
    "Above Federal Poverty Line"
  )))
})

test_that("calculate_ner handles edge cases", {
  # Zero income
  expect_equal(ner_func(0, 1000), -1)

  # Zero energy cost
  expect_equal(ner_func(50000, 0), Inf)

  # Negative income
  expect_true(is.finite(ner_func(-1000, 1000)))
})
```

## 6. Schema Normalization Tests

**File**: `tests/testthat/test-schema-normalization.R`

```r
test_that("normalizes AMI brackets across vintages", {
  # 2018 schema
  data_2018 <- data.frame(
    income_bracket = c("0-30%", "30-60%", "60-80%", "80-100%", "100%+")
  )

  # 2022 schema (same in this case)
  data_2022 <- data.frame(
    income_bracket = c("0-30%", "30-60%", "60-80%", "80-100%", "100%+")
  )

  norm_2018 <- normalize_ami_schema(data_2018, vintage = "2018")
  norm_2022 <- normalize_ami_schema(data_2022, vintage = "2022")

  expect_equal(
    sort(unique(norm_2018$income_bracket)),
    sort(unique(norm_2022$income_bracket))
  )
})

test_that("aggregates detailed brackets to simplified schema", {
  data <- data.frame(
    income_bracket = c("0-30%", "30-60%", "60-80%", "80-100%", "100%+"),
    households = c(100, 200, 150, 300, 250)
  )

  result <- aggregate_to_simplified_schema(data)

  expect_equal(nrow(result), 3)  # very_low, low_mod, mid_high
  expect_equal(result$households[1], 100)  # 0-30%
  expect_equal(result$households[2], 350)  # 30-80% (200 + 150)
})

test_that("normalizes building type across datasets", {
  data <- data.frame(
    bld_index = c("1 unit detached", "1 unit attached", "2-4 units", "5+ units")
  )

  result <- normalize_building_type(data)

  expect_true(all(result$building_type %in% c("Single-Family", "Multi-Family")))
})
```

## 7. Integration Tests

**File**: `tests/testthat/test-integration.R`

```r
test_that("end-to-end: load and compare vintages", {
  # This test uses real data (if available) or mocked data
  skip_if_offline()

  comparison <- compare_energy_burden(
    dataset = "ami",
    states = "NC",
    group_by = "income_bracket"
  )

  expect_s3_class(comparison, "energy_burden_comparison")
  expect_true("neb_2018" %in% names(comparison))
  expect_true("neb_2022" %in% names(comparison))
  expect_true("neb_change_pp" %in% names(comparison))
})

test_that("end-to-end: calculate weighted metrics", {
  data <- load_census_tract_data(states = "NC")

  metrics <- calculate_weighted_metrics(
    data,
    group_columns = "county_name",
    metric_name = "ner"
  )

  expect_true("ner" %in% names(metrics))
  expect_true("household_count" %in% names(metrics))
  expect_true(all(metrics$ner > 0))
})
```

## 8. Helper Functions for Testing

**File**: `tests/testthat/helper-mocks.R`

```r
# Create sample LEAD data for testing
create_sample_lead_data <- function(n = 100) {
  data.frame(
    geoid = sample(paste0("37", sprintf("%03d", 1:100)), n, replace = TRUE),
    income_bracket = sample(c("0-30%", "30-60%", "60-80%", "80-100%", "100%+"), n, replace = TRUE),
    income = rnorm(n, 50000, 20000),
    energy_cost = rnorm(n, 2000, 500),
    households = sample(50:500, n, replace = TRUE),
    housing_tenure = sample(c("OWNER", "RENTER"), n, replace = TRUE),
    primary_heating_fuel = sample(c("Electricity", "Natural gas", "Fuel oil"), n, replace = TRUE)
  )
}

# Mock HTTP responses
mock_openei_response <- function(dataset, state, vintage) {
  httptest2::mock_api({
    path <- file.path(
      "data.openei.org",
      paste0(dataset, "_", state, "_", vintage, ".csv")
    )
    httptest2::mock_response(path, status = 200, body = create_sample_lead_data())
  })
}

# Create temporary test database
create_test_database <- function() {
  db_path <- tempfile(fileext = ".db")
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  DBI::dbWriteTable(con, "ami_2022", create_sample_lead_data())
  DBI::dbWriteTable(con, "ami_2018", create_sample_lead_data())
  DBI::dbWriteTable(con, "fpl_2022", create_sample_lead_data())
  DBI::dbWriteTable(con, "fpl_2018", create_sample_lead_data())

  DBI::dbDisconnect(con)
  return(db_path)
}
```

**File**: `tests/testthat/helper-fixtures.R`

```r
# Create fixture data files for testing
create_fixtures <- function(fixture_dir) {
  dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)

  # Sample AMI data
  write.csv(
    create_sample_lead_data(500),
    file.path(fixture_dir, "sample_ami_2022.csv"),
    row.names = FALSE
  )

  # Corrupted data (all-NA income_bracket)
  corrupted <- create_sample_lead_data(100)
  corrupted$income_bracket <- NA_character_
  write.csv(
    corrupted,
    file.path(fixture_dir, "corrupted_data.csv"),
    row.names = FALSE
  )

  # Incomplete schema (missing required column)
  incomplete <- create_sample_lead_data(100)
  incomplete$income <- NULL
  write.csv(
    incomplete,
    file.path(fixture_dir, "incomplete_schema.csv"),
    row.names = FALSE
  )
}
```

## 9. Test Coverage Goals

Target coverage levels:
- **Data loaders**: 95%+ line coverage
- **Data processing**: 90%+ line coverage
- **Validation functions**: 100% line coverage
- **Overall package**: 85%+ line coverage

Run coverage report with:
```r
covr::package_coverage()
covr::report()
```

## 10. Continuous Integration

Add to `.github/workflows/R-CMD-check.yml`:

```yaml
- name: Test coverage
  run: |
    covr::codecov(
      quiet = FALSE,
      clean = FALSE,
      install_path = file.path(Sys.getenv("RUNNER_TEMP"), "package")
    )
  shell: Rscript {0}
```

## Implementation Priority

1. **Phase 1** (Critical):
   - File validation tests
   - Data loader basic tests
   - Schema normalization tests

2. **Phase 2** (High):
   - HTTP mocking tests
   - Database mocking tests
   - Edge case tests

3. **Phase 3** (Medium):
   - Integration tests
   - Performance tests
   - Coverage improvement

## Expected Benefits

1. **Reliability**: Catch bugs before they reach users
2. **Refactoring confidence**: Safe to improve code
3. **Documentation**: Tests serve as usage examples
4. **Regression prevention**: Ensure fixes stay fixed
5. **API stability**: Tests lock in expected behavior
