# Orange County NC Energy Burden Sample Data

A sample dataset containing energy burden data for Orange County, North
Carolina (FIPS code 37135). This dataset includes both Federal Poverty
Line (FPL) and Area Median Income (AMI) cohort data for 2018 and 2022
vintages.

## Usage

``` r
orange_county_sample
```

## Format

A named list with 4 data frames:

- fpl_2018:

  Federal Poverty Line cohort data for 2018 (135 rows)

- fpl_2022:

  Federal Poverty Line cohort data for 2022 (206 rows)

- ami_2018:

  Area Median Income cohort data for 2018 (259 rows)

- ami_2022:

  Area Median Income cohort data for 2022 (149 rows)

Each data frame contains:

- geoid:

  11-digit census tract identifier (character)

- income_bracket:

  Income bracket category (character)

- households:

  Number of households in this cohort (numeric)

- total_income:

  Total household income in dollars (numeric)

- total_electricity_spend:

  Total electricity spending in dollars (numeric)

- total_gas_spend:

  Total gas spending in dollars (numeric)

- total_other_spend:

  Total other fuel spending in dollars (numeric)

## Source

U.S. Department of Energy Low-Income Energy Affordability Data (LEAD)
Tool

- 2018 vintage: <https://data.openei.org/submissions/573>

- 2022 vintage: <https://data.openei.org/submissions/6219>

## Details

This sample data is provided for quick demos, testing, and vignettes
without requiring a large download. For full state or national analysis,
use
[`load_cohort_data()`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md)
to download complete datasets from OpenEI.

**Orange County NC** (Chapel Hill, Carrboro, Hillsborough):

- 2018: 27 census tracts

- 2022: 42 census tracts (tract boundaries changed)

**Income Brackets**:

- FPL: 0-100%, 100-150%, 150-200%, 200-400%, 400%+

- AMI: very_low, low_mod, mid_high (aggregated from 6 AMI categories)

## See also

- [`load_cohort_data`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md) -
  Load full datasets for any state

- [`compare_energy_burden`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md) -
  Compare energy burden across vintages

- [`calculate_weighted_metrics`](https://ericscheier.github.io/emburden/reference/calculate_weighted_metrics.md) -
  Calculate weighted metrics with grouping

## Examples

``` r
# Load sample data
data(orange_county_sample)

# View structure
names(orange_county_sample)
#> [1] "fpl_2018" "fpl_2022" "ami_2018" "ami_2022"

# Quick analysis of 2022 FPL data
library(dplyr)
orange_county_sample$fpl_2022 %>%
  group_by(income_bracket) %>%
  summarise(
    households = sum(households),
    avg_energy_burden = sum(total_electricity_spend + total_gas_spend + total_other_spend) /
                        sum(total_income)
  )
#> # A tibble: 5 × 3
#>   income_bracket households avg_energy_burden
#>   <chr>               <dbl>             <dbl>
#> 1 0-100%              5342.            0.163 
#> 2 100-150%            3612.            0.0811
#> 3 150-200%            3004.            0.0481
#> 4 200-400%           12926.            0.0296
#> 5 400%+              30650.            0.0104
```
