# Calculate Disposable Energy-Adjusted Resources (DEAR)

Calculates DEAR as the ratio of net income after energy spending to
gross income. DEAR = (G - S) / G.

## Usage

``` r
dear_func(g, s, se = NULL)
```

## Arguments

- g:

  Numeric vector of gross income values

- s:

  Numeric vector of energy spending values

- se:

  Optional numeric vector of effective energy spending (defaults to s)

## Value

Numeric vector of DEAR values (ratio of disposable income to gross
income)

## Examples

``` r
# Calculate DEAR
dear_func(50000, 3000)
#> [1] 0.94
```
