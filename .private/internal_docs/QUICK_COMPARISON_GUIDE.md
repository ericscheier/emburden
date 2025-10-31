# Quick Guide: Comparing 2018 vs 2022 Energy Burden

**Date**: 2025-10-24
**Status**: Ready to use immediately

## Quick Start

```r
library(netenergyequity)

# Compare North Carolina at state level
nc_comparison <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state"
)

print(nc_comparison)
```

## Geographic Levels

### State-Level Comparison
```r
# Single state
state_comp <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state"
)

# Multiple states
multi_state <- compare_vintages(
  dataset = "ami",
  states = c("NC", "SC", "VA"),
  aggregate_by = "state"
)
```

### Census Tract-Level Comparison
```r
# All tracts in a state
tract_comp <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "tract"
)

# Specific tracts (by GEOID)
specific_tracts <- compare_vintages(
  dataset = "ami",
  geoids = c("37031980100", "37051003402"),
  aggregate_by = "tract"
)
```

### Income Bracket Comparison
```r
# Compare across all income brackets
income_comp <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "income_bracket"
)

# Specific income brackets only
low_income_comp <- compare_vintages(
  dataset = "ami",
  states = "NC",
  income_brackets = c("0-30% AMI", "30-60% AMI"),
  aggregate_by = "income_bracket"
)
```

### No Aggregation (Raw Comparison)
```r
# Get all individual cohorts with changes
detailed_comp <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "none"
)
# Returns every tract × income × tenure × unit_type combination
```

## Dataset Options

### Area Median Income (AMI)
```r
ami_comp <- compare_vintages(
  dataset = "ami",  # Most common
  states = "NC",
  aggregate_by = "state"
)
```

### Federal Poverty Line (FPL)
```r
fpl_comp <- compare_vintages(
  dataset = "fpl",  # Alternative income definition
  states = "NC",
  aggregate_by = "state"
)
```

## Understanding the Results

The comparison returns a data frame with these key columns:

### 2018 Metrics (suffix `_2018`)
- `households_2018` - Number of households
- `total_income_2018` - Total income
- `total_electricity_spend_2018` - Total electricity spending
- `total_gas_spend_2018` - Total gas spending
- `total_other_spend_2018` - Other fuel spending

### 2022 Metrics (suffix `_2022`)
- Same as above with `_2022` suffix

### Change Metrics (suffix `_change` or `_pct_change`)
- `households_change` - Absolute change in households
- `households_pct_change` - Percent change in households
- `total_income_change` - Absolute change in income
- `total_income_pct_change` - Percent change in income
- Similar for all spending categories

### Calculating Energy Burden from Results
```r
comparison <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state"
)

# Calculate energy burden for each year
comparison$energy_burden_2018 <- (
  comparison$total_electricity_spend_2018 +
  comparison$total_gas_spend_2018 +
  comparison$total_other_spend_2018
) / comparison$total_income_2018

comparison$energy_burden_2022 <- (
  comparison$total_electricity_spend_2022 +
  comparison$total_gas_spend_2022 +
  comparison$total_other_spend_2022
) / comparison$total_income_2022

# Calculate change in burden
comparison$burden_change <-
  comparison$energy_burden_2022 - comparison$energy_burden_2018

comparison$burden_pct_change <-
  (comparison$burden_change / comparison$energy_burden_2018) * 100
```

## Complete Example: Multi-Level Analysis

```r
library(netenergyequity)
library(dplyr)
library(ggplot2)

# 1. State-level overview
state_results <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state"
) %>%
  mutate(
    energy_burden_2018 = (total_electricity_spend_2018 +
                          total_gas_spend_2018 +
                          total_other_spend_2018) / total_income_2018,
    energy_burden_2022 = (total_electricity_spend_2022 +
                          total_gas_spend_2022 +
                          total_other_spend_2022) / total_income_2022
  )

cat(sprintf("NC State Energy Burden Change: %.2f%% -> %.2f%%\n",
            state_results$energy_burden_2018 * 100,
            state_results$energy_burden_2022 * 100))

# 2. Income bracket analysis
income_results <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "income_bracket"
) %>%
  mutate(
    energy_burden_2018 = (total_electricity_spend_2018 +
                          total_gas_spend_2018 +
                          total_other_spend_2018) / total_income_2018,
    energy_burden_2022 = (total_electricity_spend_2022 +
                          total_gas_spend_2022 +
                          total_other_spend_2022) / total_income_2022
  )

print(income_results[, c("income_bracket",
                         "energy_burden_2018",
                         "energy_burden_2022")])

# 3. Visualize
ggplot(income_results, aes(x = income_bracket)) +
  geom_col(aes(y = energy_burden_2018 * 100, fill = "2018"),
           position = "dodge", alpha = 0.7) +
  geom_col(aes(y = energy_burden_2022 * 100, fill = "2022"),
           position = "dodge", alpha = 0.7) +
  labs(
    title = "Energy Burden by Income: 2018 vs 2022",
    subtitle = "North Carolina",
    x = "Income Bracket (% of Area Median Income)",
    y = "Energy Burden (%)",
    fill = "Year"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# 4. Identify tracts with biggest changes
tract_results <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "tract"
) %>%
  mutate(
    energy_burden_2018 = (total_electricity_spend_2018 +
                          total_gas_spend_2018 +
                          total_other_spend_2018) / total_income_2018,
    energy_burden_2022 = (total_electricity_spend_2022 +
                          total_gas_spend_2022 +
                          total_other_spend_2022) / total_income_2022,
    burden_change = energy_burden_2022 - energy_burden_2018
  ) %>%
  arrange(desc(abs(burden_change)))

# Top 10 tracts with largest burden changes
top_changes <- head(tract_results, 10)
print(top_changes[, c("geoid", "energy_burden_2018",
                       "energy_burden_2022", "burden_change")])
```

## Advanced: Multi-State Regional Analysis

```r
# Compare Southern states
southern_states <- c("NC", "SC", "GA", "VA", "TN")

regional_comp <- compare_vintages(
  dataset = "ami",
  states = southern_states,
  aggregate_by = "state"
) %>%
  mutate(
    energy_burden_2018 = (total_electricity_spend_2018 +
                          total_gas_spend_2018 +
                          total_other_spend_2018) / total_income_2018,
    energy_burden_2022 = (total_electricity_spend_2022 +
                          total_gas_spend_2022 +
                          total_other_spend_2022) / total_income_2022,
    burden_change = energy_burden_2022 - energy_burden_2018
  ) %>%
  arrange(desc(burden_change))

# Visualize regional comparison
ggplot(regional_comp, aes(x = reorder(state, burden_change))) +
  geom_col(aes(y = burden_change * 100), fill = "steelblue") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  coord_flip() +
  labs(
    title = "Change in Energy Burden: 2018 → 2022",
    subtitle = "Southern States",
    x = "State",
    y = "Change in Energy Burden (percentage points)"
  ) +
  theme_minimal()
```

## Combining with Demographic Analysis

```r
# Load census tract data for demographic context
nc_tracts <- load_census_tract_data(states = "NC")

# Get tract-level comparison
tract_comp <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "tract"
) %>%
  mutate(
    energy_burden_2018 = (total_electricity_spend_2018 +
                          total_gas_spend_2018 +
                          total_other_spend_2018) / total_income_2018,
    energy_burden_2022 = (total_electricity_spend_2022 +
                          total_gas_spend_2022 +
                          total_other_spend_2022) / total_income_2022,
    burden_change = energy_burden_2022 - energy_burden_2018
  )

# Join with demographic data
combined <- tract_comp %>%
  left_join(nc_tracts, by = "geoid")

# Analyze by locale type
locale_summary <- combined %>%
  group_by(locale) %>%
  summarize(
    avg_burden_2018 = weighted.mean(energy_burden_2018, households_2018, na.rm = TRUE),
    avg_burden_2022 = weighted.mean(energy_burden_2022, households_2022, na.rm = TRUE),
    avg_change = mean(burden_change, na.rm = TRUE),
    n_tracts = n()
  )

print(locale_summary)
```

## Exporting Results

```r
# Export to CSV
comparison <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "income_bracket"
)

write.csv(comparison,
          "nc_income_bracket_comparison_2018_2022.csv",
          row.names = FALSE)

# Export to Excel (requires openxlsx package)
library(openxlsx)
wb <- createWorkbook()
addWorksheet(wb, "State Level")
addWorksheet(wb, "Income Brackets")

writeData(wb, "State Level", state_results)
writeData(wb, "Income Brackets", income_results)

saveWorkbook(wb, "nc_energy_burden_comparison.xlsx", overwrite = TRUE)
```

## Performance Tips

### For Large Analyses
```r
# Process one state at a time
states <- c("NC", "SC", "GA", "VA", "TN", "FL", "AL", "MS", "LA", "AR")

results_list <- lapply(states, function(st) {
  message("Processing ", st, "...")
  compare_vintages(
    dataset = "ami",
    states = st,
    aggregate_by = "state"
  )
})

# Combine results
all_results <- bind_rows(results_list)
```

### Using Database (Faster)
```r
# Connect to database first
conn <- connect_emrgi_db()

# Pass connection to speed up queries
comparison <- compare_vintages(
  conn = conn,
  dataset = "ami",
  states = "NC",
  aggregate_by = "state"
)

# Don't forget to disconnect
DBI::dbDisconnect(conn)
```

## Troubleshooting

### No database found
```r
# Check data sources
check_data_sources()

# If database missing, falls back to CSV automatically
# or specify CSV path
comparison <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state",
  prefer_csv = TRUE  # Force CSV usage
)
```

### Missing data for a state
Some tracts may not exist in both vintages due to Census boundary changes.
The comparison handles this gracefully, showing NA for missing data.

### Income bracket mapping issues
2018 has 5 brackets, 2022 has 6 brackets. The function handles this by:
- Keeping brackets that exist in both years
- Aggregating when necessary
- Documenting mismatches in output

## See Also

- `LEAD_2022_IMPLEMENTATION_SUMMARY.md` - Full implementation details
- `LEAD_2016_INVESTIGATION.md` - Information about 2016 data
- `data-raw/LEAD_SCHEMA_COMPARISON.md` - Schema differences
- `analysis/scripts/compare_2018_2022_nc.R` - Complete working example

---

**Quick Reference**: `?compare_vintages` for full function documentation
