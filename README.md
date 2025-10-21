# netenergyequity

<!-- badges: start -->
[![R-CMD-check](https://github.com/ericscheier/net_energy_equity/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ericscheier/net_energy_equity/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R package for analyzing household energy burden using the Net Energy Return (Nh) methodology.

## Overview

**netenergyequity** provides tools for calculating and analyzing household energy burden across geographic and demographic cohorts. The package implements proper aggregation methodology using Net Energy Return (Nh) as the preferred metric before converting back to energy burden ratios.

### Key Features

- **Energy metrics calculations**: Energy burden, Net Energy Return (Nh), EROI, DEAR
- **Weighted statistical analysis**: Proper aggregation using household weights
- **Flexible grouping**: Analyze by utility, state, county, census tract, or custom categories
- **Publication-ready formatting**: Functions for creating formatted tables in multiple output formats

### Why Net Energy Return?

Energy burden (E_b = S/G) is a ratio that requires harmonic mean aggregation. The Net Energy Return transformation (Nh = (G-S)/S) allows proper weighted mean aggregation, then converts back to energy burden via E_b = 1/(Nh+1). This methodology is detailed in:

> **Net energy metrics reveal striking disparities across United States household energy burdens**

## Installation

You can install the development version of netenergyequity from GitHub:

```r
# install.packages("devtools")
devtools::install_github("ericscheier/net_energy_equity")
```

## Quick Start

```r
library(netenergyequity)
library(dplyr)

# Calculate Net Energy Return (Nh)
gross_income <- 50000
energy_spending <- 3000
nh <- ner_func(gross_income, energy_spending)

# Convert to energy burden
energy_burden <- 1 / (nh + 1)
print(energy_burden)  # 0.06 or 6%

# Analyze weighted metrics across groups
results <- calculate_weighted_metrics(
  graph_data = your_data,
  group_columns = "utility_name",
  metric_name = "ner",
  metric_cutoff_level = 15.67,  # 6% energy burden threshold
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)

# Format results for publication
library(scales)
results$formatted_median <- to_percent(results$metric_median)
```

## Core Functions

### Energy Metrics

- `energy_burden_func()` - Calculate energy burden (S/G)
- `ner_func()` - Calculate Net Energy Return ((G-S)/S)
- `eroi_func()` - Calculate Energy Return on Investment (G/S)
- `dear_func()` - Calculate Disposable Energy-Adjusted Resources

### Statistical Analysis

- `calculate_weighted_metrics()` - Weighted mean, median, quantiles with grouping
- Automatically calculates poverty rates below specified thresholds
- Handles missing data and small sample sizes

### Formatting

- `to_percent()` - Format as percentage with optional LaTeX escaping
- `to_dollar()` - Format as currency
- `to_big()` - Format large numbers with thousand separators
- `to_million()` / `to_billion_dollar()` - Compact formats for large values

## Project Structure

This repository contains both the **R package** and **analysis code**:

```
net_energy_equity/
├── R/                      # Package source code (exportable)
│   ├── energy_ratios.R     # Energy metric calculations
│   ├── metrics.R           # Weighted statistical functions
│   └── formatting.R        # Output formatting utilities
├── analysis/               # Analysis scripts and outputs (not in package)
│   ├── scripts/            # Example analysis scripts
│   └── outputs/            # Generated tables and results
├── DESCRIPTION             # Package metadata
├── NAMESPACE               # Package exports
└── README.md               # This file
```

The package is designed to be extractable to a separate repository while analysis scripts remain here and depend on the installed package.

## Example Analysis

See `analysis/scripts/` for complete examples:

- **`nc_all_utilities_energy_burden.R`**: Analyze all NC electric utilities
- **`nc_cooperatives_energy_burden.R`**: Focus on NC electric cooperatives
- **`all_utilities_energy_burden.R`**: National-level analysis

Run from project root:

```r
# Load package for development
devtools::load_all()

# Run analysis
source("analysis/scripts/nc_all_utilities_energy_burden.R")

# View outputs in analysis/outputs/
```

## Data Requirements

Analysis scripts expect data files with columns:

- `geoid` - Census tract identifier
- `ner` - Net Energy Return values
- `households` - Household counts for weighting
- Group columns (e.g., `company_na`, `company_ty`, `state_abbr`)

Large data files (>100MB) are not included in the package. See `analysis/README.md` for data documentation.

## Energy Poverty Threshold

The standard 6% energy burden threshold corresponds to:

- **Energy Burden**: E_b ≤ 0.06
- **Net Energy Return**: Nh ≤ 15.67
- **EROI**: EROI ≥ 16.67

Use `ner_func(g = 1, s = 0.06)` to calculate the Nh threshold for any energy burden level.

## Citation

If you use this package in research, please cite:

```
[Citation information to be added]
```

## License

GNU Affero General Public License v3.0 or later (AGPL-3+)

See [LICENSE](LICENSE) for full text.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests and documentation
4. Submit a pull request

## Issues

Report bugs or request features at: https://github.com/ericscheier/net_energy_equity/issues

## Development

```r
# Load package during development
devtools::load_all()

# Run tests
devtools::test()

# Check package
devtools::check()

# Build documentation
devtools::document()

# Install locally
devtools::install()
```

## Related Resources

- **Paper**: "Net energy metrics reveal striking disparities across United States household energy burdens"
- **Data sources**: [To be documented]
- **Methodology**: See package vignettes (coming soon)
