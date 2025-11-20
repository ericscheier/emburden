# Detect potentially corrupted database data

Checks if loaded data appears corrupted (too small, missing states,
missing columns). **Does NOT automatically delete** - only warns and
provides recommendations.

## Usage

``` r
detect_database_corruption(
  data,
  dataset,
  vintage,
  states = NULL,
  verbose = TRUE
)
```

## Arguments

- data:

  Data frame to check

- dataset:

  Character, "ami" or "fpl"

- vintage:

  Character, "2018" or "2022"

- states:

  Character vector of expected states (NULL = all US states)

- verbose:

  Logical, print warnings

## Value

List with: is_corrupted (logical), issues (character vector),
recommendation (character)
