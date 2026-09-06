# Format Number as Dollar Amount

Converts numeric values to formatted dollar strings with appropriate
decimal places and thousand separators.

## Usage

``` r
to_dollar(x, latex = FALSE)
```

## Arguments

- x:

  Numeric vector to format

- latex:

  Logical indicating whether to escape dollar sign for LaTeX (default:
  FALSE)

## Value

Character vector of formatted dollar amounts

## Examples

``` r
# Format dollar amounts
to_dollar(c(1000, 2500.50, 10000))
#> [1] "$1,000"  "$2,500"  "$10,000"

# LaTeX-escaped format
to_dollar(c(1000, 2500.50), latex = TRUE)
#> [1] "\\$1,000" "\\$2,500"
```
