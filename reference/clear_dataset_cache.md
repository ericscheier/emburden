# Clear cache for a specific dataset

Removes cached CSV files and database entries for a specific
dataset/vintage. Useful when you know a specific dataset is corrupted.

## Usage

``` r
clear_dataset_cache(
  dataset = c("ami", "fpl"),
  vintage = c("2018", "2022"),
  verbose = TRUE
)
```

## Arguments

- dataset:

  Character, "ami" or "fpl"

- vintage:

  Character, "2018" or "2022"

- verbose:

  Logical, print progress messages

## Value

Invisibly returns number of items cleared

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear corrupted AMI 2018 cache
clear_dataset_cache("ami", "2018")

# Clear FPL 2022 cache
clear_dataset_cache("fpl", "2022", verbose = TRUE)
} # }
```
