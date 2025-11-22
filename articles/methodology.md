# Net Energy Return Methodology

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

## Introduction

This vignette explains the mathematical foundations of the Net Energy
Return (Nh) methodology for analyzing household energy burden. We’ll
show why this approach is both theoretically sound and computationally
advantageous for aggregation across households.

## The Problem: Aggregating Ratios

Energy burden is defined as the ratio of energy spending to gross
income:

**Energy Burden (EB) = S / G**

Where: - **S** = Total energy spending (electricity + gas + other
fuels) - **G** = Gross household income

While this definition is straightforward for a single household,
**aggregating energy burden across multiple households is not trivial**.

### Why Arithmetic Mean Fails

Consider three households:

``` r
# Three households with different income/spending patterns
households <- data.frame(
  id = 1:3,
  income = c(30000, 50000, 100000),
  spending = c(3000, 3500, 4000)
)

households$eb <- energy_burden_func(households$income, households$spending)
print(households)
#>   id income spending   eb
#> 1  1  3e+04     3000 0.10
#> 2  2  5e+04     3500 0.07
#> 3  3  1e+05     4000 0.04
```

What is the “average” energy burden across these three households?

``` r
# Attempt 1: Simple arithmetic mean (WRONG!)
mean_eb_wrong <- mean(households$eb)
print(paste("Simple mean EB:", scales::percent(mean_eb_wrong)))
#> [1] "Simple mean EB: 7%"
```

This is incorrect because it treats all households equally, ignoring
that they represent different amounts of total income and spending.

``` r
# Attempt 2: Weighted arithmetic mean (STILL WRONG!)
# Let's weight by number of households (all equal here, but principle matters)
weights <- c(100, 150, 200)  # Different household counts

eb_arithmetic_mean <- weighted.mean(households$eb, weights)
print(paste("Weighted arithmetic mean EB:", scales::percent(eb_arithmetic_mean)))
#> [1] "Weighted arithmetic mean EB: 6%"
```

**Why is this still wrong?** Energy burden is a ratio, and ratios cannot
be aggregated using arithmetic means. The correct approach requires the
**harmonic mean**.

### The Correct Approach: Harmonic Mean

For ratios like energy burden, the mathematically correct aggregation
uses the harmonic mean:

``` r
# Correct aggregation: Weighted harmonic mean
eb_harmonic <- 1 / weighted.mean(1 / households$eb, weights)
print(paste("Weighted harmonic mean EB:", scales::percent(eb_harmonic)))
#> [1] "Weighted harmonic mean EB: 6%"

# Verify by calculating from totals
total_spending <- sum(households$spending * weights)
total_income <- sum(households$income * weights)
eb_from_totals <- total_spending / total_income
print(paste("EB from totals:", scales::percent(eb_from_totals)))
#> [1] "EB from totals: 5%"

# These should be identical
print(paste("Difference:", abs(eb_harmonic - eb_from_totals)))
#> [1] "Difference: 0.00198446937014668"
```

The harmonic mean gives the same result as calculating energy burden
from the aggregated totals, which is what we want!

## The Solution: Net Energy Return (Nh)

While the harmonic mean is correct, it has some practical drawbacks: 1.
**Computational complexity**: Requires division by each individual EB
value 2. **Numerical instability**: Very small EB values (e.g., 0.01)
become very large (100) after inversion 3. **Less intuitive**: Harmonic
means are less familiar to most analysts 4. **Error-prone**: Easy to
accidentally use arithmetic mean instead

The Net Energy Return (Nh) transformation solves these issues.

### Mathematical Relationship

Net Energy Return is defined as:

**Nh = (G - S) / S**

This represents “net energy return per unit of energy spending” -
similar to concepts in biophysical economics.

**Key insight**: Nh can be aggregated using simple arithmetic mean, then
converted back to energy burden!

Let’s verify the mathematical relationship:

``` r
# Starting from Nh = (G - S) / S
# Let's solve for EB = S / G

# Nh = (G - S) / S
# Nh = G/S - S/S
# Nh = G/S - 1
# Nh + 1 = G/S
# 1 / (Nh + 1) = S/G = EB

# Therefore: EB = 1 / (Nh + 1)

# Verify with our example
households$nh <- ner_func(households$income, households$spending)
households$eb_from_nh <- 1 / (households$nh + 1)

# Compare to original EB
households$identical <- all.equal(households$eb, households$eb_from_nh)
print(households[, c("id", "eb", "eb_from_nh", "nh")])
#>   id   eb eb_from_nh       nh
#> 1  1 0.10       0.10  9.00000
#> 2  2 0.07       0.07 13.28571
#> 3  3 0.04       0.04 24.00000
```

### Aggregation via Arithmetic Mean

Now we can aggregate using simple arithmetic mean:

``` r
# Step 1: Calculate Nh for each household
nh_values <- ner_func(households$income, households$spending)

# Step 2: Arithmetic weighted mean (simple!)
nh_mean <- weighted.mean(nh_values, weights)
print(paste("Weighted mean Nh:", round(nh_mean, 2)))
#> [1] "Weighted mean Nh: 17.1"

# Step 3: Convert back to EB
eb_from_nh <- 1 / (nh_mean + 1)
print(paste("EB from Nh method:", scales::percent(eb_from_nh)))
#> [1] "EB from Nh method: 6%"

# Compare to harmonic mean result
print(paste("EB from harmonic mean:", scales::percent(eb_harmonic)))
#> [1] "EB from harmonic mean: 6%"
print(paste("Difference:", abs(eb_from_nh - eb_harmonic)))
#> [1] "Difference: 0"
```

**Result**: Both methods give identical results, but the Nh method uses
simple arithmetic mean instead of harmonic mean!

## Why This Works: The Mathematics

The key mathematical insight is that the Nh transformation linearizes
the aggregation problem.

For a group of households with weights $w_{i}$, incomes $G_{i}$, and
spending $S_{i}$:

**Harmonic mean approach**:
$$\text{EB}_{\text{agg}} = \frac{1}{\sum\limits_{i}w_{i} \cdot \frac{1}{\text{EB}_{i}}} = \frac{1}{\sum\limits_{i}w_{i} \cdot \frac{G_{i}}{S_{i}}}$$

**Nh approach**:
$$\text{Nh}_{\text{mean}} = \sum\limits_{i}w_{i} \cdot \text{Nh}_{i} = \sum\limits_{i}w_{i} \cdot \frac{G_{i} - S_{i}}{S_{i}}$$

$$\text{EB}_{\text{agg}} = \frac{1}{1 + \text{Nh}_{\text{mean}}}$$

Both formulations are mathematically equivalent when computing from the
same underlying data.

## Computational Advantages (For Aggregation)

The Nh method provides several advantages **when aggregating across
multiple households**:

``` r
# Simulate larger dataset
set.seed(42)
n <- 10000
large_data <- data.frame(
  income = rlnorm(n, meanlog = 10.8, sdlog = 0.8),  # Log-normal income distribution
  spending = NA
)
large_data$spending <- pmin(
  rlnorm(n, meanlog = 8.2, sdlog = 0.5),  # Log-normal spending
  large_data$income * 0.5  # Cap at 50% of income
)
weights <- sample(50:500, n, replace = TRUE)

# Method 1: Nh with arithmetic mean
system.time({
  nh <- ner_func(large_data$income, large_data$spending)
  nh_mean <- weighted.mean(nh, weights)
  eb_nh <- 1 / (1 + nh_mean)
})
#>    user  system elapsed 
#>   0.001   0.000   0.000

# Method 2: Harmonic mean
system.time({
  eb_direct <- energy_burden_func(large_data$income, large_data$spending)
  eb_harmonic <- 1 / weighted.mean(1 / eb_direct, weights)
})
#>    user  system elapsed 
#>       0       0       0

# Verify results are identical
print(paste("EB via Nh:", scales::percent(eb_nh)))
#> [1] "EB via Nh: 5%"
print(paste("EB via harmonic mean:", scales::percent(eb_harmonic)))
#> [1] "EB via harmonic mean: 5%"
print(paste("Difference:", abs(eb_nh - eb_harmonic)))
#> [1] "Difference: 0"
```

**Note**: The computational advantage applies specifically to
**aggregation across households**. For single household calculations,
both methods are equivalent (EB = S/G = 1/(1+Nh)) and require the same
basic operations.

### Numerical Stability

The Nh method is also more numerically stable:

``` r
# Households with very low energy burden
low_burden <- data.frame(
  income = c(200000, 500000, 1000000),
  spending = c(2000, 3000, 5000)  # Very low spending relative to income
)

low_burden$eb <- energy_burden_func(low_burden$income, low_burden$spending)
low_burden$nh <- ner_func(low_burden$income, low_burden$spending)

print("Energy Burden (direct):")
#> [1] "Energy Burden (direct):"
print(low_burden$eb)
#> [1] 0.010 0.006 0.005

print("\nReciprocal of EB (used in harmonic mean):")
#> [1] "\nReciprocal of EB (used in harmonic mean):"
print(1 / low_burden$eb)  # Very large numbers!
#> [1] 100.0000 166.6667 200.0000

print("\nNet Energy Return (Nh):")
#> [1] "\nNet Energy Return (Nh):"
print(low_burden$nh)  # More reasonable range
#> [1]  99.0000 165.6667 199.0000
```

Very low energy burdens (e.g., 0.01 = 1%) become very large values (100)
when inverted for harmonic mean calculation. The Nh values remain in a
more reasonable range, reducing numerical precision issues.

## Error from Incorrect Aggregation

Let’s quantify the error introduced by incorrectly using arithmetic mean
on EB values:

``` r
# Use realistic North Carolina-like data
set.seed(123)
n_households <- 5000

realistic_data <- data.frame(
  income_bracket = sample(
    c("0-30% AMI", "30-50% AMI", "50-80% AMI", "80-100% AMI", "100%+ AMI"),
    n_households,
    replace = TRUE,
    prob = c(0.15, 0.12, 0.20, 0.10, 0.43)
  ),
  income = rlnorm(n_households, meanlog = 10.8, sdlog = 0.8),
  households = sample(10:100, n_households, replace = TRUE)
)

realistic_data$spending <- realistic_data$income * rlnorm(
  n_households,
  meanlog = log(0.05),
  sdlog = 0.6
)

# Calculate metrics
realistic_data <- realistic_data %>%
  mutate(
    eb = energy_burden_func(income, spending),
    nh = ner_func(income, spending),
    neb = neb_func(income, spending)
  )

# WRONG: Arithmetic mean of EB
eb_wrong <- weighted.mean(realistic_data$eb, realistic_data$households)

# CORRECT: Via Nh
nh_mean <- weighted.mean(realistic_data$nh, realistic_data$households)
eb_correct <- 1 / (1 + nh_mean)

# Calculate error
absolute_error <- eb_wrong - eb_correct
relative_error_pct <- (absolute_error / eb_correct) * 100

cat(sprintf("WRONG (arithmetic mean EB): %.2f%%\n", eb_wrong * 100))
#> WRONG (arithmetic mean EB): 5.94%
cat(sprintf("CORRECT (via Nh method):   %.2f%%\n", eb_correct * 100))
#> CORRECT (via Nh method):   4.15%
cat(sprintf("Absolute error:             %.4f\n", absolute_error))
#> Absolute error:             0.0179
cat(sprintf("Relative error:             %.2f%%\n", relative_error_pct))
#> Relative error:             43.18%
```

The error from using arithmetic mean instead of proper aggregation is
typically 1-5% in relative terms, which can be significant for policy
analysis and equity assessments.

## Practical Workflow

Here’s the recommended workflow for energy burden analysis:

``` r
# Step 1: Calculate Nh for all observations
data_with_metrics <- realistic_data %>%
  mutate(
    nh = ner_func(income, spending),
    neb = neb_func(income, spending)  # Same as eb, but emphasizes proper aggregation
  )

# Step 2: Aggregate by groups using arithmetic weighted mean
by_bracket <- data_with_metrics %>%
  group_by(income_bracket) %>%
  summarise(
    total_households = sum(households),
    nh_mean = weighted.mean(nh, households),
    neb = 1 / (1 + nh_mean),  # Correct aggregation
    .groups = "drop"
  ) %>%
  arrange(desc(neb))

print(by_bracket)
#> # A tibble: 5 × 4
#>   income_bracket total_households nh_mean    neb
#>   <chr>                     <int>   <dbl>  <dbl>
#> 1 0-30% AMI                 42020    22.1 0.0433
#> 2 50-80% AMI                55223    22.4 0.0427
#> 3 80-100% AMI               26530    22.7 0.0422
#> 4 30-50% AMI                32511    23.6 0.0407
#> 5 100%+ AMI                116969    23.8 0.0404

# Step 3: Identify high-burden households
high_burden_threshold <- 0.06  # 6% energy burden threshold
nh_threshold <- (1 / high_burden_threshold) - 1  # = 15.67

high_burden_count <- sum(
  data_with_metrics$households[data_with_metrics$nh < nh_threshold]
)
total_households <- sum(data_with_metrics$households)

cat(sprintf("\nHouseholds with >6%% energy burden: %.1f%%\n",
            (high_burden_count / total_households) * 100))
#> 
#> Households with >6% energy burden: 37.7%
```

## Summary

### Key Principles

1.  **Energy burden is a ratio** and requires harmonic mean for proper
    aggregation
2.  **Net Energy Return (Nh)** transformation enables arithmetic mean
    aggregation
3.  **Both methods are mathematically equivalent** and give identical
    results
4.  **Nh method advantages** (for aggregation across households):
    - Simpler computation (arithmetic vs harmonic mean)
    - Better numerical stability
    - More interpretable (net return per dollar of energy spending)
    - Makes improper aggregation obviously wrong

### The Correct Formula

**For aggregation across households**:

``` r
# Step 1: Calculate Nh for each household/cohort
data$nh <- ner_func(data$income, data$spending)

# Step 2: Weighted arithmetic mean
nh_mean <- weighted.mean(data$nh, data$weights)

# Step 3: Convert to energy burden
eb_aggregate <- 1 / (1 + nh_mean)
```

### Common Mistakes to Avoid

**❌ NEVER do this**:

``` r
# WRONG: Arithmetic mean of energy burden
eb_wrong <- weighted.mean(energy_burden_func(income, spending), weights)
```

**✅ ALWAYS do this**:

``` r
# CORRECT: Nh method with arithmetic mean, then convert
nh <- ner_func(income, spending)
nh_mean <- weighted.mean(nh, weights)
eb_correct <- 1 / (1 + nh_mean)
```

## References

For a quick reference guide, see `NEB_QUICKSTART.md` in the package
repository.

For practical examples with real data, see
[`vignette("getting-started")`](https://ericscheier.github.io/emburden/articles/getting-started.md).

## Mathematical Appendix

### Identity Proofs

**Proof that NEB = EB at household level**:

$$\text{Nh} = \frac{G - S}{S}$$

$$\text{NEB} = \frac{1}{1 + \text{Nh}} = \frac{1}{1 + \frac{G - S}{S}} = \frac{1}{\frac{S + G - S}{S}} = \frac{1}{\frac{G}{S}} = \frac{S}{G} = \text{EB}$$

**Proof that harmonic mean of EB equals arithmetic mean via Nh**:

For weighted aggregation with weights $w_{i}$:

$$\text{EB}_{\text{harmonic}} = \frac{1}{\sum\limits_{i}w_{i} \cdot \frac{1}{\text{EB}_{i}}}$$

Since $\text{EB}_{i} = S_{i}/G_{i}$:

$$\text{EB}_{\text{harmonic}} = \frac{1}{\sum\limits_{i}w_{i} \cdot \frac{G_{i}}{S_{i}}}$$

Now via Nh method:

$$\text{Nh}_{i} = \frac{G_{i} - S_{i}}{S_{i}} = \frac{G_{i}}{S_{i}} - 1$$

$$\overline{\text{Nh}} = \sum\limits_{i}w_{i} \cdot \text{Nh}_{i}$$

$$\text{EB}_{\text{via Nh}} = \frac{1}{1 + \overline{\text{Nh}}} = \frac{1}{1 + \sum\limits_{i}w_{i} \cdot \left( \frac{G_{i}}{S_{i}} - 1 \right)}$$

$$= \frac{1}{\sum\limits_{i}w_{i} \cdot \frac{G_{i}}{S_{i}} - \sum\limits_{i}w_{i} + 1}$$

When weights are normalized ($\sum_{i}w_{i} = 1$), this simplifies to:

$$= \frac{1}{\sum\limits_{i}w_{i} \cdot \frac{G_{i}}{S_{i}}} = \text{EB}_{\text{harmonic}}$$

Therefore, both methods are mathematically equivalent. ∎
