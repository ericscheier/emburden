# Download Dataset from Zenodo

Downloads a pre-processed dataset from the emburden Zenodo repository.
Includes progress bars, checksum verification, and automatic retry
logic.

## Usage

``` r
download_from_zenodo(dataset, vintage, verbose = FALSE)
```

## Arguments

- dataset:

  Character, either "ami" or "fpl"

- vintage:

  Character, data vintage: "2018" or "2022"

- verbose:

  Logical, print progress messages (default TRUE)

## Value

Tibble with downloaded data, or NULL if download fails
