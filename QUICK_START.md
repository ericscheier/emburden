# Quick Start Guide

## Package Status: ✅ Ready to Use

All 52 tests pass! The package is functional and ready for development use.

## Load the Package

### Option 1: Development Mode (Recommended)
```r
# From the project root
devtools::load_all()
```

### Option 2: Install Locally
```r
devtools::install()
library(netenergyequity)
```

### Option 3: Install from GitHub (after pushing)
```r
devtools::install_github("ericscheier/net_energy_equity")
library(netenergyequity)
```

## Clear Conflicts (If You See Warnings)

If you see conflicts about masked functions, it means you previously `source()`d the old helper files.

**Easy fix:**
```r
# Run the cleanup script
source("cleanup_conflicts.R")

# Then reload the package
devtools::load_all()
```

**Or restart R (recommended):**
```r
# In RStudio
.rs.restartR()

# Or restart R and run
devtools::load_all()
```

**Manual cleanup:**
```r
rm(list = c("calculate_weighted_metrics", "colorize", "dear_func",
            "energy_burden_func", "eroi_func", "ner_func", "to_big",
            "to_dollar", "to_million", "to_percent", "to_billion_dollar"))
devtools::load_all()
```

**Note:** The `.Rprofile` file will automatically clean up conflicts on next R restart!

## Quick Examples

### Calculate Energy Metrics

```r
library(netenergyequity)

# Single household
gross_income <- 50000
energy_spending <- 3000

# Net Energy Return (Nh)
nh <- ner_func(gross_income, energy_spending)
print(nh)  # 15.67

# Energy Burden
eb <- energy_burden_func(gross_income, energy_spending)
print(eb)  # 0.06 (6%)

# Or convert from Nh to energy burden
eb_from_nh <- 1 / (nh + 1)
print(eb_from_nh)  # 0.06
```

### Calculate Energy Poverty Threshold

```r
# What Nh value corresponds to 6% energy burden?
nh_poverty_line <- ner_func(g = 1, s = 0.06)
print(nh_poverty_line)  # 15.67

# Any household with Nh ≤ 15.67 is energy poor (≥6% burden)
```

### Analyze Groups with Weighted Statistics

```r
library(dplyr)

# Example data
data <- data.frame(
  utility = rep(c("Utility A", "Utility B"), each = 3),
  ner = c(20, 15, 25, 18, 22, 12),
  households = c(1000, 500, 750, 900, 600, 400)
)

# Calculate weighted metrics by utility
results <- calculate_weighted_metrics(
  graph_data = data,
  group_columns = "utility",
  metric_name = "ner",
  metric_cutoff_level = 15.67,  # 6% poverty threshold
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)

# Convert Nh back to energy burden
results <- results %>%
  mutate(
    energy_burden_median = 1 / (metric_median + 1),
    pct_energy_poor = pct_in_group_below_cutoff
  )

print(results)
```

### Format Results for Tables

```r
# Format as percentages
to_percent(c(0.06, 0.08, 0.12))
# [1] "6%" "8%" "12%"

# Format as dollars
to_dollar(c(1000, 2500, 10000))
# [1] "$1,000" "$2,500" "$10,000"

# Format large numbers
to_big(c(1234, 567890))
# [1] "1,234" "567,890"

# LaTeX-escaped for publications
to_percent(0.06, latex = TRUE)
# [1] "6\\%"
```

## Run Analysis Scripts

The example scripts in `analysis/scripts/` use the package:

```r
# Load package
devtools::load_all()

# Run NC utilities analysis
source("analysis/scripts/nc_all_utilities_energy_burden.R")

# Check outputs
list.files("analysis/outputs/", pattern = "nc_all")
```

## Run Tests

```r
# Run all tests
devtools::test()

# Should see: [ FAIL 0 | WARN 0 | SKIP 0 | PASS 52 ]
```

## Check Package Quality

```r
# Full R CMD check
devtools::check()

# Should pass with no ERRORs, WARNINGs, or NOTEs
```

## Next Steps

1. **Update DESCRIPTION** with your email/ORCID:
   ```r
   usethis::edit_file("DESCRIPTION")
   # Change eric@example.com to your real email
   # Add your ORCID ID
   ```

2. **Test an analysis script**:
   ```r
   devtools::load_all()
   source("analysis/scripts/nc_all_utilities_energy_burden.R")
   ```

3. **View results**:
   ```r
   # Open HTML table in browser
   browseURL("analysis/outputs/nc_all_utilities_energy_burden_results.csv")
   ```

4. **Push to GitHub** (when ready):
   ```bash
   git add -A
   git commit -m "Transform to R package structure

   - Create package infrastructure (DESCRIPTION, NAMESPACE, R/)
   - Add comprehensive documentation and tests
   - Separate analysis code from package code
   - Setup CI/CD with GitHub Actions
   - All 52 tests passing"

   git push origin main
   ```

5. **Enable GitHub Pages**:
   - Go to repository Settings → Pages
   - Source: Deploy from branch `gh-pages`
   - After next push, site will be at: https://ericscheier.github.io/net_energy_equity/

## Troubleshooting

### "Could not find function X"
- Make sure you've loaded the package: `devtools::load_all()`
- Check for typos in function names

### "Object X not found"
- The function needs data as input
- Make sure you've loaded/created the required data

### Tests fail
- Run `devtools::test()` to see which tests fail
- Tests require: dplyr, scales, spatstat, testthat

### Conflicts/masking warnings
- Clear old functions from environment (see "Clear Conflicts" above)
- Restart R session: `.rs.restartR()` in RStudio

## Get Help

```r
# Function help
?ner_func
?calculate_weighted_metrics

# Package help
?netenergyequity

# List all functions
ls("package:netenergyequity")
```

## Success Indicators

✅ `devtools::load_all()` works without errors
✅ `devtools::test()` shows all 52 tests passing
✅ Basic functions work: `ner_func(50000, 3000)` returns 15.67
✅ Analysis script runs: `source("analysis/scripts/nc_all_utilities_energy_burden.R")`

You're ready to go! 🚀
