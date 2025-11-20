# Compare Energy Burden Between Years

Compare household energy burden metrics across different data vintages,
using proper Net Energy Return (Nh) aggregation methodology.

## Usage

``` r
compare_energy_burden(
  dataset = c("ami", "fpl"),
  states = NULL,
  group_by = "income_bracket",
  counties = NULL,
  vintage_1 = "2022",
  vintage_2 = "2018",
  format = TRUE
)
```

## Arguments

- dataset:

  Character, either "ami" or "fpl" for cohort data type

- states:

  Character vector of state abbreviations to filter by (optional)

- group_by:

  Character or character vector. Use keywords "income_bracket"
  (default), "state", or "none" for standard groupings. Or provide
  custom column name(s) for dynamic grouping (e.g., "geoid" for
  tract-level, c("state_abbr", "income_bracket") for multi-level
  grouping). Custom columns must exist in the loaded data.

- counties:

  Character vector of county names or FIPS codes to filter by
  (optional). Requires `states` to be specified.

- vintage_1:

  Character, first vintage year: "2018" or "2022" (default "2022")

- vintage_2:

  Character, second vintage year: "2018" or "2022" (default "2018")

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
# Single state comparison (fast, good for learning)
nc_comparison <- compare_energy_burden("ami", "NC", "income_bracket")

# Multi-state regional comparison
southeast <- compare_energy_burden(
  dataset = "fpl",
  states = c("NC", "SC", "GA", "FL"),
  group_by = "state"
)

# Nationwide comparison by income bracket (all 51 states)
us_comparison <- compare_energy_burden(
  dataset = "ami",
  group_by = "income_bracket"  # No states filter = all states
)

# Overall comparison (no grouping)
compare_energy_burden("ami", "NC", "none")

# Compare specific counties within a state
compare_energy_burden("fpl", "NC", counties = c("Orange", "Durham", "Wake"))

# Custom grouping by tract-level geoid
compare_energy_burden("ami", "NC", group_by = "geoid")

# Multi-level custom grouping (requires joining with tract data)
# compare_energy_burden("fpl", "NC", group_by = c("state_abbr", "income_bracket"))
} # }
```
