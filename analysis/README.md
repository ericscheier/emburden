# Analysis Scripts and Outputs

This directory contains analysis scripts, research outputs, and data files that are separate from the `netenergyequity` R package but depend on it.

## Directory Structure

```
analysis/
├── scripts/           # Analysis R scripts
├── outputs/          # Generated results (CSV, HTML, LaTeX tables)
└── README.md         # This file
```

## Running Analysis Scripts

All scripts in `scripts/` use the `netenergyequity` package. You can run them in two ways:

### Option 1: Development Mode (Recommended)

From the project root:

```r
# Load package functions without installing
devtools::load_all()

# Run analysis script
source("analysis/scripts/nc_all_utilities_energy_burden.R")
```

### Option 2: Installed Package

```r
# Install the package locally
devtools::install()

# Run analysis script
source("analysis/scripts/nc_all_utilities_energy_burden.R")
```

## Available Scripts

### Electric Utilities Energy Burden Analysis

- **`nc_all_utilities_energy_burden.R`**: Analyze all NC utilities (cooperatives, IOUs, municipal, federal)
- **`nc_cooperatives_energy_burden.R`**: Focus on NC electric cooperatives only
- **`all_utilities_energy_burden.R`**: National analysis across all states

### Table Formatting and Rendering

- **`format_all_utilities_table.R`**: Formatting functions for utility tables
- **`format_nc_cooperatives_table.R`**: Formatting for cooperatives tables
- **`render_*_tables.R`**: Generate HTML, LaTeX, and Markdown output tables

## Outputs

Generated files are saved to `outputs/`:

- CSV files: Raw results data
- HTML files: Color-coded tables for viewing in browser
- LaTeX files: Tables for inclusion in publications
- Markdown files: Documentation and formatted tables

## Data Files

Large data files (CohortData_*.csv, CensusTractData.csv) remain in the project root for now. These are:

- **Not included in the R package** (excluded via `.Rbuildignore`)
- Used by analysis scripts
- Should eventually be moved to external hosting or a separate data package

## Notes

- Analysis scripts have been updated to use `netenergyequity::` package functions
- Output paths have been updated to save to `analysis/outputs/`
- The package can be extracted to a separate repository while these scripts remain here
