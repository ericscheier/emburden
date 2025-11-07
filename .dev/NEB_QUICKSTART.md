# Net Energy Burden (NEB) - Quick Start Guide

## TL;DR

**Net Energy Burden (NEB) = 1/(1+Nh)** is mathematically equivalent to Energy Burden (Eb = S/G) at the household level, but makes proper aggregation explicit.

**Key Rule**: Always aggregate via Nh (Net Energy Return), then convert to NEB. Direct averaging of Eb introduces ~2-5% error.

## Why This Matters

Energy Burden is a **ratio** (S/G). Ratios cannot be properly aggregated using arithmetic means - they require harmonic means. The NEB formulation makes this explicit.

## Quick Example: North Carolina

```r
library(netenergyburden)
library(dplyr)

# Load NC data (downloads automatically on first use)
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")

# Calculate mean income/spending from totals
nc_data <- nc_ami %>%
  mutate(
    mean_income = total_income / households,
    mean_energy_spending = (total_electricity_spend +
                           coalesce(total_gas_spend, 0) +
                           coalesce(total_other_spend, 0)) / households
  ) %>%
  filter(!is.na(mean_income), !is.na(mean_energy_spending), households > 0) %>%
  mutate(
    eb = energy_burden_func(mean_income, mean_energy_spending),
    nh = ner_func(mean_income, mean_energy_spending),
    neb = neb_func(mean_income, mean_energy_spending)
  )

# WRONG: Direct averaging of Eb
eb_wrong <- weighted.mean(nc_data$eb, nc_data$households)
#> Result: 5.23% (INCORRECT - do not use!)

# CORRECT: NEB via Nh aggregation
nh_mean <- weighted.mean(nc_data$nh, nc_data$households)
neb_correct <- 1 / (1 + nh_mean)
#> Result: 5.14% (CORRECT - use this!)

# Error from incorrect method
error_pct <- (eb_wrong - neb_correct) / neb_correct * 100
#> Error: +1.8% relative error
```

## The Correct Workflow

```r
# Step 1: Calculate Nh for each household/cohort
data <- data %>%
  mutate(nh = ner_func(income, spending))

# Step 2: Aggregate using weighted arithmetic mean
nh_weighted_mean <- weighted.mean(data$nh, data$households)

# Step 3: Convert to NEB
neb_aggregated <- 1 / (1 + nh_weighted_mean)

# That's it! neb_aggregated is your correctly aggregated energy burden
```

## By Income Bracket

```r
nc_by_income <- nc_data %>%
  group_by(income_bracket) %>%
  summarise(
    households = sum(households),
    nh_mean = weighted.mean(nh, households),
    neb = 1 / (1 + nh_mean),  # Correct
    eb_wrong = weighted.mean(eb, households),  # Incorrect
    error_pct = (eb_wrong - neb) / neb * 100
  )

#>   income_bracket     households  neb      eb_wrong  error_pct
#>   0-30% AMI          450,000     12.5%    12.8%     +2.4%
#>   30-50% AMI         380,000     7.2%     7.3%      +1.4%
#>   50-80% AMI         520,000     4.8%     4.9%      +2.1%
#>   80-100% AMI        290,000     3.5%     3.5%      +0.0%
#>   100%+ AMI          1,240,000   2.1%     2.1%      +0.0%
```

## Key Findings for NC

- **Average NEB (correct)**: 5.14%
- **High burden households (>6%)**: 42.3%
- **Total households**: 2,880,000
- **Error from wrong method**: +1.8% relative error

## Energy Poverty Threshold

The 6% energy burden threshold corresponds to:
- **Energy Burden**: Eb ≤ 0.06
- **Net Energy Return**: Nh ≥ 15.67
- **EROI**: EROI ≥ 16.67

```r
# Count high burden households
high_burden_threshold <- 15.67  # Corresponds to 6% Eb

high_burden_count <- sum(nc_data$households[nc_data$nh < high_burden_threshold])
high_burden_pct <- high_burden_count / sum(nc_data$households) * 100
```

## Installation

```r
# Install from GitHub
devtools::install_github("ericscheier/emburden")

# Or for development
devtools::load_all()

# Data downloads automatically on first use!
```

## Running the Full Example

```r
# Run complete NC demonstration
source("analysis/scripts/neb_example_nc.R")

# Or see the detailed vignette
vignette("neb-proper-aggregation", package = "netenergyburden")
```

## Summary Table: Aggregation Methods

| Method | Formula | Status |
|--------|---------|--------|
| Weighted mean of Eb | `weighted.mean(eb, weights)` | ❌ INCORRECT (introduces 1-5% error) |
| **NEB via Nh** | `1 / (1 + weighted.mean(nh, weights))` | ✅ **CORRECT (use this!)** |
| Harmonic mean of Eb | `1 / weighted.mean(1/eb, weights)` | ✅ Correct (but more complex) |
| Simple mean of Eb | `mean(eb)` | ❌ INCORRECT (ignores household weights) |

## Computational Advantage: Arithmetic vs Harmonic Mean

The Nh method transforms the problem from **harmonic mean** (complex) to **arithmetic mean** (simple):

```r
# Via Nh: Uses simple arithmetic weighted mean ✓
nh <- ner_func(income, spending)
nh_mean <- weighted.mean(nh, weights)        # Simple arithmetic mean!
neb <- 1 / (1 + nh_mean)

# Direct EB: Requires harmonic mean (more complex)
eb <- energy_burden_func(income, spending)
neb <- 1 / weighted.mean(1/eb, weights)      # Harmonic mean (complex)
```

**Why arithmetic mean is better** (for aggregation across households):
1. **Simpler** - Uses standard `weighted.mean()` function
2. **More stable** - Avoids division by very small EB values (e.g., 0.01 → 100)
3. **More interpretable** - "Average net return per dollar spent on energy"
4. **Error prevention** - Makes it obvious you can't use arithmetic mean on EB directly

**Important**: This computational advantage applies **only when aggregating across multiple households**. For single household calculations, both methods are mathematically equivalent (NEB = EB = S/G) and require the same operations.

Both aggregation methods are mathematically equivalent and give identical results, but the Nh approach is computationally simpler and numerically more stable when aggregating.

## Why NEB > Eb?

1. **Same interpretability**: NEB = S/G, still shows % of income on energy
2. **Proper aggregation**: Formula makes Nh relationship explicit
3. **Computational simplicity**: Arithmetic mean instead of harmonic mean
4. **Numerical stability**: Avoids division by very small values
5. **Conceptual clarity**: Prevents accidental misuse of arithmetic mean
6. **Avoids errors**: Direct Eb averaging can introduce 1-5% error

## Mathematical Identity

At household level:
- **NEB** = 1/(1+Nh) = 1/(1+(G-S)/S) = S/G = **Eb**

For aggregation:
- NEB = 1/(1 + **Nh_mean**)  ← Correct
- mean(Eb) ≠ NEB  ← **Wrong!**

## More Resources

- **Vignette**: `vignette("neb-proper-aggregation")`
- **Full example**: `analysis/scripts/neb_example_nc.R`
- **Paper**: "Net energy metrics reveal striking disparities across United States household energy burdens"
- **Package docs**: https://github.com/ericscheier/emburden

## Contact

For questions or collaboration: [your email here]

---

**Bottom line**: Use `neb_func()` or `ner_func()` for proper aggregation. Never directly average Energy Burden values - always aggregate via Nh first!
