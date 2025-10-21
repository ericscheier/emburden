# NC Electric Cooperatives Energy Burden Analysis

This analysis calculates energy burden statistics for 17 electric cooperatives serving customers in North Carolina.

## Files Created

### Analysis Scripts

1. **`nc_cooperatives_energy_burden.R`**
   - Main analysis script
   - Loads AMI cohort data and census tract supplemental data
   - Filters for NC cooperatives
   - Calculates weighted energy burden metrics using Nh (Net Energy Return) approach
   - Outputs CSV results and console summary

2. **`format_nc_cooperatives_table.R`**
   - Helper functions for formatting results tables
   - Uses existing `to_percent()`, `to_big()` helpers from `helpers.R`
   - Functions:
     - `format_nc_cooperatives_table()` - Full formatted table
     - `format_nc_cooperatives_table_compact()` - Compact view with key metrics

### Reports

3. **`nc_cooperatives_table.Rmd`**
   - R Markdown document for generating formatted PDF/HTML reports
   - Includes multiple table views (full, compact, top/bottom 5)
   - Uses `knitr::kable()` and `kableExtra` for professional formatting
   - Includes methodology notes and definitions

### Output Files

4. **`nc_cooperatives_energy_burden_results.csv`**
   - CSV file with complete results for all 17 cooperatives
   - Columns: cooperative name, household counts, poverty rates, energy burden statistics, Nh values

## Usage

### Run the Analysis

```r
# From R console or RStudio
source("nc_cooperatives_energy_burden.R")
```

This will:
- Generate console output with summary statistics
- Create `nc_cooperatives_energy_burden_results.csv`
- Display formatted table (if knitr/kableExtra available)

### Generate PDF/HTML Report

```r
# Render PDF report
rmarkdown::render("nc_cooperatives_table.Rmd", output_format = "pdf_document")

# Render HTML report
rmarkdown::render("nc_cooperatives_table.Rmd", output_format = "html_document")
```

Or from command line:
```bash
Rscript -e "rmarkdown::render('nc_cooperatives_table.Rmd')"
```

## Methodology

The analysis follows the established methodology in the codebase:

1. **Data Sources**:
   - `CohortData_AreaMedianIncome.csv` - Energy burden estimates by census tract
   - `CensusTractData.csv` - Utility service territory mapping

2. **Aggregation Approach**:
   - Energy burden (Eb = S/G) is converted to Net Energy Return (Nh = (G-S)/S)
   - Weighted harmonic mean calculated using `calculate_weighted_metrics()` from `helpers.R`
   - Results converted back to energy burden for interpretation

3. **Key Metrics**:
   - **Energy Burden (Eb)**: Proportion of income spent on energy
   - **Energy Poverty Line**: Eb ≥ 6% (equivalent to Nh ≤ 15.67)
   - **Weighted Mean/Median**: Household-weighted statistics
   - **5th/95th Percentiles**: Distribution range

## Results Summary

- **17 electric cooperatives** analyzed
- **114,172 households** across all NC cooperatives
- **35.7%** overall poverty rate (households with Eb ≥ 6%)

**Range of median energy burdens**:
- Highest: Cape Hatteras Electric Membership Corp (10.6%)
- Lowest: Piedmont Electric Member Corp (2.2%)

## Dependencies

### R Packages Used
- `dplyr` - Data manipulation
- `scales` - Number formatting
- `spatstat` - Weighted quantiles (weighted.quantile, weighted.median)
- `knitr` - Table generation (optional)
- `kableExtra` - Advanced table formatting (optional)
- `rmarkdown` - Report rendering (optional)

### Existing Infrastructure
- `ratios.R` - Energy burden/NER conversion functions
- `helpers.R` - Weighted metrics calculation and formatting functions
- `comparison_table.R` - Table structuring patterns (reference)
