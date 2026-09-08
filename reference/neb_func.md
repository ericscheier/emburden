# Calculate Net Energy Burden (NEB)

Calculates Net Energy Burden with proper aggregation methodology via the
Net Energy Return (Nh) framework. For individual households, NEB = EB =
S/G. When aggregating across households (with weights), automatically
uses the Nh method to avoid 1-5% aggregation errors.

## Usage

``` r
neb_func(g, s, se = NULL, weights = NULL, aggregate = FALSE)
```

## Arguments

- g:

  Numeric vector of gross income values

- s:

  Numeric vector of energy spending values

- se:

  Optional numeric vector of effective energy spending (defaults to s)

- weights:

  Optional numeric vector of weights for aggregation (e.g., household
  counts). When provided, uses Nh method:
  `1 / (1 + weighted.mean(nh, weights))`

- aggregate:

  Logical, if TRUE forces aggregation even without weights (uses
  unweighted mean). Default FALSE for backwards compatibility.

## Value

- If `weights = NULL` and `aggregate = FALSE`: Numeric vector of
  individual NEB values (S/G)

- If `weights` provided or `aggregate = TRUE`: Single aggregated NEB
  value via Nh method

## Details

**Individual Level:** NEB = EB = S/G (mathematically identical)

**Aggregation Modes:**

1.  **No aggregation** (default): Returns vector of individual NEB
    values

        neb_func(income, spending)  # Returns vector

2.  **Weighted aggregation**: Automatically uses Nh method when weights
    provided

        neb_func(income, spending, weights = households)  # Returns single value

3.  **Unweighted aggregation**: Use `aggregate = TRUE` for simple mean

        neb_func(income, spending, aggregate = TRUE)  # Returns single value

**Why Nh Method?** Avoids 1-5% error from naive averaging:

- **CORRECT**: `neb_func(g, s, weights = w)` → Uses Nh internally

- **WRONG**: `weighted.mean(s/g, w)` → Introduces bias

The Nh method: `1 / (1 + weighted.mean(nh, weights))` where
`nh = (g-s)/se` uses arithmetic mean instead of harmonic mean, providing
computational simplicity and numerical stability.

## See also

[`ner_func()`](https://emburden.org/reference/ner_func.md) for the Net
Energy Return (Nh) calculation

[`energy_burden_func()`](https://emburden.org/reference/energy_burden_func.md)
for simple EB without aggregation support

## Examples

``` r
# Individual household - returns vector
neb_func(50000, 3000)  # 0.06
#> [1] 0.06
neb_func(c(30000, 50000), c(3000, 3500))  # c(0.10, 0.07)
#> [1] 0.10 0.07

# Aggregation with weights - returns single value (CORRECT method)
incomes <- c(30000, 50000, 75000)
spending <- c(3000, 3500, 4000)
households <- c(100, 150, 200)
neb_func(incomes, spending, weights = households)
#> [1] 0.06528497

# Unweighted aggregation
neb_func(incomes, spending, aggregate = TRUE)
#> [1] 0.06970954

# Comparison: naive mean (WRONG) vs Nh method (CORRECT)
neb_naive <- weighted.mean(spending/incomes, households)  # Biased
neb_correct <- neb_func(incomes, spending, weights = households)  # Correct
abs(neb_naive - neb_correct) / neb_correct  # ~1-5% error
#> [1] 0.06087596
```
