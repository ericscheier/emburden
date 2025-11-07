# Getting Started with emburden

## Introduction

The **emburden** package provides tools for analyzing household energy
burden using the Net Energy Return (Nh) methodology. This vignette will
walk you through the basic workflow for calculating and analyzing energy
burden metrics.

## Installation

You can install emburden from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("ericscheier/emburden")
```

``` r
library(emburden)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
```

## What is Energy Burden?

Energy burden is the ratio of household energy spending to gross income:

**Energy Burden (EB) = S / G**

Where: - **S** = Energy spending (electricity, gas, other fuels) - **G**
= Gross household income

A household spending \$3,000 on energy with \$50,000 income has a 6%
energy burden.

## Quick Example: Single Household

``` r
# Calculate energy burden for a single household
gross_income <- 50000
energy_spending <- 3000

# Method 1: Direct energy burden
eb <- energy_burden_func(gross_income, energy_spending)
print(paste("Energy Burden:", scales::percent(eb)))
#> [1] "Energy Burden: 6%"

# Method 2: Via Net Energy Return (mathematically identical)
nh <- ner_func(gross_income, energy_spending)
neb <- 1 / (nh + 1)
print(paste("Net Energy Burden:", scales::percent(neb)))
#> [1] "Net Energy Burden: 6%"
print(paste("Net Energy Return:", round(nh, 2)))
#> [1] "Net Energy Return: 15.67"
```

For a single household, both methods give the same result: **6% energy
burden**.

## Loading Data

The package automatically downloads data from OpenEI on first use:

``` r
# Load census tract data for North Carolina
nc_tracts <- load_census_tract_data(states = "NC")

# Load household cohort data by Area Median Income
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")

# View structure
head(nc_ami)
```

## Calculating Metrics from Cohort Data

When working with pre-aggregated cohort data (total income and
spending), calculate metrics from the totals:

``` r
# Calculate mean income and spending from totals
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
```

## Aggregating Energy Burden (Critical!)

**⚠️ Important**: Energy burden is a ratio and **cannot be aggregated
using arithmetic mean**!

### The WRONG Way

``` r
# ❌ WRONG: Direct averaging of energy burden introduces ~1-5% error
eb_wrong <- weighted.mean(nc_data$eb, nc_data$households)
```

### The CORRECT Way: Via Net Energy Return

``` r
# ✅ CORRECT: Aggregate using Nh, then convert to NEB
nh_mean <- weighted.mean(nc_data$nh, nc_data$households)
neb_correct <- 1 / (1 + nh_mean)

print(paste("Correct NEB:", scales::percent(neb_correct)))
```

**Why does this work?** The Nh transformation allows us to use simple
arithmetic weighted mean instead of harmonic mean, making aggregation
both simpler and more intuitive.

## Analysis by Income Bracket

``` r
nc_by_income <- nc_data %>%
  group_by(income_bracket) %>%
  summarise(
    households = sum(households),
    nh_mean = weighted.mean(nh, households),
    neb = 1 / (1 + nh_mean),  # Correct aggregation
    .groups = "drop"
  )

print(nc_by_income)
```

## Identifying High Energy Burden Households

The 6% energy burden threshold is commonly used to identify energy
poverty:

``` r
# 6% energy burden corresponds to Nh = 15.67
high_burden_threshold <- 15.67

high_burden_households <- sum(nc_data$households[nc_data$nh < high_burden_threshold])
total_households <- sum(nc_data$households)
high_burden_pct <- (high_burden_households / total_households) * 100

print(paste("Households with >6% energy burden:",
            scales::percent(high_burden_pct/100)))
```

## Using calculate_weighted_metrics()

For more complex grouped analysis, use the built-in function:

``` r
results <- calculate_weighted_metrics(
  graph_data = nc_ami,
  group_columns = "income_bracket",
  metric_name = "ner",
  metric_cutoff_level = 15.67,  # 6% burden threshold
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)

# Format for publication
results$formatted_median <- to_percent(results$metric_median)
print(results)
```

## Key Takeaways

1.  **For single households**: Both EB and NEB give identical results
2.  **For aggregation**: Always use the Nh method to avoid errors
3.  **Never**: Directly average energy burden values
4.  **Data loading**: Automatic from OpenEI (2018 and 2022 vintages
    available)
5.  **Threshold**: 6% energy burden (Nh ≥ 15.67) identifies high burden
    households

## Next Steps

- See
  [`vignette("methodology")`](https://ericscheier.github.io/emburden/articles/methodology.md)
  for mathematical details
- See `NEB_QUICKSTART.md` for quick reference
- Run example scripts in `analysis/scripts/` directory
- Read full documentation:
  [`?energy_burden_func`](https://ericscheier.github.io/emburden/reference/energy_burden_func.md),
  [`?ner_func`](https://ericscheier.github.io/emburden/reference/ner_func.md)

## References

- **Paper**: “Net energy metrics reveal striking disparities across
  United States household energy burdens”
- **LEAD Tool Data**: <https://data.openei.org/>
- **GitHub**: <https://github.com/ericscheier/emburden>
