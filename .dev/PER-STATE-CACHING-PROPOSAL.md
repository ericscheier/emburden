# Per-State Caching Architecture Proposal

## Problem

Currently, if a nationwide dataset is missing just 1-2 states (e.g., FPL 2022 missing HI and IL), we must re-download all 51 states (~12GB, 30-60 minutes) instead of just the missing states.

**Root Cause**: Individual state ZIP files are not cached - they're downloaded, extracted, then deleted.

## Proposed Architecture

### 1. Cache Structure

```
~/.cache/emburden/
├── lead_2022_fpl_AL.zip          # Individual state ZIPs (kept!)
├── lead_2022_fpl_AK.zip
├── lead_2022_fpl_...
├── lead_2022_fpl_HI.zip          # Missing state
├── lead_2022_fpl_IL.zip          # Missing state
├── lead_2022_fpl_WY.zip
├── lead_2022_fpl.csv             # Merged nationwide CSV
└── emburden_db.sqlite            # Database with nationwide data
```

### 2. Smart Download Logic

#### Before (Current):
```r
download_and_merge_states() {
  for each state in all 51 states:
    download ZIP
    extract CSV
    delete ZIP    # ❌ Lost!
  merge all CSVs
  save merged CSV
}
```

#### After (Proposed):
```r
download_and_merge_states() {
  # 1. Check which states are already cached
  cached_states <- check_cached_state_files(dataset, vintage)
  missing_states <- setdiff(all_states, cached_states)

  # 2. Only download missing states
  for each state in missing_states:
    download ZIP to state-specific file (e.g., lead_2022_fpl_HI.zip)
    keep ZIP for future use    # ✅ Cached!

  # 3. Load all states (cached + newly downloaded)
  for each state in all 51 states:
    if (state ZIP exists):
      extract and load data
    else:
      skip (log warning)

  # 4. Merge and validate
  merge all loaded states
  if (missing states):
    report which states are missing
  save merged CSV
}
```

### 3. Validation & Self-Healing

When validation detects corrupt/incomplete nationwide data:

```r
# Current behavior:
clear_dataset_cache("fpl", "2022")  # Deletes EVERYTHING
re-download all 51 states           # 12GB download

# Proposed behavior:
detect_missing_states(data)         # Returns: ["HI", "IL"]
clear_state_cache("fpl", "2022", c("HI", "IL"))  # Delete only corrupt states
re-download missing 2 states        # 500MB download
merge with 49 cached states         # 1-2 minutes
```

### 4. Functions to Implement

#### `check_cached_state_files(dataset, vintage)`
Returns character vector of states that have valid cached ZIP files.

```r
check_cached_state_files <- function(dataset, vintage) {
  cache_dir <- get_cache_dir()
  all_states <- get_all_states()

  cached <- character()
  for (state in all_states) {
    zip_file <- file.path(cache_dir,
                          sprintf("lead_%s_%s_%s.zip", vintage, dataset, state))
    if (file.exists(zip_file) && file.size(zip_file) > 10000) {  # >10KB
      cached <- c(cached, state)
    }
  }

  return(cached)
}
```

#### `clear_state_cache(dataset, vintage, states)`
Removes specific state ZIP files (for corrupted data).

```r
clear_state_cache <- function(dataset, vintage, states, verbose = TRUE) {
  cache_dir <- get_cache_dir()

  for (state in states) {
    zip_file <- file.path(cache_dir,
                          sprintf("lead_%s_%s_%s.zip", vintage, dataset, state))
    if (file.exists(zip_file)) {
      unlink(zip_file)
      if (verbose) message("  ✓ Deleted: ", basename(zip_file))
    }
  }
}
```

#### Modified `download_and_merge_states()`

```r
download_and_merge_states <- function(dataset, vintage, states, verbose = TRUE) {

  # Check which states are already cached
  cached_states <- check_cached_state_files(dataset, vintage)
  missing_states <- setdiff(states, cached_states)

  if (verbose) {
    message(sprintf("Cached states: %d, Missing states: %d",
                    length(cached_states), length(missing_states)))
    if (length(missing_states) > 0) {
      message("Will download: ", paste(missing_states, collapse = ", "))
    }
    if (length(cached_states) > 0) {
      message("Will load from cache: ", paste(cached_states, collapse = ", "))
    }
  }

  # Download only missing states
  if (length(missing_states) > 0) {
    for (i in seq_along(missing_states)) {
      state <- missing_states[i]
      if (verbose) {
        message(sprintf("[%d/%d] Downloading %s...", i, length(missing_states), state))
      }
      download_single_state_cached(dataset, vintage, state, verbose = FALSE)
    }
  }

  # Load all states (cached + newly downloaded)
  all_data <- list()
  failed_states <- character()

  for (state in states) {
    tryCatch({
      state_data <- load_state_from_cache(dataset, vintage, state, verbose = FALSE)
      if (!is.null(state_data) && nrow(state_data) > 0) {
        all_data[[state]] <- state_data
      } else {
        failed_states <- c(failed_states, state)
      }
    }, error = function(e) {
      warning(sprintf("Failed to load %s: %s", state, e$message))
      failed_states <- c(failed_states, state)
    })
  }

  # Merge and save
  combined_data <- dplyr::bind_rows(all_data)

  # Save merged nationwide CSV
  cache_dir <- get_cache_dir()
  cache_file <- file.path(cache_dir, paste0("lead_", vintage, "_", dataset, ".csv"))
  readr::write_csv(combined_data, cache_file)

  # Import to database
  try_import_to_database(combined_data, dataset, vintage, verbose = verbose)

  return(combined_data)
}
```

### 5. Benefits

✅ **Efficiency**: Download only missing states (minutes vs hours)
✅ **Resilience**: Individual state corruption doesn't require full re-download
✅ **Transparency**: Clear reporting of cached vs downloaded states
✅ **Storage**: ~13GB per dataset (51 states × ~250MB), but saves bandwidth
✅ **Debugging**: Can inspect individual state files

### 6. Disk Space Considerations

**Before**: ~50MB merged CSV per dataset
**After**: ~13GB state ZIPs + ~50MB merged CSV per dataset

**Mitigation**:
- State ZIPs can be deleted after successful merge (optional)
- Add `clear_state_cache()` function for manual cleanup
- Add `--keep-state-cache` flag to regeneration script

### 7. Implementation Priority

1. **Phase 1** (For current regeneration):
   - Modify `download_and_merge_states()` to cache state ZIPs
   - Implement `check_cached_state_files()`
   - Test with current FPL 2022 issue

2. **Phase 2** (Post-CRAN):
   - Add `clear_state_cache()` to `R/cache_utils.R`
   - Update corruption detection to identify missing states
   - Implement selective re-download

3. **Phase 3** (Optional):
   - Add cleanup options to regeneration script
   - Implement automatic state cache expiration (30 days?)

### 8. Migration Strategy

Existing users with no cached state files will simply download as before. Once state caching is implemented, future downloads benefit from the per-state cache.

No breaking changes to existing API.

---

## Implementation Decision

**Should we implement this now?**

### Option A: Implement now (before completing current regeneration)
- ✅ PRO: Solves FPL 2022 issue efficiently (download just HI, IL)
- ✅ PRO: Future-proofs against similar issues
- ❌ CON: Delays Zenodo upload by 1-2 hours
- ❌ CON: Requires testing with active downloads

### Option B: Implement after Zenodo upload (post-CRAN)
- ✅ PRO: Current regeneration completes sooner
- ✅ PRO: Can test thoroughly in development
- ✅ PRO: CRAN submission not delayed
- ❌ CON: Must re-download all 51 states for FPL 2022 now

### Recommendation: **Option B**

**Reason**: We're already 71% through AMI 2018 download. Implementing per-state caching now would require:
1. Stopping current regeneration
2. Implementing and testing new code
3. Re-running downloads (losing current progress)

Better to:
1. Complete current regeneration
2. Get clean datasets to Zenodo
3. Implement per-state caching properly in next version
4. Include in v0.6.0 release notes as improvement

This makes per-state caching a **v0.6.0 feature** rather than rushing it into v0.5.x.
