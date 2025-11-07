# Format Numbers in Millions

Converts large numeric values to millions format with appropriate
suffix. Values less than 1 million are shown in thousands.

## Usage

``` r
to_million(x, suffix = " million", override_to_k = TRUE)
```

## Arguments

- x:

  Numeric vector to format

- suffix:

  Character string to append after "million" (default: " million")

- override_to_k:

  Logical indicating whether to show values \< 1M as thousands (default:
  TRUE)

## Value

Character vector of formatted numbers with "million" or "k" suffix

## Examples

``` r
# Format in millions
to_million(c(5000, 1000000, 2500000))
#> [1] "5k"          "1.0 million" "2.5 million"
```
