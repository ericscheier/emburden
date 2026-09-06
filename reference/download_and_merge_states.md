# Download and merge data from multiple states

Download and merge data from multiple states

## Usage

``` r
download_and_merge_states(dataset, vintage, states, verbose = TRUE)
```

## Arguments

- dataset:

  Character, "ami" or "fpl"

- vintage:

  Character, "2018" or "2022"

- states:

  Character vector of state abbreviations

- verbose:

  Logical, print progress messages

## Value

Combined tibble with data from all states
