# Load Census Tract Data

Load census tract demographics and utility service territory information
with automatic fallback to CSV or OpenEI download.

## Usage

``` r
load_census_tract_data(states = NULL, verbose = TRUE)
```

## Arguments

- states:

  Character vector of state abbreviations to filter by (optional)

- verbose:

  Logical, print status messages (default TRUE)

## Value

A tibble with columns:

- geoid: Census tract identifier

- state_abbr: State abbreviation

- county_name: County name

- tract_name: Tract name

- utility_name: Electric utility serving this tract

- Additional demographic columns

## Examples

``` r
if (FALSE) { # \dontrun{
# Single state
nc_tracts <- load_census_tract_data(states = "NC")

# Multiple states (regional)
southeast <- load_census_tract_data(states = c("NC", "SC", "GA", "FL"))

# Nationwide (all ~73,000 census tracts)
us_tracts <- load_census_tract_data()  # No filter = all states
} # }
```
