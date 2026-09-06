# Load DOE LEAD Tool Cohort Data

Load household energy burden cohort data with automatic fallback:

1.  Try local database

2.  Fall back to local CSV files

3.  Auto-download from OpenEI if neither exists

4.  Auto-import downloaded data to database for future use

## Usage

``` r
load_cohort_data(
  dataset = c("ami", "fpl"),
  states = NULL,
  counties = NULL,
  vintage = "2022",
  income_brackets = NULL,
  verbose = TRUE,
  ...
)
```

## Arguments

- dataset:

  Character, either "ami" (Area Median Income) or "fpl" (Federal Poverty
  Line)

- states:

  Character vector of state abbreviations to filter by (optional)

- counties:

  Character vector of county names or FIPS codes to filter by
  (optional). County names are matched case-insensitively. Requires
  `states` to be specified.

- vintage:

  Character, data vintage: "2018" or "2022" (default "2022")

- income_brackets:

  Character vector of income brackets to filter by (optional)

- verbose:

  Logical, print status messages (default TRUE)

- ...:

  Additional filter expressions passed to dplyr::filter() for dynamic
  filtering. Allows filtering by any column in the dataset using
  tidyverse syntax. Example: `households > 100, total_income > 50000`

## Value

A tibble with columns:

- geoid: Census tract identifier

- income_bracket: Income bracket label

- households: Number of households

- total_income: Total household income (\$)

- total_electricity_spend: Total electricity spending (\$)

- total_gas_spend: Total gas spending (\$)

- total_other_spend: Total other fuel spending (\$)

- TEN: Housing tenure category (1=Owned free/clear, 2=Owned with
  mortgage, 3=Rented, 4=Occupied without rent). Enables analysis of
  energy burden differences between renters and owners.

- TEN-YBL6: Housing tenure crossed with year structure built (6
  categories). Allows analysis of how building age and ownership status
  interact to affect energy burden (e.g., older rental units vs newer
  owner-occupied homes).

- TEN-BLD: Housing tenure crossed with building type (e.g.,
  single-family, multi-unit). Enables analysis of energy burden across
  different housing structures and ownership patterns.

- TEN-HFL: Housing tenure crossed with primary heating fuel type (e.g.,
  gas, electric, oil). Critical for analyzing how heating fuel choice
  and tenure status jointly influence energy costs and burden.

## Examples

``` r
# \donttest{
# Single state (fast, good for learning)
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")
#> Loading 2022 AMI cohort data...
#>   ✓ Loaded from database
#> Filtered to state(s): NC
#> Loaded 15821 cohort records

# Load specific vintage
nc_2018 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2018")
#> Loading 2018 AMI cohort data...
#>   ✓ Loaded from database
#> Filtered to state(s): NC
#> Loaded 10820 cohort records
# }

# \donttest{
if (interactive()) {
  # Multiple states (regional analysis - requires data download)
  southeast <- load_cohort_data(dataset = "fpl", states = c("NC", "SC", "GA", "FL"))

  # Nationwide (all 51 states - no filter)
  us_data <- load_cohort_data(dataset = "ami", vintage = "2022")

# Filter to specific income brackets
low_income <- load_cohort_data(
  dataset = "ami",
  states = "NC",
  income_brackets = c("0-30% AMI", "30-50% AMI")
)

# Filter to specific counties within a state
triangle <- load_cohort_data(
  dataset = "fpl",
  states = "NC",
  counties = c("Orange", "Durham", "Wake")
)

# Or use county FIPS codes
orange <- load_cohort_data(
  dataset = "fpl",
  states = "NC",
  counties = "37135"
)

# Use dynamic filtering for custom criteria
high_burden <- load_cohort_data(
  dataset = "ami",
  states = "NC",
  households > 100,
  total_electricity_spend / total_income > 0.06
)

# Analyze energy burden by housing characteristics
# Compare renters vs owners by heating fuel type
nc_housing <- load_cohort_data(dataset = "ami", states = "NC")
library(dplyr)

# Group by tenure and heating fuel to analyze energy burden patterns
housing_analysis <- nc_housing %>%
  filter(!is.na(TEN), !is.na(`TEN-HFL`)) %>%
  group_by(TEN, `TEN-HFL`) %>%
  summarise(
    total_households = sum(households),
    avg_energy_burden = weighted.mean(
      (total_electricity_spend + total_gas_spend + total_other_spend) / total_income,
      w = households,
      na.rm = TRUE
    ),
    .groups = "drop"
  )
}
# }
```
