# North Carolina Complete Energy Burden Sample Data

A comprehensive dataset containing energy burden data for all counties
in North Carolina. This dataset includes both Federal Poverty Line (FPL)
and Area Median Income (AMI) cohort data for 2018 and 2022 vintages,
aggregated to the census tract × income bracket level.

## Usage

``` r
nc_sample
```

## Format

A named list with 4 data frames:

- fpl_2018:

  Federal Poverty Line cohort data for 2018 (~10,805 rows)

- fpl_2022:

  Federal Poverty Line cohort data for 2022 (~13,185 rows)

- ami_2018:

  Area Median Income cohort data for 2018 (~6,484 rows)

- ami_2022:

  Area Median Income cohort data for 2022 (~5,091 rows)

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

This sample data provides full state coverage for more comprehensive
analysis, testing, and demonstrations. For lightweight quick demos, see
[`orange_county_sample`](https://ericscheier.github.io/emburden/reference/orange_county_sample.md).

**North Carolina** (all 100 counties):

- 2018: 2,163 census tracts

- 2022: 2,642 census tracts (tract boundaries changed)

**Income Brackets**:

- FPL: 0-100%, 100-150%, 150-200%, 200-400%, 400%+

- AMI: Varies by vintage (4-6 categories)

**Size**: 1.3 MB compressed (.rda)

## See also

- [`orange_county_sample`](https://ericscheier.github.io/emburden/reference/orange_county_sample.md) -
  Lightweight sample (94 KB) for quick demos

- [`load_cohort_data`](https://ericscheier.github.io/emburden/reference/load_cohort_data.md) -
  Load data for any state with county filtering

- [`compare_energy_burden`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md) -
  Compare energy burden across vintages

- [`calculate_weighted_metrics`](https://ericscheier.github.io/emburden/reference/calculate_weighted_metrics.md) -
  Calculate weighted metrics with grouping

## Examples

``` r
# Load sample data
data(nc_sample)

# View structure
names(nc_sample)
#> [1] "fpl_2018" "fpl_2022" "ami_2018" "ami_2022"

# Analyze energy burden by county
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union

# Extract county FIPS (first 5 digits of geoid)
nc_sample$fpl_2022 %>%
  mutate(county_fips = substr(geoid, 1, 5)) %>%
  group_by(county_fips, income_bracket) %>%
  summarise(
    households = sum(households),
    avg_energy_burden = sum(total_electricity_spend + total_gas_spend + total_other_spend) /
                        sum(total_income),
    .groups = "drop"
  ) %>%
  filter(county_fips == "37183")  # Wake County
#> # A tibble: 5 × 4
#>   county_fips income_bracket households avg_energy_burden
#>   <chr>       <chr>               <dbl>             <dbl>
#> 1 37183       0-100%             27123.            0.153 
#> 2 37183       100-150%           21426.            0.0663
#> 3 37183       150-200%           23547.            0.0484
#> 4 37183       200-400%          100336.            0.0275
#> 5 37183       400%+             258065.            0.0110

# Compare urban vs rural counties
urban_counties <- c("37119", "37063", "37183")  # Mecklenburg, Durham, Wake
rural_counties <- c("37069", "37095", "37131")  # Franklin, Hyde, Northampton

nc_sample$fpl_2022 %>%
  mutate(
    county_fips = substr(geoid, 1, 5),
    region = case_when(
      county_fips %in% urban_counties ~ "Urban",
      county_fips %in% rural_counties ~ "Rural",
      TRUE ~ "Other"
    )
  ) %>%
  filter(region != "Other") %>%
  group_by(region, income_bracket) %>%
  summarise(
    households = sum(households),
    energy_burden = sum(total_electricity_spend + total_gas_spend + total_other_spend) /
                    sum(total_income),
    .groups = "drop"
  )
#> # A tibble: 10 × 4
#>    region income_bracket households energy_burden
#>    <chr>  <chr>               <dbl>         <dbl>
#>  1 Rural  0-100%              4066.        0.229 
#>  2 Rural  100-150%            3744.        0.107 
#>  3 Rural  150-200%            3018.        0.0724
#>  4 Rural  200-400%           11405.        0.0419
#>  5 Rural  400%+              13706.        0.0190
#>  6 Urban  0-100%             74436.        0.147 
#>  7 Urban  100-150%           57355.        0.0624
#>  8 Urban  150-200%           61034.        0.0463
#>  9 Urban  200-400%          255846.        0.0275
#> 10 Urban  400%+             563879.        0.0107
```
