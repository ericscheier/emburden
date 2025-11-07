# Calculate Net Energy Burden (NEB)

Calculates Net Energy Burden as the ratio of energy spending to gross
income. **Note**: NEB is mathematically identical to Energy Burden (EB =
S/G). The distinction is conceptual - "NEB" emphasizes that proper
aggregation methodology should be used via Net Energy Return (Nh).

## Usage

``` r
neb_func(g, s, se = NULL)
```

## Arguments

- g:

  Numeric vector of gross income values

- s:

  Numeric vector of energy spending values

- se:

  Optional numeric vector of effective energy spending (defaults to s)

## Value

Numeric vector of Net Energy Burden values (identical to energy burden)

## Details

**Mathematical Identity:** At the household level, NEB = EB = S/G.

**For aggregation across households:**

- **Individual household data**: Use
  [`ner_func()`](https://ericscheier.github.io/emburden/reference/ner_func.md)
  first, then `weighted.mean(nh)`, then convert back via
  `neb = 1/(1+nh_mean)`. This uses arithmetic mean instead of harmonic
  mean, providing both computational simplicity and numerical stability.

- **Cohort data** (pre-aggregated totals): Can use direct calculation
  `sum(spending)/sum(income)` which is equivalent to the Nh method.

- **Never use** `weighted.mean(neb)` or `weighted.mean(eb)` - this
  introduces 1-5% error.

**Why "NEB" vs "EB"?** The "Net" terminology connects to the Nh (Net
Energy Return) framework and reminds users to use proper aggregation.
Mathematically identical, conceptually clarifying.

## See also

[`ner_func()`](https://ericscheier.github.io/emburden/reference/ner_func.md)
for the Net Energy Return calculation used in proper aggregation

[`energy_burden_func()`](https://ericscheier.github.io/emburden/reference/energy_burden_func.md)
for the mathematically identical calculation

## Examples

``` r
# Individual household - NEB identical to EB
neb_func(50000, 3000)  # 0.06
#> [1] 0.06
energy_burden_func(50000, 3000)  # 0.06 (same)
#> [1] 0.06

# For aggregation - use Nh method (individual HH data)
incomes <- c(30000, 50000, 75000)
spending <- c(3000, 3500, 4000)
households <- c(100, 150, 200)

# CORRECT: Via Nh (arithmetic mean)
nh <- ner_func(incomes, spending)
nh_mean <- weighted.mean(nh, households)
neb_correct <- 1 / (1 + nh_mean)

# WRONG: Direct mean of NEB
neb_wrong <- weighted.mean(neb_func(incomes, spending), households)

# For cohort data (totals already aggregated)
total_income <- c(3000000, 7500000, 15000000)
total_spend <- c(300000, 525000, 750000)
neb_direct <- sum(total_spend) / sum(total_income)  # Simple and correct
```
