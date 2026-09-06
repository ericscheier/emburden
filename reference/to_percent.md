# Format Number as Percentage

Converts numeric values to formatted percentage strings with no decimal
places by default.

## Usage

``` r
to_percent(x, latex = FALSE)
```

## Arguments

- x:

  Numeric vector to format (as proportions, not percentages)

- latex:

  Logical indicating whether to escape percent sign for LaTeX (default:
  FALSE)

## Value

Character vector of formatted percentages

## Examples

``` r
# Format percentages
to_percent(c(0.25, 0.50, 0.123))
#> [1] "25%" "50%" "12%"

# LaTeX-escaped format
to_percent(c(0.25, 0.50), latex = TRUE)
#> [1] "25\\%" "50\\%"
```
