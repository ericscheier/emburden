# Validate data before caching to database

Performs comprehensive validation BEFORE data is saved to database or
cache. Prevents corrupted data from being cached in the first place.

## Usage

``` r
validate_before_caching(
  data,
  dataset,
  vintage,
  expected_states = 51,
  strict = TRUE
)
```

## Arguments

- data:

  Data frame to validate

- dataset:

  Character, "ami" or "fpl"

- vintage:

  Character, "2018" or "2022"

- expected_states:

  Integer, expected number of states (51 for nationwide)

- strict:

  Logical, if TRUE throws errors; if FALSE returns list with validation
  results

## Value

If strict=FALSE, returns list with: valid (logical), issues (character
vector) If strict=TRUE, throws error on validation failure
