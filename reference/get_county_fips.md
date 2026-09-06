# Convert county identifiers to FIPS codes

Supports both 3-digit county FIPS codes and 5-digit state+county FIPS
codes. County names can be matched from the orange_county_sample or
nc_sample datasets.

## Usage

``` r
get_county_fips(counties, states)
```

## Arguments

- counties:

  Character vector of county identifiers (FIPS codes or names)

- states:

  Character vector of state abbreviations for context

## Value

Character vector of 3-digit county FIPS codes
