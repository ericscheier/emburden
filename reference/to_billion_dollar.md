# Format Dollar Amounts in Billions

Converts large dollar values to billions format with dollar sign prefix.
Values less than 1 billion are shown in millions.

## Usage

``` r
to_billion_dollar(x, suffix = " billion", override_to_k = TRUE)
```

## Arguments

- x:

  Numeric vector to format

- suffix:

  Character string to append after "billion" (default: " billion")

- override_to_k:

  Logical (currently unused, kept for compatibility)

## Value

Character vector of formatted dollar amounts with "billion" or "m"
suffix

## Examples

``` r
# Format in billions
to_billion_dollar(c(5000000, 1000000000, 2500000000))
#> [1] "$5m"          "$1.0 billion" "$2.5 billion"
```
