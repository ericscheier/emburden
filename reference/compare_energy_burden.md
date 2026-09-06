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
  format = TRUE,
  strict_matching = TRUE
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

- strict_matching:

  Logical, if TRUE (default) only compares income brackets that exist in
  both vintages and warns about mismatched brackets. If FALSE, compares
  all brackets (may result in NA values for brackets unique to one
  vintage).

## Value

A data.frame with energy burden comparison showing:

- neb_YYYY: Net Energy Burden for each vintage (where YYYY is the year)

- change_pp: Absolute change in percentage points

- change_pct: Relative percent change

## Examples

``` r
# \donttest{
# Single state comparison (fast, good for learning)
nc_comparison <- compare_energy_burden("ami", "NC", "income_bracket")
#> Loading 2022 data...
#> Loading 2018 data...
#> Income bracket mismatch in AMI dataset:
#>   - Only in 2022: 100-150%, 150%+
#>   - Keeping only common brackets: very_low, low_mod, mid_high
#> Note: Dropped brackets not present in both vintages: 100-150%, 150%+
#> Comparison complete: 2022 vs 2018

# Overall comparison (no grouping)
compare_energy_burden("ami", "NC", "none")
#> Loading 2022 data...
#> Loading 2018 data...
#> Comparison complete: 2022 vs 2018
#> # A tibble: 1 × 6
#>   neb_2018 neb_2022 households_2018 households_2022 change_pp change_pct
#>   <chr>    <chr>              <dbl>           <dbl> <chr>     <chr>     
#> 1 2.63%    2.13%           3918597.        4105232. -0.50 pp  -18.9%    
# }

# \donttest{
if (interactive()) {
  # Multi-state regional comparison (requires census data download)
  southeast <- compare_energy_burden(
    dataset = "fpl",
    states = c("NC", "SC", "GA", "FL"),
    group_by = "state"
  )

  # Nationwide comparison by income bracket (all 51 states)
  us_comparison <- compare_energy_burden(
    dataset = "ami",
    group_by = "income_bracket"
  )

  # Compare specific counties within a state (requires census data)
  compare_energy_burden("fpl", "NC", counties = c("Orange", "Durham", "Wake"))

  # Custom grouping by tract-level geoid (requires census data)
  compare_energy_burden("ami", "NC", group_by = "geoid")
}
# }
```
