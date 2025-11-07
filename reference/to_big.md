# Format Large Numbers with Thousand Separators

Converts numeric values to formatted strings with thousand separators
(commas).

## Usage

``` r
to_big(x)
```

## Arguments

- x:

  Numeric vector to format

## Value

Character vector of formatted numbers

## Examples

``` r
# Format large numbers
to_big(c(1000, 25000, 1000000))
#> [1] "1,000"     "25,000"    "1,000,000"
```
