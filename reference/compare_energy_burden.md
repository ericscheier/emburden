# Compare Energy Burden Between Years

Compare household energy burden metrics across different data vintages,
using proper Net Energy Return (Nh) aggregation methodology.

## Usage

``` r
compare_energy_burden(
  dataset = c("ami", "fpl"),
  states = NULL,
  counties = NULL,
  group_by = c("income_bracket", "state", "none"),
  vintage_1 = "2018",
  vintage_2 = "2022",
  format = TRUE
)
```

## Arguments

- dataset:

  Character, either "ami" or "fpl" for cohort data type

- states:

  Character vector of state abbreviations to filter by (optional)

- counties:

  Character vector of county names or FIPS codes to filter by
  (optional). Requires `states` to be specified.

- group_by:

  Character, grouping variable: "income_bracket" (default), "state", or
  "none" for overall comparison

- vintage_1:

  Character, first vintage year: "2018" or "2022" (default "2018")

- vintage_2:

  Character, second vintage year: "2018" or "2022" (default "2022")

- format:

  Logical, if TRUE returns formatted percentages (default TRUE)

## Value

A data.frame with energy burden comparison showing:

- neb_YYYY: Net Energy Burden for each vintage (where YYYY is the year)

- change_pp: Absolute change in percentage points

- change_pct: Relative percent change

## Examples

``` r
if (FALSE) { # \dontrun{
# Compare NC energy burden by income bracket (2018 vs 2022)
compare_energy_burden(dataset = "ami", states = "NC")

# State-level comparison
compare_energy_burden(dataset = "ami", states = "NC", group_by = "state")

# Overall comparison (no grouping)
compare_energy_burden(dataset = "fpl", states = c("NC", "SC"), group_by = "none")

# Custom vintage comparison
compare_energy_burden(dataset = "ami", states = "CA",
                     vintage_1 = "2018", vintage_2 = "2022")

# Compare specific counties
compare_energy_burden(dataset = "fpl", states = "NC",
                     counties = c("Orange", "Durham", "Wake"))
} # }
```
