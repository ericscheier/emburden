# Zenodo Dataset Regeneration Decision Guide

This guide helps you decide whether to **post-process** existing datasets or **regenerate from scratch**.

## Quick Decision Tree

```
Does the change affect...
│
├─ Column names/renaming only?
│  └─ ✅ POST-PROCESS (fast, no download)
│     → Use: .dev/post-process-zenodo-data.R
│
├─ Adding metadata/derived columns?
│  └─ ✅ POST-PROCESS (if source data unchanged)
│     → Use: .dev/post-process-zenodo-data.R
│
├─ Data loading/downloading logic?
│  └─ ❌ REGENERATE (requires fresh download)
│     → Use: .dev/prepare-zenodo-data-nationwide.R --force-download
│
├─ Aggregation/grouping/filtering during load?
│  └─ ❌ REGENERATE (requires re-processing)
│     → Use: .dev/prepare-zenodo-data-nationwide.R --force-download
│
└─ New data sources or vintages?
   └─ ❌ REGENERATE (new data required)
      → Use: .dev/prepare-zenodo-data-nationwide.R --force-download
```

---

## Examples

### ✅ POST-PROCESS (No Regeneration Needed)

**Scenario**: AMI datasets use `AMI150` column but should use `income_bracket`

**Why**: This is just a column rename on already-correct data

**Command**:
```bash
Rscript .dev/post-process-zenodo-data.R --fix ami-column-rename
```

**Time**: ~1 minute (vs 2-3 hours for full regeneration)

---

**Scenario**: Add a `burden_category` column based on existing `income_bracket`

**Why**: Derived from existing data, no need to re-download

**Command**:
```bash
# Edit post-process-zenodo-data.R to add the transformation
Rscript .dev/post-process-zenodo-data.R
```

---

### ❌ REGENERATE (Full Regeneration Required)

**Scenario**: Change how data is aggregated by census tract

**Why**: Requires re-processing raw OpenEI data

**Command**:
```bash
Rscript .dev/prepare-zenodo-data-nationwide.R --force-download --nationwide-only
```

**Time**: 2-3 hours (downloads 30GB)

---

**Scenario**: Fix a bug in `load_cohort_data()` that affects what data is downloaded

**Why**: Need fresh data with corrected loading logic

**Command**:
```bash
# After fixing R/lead_data_loaders.R:
Rscript .dev/prepare-zenodo-data-nationwide.R --force-download --nationwide-only
```

---

**Scenario**: Add 2020 vintage datasets

**Why**: New data source, doesn't exist in cache

**Command**:
```bash
# After updating datasets list in prepare script:
Rscript .dev/prepare-zenodo-data-nationwide.R --nationwide-only
```

---

## When to Trigger Version Bump

Full regeneration should trigger version management workflow:

### Automatic Version Bump Triggers:
- Changes to `R/lead_data_loaders.R` (data loading logic)
- Changes to dataset aggregation/filtering
- Adding new vintages or data sources
- Changes that affect dataset checksums

### Manual Version Bump (Optional):
- Post-processing fixes (column renames, metadata)
- Documentation changes
- Non-data changes

### Version Bump Workflow:

```bash
# 1. After successful regeneration, bump version
Rscript .dev/bump-version.R --minor  # or --major, --patch

# 2. This automatically:
#    - Updates DESCRIPTION version
#    - Updates NEWS.md
#    - Updates R/zenodo.R checksums
#    - Creates git tag
#    - Commits changes

# 3. Then upload to Zenodo
bash .dev/upload-to-zenodo-nationwide.sh

# 4. Push with tags
git push --follow-tags
```

---

## Cache Management

### Use Cached Data (Recommended for Post-Processing)
```bash
Rscript .dev/prepare-zenodo-data-nationwide.R --nationwide-only --use-cache
```
- Uses existing downloaded data
- Fast (minutes, not hours)
- Ideal when fixing processing bugs, not loading bugs

### Force Fresh Download (Slow but Thorough)
```bash
Rscript .dev/prepare-zenodo-data-nationwide.R --nationwide-only --force-download
```
- Clears cache and re-downloads all data
- Slow (~2-3 hours)
- Required when data source or loading logic changes

### Default (Smart Caching)
```bash
Rscript .dev/prepare-zenodo-data-nationwide.R --nationwide-only
```
- Uses cache if available, downloads if missing
- Good balance for most use cases

---

## Summary

**Post-processing** = Fast fixes to existing data (minutes)
- Column renames
- Adding derived fields
- Metadata updates

**Regeneration** = Full re-download and re-process (hours)
- Data loading changes
- Aggregation changes
- New data sources

**Version bump** = Automatic on regeneration, manual on post-processing
- Triggers when dataset output changes
- Updates DESCRIPTION, NEWS.md, git tags
- Coordinates with Zenodo upload
