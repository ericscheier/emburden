# Calculate Net Energy Return (Nh)

Calculates the Net Energy Return using the formula Nh = (G - S) / Se,
where G is gross income, S is energy spending, and Se is effective
energy spending. This metric is the preferred aggregation variable as it
properly accounts for harmonic mean behavior when aggregating across
households.

## Usage

``` r
ner_func(g, s, se = NULL)
```

## Arguments

- g:

  Numeric vector of gross income values

- s:

  Numeric vector of energy spending values

- se:

  Optional numeric vector of effective energy spending (defaults to s)

## Value

Numeric vector of Net Energy Return (Nh) values

## Details

The Net Energy Return is mathematically related to energy burden by: E_b
= 1 / (Nh + 1), or equivalently: Nh = (1/E_b) - 1

**Why use Nh for aggregation?**

For individual household data, the Nh method enables simple arithmetic
weighted mean aggregation:

- **Via Nh**: `neb = 1 / (1 + weighted.mean(nh, weights))` (arithmetic
  mean)

- **Direct EB**: `neb = 1 / weighted.mean(1/eb, weights)` (harmonic
  mean)

**Computational advantages of the arithmetic mean approach:**

1.  **Simpler to compute** - Uses standard
    [`weighted.mean()`](https://rdrr.io/r/stats/weighted.mean.html)
    function

2.  **More numerically stable** - Avoids division by very small EB
    values (e.g., 0.01)

3.  **More interpretable** - "Average net return per dollar spent on
    energy"

4.  **Prevents errors** - Makes it obvious you can't use arithmetic mean
    on EB directly

For cohort data (pre-aggregated totals), direct calculation
`sum(S)/sum(G)` is mathematically equivalent to the Nh method but
simpler.

The 6% energy burden poverty threshold corresponds to Nh ≥ 15.67.

## Examples

``` r
# Calculate Net Energy Return
gross_income <- 50000
energy_spending <- 3000
nh <- ner_func(gross_income, energy_spending)

# Convert back to energy burden
energy_burden <- 1 / (nh + 1)
```
