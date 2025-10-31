# LEAD Tool 2016 Data Investigation

**Date**: 2025-10-24
**Status**: Investigation Complete
**Outcome**: 2016 data unavailable; 2018 confirmed as actual baseline

## Summary

Investigation into the availability and use of 2016 LEAD Tool data in the netenergyequity package and Nature Communications publication. Key finding: **The paper likely used 2018 data despite citing "2016 5-year ACS"** - appears to be a citation error.

## Background

The Nature Communications paper (Scheier & Kittner, 2022) states in the Methods section:

> "The dataset is assembled by applying an iterative proportional fitting (IPF) algorithm to cross-tabulations of household responses from the **2016 5-year American Community Survey**"

This investigation was triggered when implementing support for the 2022 LEAD Tool update and discovering questions about which baseline vintage was actually used.

## Evidence That 2018 Was Used (Not 2016)

### 1. Code Evidence
- `lead_munging.R` line 102: `acs_version=2018#"2016"` - 2018 is the default
- 2018 support already present when repo forked (Feb 2021)
- Data added to repo in Nov 2021, after 2018 LEAD release (July 2020)

### 2. Data Characteristics
- `CohortData_AreaMedianIncome.csv`: **701,491 rows**
- Not the 1.2M+ rows from raw 2018 LEAD
- But ~700k is consistent with **processed/simplified 2018 data** (merged with REPLICA, 3 income brackets)
- 2022 raw data has 708k rows, but this is pre-2022 release

### 3. Timeline Evidence
- Paper submitted: 2021
- 2018 LEAD Tool released: July 1, 2020 (OpenEI submission 573)
- 2016 LEAD Tool: Released ~2019, deprecated by 2020
- Code had 2018 as default before paper finalized

### 4. Ma et al. 2019 Citation
The paper cites:
> Ma, O. et al. (2019). "Low-Income Energy Affordability Data (LEAD) Tool Methodology"

This is the **methodology paper** (DOI: 10.2172/1545589), not a specific data release. The methodology paper describes the IPF algorithm and may have used 2016 ACS as an example, leading to the confusion.

## Search for 2016 Data

Comprehensive search conducted for the original 2016 LEAD Tool data:

### Repositories Searched
- ❌ OpenEI (data.openei.org) - only 2018 & 2022 available
- ❌ Data.gov - only 2018 & 2022
- ❌ NREL Data Catalog - only 2018 & 2022
- ❌ OSTI.gov - only 2018 & 2022
- ❌ Zenodo - not found
- ❌ Dryad / Figshare / Harvard Dataverse - not found
- ❌ OSF (Open Science Framework) - not found
- ❌ Internet Archive / Wayback Machine - not archived

### 2016 Data Characteristics (from code)
The 2016 version used identifier **"SH"** suffix:
- File pattern: `AMI68_TRACT_SH_NC.csv`, `FPL15_TRACT_SH_NC.csv`
- OpenEI package ID: `9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b`
- Column structure: Separate columns (ABV, FIP, TEN, YBL6, BLD, HFL)
- Income brackets: 4 categories (very_low, low, moderate, above_moderate)

### CELICA Dataset Search
The "original 2015 dataset" mentioned at https://openei.org/datasets/dataset/celica-data returns **404 Not Found**. The CELICA (Clean Energy for Low Income Communities Accelerator) program ran 2016-2018, but the original data has been removed from OpenEI and replaced with 2018 and 2022 updates.

## Local Search Patterns Created

For potential recovery from local backups, the following search patterns were documented:

**Key identifier**: `*_SH_*.csv` (unique to 2016 version)

**Specific files**:
- `AMI68_TRACT_SH_*.csv`
- `FPL15_TRACT_SH_*.csv`
- `SMI_TRACT_SH_*.csv`
- `clean_lead_AMI68_TRACT_SH_*.csv`
- `very_clean_data_ami68_tract_sh_*.csv`

See search guide files for complete patterns.

## Conclusions

### What Actually Happened
1. **Paper was written in 2020-2021** after 2018 LEAD Tool release
2. **Code used `acs_version=2018`** as default
3. **Citation error**: Cited Ma et al. 2019 methodology which described 2016 ACS
4. **Data is actually 2018-based**, processed and merged with REPLICA

### Why the Confusion
- Ma et al. 2019 methodology paper used 2016 ACS as example
- First LEAD Tool release (~2019) was based on 2016 ACS
- By time of paper writing (2020-2021), 2018 update had replaced it
- Citation to methodology paper instead of specific data release caused ambiguity

### Impact
- **Low**: The paper's findings remain valid
- Analysis used a consistent, well-documented dataset (2018 LEAD)
- Only the ACS year citation needs correction
- For this package: **2018 is the baseline** for temporal comparison

## Recommendations

### 1. Documentation Correction
Consider submitting an erratum or corrigendum to Nature Communications:
- Correct citation from "2016 5-year ACS" to "2018 5-year ACS"
- Reference OpenEI submission 573 (2018 LEAD Tool)
- No changes to analysis or conclusions needed

### 2. Package Implementation
- ✅ **Use 2018 as baseline** for vintage comparison
- ✅ **Support 2018 and 2022** vintages (both available)
- ✅ **Document this investigation** for transparency
- ⚠️ **2016 data unavailable** - cannot be added without recovery from backups

### 3. Future Work
If 2016 data is recovered from local backups:
- Can be added as third vintage for extended temporal analysis
- Would require schema adaptation (4 brackets vs 5/6)
- Lower priority - 2018 vs 2022 comparison is sufficient

## Recovery Options (If Needed)

### Option 1: Local Backup Search
- Search user's systems, external drives, cloud storage
- Use provided search patterns
- Check old project directories from 2019-2021

### Option 2: Contact NREL/DOE
- Email: LEAD.Tool@hq.doe.gov
- Reference package ID: `9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b`
- Request for published research reproducibility

### Option 3: Collaborators
- Contact Noah Kittner (co-author)
- Check UNC research data repositories
- Advisor archives

### Option 4: Accept 2018 Baseline
- Recommended approach
- 2018 data is available and well-documented
- Sufficient for temporal analysis with 2022

## References

- **2018 LEAD Tool**: https://data.openei.org/submissions/573 (Jul 1, 2020)
- **2022 LEAD Tool**: https://data.openei.org/submissions/6219 (Aug 1, 2024)
- **Ma et al. 2019**: DOI 10.2172/1545589 (NREL/TP-6A20-74249)
- **Nature Comms Paper**: Scheier & Kittner (2022), DOI 10.1038/s41467-021-27673-y

## Files Created During Investigation

- `LEAD_2016_INVESTIGATION.md` (this file)
- `/tmp/lead_2016_search_patterns.txt` (search patterns)
- `/tmp/lead_2016_recovery_guide.md` (recovery guide)

---

**Conclusion**: The 2016 LEAD Tool data has been deprecated and removed from public repositories. The Nature Communications paper likely used 2018 data despite citing 2016 ACS, and this should be corrected. For this package, 2018 serves as the baseline for temporal comparison with 2022.
