# Data Processing Pipeline Integration Status

## Summary

Successfully located the lost data processing pipeline that converts raw Open EI LEAD data into analysis-ready format!

## What Was Found

### 1. Complete Processing Pipeline (`.private/scripts/`)

**File: `.private/scripts/lead_munging.R`** (917 lines)
- `download_new_lead_folders()` - Downloads state-specific ZIP files from OpenEI
- `raw_to_lead()` - Converts raw OpenEI format → clean standardized format
  - Handles 2016 (SH) and 2018+ ACS vintages
  - Processes building types, creates min_units and detached fields
  - Standardizes column names (FIP→geoid, HINCP→income, ELEP→electricity_spend, etc.)
- `get_lead_dataset()` - Downloads and processes single state
- `get_multiple_states()` - Multi-state parallel processing with data.table
- `lead_to_poverty()` - Aggregates by poverty status

**File: `.private/scripts/methods.R`** (278 lines)
- `paper_methods()` - Main workflow orchestration
  - Calls `get_multiple_states()` to download & process
  - Adds energy burden metrics (energy_burden, eroi, ner, dear)
  - Integrates with Replica building data
  - Downloads EIA natural gas price data
  - Saves as "very_clean_data_*.csv" format

### 2. Database Integration (Already in Package)

**File: `R/lead_data_loaders.R`**
- `try_load_from_database()` ✓ - Works
- `try_import_to_database()` ✓ - Works
- Database file exists: `data/usurdb.db` (640MB)

## What Was Completed

1. **Created `R/lead_processing.R`** with:
   - `raw_to_lead()` - Adapted from `.private/scripts`, handles 2018+ format
   - `lead_to_poverty()` - Aggregates by poverty status
   - `process_lead_cohort_data()` - Main processing workflow

## What Still Needs to be Done

### Phase 1: URL Configuration
The current `download_lead_data()` uses pre-aggregated tract URLs:
- 2022 AMI: `https://data.openei.org/files/6219/lead_ami_tracts_2022.csv`
- 2022 FPL: `https://data.openei.org/files/6219/lead_fpl_tracts_2022.csv`

But `.private/scripts/lead_munging.R` shows raw data comes from state ZIP files:
- Format: `https://data.openei.org/files/573/{STATE}-2018-LEAD-data.zip`
- Example: `https://data.openei.org/files/573/NC-2018-LEAD-data.zip`

**Decision needed:**
- Option A: Download state ZIPs, extract CSVs, process with `raw_to_lead()`
- Option B: Use tract URLs but apply processing to handle their format
- Option C: Hybrid - check if processed files work as-is, fall back to raw processing

### Phase 2: Integrate Processing into Download Workflow

Modify `R/lead_data_loaders.R::download_lead_data()`:

```r
download_lead_data <- function(dataset, vintage, states = NULL, verbose = FALSE) {

  # Download raw data (ZIP or CSV depending on configuration)
  raw_data <- download_from_openei(...)

  # Process raw → clean format
  processed_data <- process_lead_cohort_data(
    data = raw_data,
    dataset = dataset,
    vintage = vintage,
    aggregate_poverty = FALSE  # Keep cohort-level detail
  )

  # Cache processed data
  cache_file <- file.path(cache_dir, paste0("lead_", vintage, "_", dataset, ".csv"))
  readr::write_csv(processed_data, cache_file)

  # Import to database
  try_import_to_database(processed_data, dataset, vintage, verbose)

  return(processed_data)
}
```

### Phase 3: Fix Column Standardization

Update `standardize_cohort_columns()` to handle:
- Raw format: `HINCP`, `ELEP`, `GASP`, `FULP`, `FIP`
- Clean format: `income`, `electricity_spend`, `gas_spend`, `other_spend`, `geoid`
- Package expected: May need `total_` prefix on some columns

### Phase 4: Handle State Filtering

Currently `load_cohort_data()` filters by state after loading all data. With state ZIP files:
- Download only requested states' ZIPs
- Process each state separately
- Combine into single dataframe
- Much more efficient!

### Phase 5: Testing

1. Clear all caches and test from scratch:
```r
# Clear cache
unlink("~/.cache/emburden/", recursive = TRUE)

# Test load (should download, process, save, import to DB)
data <- emburden::load_cohort_data(
  dataset = "ami",
  states = "NC",
  vintage = "2022",
  verbose = TRUE
)

# Second load (should use database - fast!)
data2 <- emburden::load_cohort_data(
  dataset = "ami",
  states = "NC",
  vintage = "2022",
  verbose = TRUE
)

# Test comparison function
result <- emburden::compare_energy_burden(
  dataset = "ami",
  states = "NC",
  group_by = "income_bracket"
)
```

## Key Files Created/Modified

- ✓ Created: `R/lead_processing.R` - Core processing functions
- ⏳ Need to modify: `R/lead_data_loaders.R` - Integrate processing
- ⏳ Need to update: `NAMESPACE` - Export new functions
- ⏳ Need to run: `devtools::document()` - Generate docs
- ⏳ Need to test: End-to-end workflow

## Architecture Decision: Data Sources

**Current approach** (pre-aggregated tract files):
- ➕ Simpler URLs, single file per dataset/vintage
- ➖ No state filtering (downloads entire US)
- ➖ May not be raw format (unclear what processing was already done)

**Original approach** (state ZIP files):
- ➕ State-level filtering (only download what you need)
- ➕ Known raw format (explicit control over processing)
- ➕ Matches `.private/scripts` approach that was working
- ➖ More complex download logic (ZIP extraction)
- ➖ Need to handle multiple files per query

**Recommendation:** Start with state ZIP approach to match working `.private/scripts` code.

## Notes

- The existing `.private/scripts/` code is production-tested and was working
- It includes parallel processing with `doParallel` for performance
- It handles both 2016 and 2018 formats (though we simplified to 2018+ only initially)
- The replica integration and EIA natural gas data are important for full metrics
- Database schema uses table names like: `lead_{vintage}_{dataset}_cohorts`
