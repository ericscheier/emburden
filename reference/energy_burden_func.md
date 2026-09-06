# Calculate Energy Burden

Calculates the energy burden as the ratio of energy spending to gross
income. Energy burden is defined as E_b = S/G, where S is energy
spending and G is gross income.

## Usage

``` r
energy_burden_func(g, s, se = NULL)
```

## Arguments

- g:

  Numeric vector of gross income values

- s:

  Numeric vector of energy spending values

- se:

  Optional numeric vector of effective energy spending (defaults to s)

## Value

Numeric vector of energy burden values (ratio of spending to income)

## Examples

``` r
# Calculate energy burden for households
gross_income <- c(50000, 75000, 100000)
energy_spending <- c(3000, 3500, 4000)
energy_burden_func(gross_income, energy_spending)
#> [1] 0.06000000 0.04666667 0.04000000
```
