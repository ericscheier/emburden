# Calculate Energy Return on Investment (EROI)

Calculates the Energy Return on Investment as the ratio of gross income
to effective energy spending. EROI = G/Se.

## Usage

``` r
eroi_func(g, s, se = NULL)
```

## Arguments

- g:

  Numeric vector of gross income values

- s:

  Numeric vector of energy spending values

- se:

  Optional numeric vector of effective energy spending (defaults to s)

## Value

Numeric vector of EROI values

## Examples

``` r
# Calculate EROI for households
eroi_func(50000, 3000)
#> [1] 16.66667
```
