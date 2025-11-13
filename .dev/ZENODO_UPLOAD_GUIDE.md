# Zenodo Data Hosting Guide

This guide documents how to prepare and upload emburden datasets to Zenodo for CRAN-compliant data hosting.

## Overview

**Problem**: CRAN has a 5MB package size limit, but our full US energy burden datasets exceed 500MB.

**Solution**: Host processed datasets on Zenodo (free, permanent, citable), include small sample data in package, auto-download full data on first use.

## Benefits of Zenodo

1. **Free & Permanent**: Datasets get a DOI and are permanently archived
2. **Fast Downloads**: Better mirrors and CDN than OpenEI
3. **Versioned**: Each upload gets its own DOI for reproducibility
4. **Citable**: Proper academic citation with DOI
5. **CRAN-Friendly**: No package size restrictions

---

## Upload Process

### 1. Prepare PROCESSED Datasets

**IMPORTANT**: Upload PROCESSED, analysis-ready data, NOT raw OpenEI data!

Run the automated data preparation script:

```bash
cd /path/to/emburden

# This script:
# 1. Downloads raw data from OpenEI (if not cached)
# 2. Processes it into analysis-ready format
# 3. Saves processed CSV files ready for Zenodo upload
Rscript .dev/prepare-zenodo-data.R
```

This creates 4 processed datasets in `zenodo-upload/`:

```bash
# 2022 PROCESSED Cohort Data (analysis-ready!)
lead_ami_cohorts_2022_us.csv      # ~200 MB uncompressed, PROCESSED
lead_fpl_cohorts_2022_us.csv      # ~300 MB uncompressed, PROCESSED

# 2018 PROCESSED Cohort Data (analysis-ready!)
lead_ami_cohorts_2018_us.csv      # ~180 MB uncompressed, PROCESSED
lead_fpl_cohorts_2018_us.csv      # ~250 MB uncompressed, PROCESSED
```

**What makes these "processed"?**
- ✅ Aggregated by census tract + income bracket
- ✅ Includes computed energy burden metrics (EROI, NER, DEAR)
- ✅ Standardized column names
- ✅ Ready for immediate analysis (no processing needed)

**Census Tract Data** (optional - can also be bundled in package):
```bash
census_tract_data.csv             # ~40 MB uncompressed
```

### 2. Compress Datasets

Zenodo supports gzip compression for faster transfers:

```bash
cd zenodo-upload/

# Compress each PROCESSED file
gzip -9 -k lead_ami_cohorts_2022_us.csv  # Creates .csv.gz
gzip -9 -k lead_fpl_cohorts_2022_us.csv
gzip -9 -k lead_ami_cohorts_2018_us.csv
gzip -9 -k lead_fpl_cohorts_2018_us.csv

# Verify compression ratios
ls -lh *.csv.gz
```

Expected compression: 70-85% reduction in size.

**Note**: These are PROCESSED files, so they're already smaller than raw data!

### 3. Calculate MD5 Checksums

For data integrity verification:

```bash
md5sum lead_ami_cohorts_2022_us.csv.gz > checksums.txt
md5sum lead_fpl_cohorts_2022_us.csv.gz >> checksums.txt
md5sum lead_ami_cohorts_2018_us.csv.gz >> checksums.txt
md5sum lead_fpl_cohorts_2018_us.csv.gz >> checksums.txt
md5sum census_tract_data.csv.gz >> checksums.txt

cat checksums.txt
```

### 4. Create Zenodo Record

1. Go to https://zenodo.org/ and log in (or create account)
2. Click "New Upload"
3. Fill in metadata:

**Basic Information:**
- **Title**: "emburden: Pre-processed Energy Burden Datasets"
- **Upload type**: Dataset
- **Publication date**: (today's date)
- **DOI**: (leave blank - Zenodo will assign)

**Creators:**
- Name: Eric Scheier
- Affiliation: Emergi Foundation, UNC Chapel Hill
- ORCID: 0000-0001-9849-9089

**Description:**
```
PROCESSED, analysis-ready household energy burden datasets from the DOE Low-Income
Energy Affordability Data (LEAD) Tool, formatted for the emburden R package.

**IMPORTANT**: These are PRE-PROCESSED datasets, not raw OpenEI data. They have been:
- Aggregated by census tract + income bracket
- Enriched with computed energy burden metrics (EROI, NER, DEAR)
- Standardized for immediate analysis
- Quality-checked and validated

This repository provides nationwide census tract-level data on household energy
burden across all 50 US states and District of Columbia, covering ~72,000 census
tracts. Data includes both Area Median Income (AMI) and Federal Poverty Line (FPL)
cohort analyses for 2018 and 2022 vintages.

## Files Included:

- lead_ami_cohorts_2022_us.csv.gz: 2022 AMI cohort data (PROCESSED, analysis-ready)
- lead_fpl_cohorts_2022_us.csv.gz: 2022 FPL cohort data (PROCESSED, analysis-ready)
- lead_ami_cohorts_2018_us.csv.gz: 2018 AMI cohort data (PROCESSED, analysis-ready)
- lead_fpl_cohorts_2018_us.csv.gz: 2018 FPL cohort data (PROCESSED, analysis-ready)
- checksums.txt: MD5 checksums for verification

## Data Processing

Source: Raw LEAD Tool data from OpenEI
Processing: emburden R package data pipeline
Format: CSV (aggregated tract-level cohorts with computed metrics)
Ready for: Immediate analysis, no additional processing required

## Data Sources

Original raw data from:
- DOE LEAD Tool 2022: https://data.openei.org/submissions/6219
- DOE LEAD Tool 2018: https://data.openei.org/submissions/573

Processed using: emburden R package (github.com/ericscheier/emburden)

## Citation

When using this data, please cite:
1. This Zenodo repository (DOI will be provided)
2. The emburden R package
3. The original DOE LEAD Tool publications

## License

CC-BY-4.0 (same as source data)
```

**License:** Creative Commons Attribution 4.0 International

**Keywords:**
- energy burden
- energy poverty
- household energy
- census tracts
- LEAD Tool
- R package
- emburden

**Related Identifiers:**
- Is supplement to: (add emburden GitHub repo)
- Is derived from: https://data.openei.org/submissions/6219
- Is derived from: https://data.openei.org/submissions/573

### 5. Upload Files

1. Drag and drop or click "Choose files"
2. Upload all 6 files (.csv.gz + checksums.txt)
3. Wait for upload to complete (may take 10-30 minutes)
4. Verify all files uploaded successfully

### 6. Publish

1. Review all metadata
2. Click "Publish"
3. **Important**: Save the assigned DOI!

---

## Update R Package Configuration

After publishing, update `R/zenodo.R` with the new DOIs and URLs:

```r
# In R/zenodo.R, function get_zenodo_config():

list(
  concept_doi = "10.5281/zenodo.XXXXXXX",  # Concept DOI (always latest)
  version_doi = "10.5281/zenodo.YYYYYYY",  # This version's DOI

  files = list(
    ami_2022 = list(
      filename = "lead_ami_cohorts_2022_us.csv.gz",
      url = "https://zenodo.org/records/YYYYYYY/files/lead_ami_cohorts_2022_us.csv.gz",
      size_mb = XX,  # Fill in actual size
      md5 = "xxxxxxxxxx"  # From checksums.txt
    ),
    fpl_2022 = list(
      filename = "lead_fpl_cohorts_2022_us.csv.gz",
      url = "https://zenodo.org/records/YYYYYYY/files/lead_fpl_cohorts_2022_us.csv.gz",
      size_mb = XX,
      md5 = "xxxxxxxxxx"
    ),
    # ... repeat for all files
  )
)
```

---

## Testing

After updating configuration:

```r
# Test Zenodo download
devtools::load_all()

# Clear cache first
unlink(file.path("~/.cache/emburden"), recursive = TRUE)

# Try loading data (should download from Zenodo)
nc_data <- load_cohort_data("ami", "NC", "2022", verbose = TRUE)

# Verify it worked
nrow(nc_data)  # Should be > 0
head(nc_data)

# Check that cached file exists
list.files("~/.cache/emburden/")
```

---

## Updating Data (New Versions)

When OpenEI releases new data vintages:

1. Download and process new data
2. Create NEW Zenodo version (don't overwrite!)
3. Update `R/zenodo.R` with new version DOI
4. Bump package version (major.minor.patch)
5. Update NEWS.md with data changes

**Important**: Never delete or replace old Zenodo versions. Each version gets a permanent DOI for reproducibility.

---

## Maintenance Notes

- **Zenodo record URL**: https://zenodo.org/records/XXXXXXX (fill in after upload)
- **Concept DOI**: 10.5281/zenodo.XXXXXXX (fill in after upload)
- **Version 1 DOI**: 10.5281/zenodo.YYYYYYY (fill in after upload)
- **Upload date**: (fill in)
- **File sizes**:
  - ami_2022: XX MB compressed
  - fpl_2022: XX MB compressed
  - ami_2018: XX MB compressed
  - fpl_2018: XX MB compressed
  - census_tracts: XX MB compressed
- **Total size**: ~XXX MB compressed

---

## Troubleshooting

**Upload fails:**
- Try smaller files first to test
- Check Zenodo file size limits (50 GB per file)
- Ensure stable internet connection

**Download fails in R:**
- Verify URLs are correct
- Check firewall/proxy settings
- Test URL manually in browser
- OpenEI fallback should activate automatically

**Checksum mismatch:**
- Re-download file
- Re-calculate checksum
- If persistent, file may be corrupted - re-upload

---

## References

- Zenodo documentation: https://help.zenodo.org/
- CRAN package size policy: https://cran.r-project.org/web/packages/policies.html
- DOE LEAD Tool: https://www.energy.gov/scep/slsc/low-income-energy-affordability-data-lead-tool
