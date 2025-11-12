# Testing Framework for emburden Package

This directory contains comprehensive tests for the emburden package, including unit tests, integration tests, and a local test runner.

## Running Tests

### Quick Local Test Run

From the package root directory:

```bash
Rscript tests/run-tests-locally.R
```

Or from R console:

```r
source("tests/run-tests-locally.R")
```

### Full R CMD Check

To run complete package checks (like GitHub Actions):

```bash
RUN_CMD_CHECK=true Rscript tests/run-tests-locally.R
```

### Run Specific Test Files

From R console:

```r
devtools::load_all()
testthat::test_file("tests/testthat/test-energy-metrics.R")
```

### Coverage Report

```r
covr::package_coverage()
covr::report()  # Opens HTML report in browser
```

## Test Organization

### Phase 1: Critical Tests (Implemented)

- **test-file-validation.R**: Data quality checks, edge cases, fixture generation
- **test-energy-metrics.R**: Core NER, energy burden, and related calculations

### Phase 2: High Priority (Planned)

- **test-data-loaders.R**: HTTP mocking, database tests, file loading
- **test-schema-normalization.R**: Vintage compatibility, bracket aggregation

### Phase 3: Medium Priority (Planned)

- **test-integration.R**: End-to-end workflows
- **test-formatting.R**: Output formatting functions

## Helper Files

- **helper-fixtures.R**: Test data generation and cleanup utilities
  - `create_sample_lead_data()`: Generate realistic test data
  - `create_corrupted_fpl_data()`: Test all-NA income_bracket bug
  - `create_test_database()`: SQLite database for testing
  - `cleanup_test_files()`: Remove temporary files

## Writing New Tests

### Template for New Test File

```r
# Phase X: Description
# Tests for specific functionality

test_that("descriptive test name", {
  # Arrange: Set up test data
  data <- create_sample_lead_data(n = 50)

  # Act: Perform the operation
  result <- some_function(data)

  # Assert: Check expectations
  expect_equal(result$value, expected_value)
  expect_true(some_condition)
})
```

### Best Practices

1. **Use fixtures**: Don't rely on external data - use `create_sample_lead_data()`
2. **Test edge cases**: Zero, negative, NA, Inf values
3. **Clean up**: Use `cleanup_test_files()` to remove temporary files
4. **Skip when appropriate**: Use `skip_if_offline()` for network tests
5. **Descriptive names**: Test names should describe what's being tested

## Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| Data loaders | 95% | TBD |
| Energy metrics | 95% | TBD |
| Data processing | 90% | TBD |
| Validation functions | 100% | TBD |
| Overall package | 85% | TBD |

## Continuous Integration

Tests run automatically on:
- Pull requests targeting `main` branch
- Pushes to `main` branch
- Multiple OS/R version combinations (macOS, Windows, Ubuntu)

See `.github/workflows/R-CMD-check.yml` and `.github/workflows/test-coverage.yml` for details.

## Debugging Failed Tests

### View Detailed Output

```r
devtools::test(reporter = "check")  # More verbose than default
```

### Interactive Debugging

```r
devtools::load_all()
library(testthat)

# Set breakpoint in your test
test_that("my failing test", {
  browser()  # Execution will pause here
  # ... test code ...
})
```

### Check Test Data

```r
# Generate and inspect test data
data <- create_sample_lead_data(n = 10)
str(data)
summary(data)
```

## Test Data Fixtures

Test fixtures are generated on-the-fly using `helper-fixtures.R`. This ensures:

1. **No large data files in git**: Fixtures are created during test runs
2. **Reproducibility**: Seed values ensure consistent test data
3. **Flexibility**: Easy to modify fixture characteristics
4. **Speed**: Minimal data creation for fast tests

### Example Fixture Usage

```r
# Create standard test data
data <- create_sample_lead_data(n = 100, dataset = "ami", vintage = "2022")

# Create edge case data
edge_data <- create_edge_case_data()

# Create corrupted data (for testing validation)
corrupted <- create_corrupted_fpl_data(n = 50)
```

## Performance Benchmarks

Target test suite execution time:
- Unit tests: < 30 seconds
- Integration tests: < 60 seconds
- Full suite with coverage: < 2 minutes

## Adding Tests for New Features

When adding new features:

1. Write tests first (TDD approach preferred)
2. Ensure new code has >85% coverage
3. Add integration tests for major features
4. Update this README with new test files

## Troubleshooting

### "Package not installed" Error

```bash
# Install in development mode
Rscript -e "devtools::install()"
```

### Missing Test Dependencies

```r
# Install testing packages
install.packages(c("testthat", "covr", "withr", "mockery"))
```

### Tests Pass Locally but Fail in CI

- Check R version differences
- Verify all dependencies in DESCRIPTION
- Check for hardcoded paths
- Ensure fixtures are platform-independent

## Additional Resources

- [testthat documentation](https://testthat.r-lib.org/)
- [covr package](https://covr.r-lib.org/)
- [R Packages book - Testing chapter](https://r-pkgs.org/testing-basics.html)
- [Testing spec document](.dev/testing-spec.md)
