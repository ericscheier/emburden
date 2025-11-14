# NC → Nationwide Transition Plan

**Goal**: Update package from NC-focused to nationwide US (51 states)

**Status**: Zenodo nationwide data uploaded ✓, now updating code/docs

---

## Phase 1: CRITICAL (Required for next release)

### 1.1 Core Documentation
- [ ] `README.md` - Change primary examples from NC to nationwide
  - Update intro paragraph
  - Change example from `states = "NC"` to multi-state or no filter
  - Update data availability statement

- [ ] `R/zenodo.R` - Already updated ✓
  - Description changed from "NC" to "US Nationwide" ✓

### 1.2 Primary Tests
- [ ] `tests/testthat/test-zenodo-download.R`
  - Currently tests NC data
  - Change to test nationwide data availability

- [ ] `tests/testthat/test-data-loaders.R`
  - Update tests to use multiple states instead of just NC
  - Keep NC as ONE example, but not the ONLY example

### 1.3 Function Documentation
- [ ] `R/compare_burden.R` + `man/compare_energy_burden.Rd`
  - Examples use `states = "NC"`
  - Add examples with multiple states: `states = c("NC", "CA", "TX")`

- [ ] `R/lead_data_loaders.R` + man files
  - `load_cohort_data()` examples
  - `load_census_tract_data()` examples

---

## Phase 2: IMPORTANT (Should do soon)

### 2.1 Vignettes
- [ ] `vignettes/getting-started.Rmd`
  - Primary vignette - should showcase nationwide capability
  - Keep NC examples but add nationwide examples

- [ ] `vignettes/jss-emburden.Rmd`
  - JSS manuscript - can stay NC-focused as case study
  - Add note that nationwide data available

### 2.2 Sample Data
- [ ] Keep `orange_county_sample` (NC) for offline demos
- [ ] Consider adding CA or TX sample data for diversity
- [ ] Update `R/data.R` documentation

### 2.3 Development Docs
- [ ] `.dev/ZENODO_UPLOAD_GUIDE.md` - Update from NC to nationwide
- [ ] `.dev/TEST_ZENODO_DOWNLOAD.md` - Already updated
- [ ] `NEWS.md` - Add nationwide transition notes for v0.4.8

---

## Phase 3: OPTIONAL (Future releases)

### 3.1 Analysis Scripts (in `analysis/`)
These are research outputs, can stay as-is:
- `nc_all_utilities_energy_burden.R`
- `nc_cooperatives_energy_burden.R`
- `nc_comparison_for_email.R`

### 3.2 Research Materials (in `research/`)
These are historical, can stay as-is:
- Manuscripts
- Presentations
- Posters

---

## Key Files to Update (Priority Order)

### Must Update (v0.4.8):
1. `README.md` - Primary package introduction
2. `R/compare_burden.R` - Add nationwide examples
3. `R/lead_data_loaders.R` - Add nationwide examples
4. `man/*.Rd` - Regenerate with roxygen2
5. `tests/testthat/test-data-loaders.R` - Expand tests
6. `NEWS.md` - Document transition

### Should Update (v0.4.9):
7. `vignettes/getting-started.Rmd` - Primary tutorial
8. `vignettes/methodology.Rmd` - If it has examples

### Can Keep as NC:
- `orange_county_sample` data
- JSS vignette (as case study)
- Analysis scripts
- Research materials

---

## Implementation Strategy

### Option A: Gradual Transition (RECOMMENDED)
- **v0.4.8**: Update core docs + examples to nationwide, keep NC as one example
- **v0.4.9**: Expand vignettes to showcase nationwide analysis
- **v0.5.0**: Full nationwide focus, NC is just one state among many

### Option B: Immediate Transition
- All at once in v0.4.8
- More risky, harder to review

### Option C: Dual Focus
- Keep showing NC examples (familiar, small, fast)
- Add nationwide examples alongside
- Best of both worlds

---

## Specific Changes Needed

### README.md
```r
# BEFORE
data <- load_cohort_data("fpl", "2022", states = "NC")

# AFTER (show both!)
# Example 1: Single state (fast, good for learning)
nc_data <- load_cohort_data("fpl", "2022", states = "NC")

# Example 2: Multiple states
southeast <- load_cohort_data("fpl", "2022", states = c("NC", "SC", "GA", "FL"))

# Example 3: Nationwide (all 51 states)
us_data <- load_cohort_data("fpl", "2022")  # No filter = all states
```

### Test Files
```r
# BEFORE
test_that("can load NC data", {
  data <- load_cohort_data("fpl", "2022", states = "NC")
  expect_true(nrow(data) > 0)
})

# AFTER
test_that("can load nationwide data", {
  # Test single state
  nc <- load_cohort_data("fpl", "2022", states = "NC")
  expect_true(nrow(nc) > 0)

  # Test multiple states
  multi <- load_cohort_data("fpl", "2022", states = c("NC", "CA", "TX"))
  expect_true(nrow(multi) > nrow(nc))
  expect_equal(length(unique(multi$state_abbr)), 3)

  # Test all states
  all_states <- load_cohort_data("fpl", "2022")
  expect_true(nrow(all_states) > 500000)  # Should be ~588k
  expect_equal(length(unique(all_states$state_abbr)), 51)
})
```

---

## Regression Concerns

### What Could Break?
1. **Orange County sample data** - Still works, no changes needed
2. **Existing user scripts** - Still work, just with more data available
3. **Vignettes** - May need data size notes for nationwide examples
4. **Tests** - Need to handle larger datasets in tests

### Migration Path for Users
- **No breaking changes** - NC data still available
- **More options** - Can now access any state or nationwide
- **Same API** - `states =` parameter works same way

---

## Timeline

### v0.4.8 (Current Release)
- [x] Upload nationwide data to Zenodo
- [x] Update R/zenodo.R
- [ ] Update README primary examples
- [ ] Update function examples in R/*.R
- [ ] Update core tests
- [ ] Update NEWS.md

### v0.4.9 (Next Release)
- [ ] Expand vignettes with nationwide examples
- [ ] Add multi-state comparison examples
- [ ] Performance guide for large queries

### v0.5.0 (Future)
- [ ] Full nationwide focus in all documentation
- [ ] Remove "proof of concept" language
- [ ] CRAN submission ready

---

## Questions to Resolve

1. **Should we keep Orange County sample data?**
   - YES - valuable for offline demos, small size

2. **Should tests download nationwide data?**
   - NO - too slow, use mock data or small subsets
   - YES - for integration tests (mark as slow)

3. **Should default be NC or nationwide?**
   - Nationwide - shows full capability
   - But provide NC examples for learning

4. **How to handle large datasets in examples?**
   - Use `states = c("NC", "CA")` for speed
   - Note that nationwide is available
   - Show how to filter results

---

## Success Metrics

- [ ] README mentions nationwide in first paragraph
- [ ] All function examples work with multiple states
- [ ] Tests cover nationwide data loading
- [ ] Vignettes show nationwide capability
- [ ] No references to "proof of concept" or "NC only"
- [ ] Users can discover nationwide data easily
