# CAUSE-SPECIFIC MORTALITY IMPLEMENTATION PLAN

**Date**: December 18, 2025
**Purpose**: Identify mechanisms driving the 4 significant heterogeneity findings
**Estimated Time**: 3-4 hours

---

## 🎯 OBJECTIVE

Test if heterogeneity is outcome-specific to identify mechanisms:

| Finding | Hypothesis | Test |
|---------|-----------|------|
| **Flood × DR** (p<10^-117) | DR programs reduce respiratory deaths during floods (indoor air quality) | Test respiratory mortality |
| **PSPS × Renewable** (p<10^-18) | Grid reliability reduces cardiovascular deaths | Test cardiovascular mortality |
| **Ida × Renewable** (p=0.002) | Same as PSPS | Test cardiovascular mortality |
| **Wildfire × Solar** (p=0.001) | Solar + batteries reduce smoke exposure deaths | Test respiratory mortality |

---

## 📋 CAUSE-SPECIFIC OUTCOMES TO SCRAPE

### 1. Cardiovascular Mortality
**ICD-10 Codes:** I00-I99
**Includes:**
- Heart disease (I20-I25)
- Stroke (I60-I69)
- Hypertension (I10-I15)
- Heart failure (I50)

**Hypothesis:** Renewable energy moderates hurricanes through grid reliability → fewer blackouts → AC/medical device access → fewer cardiovascular deaths

---

### 2. Respiratory Mortality
**ICD-10 Codes:** J00-J99
**Includes:**
- COPD (J40-J44)
- Asthma (J45-J46)
- Pneumonia (J12-J18)
- Influenza (J09-J11)

**Hypothesis:**
- Flood × DR: DR programs reduce peak loads → fewer outages → better indoor air quality
- Wildfire × Solar: Solar reduces smoke exposure deaths

---

### 3. Heat-Related Mortality (Optional)
**ICD-10 Codes:** X30
**Includes:** Direct heat exposure

**Hypothesis:** DER programs improve cooling access during heat events

---

### 4. Diabetes Mortality (Optional)
**ICD-10 Codes:** E10-E14
**Test:** If diabetes moderation (p=0.066 from earlier) is outcome-specific

---

### 5. Homicide / Injury Mortality (Added 2026-05-30)
**ICD-10 Codes:**
- `homicide`: X85-Y09, Y87.1, U01-U02 (NCHS 113 cause #125)
- `all_external`: V01-Y98 (broader external-cause umbrella)
- `undetermined`: Y10-Y34, Y87.2 (sensitivity — "was it homicide misclassified")

**Hypothesis:** Power outages compound heat stress (cooling unavailable),
disable street lighting and alarm/surveillance systems, disrupt
communication and emergency response, and concentrate people indoors —
pathways with published effects on interpersonal violence. Effect
concentrates in the energy-limited profile (Rationing × Uncomfortable
cell) where the heat-stress amplification is largest.

**Test infrastructure**: outage is already a treatment in ~15 existing
scripts (`treated_uri`, `treated_ida`, `treated_harvey`, `treated_psps`
in `analysis/integrate_event_outages.R`). Homicide is the new outcome
family — scraper exists in `data-raw/archive/superseded/selenium_cdc_wonder_cause_specific.py`
with the ICD-10 codes above already coded; needs promoting out of archive
and running.

**Analysis plan document**: `~/.claude/plans/abundant-popping-octopus.md`
(six-wave plan: pre-flight, data prep, panel assembly, FE-DiD state +
county-metros + event-study, Bayesian source reconciliation, DALY
roll-up, polar-matrix integration).

**Suppression constraint**: at county-month, homicide counts are dominated
by CDC n<10 suppression outside ~200 large-population counties. Handled
via two-layer design (state-month primary + large-metro county-month as
identification check).

**Structural template**: fork `analysis/wave3a_mediation_resp_asthma.R`
(closest existing outage × burden × DER mediation) as
`analysis/wave_outage_homicide_mediation.R`.

**Distinct from Sections 1-4** in that homicide is a behavioral outcome,
not a direct cardio/resp/heat pathway. The mediator structure is:
`outage → energy_limiting_share × heat_days_above_95f → homicide_rate`.

**Fleet audit (2026-05-30)**: confirmed novel across all 90 fleet
projects + net_energy_equity repo + auto-memory. No prior work on
outage × violence anywhere in the ecosystem.

---

## 🔧 IMPLEMENTATION STEPS

### Step 1: Set Up CDC WONDER Scraper (30 min)

**Base scraper exists:** `../data-raw/selenium_cdc_wonder_scraper.py`

**Modifications needed:**
```python
# Add cause-of-death parameter
request_data = {
    'B_1': 'D176.V9',  # Year
    'B_2': 'D176.V2',  # County
    'M_1': 'D176.M1',  # Deaths
    'M_2': 'D176.M2',  # Population
    'M_3': 'D176.M3',  # Crude Rate

    # ADD: ICD-10 cause codes
    'F_D176.V4': ['I00-I99'],  # Cardiovascular
    # OR
    'F_D176.V4': ['J00-J99'],  # Respiratory
}
```

**Create 2 scraper variants:**
1. `scrape_cardiovascular_mortality.py` (I00-I99)
2. `scrape_respiratory_mortality.py` (J00-J99)

---

### Step 2: Scrape for Years 2018, 2022 (2 hours)

**For each outcome:**
```bash
# Cardiovascular
python scrape_cardiovascular_mortality.py --years 2018,2022 --output cardio_mortality.csv

# Respiratory
python scrape_respiratory_mortality.py --years 2018,2022 --output resp_mortality.csv
```

**Expected outputs:**
- `cardiovascular_mortality_2018_2022.csv` (~3,100 counties × 2 years)
- `respiratory_mortality_2018_2022.csv` (~3,100 counties × 2 years)

---

### Step 3: Process and Merge (30 min)

```r
# Load cause-specific data
cardio <- read_csv("cardiovascular_mortality_2018_2022.csv")
resp <- read_csv("respiratory_mortality_2018_2022.csv")

# Merge with county panel
county_with_causes <- county %>%
  left_join(cardio, by=c("county_code", "year")) %>%
  left_join(resp, by=c("county_code", "year"))

# Save
saveRDS(county_with_causes, "../data/county_panel_cause_specific.rds")
```

---

### Step 4: Test Cause-Specific Heterogeneity (1 hour)

**For each significant combination, test all outcomes:**

```r
# Example: Flood × DR × Energy Burden

# All-cause (already done)
feols(all_cause_mort ~ flood * dr * burden | county + year)
# Result: p < 10^-117

# Cardiovascular
feols(cardio_mort ~ flood * dr * burden | county + year)
# If p > 0.05 → cardiovascular NOT the mechanism

# Respiratory
feols(resp_mort ~ flood * dr * burden | county + year)
# If p < 0.05 → respiratory IS the mechanism!
```

**Decision matrix:**

| All-Cause | Cardio | Resp | Heat | Interpretation |
|-----------|--------|------|------|----------------|
| Sig | Sig | NS | NS | Cardiovascular pathway |
| Sig | NS | Sig | NS | Respiratory pathway |
| Sig | Sig | Sig | NS | Multiple pathways |
| Sig | NS | NS | NS | Other mechanism |

---

### Step 5: Generate Cause-Specific Figures (30 min)

**Create 3 matrices:**
1. All-cause mortality (already have)
2. Cardiovascular mortality
3. Respiratory mortality

**Compare:**
- Which combinations significant for which outcomes?
- Identify mechanism specificity

---

## 📊 EXPECTED RESULTS

### Scenario A: Respiratory-Specific

```
Flood × DR × EB:
  All-cause:      p < 10^-117  ✓
  Cardiovascular: p = 0.45     ✗
  Respiratory:    p < 0.001    ✓

Interpretation: DR reduces respiratory deaths during floods
Mechanism: Better indoor air quality, reduced mold exposure
```

### Scenario B: Cardiovascular-Specific

```
PSPS × Renewable × EB:
  All-cause:      p < 10^-18   ✓
  Cardiovascular: p < 0.001    ✓
  Respiratory:    p = 0.32     ✗

Interpretation: Renewable energy reduces cardiovascular deaths
Mechanism: Grid reliability → fewer blackouts → AC/medical devices
```

### Scenario C: Multiple Pathways

```
All combinations show effects across multiple outcomes
Interpretation: DER effects work through multiple mechanisms
```

---

## 🔬 STATISTICAL CONSIDERATIONS

### Multiple Testing Correction

**Total tests:** 4 combinations × 3 outcomes = 12 tests

**Bonferroni:** p < 0.05/12 = 0.004
**FDR:** Adjust within each family

**Recommended:** Use FDR within each shock×DER combination
```r
# For Flood × DR:
p_values <- c(p_allcause, p_cardio, p_resp)
p_adjusted <- p.adjust(p_values, method="BH")
```

---

### Sample Size Considerations

**All-cause mortality:**
- Flood: 458 counties
- Wildfire: 77 counties
- PSPS: 12 counties

**Cause-specific mortality:**
- Fewer deaths → less power
- Cardiovascular: ~30% of all deaths
- Respiratory: ~10% of all deaths

**Implication:** May lose significance for smaller samples (PSPS, wildfire)

---

## 📁 FILES TO CREATE

### Scraping:
- `scrape_cardiovascular_mortality.py`
- `scrape_respiratory_mortality.py`
- `cardiovascular_mortality_2018_2022.csv`
- `respiratory_mortality_2018_2022.csv`

### Processing:
- `process_cause_specific_mortality.R`
- `county_panel_cause_specific.rds`

### Analysis:
- `test_cause_specific_heterogeneity.R`
- `cause_specific_results.rds`

### Figures:
- `Fig_Cardiovascular_Heterogeneity.png`
- `Fig_Respiratory_Heterogeneity.png`
- `Fig_Mechanism_Comparison.png` (all 3 outcomes side-by-side)

---

## ⏱️ TIMELINE

**Session 1 (Today):** ✅ COMPLETE
- Identified 4 significant combinations
- Generated all-cause mortality matrix
- Documented plan

**Session 2 (Next):** 3-4 hours
- Set up cause-specific scrapers (30 min)
- Scrape cardiovascular + respiratory (2 hours)
- Process and merge (30 min)
- Test heterogeneity (1 hour)
- Generate figures (30 min)

---

## 🎯 EXPECTED SCIENTIFIC CONTRIBUTION

**Current:** "DER effects are heterogeneous by shock and DER type"

**After cause-specific:** "DER effects work through specific health pathways:
- Demand response reduces respiratory mortality during floods
- Renewable energy reduces cardiovascular mortality during power outages
- Solar reduces respiratory mortality during wildfires"

**Impact:**
- Stronger mechanistic story
- Policy-relevant (target DER types to specific risks)
- Publishable in top journal

---

## ✅ READY TO IMPLEMENT

**Everything needed:**
- ✅ Base scraper exists
- ✅ ICD-10 codes identified
- ✅ Processing scripts outlined
- ✅ Analysis plan complete
- ✅ Figure templates ready

**Next session:** Just execute the plan!

---

**End of Plan**
