# Data Sources and Provenance

This directory contains documentation and scripts related to the data used in the `emburden` package.

**Note:** This directory is excluded from the R package build (via `.Rbuildignore`). The actual data files are **not** distributed with the package to keep it under CRAN's 5MB size limit.

## Data Distribution Strategy

The `emburden` package uses an **automatic download system** instead of bundling large datasets:

1. **Primary Source**: Data automatically downloads from OpenEI (U.S. Department of Energy) on first use
2. **Local Caching**: Downloaded data is cached locally for fast subsequent access
3. **Database Integration**: Optional SQLite database for enhanced performance
4. **No Manual Setup**: Users don't need to download anything manually!

### How It Works

```r
library(emburden)

# First use - automatically downloads from OpenEI
nc_data <- load_cohort_data(dataset = "ami", states = "NC")
# ✓ Data downloaded, cached, and imported to database

# Subsequent uses - instant loading from database/cache
nc_data <- load_cohort_data(dataset = "ami", states = "NC")
# ✓ Loaded from local database (fast!)
```

## Data Sources

### 1. DOE Low-Income Energy Affordability Data (LEAD) Tool

**Primary data source** for household energy burden analysis.

#### 2022 Vintage (Latest)
- **OpenEI Submission**: https://data.openei.org/submissions/6219
- **Direct Download Links**:
  - AMI Census Tracts: `https://data.openei.org/files/6219/lead_ami_tracts_2022.csv`
  - Census Tract Metadata: `https://data.openei.org/files/6219/lead_census_tracts_2022.csv`
  - State ZIP files (FPL data): `https://data.openei.org/files/6219/{STATE}-2022-LEAD-data.zip`
- **Coverage**: All 50 states + DC, ~72,000 census tracts
- **Income Brackets**: 6 AMI categories (very_low, low, moderate, mid, high, very_high)
- **Key Features**:
  - 6 AMI brackets (vs. 4 in 2018)
  - Improved demographic breakdowns
  - Updated utility service territories

#### 2018 Vintage (Legacy)
- **OpenEI Submission**: https://data.openei.org/submissions/573
- **Download Format**: State-specific ZIP files
  - Pattern: `https://data.openei.org/files/573/{STATE}-2018-LEAD-data.zip`
  - Example: `https://data.openei.org/files/573/NC-2018-LEAD-data.zip`
- **Income Brackets**: 4 AMI percentages (0-30%, 30-60%, 60-80%, 80-100%, 100%+)
- **Use Case**: Temporal analysis (2018 vs 2022 comparison)

### Data File Structure

#### Census Tract Data
**File**: `CensusTractData.csv` (41MB)
- **Rows**: ~72,000 census tracts
- **Key Columns**:
  - `geoid`: 11-digit census tract identifier (FIPS code)
  - `state_abbr`: State abbreviation
  - `utility_name`: Electric utility serving this tract
  - Demographic variables (population, income, housing)

#### Cohort Data - Area Median Income (AMI)
**File**: `CohortData_AreaMedianIncome.csv` (359MB)
- **Rows**: ~2.4 million cohort records
- **Structure**: Census tract × income bracket × demographics
- **Key Columns**:
  - `geoid`: Census tract identifier
  - `income_bracket`: AMI category (2022: very_low/low/mod/mid/high, 2018: 0-30%/30-60%/etc.)
  - `households`: Number of households in cohort
  - `total_income`: Total household income ($)
  - `total_electricity_spend`: Total electricity spending ($)
  - `total_gas_spend`: Total gas spending ($)
  - `total_other_spend`: Total other fuel spending ($)

#### Cohort Data - Federal Poverty Line (FPL)
**File**: `CohortData_FederalPovertyLine.csv` (737MB)
- **Rows**: ~5 million cohort records
- **Structure**: Similar to AMI, stratified by FPL instead
- **Income Brackets**: 0-100%, 100-150%, 150-200%, 200%+

## Data Vintages and Compatibility

The package supports **temporal analysis** across vintages:

```r
# Compare 2018 vs 2022 for same region
nc_2018 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2018")
nc_2022 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2022")

# Automated comparison
comparison <- compare_vintages(
  dataset = "ami",
  states = "NC",
  aggregate_by = "state"
)
```

**Key Differences**:
- **AMI brackets**: 4 in 2018 → 6 in 2022
- **Data quality**: Improved imputation methods in 2022
- **Utility coverage**: More complete utility mappings in 2022

## Local Data Files

For **development and offline work**, large CSV files can be placed in `data/`:

```
data/
  CensusTractData.csv              # Census tract metadata (2018-based)
  CohortData_AreaMedianIncome.csv  # AMI cohort data (2018-based)
  CohortData_FederalPovertyLine.csv # FPL cohort data (2018-based)
  emrgi_db.sqlite                  # Optional database (auto-generated)
```

**Note on CSV files in data/**: These files are from the **2018 LEAD Tool vintage** and were originally published on Zenodo:
- **Zenodo DOI**: [10.5281/zenodo.5725912](https://zenodo.org/records/5725912)
- **Published**: December 2021
- **Data Source**: DOE LEAD Tool 2018 vintage (https://data.openei.org/submissions/573)
- **Structure**: Same schema as used in the original analysis

These files are:
- **Excluded from package** (via `.Rbuildignore` pattern `^data/`)
- **Not required** (package downloads automatically if missing)
- **Useful for**:
  - Offline development
  - Faster initial load times
  - Custom data processing
  - Reproducing 2018-based analysis
  - Temporal comparison with 2022 data

## Data Processing Pipeline

The package includes data processing functions (in `R/lead_data_loaders.R`):

1. **`load_cohort_data()`**: Main data loader with automatic fallback
   - Tries: Database → Local CSV → OpenEI download
2. **`standardize_cohort_columns()`**: Harmonizes column names across vintages
3. **`download_lead_data()`**: Fetches data from OpenEI
4. **`try_import_to_database()`**: Caches downloaded data in SQLite

## Benchmark Dataset Publication

For **academic citation** and **reproducibility**, consider publishing processed datasets to:

### Option A: Zenodo (Recommended)
- **Pros**: DOI, version control, 50GB limit, permanent hosting
- **Integration**: Already configured via `.zenodo.json`
- **Workflow**:
  1. Upload processed "clean" datasets
  2. Get DOI
  3. Reference in README and paper

### Option B: figshare / Dryad
- Similar to Zenodo, academic-focused data repositories

### Option C: Keep OpenEI as Primary
- DOE LEAD Tool is the official source
- No need to redistribute
- Users get latest data automatically

## Data Schema

See `data-raw/LEAD_SCHEMA_COMPARISON.md` for detailed column definitions and vintage comparisons.

## References

- **DOE LEAD Tool**: https://www.energy.gov/eere/slsc/low-income-energy-affordability-data-lead-tool
- **OpenEI Platform**: https://openei.org/
- **Package Paper**: "Net energy metrics reveal striking disparities across United States household energy burdens"

## Contact

For data access issues or questions:
- Package issues: https://github.com/ericscheier/emburden/issues
- LEAD Tool questions: Contact DOE LEAD team via OpenEI
