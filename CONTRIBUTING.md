# Contributing to emburden

Thank you for your interest in contributing to **emburden**! This
package provides tools for analyzing household energy burden using the
Net Energy Return (Nh) methodology.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Branching Workflow](#branching-workflow)
- [Development Setup](#development-setup)
- [Testing](#testing)
- [Documentation](#documentation)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## Code of Conduct

This project adheres to a Code of Conduct (see CODE_OF_CONDUCT.md). By
participating, you are expected to uphold this code. Please report
unacceptable behavior to <eric@scheier.org>.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the [issue
tracker](https://github.com/ericscheier/emburden/issues) to avoid
duplicates. When you create a bug report, include as many details as
possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed and what you expected**
- **Include your R version and sessionInfo() output**

Example bug report:

``` r

# Minimal reproducible example
library(emburden)
sessionInfo()

# Code that produces the bug
income <- 50000
spending <- 3000
result <- ner_func(income, spending)
# Expected: 15.67, Got: [incorrect value]
```

### Suggesting Enhancements

Enhancement suggestions are tracked as [GitHub
issues](https://github.com/ericscheier/emburden/issues). When creating
an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a step-by-step description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List some other packages where this enhancement exists, if
  applicable**

### Contributing Code

We welcome pull requests! Here’s how to get started:

## Branching Workflow

This repository uses a **Feature → Dev → Staging → Main** branching
strategy to ensure code quality and stability. All changes must flow
through this pipeline sequentially.

### Branch Overview

| Branch | Purpose | Merge Target | CI Checks |
|----|----|----|----|
| `feature/*` | Feature development | `dev` | None |
| `dev` | Integration & development | `staging` | Ubuntu R CMD check |
| `staging` | Pre-production validation | `main` | Multi-platform R CMD check |
| `main` | Production (synced to public repo) | \- | Multi-platform + CRAN checks |

### Quick Start

``` bash
# 1. Start from dev branch
git checkout dev
git pull scheier dev

# 2. Create your feature branch
git checkout -b feature/my-new-feature

# 3. Make changes and commit
git add .
git commit -m "feat: Add my new feature"

# 4. Push to remote
git push scheier feature/my-new-feature

# 5. Create PR to dev branch (not main!)
gh pr create --base dev --head feature/my-new-feature
```

### Detailed Workflow

**For detailed information about the branching strategy, promotion
workflows, and release process, see
[.github/BRANCHING_STRATEGY.md](https://emburden.org/BRANCHING_STRATEGY.md).**

Key points for contributors:

1.  **All PRs go to `dev`** - Never create PRs directly to `staging` or
    `main`
2.  **Auto-approval** - PRs with only docs/tests changes are
    auto-approved
3.  **Code review required** - PRs with R code changes need maintainer
    approval
4.  **Delete feature branches** - After merge, delete your feature
    branch
5.  **Promotions are controlled** - Only maintainers can promote
    dev→staging→main

## Development Setup

### 1. Fork and Clone the Repository

``` bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR-USERNAME/emburden.git
cd emburden

# Add the upstream repository
git remote add upstream https://github.com/ericscheier/emburden.git
```

### 2. Install R and Dependencies

Ensure you have R \>= 4.0.0 installed. Then install the development
dependencies:

``` r

# Install devtools if you don't have it
install.packages("devtools")

# Install package dependencies
devtools::install_deps(dependencies = TRUE)

# Install suggested packages for development
install.packages(c("testthat", "knitr", "rmarkdown", "covr"))
```

### 3. Load the Package for Development

``` r

# Load all package functions into your R session
devtools::load_all()

# Or use this shortcut in RStudio: Ctrl+Shift+L (Cmd+Shift+L on Mac)
```

### 4. Create a New Branch

**Important:** Always branch from `dev`, not `main`.

``` bash
# Switch to dev branch and update
git checkout dev
git pull scheier dev

# Create a branch for your feature or bug fix
git checkout -b feature/your-feature-name

# Or for bug fixes:
git checkout -b fix/issue-description

# Or for documentation:
git checkout -b docs/update-readme
```

## Testing

This package uses `testthat` for testing. **All contributions should
include tests.**

### Running Tests

``` r

# Run all tests
devtools::test()

# Or use RStudio shortcut: Ctrl+Shift+T (Cmd+Shift+T on Mac)

# Run specific test file
testthat::test_file("tests/testthat/test-metrics.R")

# Run tests with coverage
covr::package_coverage()
```

### Writing Tests

Tests should be placed in `tests/testthat/` with filenames starting with
`test-`:

``` r

# tests/testthat/test-new-feature.R
test_that("ner_func calculates net energy return correctly", {
  # Basic test
  expect_equal(ner_func(50000, 3000), 15.67, tolerance = 0.01)

  # Edge cases
  expect_error(ner_func(-50000, 3000))  # Negative income
  expect_error(ner_func(50000, -3000))  # Negative spending
  expect_error(ner_func(50000, 0))      # Zero spending
})

test_that("neb_func gives same result as energy_burden_func", {
  income <- 50000
  spending <- 3000

  eb <- energy_burden_func(income, spending)
  neb <- neb_func(income, spending)

  expect_equal(eb, neb, tolerance = 1e-10)
})
```

### Test Coverage Goals

- Aim for \>80% code coverage
- All exported functions must have tests
- Test edge cases and error conditions
- Test that aggregation methods produce correct results

## Documentation

### Roxygen2 Documentation

All exported functions must have roxygen2 documentation:

``` r

#' Calculate Net Energy Return (Nh)
#'
#' Computes the Net Energy Return, which is the ratio of net income
#' (after energy spending) to energy spending.
#'
#' @param gross_income Numeric. Household gross income in dollars.
#' @param energy_spending Numeric. Total household energy spending in dollars.
#'
#' @return Numeric. The Net Energy Return (Nh) value.
#'
#' @details
#' Net Energy Return is calculated as:
#' \deqn{Nh = \frac{G - S}{S}}
#'
#' Where G is gross income and S is energy spending.
#'
#' @examples
#' # Household with $50,000 income and $3,000 energy spending
#' ner_func(50000, 3000)
#' #> [1] 15.67
#'
#' @export
ner_func <- function(gross_income, energy_spending) {
  # Function implementation
}
```

### Building Documentation

``` r

# Generate documentation from roxygen2 comments
devtools::document()

# Or use RStudio shortcut: Ctrl+Shift+D (Cmd+Shift+D on Mac)

# Preview documentation
?ner_func
```

### Vignettes

For substantial new features, consider adding a vignette:

``` r

# Create a new vignette
usethis::use_vignette("new-feature-name")

# Build vignettes
devtools::build_vignettes()

# Preview vignette
browseVignettes("emburden")
```

## Code Style

We follow the [tidyverse style guide](https://style.tidyverse.org/). Key
points:

### Naming Conventions

- **Functions**: `snake_case` (e.g., `calculate_weighted_metrics`)
- **Variables**: `snake_case` (e.g., `gross_income`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `DEFAULT_THRESHOLD`)

### Spacing and Formatting

``` r

# Good
result <- ner_func(income, spending)
if (x > 0) {
  y <- sqrt(x)
}

# Bad
result<-ner_func( income,spending )
if(x>0){
  y<-sqrt(x)
}
```

### Pipe Operator

Use the native pipe `|>` (R \>= 4.1.0) or magrittr pipe `%>%`:

``` r

# Good
data |>
  filter(income > 0) |>
  mutate(nh = ner_func(income, spending))

# Also acceptable
data %>%
  filter(income > 0) %>%
  mutate(nh = ner_func(income, spending))
```

### Code Checking

Before submitting, ensure your code passes R CMD check:

``` r

# Run R CMD check
devtools::check()

# Should show: 0 errors ✓ | 0 warnings ✓ | 0 notes ✓
```

## Pull Request Process

### 1. Update Your Branch

**Important:** Sync with `dev` branch, not `main`.

``` bash
# Fetch latest changes
git fetch scheier

# Merge latest dev into your branch
git checkout feature/your-feature-name
git merge scheier/dev

# Resolve any conflicts if needed
```

### 2. Run Final Checks

``` r

# Run all tests
devtools::test()

# Run R CMD check
devtools::check()

# Check code style
styler::style_pkg()
lintr::lint_package()
```

### 3. Commit Your Changes

``` bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "Add feature: brief description

- Detailed point 1
- Detailed point 2
- Fixes #123"
```

### 4. Push to Your Fork

``` bash
git push origin feature/your-feature-name
```

### 5. Create Pull Request

**Important:** Create PR to `dev` branch, not `main`.

``` bash
# Using GitHub CLI (recommended)
gh pr create --base dev --head feature/your-feature-name \
  --title "feat: Brief description" \
  --body "Detailed description of changes"

# Or via web UI:
```

1.  Go to <https://github.com/ScheierVentures/emburden> (private repo)
2.  Click “New Pull Request”
3.  **Base branch:** `dev` (not main!)
4.  **Compare branch:** `feature/your-feature-name`
5.  Fill out the PR template:
    - **Title**: Use conventional commits format (`feat:`, `fix:`,
      `docs:`, etc.)
    - **Description**: What changes were made and why
    - **Related Issues**: Link to relevant issues
    - **Testing**: Describe how you tested the changes

### PR Checklist

Before submitting, ensure:

Code follows the tidyverse style guide

All tests pass (`devtools::test()`)

R CMD check passes with 0 errors, 0 warnings (`devtools::check()`)

New functions have roxygen2 documentation

New functions have tests with good coverage

NEWS.md updated (for significant changes)

Vignettes updated (if applicable)

### Review Process

- **Auto-approval:** PRs with only docs/tests are auto-approved (still
  need CI to pass)
- **Manual review:** PRs with code changes need maintainer review (1-2
  weeks)
- **Feedback:** You may be asked to make changes
- **Merge:** Once approved and CI passes, your PR will be merged to
  `dev`
- **Promotion:** Maintainers will later promote changes through staging
  → main → public repo → CRAN

### After Your PR Merges

Your changes will follow this promotion path:

1.  **Merged to `dev`** - Your PR is complete! 🎉
2.  **Promoted to `staging`** - Maintainer runs multi-platform
    validation
3.  **Released to `main`** - Version is bumped, GitHub release created
4.  **Published to public repo** - Synced to
    <https://github.com/ericscheier/emburden>
5.  **Submitted to CRAN** - Available for `install.packages("emburden")`

See
[.github/BRANCHING_STRATEGY.md](https://emburden.org/BRANCHING_STRATEGY.md)
for details on the promotion process.

## Development Workflow Example

Here’s a complete workflow for adding a new feature:

``` r

# 1. Create branch
# (done in terminal: git checkout -b feature/new-metric)

# 2. Write the function
# R/new_metric.R

#' Calculate New Energy Metric
#'
#' @param income Numeric. Gross income
#' @param spending Numeric. Energy spending
#' @return Numeric. New metric value
#' @export
new_metric_func <- function(income, spending) {
  if (income <= 0 || spending <= 0) {
    stop("Income and spending must be positive")
  }
  # Your calculation here
  result <- (income - spending) / income
  return(result)
}

# 3. Load and test interactively
devtools::load_all()
new_metric_func(50000, 3000)  # Should work

# 4. Write tests
# tests/testthat/test-new-metric.R

test_that("new_metric_func works correctly", {
  expect_equal(new_metric_func(50000, 3000), 0.94)
  expect_error(new_metric_func(-50000, 3000))
  expect_error(new_metric_func(50000, -3000))
})

# 5. Generate documentation
devtools::document()

# 6. Run all checks
devtools::test()    # All tests pass
devtools::check()   # 0 errors, 0 warnings

# 7. Commit and push
# (done in terminal)
```

## Getting Help

- **Documentation**: <https://ericscheier.github.io/emburden/>
- **Issues**: <https://github.com/ericscheier/emburden/issues>
- **Email**: <eric@scheier.org>
- **Discussions**: Use GitHub Discussions for questions

## Recognition

Contributors will be acknowledged in: - The package DESCRIPTION file
(for significant contributions) - The AUTHORS file - Release notes in
NEWS.md

Thank you for contributing to emburden!
