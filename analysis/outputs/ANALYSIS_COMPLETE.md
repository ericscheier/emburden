# NC Electric Utilities Energy Burden Analysis - Complete

## Summary

Successfully analyzed energy burden statistics for **all 24 utilities** serving North Carolina, including **17 electric cooperatives**, using the Nh (Net Energy Return) aggregation methodology.

## Dataset Coverage

✅ **Complete coverage**: All NC census tracts in the AMI dataset have utility assignments
- 2,163 unique NC census tracts in AMI data
- 100% have utility type assignments
- 100% have EIA utility IDs
- 19,766 total household cohort records for NC

## Results

### By Utility Type
| Type | Count | Households | % Below 6% | Median E_b |
|------|-------|------------|------------|------------|
| Municipal | 2 | 6,075 | 40% | 6% |
| Distribution Cooperative | 17 | 114,172 | 36% | 5% |
| Investor-Owned | 4 | 3,317,403 | 22% | 4% |
| Federal | 1 | 10,294 | 36% | 4% |

### NC Electric Cooperatives (17)
1. Albemarle Electric Member Corp
2. Blue Ridge Electric Membership Corp
3. Brunswick Electric Member Corp
4. Cape Hatteras Electric Membership Corp
5. Carteret Craven Electric Membership Corp
6. Edgecombe Martin County Electric Membership Corp
7. French Broad Electric Member Corp
8. Halifax Electric Member Corp
9. Haywood Electric Member Corp
10. Mountain Electric Coop Inc
11. Pee Dee Electric Member Corp
12. Piedmont Electric Member Corp
13. Randolph Electric Member Corp
14. Roanoke Electric Member Corp
15. Tideland Electric Member Corp
16. Tri State Electric Member Corp
17. Wake Electric Membership Corp

## Files Generated

### Analysis Scripts
- `nc_all_utilities_energy_burden.R` - Main analysis for all NC utilities
- `format_all_utilities_table.R` - Table formatting with color coding
- `render_nc_all_utilities_tables.R` - Generate formatted tables

### Output Files
- `nc_all_utilities_energy_burden_results.csv` - Complete results (24 utilities)
- `nc_all_utilities_table.html` - **Color-coded HTML** (open in browser)
- `nc_all_utilities_table.tex` - LaTeX tables
- `nc_all_utilities_table.md` - Markdown documentation
- `nc_all_utilities_type_summary.tex` - LaTeX summary by type

### Original NC Cooperatives Analysis
- `nc_cooperatives_energy_burden.R` - Original cooperative-only analysis
- `nc_cooperatives_energy_burden_results.csv` - 17 cooperatives results
- `nc_cooperatives_table.html` - HTML table (cooperatives only)

## Methodology

1. **Data Sources**:
   - `CohortData_AreaMedianIncome.csv` - Energy burden by census tract & cohort
   - `CensusTractData.csv` - Utility service territory mapping

2. **Aggregation**:
   - Energy burden (E_b) converted to N_h (Net Energy Return)
   - N_h = (G - S) / S, where G = income, S = energy spending
   - Weighted harmonic mean via `calculate_weighted_metrics()`
   - Results converted back to energy burden for interpretation

3. **Poverty Line**: 6% energy burden (equivalent to N_h ≤ 15.67)

## Key Findings

- **Overall NC**: 22.5% of households below energy poverty line
- **Cooperatives**: Higher burden (36% below poverty, 5% median E_b)
- **IOUs**: Lower burden (22% below poverty, 4% median E_b)
- **Worst burden**: Cape Hatteras Coop (98% below poverty, 11% median E_b)
- **Best burden**: Piedmont Electric Coop (8% below poverty, 2% median E_b)

## How to View Results

**HTML (recommended):**
```bash
open nc_all_utilities_table.html
```

**LaTeX in document:**
```latex
\input{nc_all_utilities_type_summary.tex}
\input{nc_all_utilities_table.tex}
```

**Regenerate tables:**
```r
source("render_nc_all_utilities_tables.R")
```

## Color Coding

Tables use color coding by utility type:
- 🟢 **Light Green** - Distribution Cooperatives
- 🔵 **Light Blue** - Investor-Owned Utilities
- 🔴 **Light Red** - Federal Utilities
- 🟠 **Light Orange** - Municipal Utilities

---
*Analysis complete: 2025-09-30*
