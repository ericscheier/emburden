# emburden

<!-- badges: start -->
[![R-CMD-check](https://github.com/ericscheier/emburden/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ericscheier/emburden/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R package for analyzing household energy burden using the Net Energy Return (Nh) methodology.

## Overview

**emburden** provides tools for calculating and analyzing household energy burden across geographic and demographic cohorts. The package implements proper aggregation methodology using Net Energy Return (Nh) as the preferred metric before converting back to energy burden ratios.

**NEW**: Data downloads automatically from OpenEI on first use! No manual data setup required. Data is automatically imported to database for fast subsequent access.

### Key Features

- **Energy metrics calculations**: Energy burden, Net Energy Return (Nh), EROI, DEAR
- **Weighted statistical analysis**: Proper aggregation using household weights
- **Flexible grouping**: Analyze by utility, state, county, census tract, or custom categories
- **Publication-ready formatting**: Functions for creating formatted tables in multiple output formats

### Why Net Energy Return?

Energy burden (E_b = S/G) is a ratio that requires harmonic mean aggregation. The Net Energy Return transformation (Nh = (G-S)/S) allows proper weighted mean aggregation using simple arithmetic mean, then converts back to energy burden via E_b = 1/(Nh+1).

**Computational Advantage** (applies to **aggregation across households only**): When aggregating individual household data, the Nh method uses arithmetic mean (`weighted.mean(nh)`) instead of harmonic mean (`1/weighted.mean(1/eb)`), providing:
- Simpler computation with standard functions
- Better numerical stability (avoids division by very small EB values)
- More interpretable results ("average net return per dollar")
- Clear error prevention (makes it obvious you can't use arithmetic mean on EB directly)

Note: For single household calculations, both methods are mathematically equivalent (NEB = EB). The advantage appears only when aggregating across multiple households.

This methodology is detailed in:

> **Net energy metrics reveal striking disparities across United States household energy burdens**

## Installation

You can install the development version of emburden from GitHub:

```r
# install.packages("devtools")
devtools::install_github("ericscheier/emburden")
```

## Quick Start

```r
library(emburden)
library(dplyr)

# Data downloads automatically on first use!
# Load census tract data for North Carolina
nc_tracts <- load_census_tract_data(states = "NC")

# Load household cohort data by Area Median Income
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")

# === EXAMPLE 1: Single household calculation ===
gross_income <- 50000
energy_spending <- 3000

# Method 1: Direct energy burden
eb <- energy_burden_func(gross_income, energy_spending)  # 0.06

# Method 2: Via Net Energy Return (mathematically identical)
nh <- ner_func(gross_income, energy_spending)  # 15.67
neb <- 1 / (nh + 1)  # 0.06 (same as eb)

# === EXAMPLE 2: Individual household data aggregation ===
# CORRECT: Use Nh method (arithmetic mean)
incomes <- c(30000, 50000, 75000)
spendings <- c(3000, 3500, 4000)
households <- c(100, 150, 200)

nh <- ner_func(incomes, spendings)
nh_mean <- weighted.mean(nh, households)
neb_correct <- 1 / (1 + nh_mean)  # Proper aggregation ✓

# WRONG: Direct mean of energy burden (introduces 1-5% error)
# neb_wrong <- weighted.mean(energy_burden_func(incomes, spendings), households)  # DON'T DO THIS!

# === EXAMPLE 3: Cohort data aggregation ===
# For pre-aggregated totals, direct ratio works
neb_cohort <- sum(nc_ami$total_electricity_spend) / sum(nc_ami$total_income)  # Simple ✓

# === EXAMPLE 4: Grouped analysis ===
results <- calculate_weighted_metrics(
  graph_data = nc_ami,
  group_columns = "income_bracket",
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

**Household-level calculations** (all mathematically related):
- `energy_burden_func(g, s)` - Energy Burden: **S/G**
- `neb_func(g, s)` - Net Energy Burden: **S/G** (identical to EB, emphasizes proper aggregation)
- `ner_func(g, s)` - Net Energy Return: **(G-S)/S** (use this for aggregation!)
- `eroi_func(g, s)` - Energy Return on Investment: **G/Se**
- `dear_func(g, s)` - Disposable Energy-Adjusted Resources: **(G-S)/G**

**Key relationships**:
- At household level: `neb_func() == energy_burden_func()` (identical)
- Transformation: `neb = 1/(1+nh)` and `nh = (1/neb) - 1`
- 6% energy burden threshold ↔ Nh ≥ 15.67

**Aggregation guidance**:
- **Individual household data**: Calculate `nh <- ner_func(income, spending)`, then `neb_aggregate <- 1/(1 + weighted.mean(nh, weights))` (arithmetic mean ✓)
- **Cohort data** (pre-aggregated totals): Calculate `neb <- sum(total_spending) / sum(total_income)` (direct ratio ✓)
- **NEVER use**: `weighted.mean(neb_func(...))` or `mean(energy_burden_func(...))` (arithmetic mean of ratios ✗ introduces 1-5% error)

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

# Data downloads automatically on first use!
# Run analysis
source("analysis/scripts/nc_all_utilities_energy_burden.R")

# View outputs in analysis/outputs/
```

## Data Requirements

### Automatic Data Download

The package automatically downloads LEAD Tool data from OpenEI on first use and caches it locally for fast subsequent access. No manual data setup required!

**NEW in v0.3.0**: Support for both 2018 and 2022 LEAD Tool data vintages enables temporal analysis.

**Loading data** (automatic database/CSV/OpenEI download fallback):

```r
library(emburden)

# Check which data source is available
check_data_sources()

# Load census tract data (tries database → CSV → automatic download)
nc_tracts <- load_census_tract_data(states = "NC")

# Load household cohort data (defaults to latest vintage - 2022)
# Auto-downloads from OpenEI on first use, imports to database for fast subsequent access!
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")

# Load specific vintage (2018 or 2022)
nc_ami_2018 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2018")
nc_ami_2022 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2022")

# Compare vintages for temporal analysis
comparison <- compare_vintages(dataset = "ami", states = "NC", aggregate_by = "state")
```

**Data Loading Workflow:**

On first use, `load_cohort_data()` automatically:
1. **Tries local database** for fast access
2. **Falls back to local CSV** files if database unavailable
3. **Downloads from OpenEI** (DOE LEAD dataset) if neither exists
4. **Imports to database** automatically for subsequent fast access
5. Returns the requested data - no manual steps required!

Data sources:
- **OpenEI 2018**: https://data.openei.org/submissions/573 (4 AMI brackets)
- **OpenEI 2022**: https://data.openei.org/submissions/6219 (6 AMI brackets)


See `data-raw/README.md` for complete migration documentation and `data-raw/LEAD_SCHEMA_COMPARISON.md` for vintage differences.

### Legacy CSV Files

For backward compatibility, the package still supports CSV files:

- `CensusTractData.csv` - Census tract demographics and utility info
- `CohortData_AreaMedianIncome.csv` - Energy burden by Area Median Income brackets
- `CohortData_FederalPovertyLine.csv` - Energy burden by Federal Poverty Line brackets

These files are large (>100MB each) and not included in git. Contact maintainer for access or use the database (recommended).

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

Report bugs or request features at: https://github.com/ScheierVentures/emburden/issues

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

## Database Integration

The package supports local SQLite database integration for enhanced analysis and improved performance:

### What's Available

**Energy Burden Data** (new in v0.2.0):
- **Census tract demographics** - 72K tracts with utility service territory info
- **Household cohort energy burden** - 2.4M cohorts by income/tenure/housing type
- **Area Median Income (AMI) brackets** - Income relative to local median
- **Federal Poverty Line (FPL) brackets** - Income relative to poverty threshold

**Utility & Market Data**:
- **Utility electricity rates** by ZIP code
- **eGrid emissions subregions** for environmental justice analysis
- **Geographic crosswalks** (tract ↔ ZIP ↔ county)
- **State retail sales projections** (1998-2050)
- **Renewable generator registry**

### Installation

```r
# Install database packages
install.packages(c("DBI", "RSQLite"))

# Optional: Set environment variable to use existing database
# Sys.setenv(EMBURDEN_DB_PATH = "/path/to/your/database.sqlite")
```

### Usage

**Energy Burden Data** (automatic database/CSV/download fallback):

```r
library(emburden)

# Load census tract data (tries database → CSV → automatic download)
nc_tracts <- load_census_tract_data(states = "NC")

# Load household cohort data by income bracket
# Downloads automatically if not available locally!
nc_ami <- load_cohort_data(
  dataset = "ami",  # or "fpl"
  states = "NC",
  income_brackets = c("0-30% AMI", "30-50% AMI")
)

# Load integrated data (burden + utility rates + emissions)
nc_full <- load_burden_with_utilities(
  states = "NC",
  dataset = "ami",
  income_brackets = "0-30% AMI"
)
```

**Utility Rate Data** (requires database connection):

```r
# Connect to database (if available)
# Database integration requires separate setup - see Database Integration section
# conn <- DBI::dbConnect(RSQLite::SQLite(), "/path/to/database.sqlite")

# Get utility rates for North Carolina (requires database connection)
# nc_rates <- get_utility_rates(conn, state = "NC")

# Get emissions regions
egrid <- get_egrid_regions(conn, zips = c(27701, 27705, 28052))

# Get retail sales projections
sales <- get_retail_sales_projections(conn, states = "NC", years = 2020:2030)

# Always disconnect when done
DBI::dbDisconnect(conn)
```

### Example Analyses

See the vignette for complete examples:

```r
vignette("integrating-utility-data", package = "emburden")
```

And the example script:

```r
source("analysis/scripts/utility_rate_comparison.R")
```

**Benefits:**
- **Faster data access** - Database queries 10-50x faster than CSV parsing
- **Integrated analysis** - Join burden data with utility rates and emissions in single query
- **Flexible filtering** - Query only needed states/income brackets instead of loading full CSVs
- **Environmental justice** - Link high-burden areas with high-emissions grid regions
- **Policy modeling** - Scenario analysis with utility rate structures and demand projections

## Related Resources

- **Paper**: "Net energy metrics reveal striking disparities across United States household energy burdens"
- **Data Source**: DOE Low-Income Energy Affordability Data (LEAD) Tool via OpenEI
- **Methodology**: See package vignettes
