# Changelog

## emburden 0.1.1

### Documentation and Infrastructure Improvements

This patch release improves documentation accessibility and workflow
infrastructure, with no code changes.

#### Documentation

- Improved README accessibility and tone
  - Simplified technical language with plain-language explanations
  - Replaced prescriptive language (“WRONG”, “NEVER”) with educational
    tone (“Recommended”, “Note”)
  - Added concrete examples explaining why simple averaging of ratios
    fails
- Added complete Nature Communications citation
  - Scheier, E., & Kittner, N. (2022). A measurement strategy to address
    disparities across household energy burdens
  - Includes BibTeX format for easy reference

#### Infrastructure

- Changed git author in publish-to-public workflow from “GitHub Actions
  Bot” to “Eric Scheier”
  - Automated commits now appear as maintainer commits

## emburden 0.1.0

### Package Release

Initial formal release with package renamed from `netenergyequity` to
`emburden` for clarity and CRAN compatibility.

This is the first release of the netenergyequity package, providing
tools for household energy burden analysis using Net Energy Return
methodology.

#### Core Functionality

- Energy metric calculations
  - [`energy_burden_func()`](https://ericscheier.github.io/emburden/reference/energy_burden_func.md) -
    Calculate energy burden (S/G)
  - [`ner_func()`](https://ericscheier.github.io/emburden/reference/ner_func.md) -
    Calculate Net Energy Return (Nh)
  - [`eroi_func()`](https://ericscheier.github.io/emburden/reference/eroi_func.md) -
    Calculate Energy Return on Investment
  - [`dear_func()`](https://ericscheier.github.io/emburden/reference/dear_func.md) -
    Calculate Disposable Energy-Adjusted Resources
- Statistical analysis
  - [`calculate_weighted_metrics()`](https://ericscheier.github.io/emburden/reference/calculate_weighted_metrics.md) -
    Weighted aggregation with proper Nh methodology
  - Automatic poverty rate calculations below specified thresholds
  - Support for grouped analysis by geographic/demographic categories
- Formatting utilities
  - [`to_percent()`](https://ericscheier.github.io/emburden/reference/to_percent.md),
    [`to_dollar()`](https://ericscheier.github.io/emburden/reference/to_dollar.md),
    [`to_big()`](https://ericscheier.github.io/emburden/reference/to_big.md) -
    Publication-ready formatting
  - [`to_million()`](https://ericscheier.github.io/emburden/reference/to_million.md),
    [`to_billion_dollar()`](https://ericscheier.github.io/emburden/reference/to_billion_dollar.md) -
    Compact number formats
  - [`colorize()`](https://ericscheier.github.io/emburden/reference/colorize.md) -
    Output-aware color formatting for R Markdown

#### Package Structure

- Separated package code (`R/`) from analysis scripts (`analysis/`)
- Comprehensive documentation with roxygen2
- Test suite with testthat
- Example analysis scripts for NC electric utilities

#### Known Issues

- roxygen2 documentation generation requires manual NAMESPACE for now
- Large data files (1.1GB+) not included in package distribution
- Some analysis scripts need updating to use package functions

#### Future Plans

- Add vignettes demonstrating methodology
- Setup pkgdown website
- Configure GitHub Actions for CI/CD
- Consider CRAN submission
- Create companion data package or external data hosting solution
