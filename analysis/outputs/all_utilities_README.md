# All Utilities Energy Burden Analysis (Generalized)

This generalized analysis calculates energy burden statistics for **all 1,266 utilities** in the United States, with color-coding by utility type.

## Files Created

### Analysis Scripts

1. **`all_utilities_energy_burden.R`**
   - Generalized version of the NC cooperatives analysis
   - Analyzes all utilities across all states
   - Groups by utility type (`company_ty`) and utility name (`company_na`)
   - Can be filtered by state(s) by setting `state_filter` variable
   - Outputs comprehensive CSV results and summary by utility type

2. **`format_all_utilities_table.R`**
   - Formatting functions with utility type color scheme
   - Color palette defined for 8 utility types:
     - **IOU** (Investor-Owned) - Light Blue
     - **DistCoop** (Distribution Cooperative) - Light Green
     - **Coop** (Cooperative) - Medium Green
     - **Muni** (Municipal) - Light Orange
     - **Federal** - Light Red
     - **State** - Light Purple
     - **Private** - Light Gray
     - **PSubdiv** (Political Subdivision) - Light Yellow
   - Functions:
     - `format_all_utilities_table()` - Full formatted table
     - `format_utilities_by_type_table()` - Compact view
     - `format_utility_type_summary()` - Summary by utility type

3. **`render_all_utilities_tables.R`**
   - Creates color-coded formatted tables in multiple formats
   - Includes color legend for utility types
   - Generates:
     - Summary table by utility type
     - Top 100 utilities table (LaTeX/HTML)
     - Top 50 utilities table (Markdown)

### Output Files

4. **`all_utilities_energy_burden_results.csv`** (322KB)
   - Complete results for all 1,266 utilities
   - Includes utility type classification

5. **`all_utilities_type_summary.tex`**
   - LaTeX summary table by utility type
   - 8 utility types summarized

6. **`all_utilities_table.tex`** (9KB)
   - LaTeX table with top 100 utilities
   - Color-coded by utility type using `\rowcolor`
   - Booktabs formatting for publication

7. **`all_utilities_table.html`** (38KB)
   - **Interactive HTML table with color coding**
   - Color legend showing all utility types
   - Scrollable table with top 100 utilities
   - Summary statistics at top
   - Ready to open in any web browser

8. **`all_utilities_table.md`** (28KB)
   - Markdown format for documentation
   - Top 50 utilities
   - GitHub-compatible

## Usage

### Run Analysis for All Utilities

```r
# Analyze all utilities nationwide
source("all_utilities_energy_burden.R")
```

### Filter by State(s)

Edit `all_utilities_energy_burden.R` and set:
```r
state_filter <- "NC"  # Single state
# or
state_filter <- c("NC", "SC", "GA")  # Multiple states
```

### Generate Color-Coded Tables

```r
# After running the analysis
source("render_all_utilities_tables.R")
```

This creates:
- LaTeX tables with color-coded rows
- HTML table with interactive color legend
- Markdown table for documentation

### View Results

**Open in browser:**
```bash
open all_utilities_table.html  # Mac
xdg-open all_utilities_table.html  # Linux
```

**Include in LaTeX document:**
```latex
\input{all_utilities_type_summary.tex}
\input{all_utilities_table.tex}
```

## Key Results

### Overall Statistics
- **1,266 unique utilities** analyzed
- **113.2 million households** total
- **23.9 million households** below poverty line (21.2%)

### By Utility Type

| Utility Type | Count | Total Households | % Below 6% | Median E_b |
|--------------|-------|------------------|------------|------------|
| Federal Utility | 4 | 3.2M | 27% | 5% |
| Distribution Cooperative | 681 | 11.5M | 27% | 4% |
| State Utility | 3 | 963K | 26% | 4% |
| Private Utility | 8 | 3.4M | 20% | 4% |
| Cooperative | 1 | 21K | 34% | 4% |
| Political Subdivision | 80 | 3.0M | 17% | 3% |
| Investor-Owned Utility | 141 | 83.8M | 20% | 3% |
| Municipal Utility | 348 | 7.3M | 20% | 3% |

### Key Findings

- **Federal and cooperative utilities** have the highest median energy burdens (4-5%)
- **Investor-owned and municipal utilities** have lower median burdens (~3%)
- **Distribution cooperatives** serve 11.5M households with 27% below poverty line
- **Investor-owned utilities** serve the largest population (83.8M households)

## Color Coding in Tables

The HTML and LaTeX tables use color coding to visually distinguish utility types:

- 🔵 **Light Blue** - Investor-Owned Utilities (141 utilities)
- 🟢 **Light Green** - Distribution Cooperatives (681 utilities)
- 🟢 **Medium Green** - Cooperatives (1 utility)
- 🟠 **Light Orange** - Municipal Utilities (348 utilities)
- 🔴 **Light Red** - Federal Utilities (4 utilities)
- 🟣 **Light Purple** - State Utilities (3 utilities)
- ⚪ **Light Gray** - Private Utilities (8 utilities)
- 🟡 **Light Yellow** - Political Subdivisions (80 utilities)

This makes it easy to spot patterns across utility types at a glance!

## Comparison to NC Cooperatives Analysis

This generalized version:
- ✅ Extends to all utilities nationwide (not just NC cooperatives)
- ✅ Groups by both utility type and utility name
- ✅ Adds color coding by utility type
- ✅ Includes summary statistics by utility type
- ✅ Can be filtered to specific states
- ✅ Uses the same Nh-based aggregation methodology

## Methodology

Same as NC cooperatives analysis:

1. Energy burden (E_b) converted to N_h
2. Weighted harmonic mean via `calculate_weighted_metrics()`
3. Converted back to energy burden for interpretation
4. Grouped by utility type AND utility name
5. 6% energy burden threshold for poverty line

## Dependencies

- `dplyr` - Data manipulation
- `scales` - Number formatting
- `spatstat` - Weighted statistics
- `knitr` - Table generation (optional)
- `kableExtra` - Advanced table formatting (optional)
