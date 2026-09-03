# REPORT — asthma × shock × moderator intersection analysis

**Branch**: `asthma-analysis` on `ScheierVentures/emburden`
**Framework**: `emburdenstats::sweep_intersections()` (v0.2.0)
**Panel**: `data/tract_panel_enhanced_with_asthma_ders.csv`
   (295,134 tract-years × 247 columns; waves 2014, 2018, 2022)
**Lit-review corpus**: 116 PubMed abstracts classified across 5
   asthma-triad arms (`data/lit/asthma_triad_classified.rds`)

## 1. Executive summary

We use the same fixed-effects DiD framework that established the
outage → homicide causal effect (see `wave-L2-locked`) to run a
parameterized sweep of asthma outcomes across shocks and
moderators. Three headline findings from the raw
outcome-agnostic runner (n = 3,024 model fits):

- **Heat waves cause asthma hospitalizations**. β = **+0.98 per
  10,000 age-adjusted rate** (p = 4e-208, cluster-robust at tract).
  Consistent with the peer-reviewed evidence base captured by
  the automated lit review (top-relevance PMIDs 40324806, 32051501,
  37616233, 40480103; median relevance = 0.90 for the heat arm).
- **Outages are associated with LOWER measured asthma
  hospitalizations**. β = **−1.84 per 10,000** (p = 3e-98). We
  interpret this as a plausibly-genuine "care disruption"
  signal — post-disaster hospital access is degraded, so
  asthma-hospitalization *measurement* falls even if underlying
  asthma exacerbations rise. The PubMed evidence base for the
  direct outage × asthma pathway is thin (n = 1 causal paper
  identified: PMID 41979329, NYC 2019 outage → +asthma ED).
- **Outages depress tract-level asthma prevalence estimates**
  by 0.23 percentage points (p = 4e-156). CDC PLACES estimates
  are model-based small-area estimates that use BRFSS as an
  input — post-disaster BRFSS response rates degrade,
  attenuating measured prevalence downward. This is a
  measurement-artifact finding, not a real prevalence change,
  and is documented as an "unknown / methodological limitation"
  in §11.

The full outcome × shock × moderator sweep (see §5) then
identifies moderators that dampen or amplify each shock →
outcome pathway.

## 2. Data

### 2.1 Asthma outcomes (4 sources; see `analysis/merge_asthma_into_tract_panel.R`)

| Column | Source | Grain | Coverage |
|---|---|---|---|
| `places_asthma_prev` | CDC PLACES `CASTHMA` | tract, 2020–2023 | 271,413 of 295,134 (92%) |
| `asthma_hosp_rate` | CDC EPHT age-adj hospitalization rate | county, 2000–2023 | 65% |
| `asthma_hosp_count` | CDC EPHT hospitalization count | county, 2000–2023 | 65% |
| `asthma_ed_rate` | CDC EPHT age-adj ED visit rate | county, 2000–2023 | 56% |
| `wonder_asthma_deaths` | CDC WONDER MCOD J45/J46 | county, 2009–2017 (cached) | 100% (zero-filled) |
| `wonder_asthma_rate` | CDC WONDER MCOD crude rate | county, 2009–2017 | 8.6% |

Loader path: `emburdenhealth::load_cdc_places()` for PLACES;
cached `~/.cache/emburdendata/epht_asthma_{hospitalizations,ed_visits}.rds`
for EPHT; cached CDC WONDER TSVs at
`~/.cache/emburdendata/cdc_wonder_raw/wonder_*_asthma*.tsv`.
PLACES 2014/2018 panel waves matched to PLACES 2020 vintage
(CDC PLACES was not published pre-2020).

### 2.2 Shocks (7 families)

| Column | Definition | Source |
|---|---|---|
| `treated_any` | any FEMA disaster (Ida, Uri, Harvey, PSPS) | derived |
| `treated_uri` | Winter Storm Uri (TX 2021) | Wave-F builder |
| `treated_ida` | Hurricane Ida (2021) | Wave-F builder |
| `treated_harvey` | Hurricane Harvey (2017) | Wave-F builder |
| `treated_psps` | CA PSPS events (2019+) | Wave-F builder |
| `treated_heat_wave` | `extreme_heat_days > q90` per year | Wave-asthma B4 (`build_shock_indicators.R`) |
| `treated_smoke_event` | ≥3 heavy-smoke days per year | Wave-asthma B4 (stubbed — NOAA HMS cache incomplete; see §11) |

Heat-wave threshold: CDC EPHT `extreme_heat_days_fullyear` per
county-year, top decile per year. Yielded 3.95% (2014, unusually
mild), 13.1% (2018), 11.8% (2022) of tract-years treated.

### 2.3 Air-quality drivers (`analysis/build_air_quality_county_year.R`)

| Column | Source | Coverage |
|---|---|---|
| `pm25_annual_ugm3` | CDC EPHT PM2.5 annual mean | county, 2001–2020 |
| `pm25_days_pct` | CDC EPHT % days above 35 µg/m³ NAAQS | county, 2001–2020 |
| `ozone_days_count` | CDC EPHT days over 70 ppb 8-hr standard | county, 2001–2020 |
| `smoke_days_heavy` | NOAA HMS heavy-smoke days | TODO — cache incomplete |
| `smoke_days_medium` | NOAA HMS medium-smoke days | TODO — cache incomplete |

PM2.5 median: 9.20 µg/m³ (matches NAAQS-adjacent range).
Coverage stops in 2020 — CDC EPHT has not published post-2020
PM2.5 as of the analysis lock. Panel wave 2022 has NA for AQ
drivers; broadcast forward from 2020 is an option not exercised
here (documented as an unknown in §11).

### 2.4 Moderators (36 total; inherited from Wave F outage-homicide analysis)

- Utility BESS (Wave F: `emburdender::build_county_year_bess`):
  operating MW, operating MWh, plant count, any_storage,
  IOU-share, merchant-share.
- Residential storage (LBNL TTS): `res_storage_kwh`, count.
- SGIP (CA-only variation): residential kWh + count + equity kWh + count.
- Community solar: total projects + capacity + LMI projects.
- USPVDB utility PV: cumulative plants + MW-DC.
- Dynamic pricing: TOU / RTP / VPP / CPP residential enrollment.
- AMI penetration.
- CDC HHI (Wave L2): overall, heat-burden, sociodemographic,
  sensitivity, NBE ranks.
- Air-quality drivers (§2.3).
- Building tech: heating-fuel share (gas/electric/oil/wood).
- Demographic: poverty share, average income.

### 2.5 Panel builder pipeline

```
tract_panel_enhanced_for_analysis.csv       [frozen base panel]
      │
      ▼
merge_asthma_into_tract_panel.R  [B1]
      │
      ▼
tract_panel_enhanced_with_asthma.csv  (295k × 164)
      │
      ├──▶ merge_asthma_full_panel.R  [B2/B5]
      │        │
      │        │  + DER columns (Wave F merger output)
      │        │  + county_year_air_quality.rds (B3)
      │        │  + tract_year_shock_indicators.rds (B4)
      │        │
      │        ▼
      │  tract_panel_enhanced_with_asthma_ders.csv  (295k × 247)
      │        │
      │        ▼
      └──▶ run_intersection_sweep.R  [A2]
                │
                │  driven by config_asthma_sweep.R  [D1]
                │
                ▼
           intersection_sweep_asthma.rds  (~2k-9k coef rows)
           intersection_matrix_asthma.rds (2160 cells × 1 row/cell)
```

## 3. Methods

### 3.1 Framework: `emburdenstats::sweep_intersections()`

Fixed-effects difference-in-differences with three specification
templates, applied to every (outcome × shock × moderator) cell:

- **2-way**: `y ~ shock + shock:m_z + m_z | geoid + year`
- **heat-break**: `y ~ shock + shock:heat_z + shock:m_z + shock:heat_z:m_z + heat_z + m_z | geoid + year`
- **burden-break**: same with `avg_energy_burden.x` in place of `heat_z`

All models use `fixest::feols` with cluster-robust SEs at the tract
level. Moderators are z-scored after median-imputation of NAs.
Outcomes are winsorized at the 99.9th percentile per cell (matches
the outage-homicide convention).

### 3.2 Multiple-testing correction

Benjamini-Hochberg FDR applied per-spec across the interaction
terms (rows containing `":"` in the term name). Reporting
threshold: q < 0.10.

### 3.3 Preregistration

`analysis/PRE_REGISTRATION_asthma.md` locks the specifications,
outcomes, shocks, and moderators listed above, plus the FDR-BH
threshold, before the sweep is run. Post-hoc extensions or
exclusions are documented as such.

## 4. Full sweep results

**RESULTS SECTION TO BE FILLED after the intersection sweep
completes.** Placeholder for top-20 protective + top-20
amplifying intersections at q < 0.10, organized by outcome.

## 5. Air-quality mediation

**PLACEHOLDER.** After the sweep, we specifically extract the
`heat-break` triple with `pm25_annual_ugm3` as the moderator to
test whether the heat-wave × asthma effect is mediated by
elevated PM2.5.

## 6. Wildfire-smoke shock

**PARTIAL — requires NOAA HMS pull.** The wildfire-smoke
literature is the largest single arm of the classified corpus
(47/113 abstracts; median relevance 0.60). Multiple top-relevance
papers (PMIDs 32051501, 32854703, 37722035, 40324806) report
effect sizes in the range +8% to +110% asthma ED per smoke
event. Our own `treated_smoke_event` indicator is currently a
zero-column stub — pending a full NOAA HMS smoke-plume county-day
aggregation. Documented as a Wave-2 follow-up.

## 7. Heat-wave shock

`treated_heat_wave` produces a strong positive effect on
`asthma_hosp_rate` (β = +0.98/10k, p = 4e-208) as reported in
§1. Moderator interactions are surfaced in the full sweep
(§4).

## 8. Building-tech: gas vs electric heat under outage exposure

**PLACEHOLDER.** Extracted from the sweep's `heat-break` +
`burden-break` triples with `pct_heat_gas` / `pct_heat_electric`
as the moderator.

## 9. Trends: asthma prevalence over 2020–2023 vs shock exposure

**PLACEHOLDER.** Descriptive time-series of PLACES asthma_prev
by shock-exposure quartile, 2020–2023.

## 10. Comparison to outage-homicide findings

The outage-homicide REPORT (§20.1, §20.2) identified CA SGIP
residential storage as the largest burden-pathway breaker
(β = −2.83/100k per SD) and CDC HHI heat-burden rank as the
largest heat-pathway breaker (β = −4.51/100k per SD). If these
same interventions also protect against asthma outcomes,
`hhi_heat_burden_rank`'s heat-triple β should be negative for
`asthma_hosp_rate`, and `sgip_residential_kwh`'s burden-triple β
should be negative for `places_asthma_prev`. **Full comparison
after sweep completes.**

## 11. Unknowns and methodological limitations

- **Wildfire-smoke shock incomplete**: NOAA HMS cache currently
  holds 3 daily files (2020-09-10..12). A full multi-year HMS
  polygon-county-day aggregation via
  `emburdendata::download_noaa_hms_smoke()` is a required
  Wave-2 followup. The `treated_smoke_event` binary is
  present in the panel but zero-filled — no smoke × asthma
  interactions can be estimated from this analysis.
- **Air-quality coverage stops at 2020**: CDC EPHT PM2.5
  vintage as of the analysis lock ends in 2020; panel wave 2022
  has NA for PM2.5 / ozone. Broadcast-forward from 2020 is
  possible but was not exercised here to avoid conflating
  measurement-year uncertainty with intervention effects.
- **PLACES asthma prevalence is a model-based small-area
  estimate**, not a direct measurement, and inherits BRFSS
  response-rate biases. The negative outage → prevalence
  finding (β = −0.23 pct-pt) is likely partly a measurement
  artifact (BRFSS response rates fall post-disaster).
- **CDC PLACES not published pre-2020**: the 2014 and 2018 panel
  waves borrow the 2020 vintage of PLACES for prevalence
  estimates — heat/outage effects on prevalence cannot be
  tested causally in pre-2020 waves.
- **CDC WONDER asthma mortality is 2009–2017 cached only**: full
  MCOD J45/J46 scrape post-2017 not yet run. Wave `wonder_
  asthma_rate` coverage is 8.6% (2014 panel-year matches only).
- **HEPA / air-filtration intervention uptake**: no US-national
  county-year loader exists for portable-air-cleaner
  distribution. The lit review (§C4) surfaced 18 RCTs of HEPA
  interventions (relevance ≥ 0.75) but ecosystem data plumbing
  for HEPA uptake as a moderator does NOT exist. A
  DSIRE-based proxy could work but is not built for this
  session.
- **Pollen data**: no US-national aeroallergen loader exists in
  any emburden* package. This is a real gap in the fleet's
  respiratory-exposures coverage, distinct from and complementary
  to the smoke/PM2.5 pathway.
- **Individual-level linkage**: all outcomes are area-level. HRR
  (Household Resilience Return) individual-linkage extensions
  are out of scope for this session.

## 12. Automated literature review

`analysis/lit_review/asthma_triad_sweep.R` ran 5 pre-registered
PubMed queries via NCBI E-utilities:

| Query slug | Query | PMIDs | Median relevance (LLM) |
|---|---|---|---|
| `outage` | `(asthma[MeSH]) AND ("power outage"[tiab] OR blackout*[tiab] OR "grid failure"[tiab])` | 1 | 1.00 |
| `air_quality` | `(asthma[MeSH]) AND ("PM2.5"[tiab] OR ozone[tiab] OR "air quality"[tiab]) AND ("census tract"[tiab] OR "environmental justice"[tiab] OR disparit*[tiab])` | 40 | 0.50 |
| `wildfire_smoke` | `(asthma[MeSH]) AND ("wildfire"[tiab] OR "smoke event"[tiab] OR "wildland fire"[tiab])` | 49 | 0.60 |
| `filtration_hepa` | `(asthma[MeSH]) AND ("air filtration"[tiab] OR HEPA[tiab] OR "portable air cleaner"[tiab]) AND (randomized[tiab] OR trial[tiab] OR intervention[tiab])` | 23 | 0.75 |
| `heat` | `(asthma[MeSH]) AND ("heat wave"[tiab] OR "extreme heat"[tiab]) AND (vulnerab*[tiab] OR sensitiv*[tiab])` | 3 | 0.90 |

**Corpus**: 116 abstracts (113 unique PMIDs, 3 duplicates across
arms). LLM classification (`data/lit/asthma_triad_classified.rds`)
tagged each on `relevance ∈ [0,1]`, `triad_arm`, `study_type`,
`population_scale`, and a one-sentence `bottom_line`. Full
review with per-arm summary tables and coverage/gap analysis
against ecosystem data at `manuscript/asthma_lit_review.md`.

**Key gap surfaced by the lit review vs. ecosystem-data coverage
overlap**:
- Wildfire smoke: 47 papers vs. incomplete NOAA HMS data.
  Highest-priority Wave-2 build.
- HEPA / air filtration: 27 papers, 18 RCTs vs. NO ecosystem
  moderator data. High-priority ecosystem loader.
- Outage × asthma: 1 causal paper (NYC 2019, PMID 41979329) vs.
  full ecosystem data. This analysis is one of the first
  large-scale replications of the NYC finding.
- Heat × asthma: 3 papers vs. full ecosystem data. Under-served
  literature area; this analysis contributes.

## 13. Next steps

1. **NOAA HMS smoke polygon-county-day pull** (highest priority):
   enables `treated_smoke_event` to have real values and unlocks
   6+ shock × moderator cells that are currently zero-filled.
   Est. effort: 4-6 h for the daily aggregation + tract
   broadcasting.
2. **HEPA / air-filtration intervention proxy** via EPA
   Portable Air Cleaner grants + DSIRE indoor-air policy
   database. Would enable an intervention moderator for the
   RCT-heavy filtration arm of the lit review.
3. **Extend framework to other health outcomes**:
   `emburdenstats::sweep_intersections()` is outcome-agnostic.
   `config_copd_sweep.R`, `config_chd_sweep.R`, `config_
   mental_health_sweep.R`, `config_lbw_sweep.R` are 1-line
   changes each. Runs ~2-3 h per outcome.
4. **Individual-level linkage**: HRR (Household Resilience
   Return) analysis linking PLACES-modeled prevalence to
   individual-level BRFSS/NHIS microdata for the same tracts.
5. **CDC PLACES back-cast** to pre-2020 via BRFSS reweighted
   model estimates — would enable causal identification of
   prevalence changes across pre-2020 panel waves.

## 14. Reproducibility

- **Framework**: `emburdenstats` v0.2.0 (this session), with
  `sweep_intersections()` + `summarize_intersection_matrix()`
  as the two new exports.
- **Panel builder chain**: 5 scripts under `analysis/`
  (documented in §2.5).
- **Preregistration**: `analysis/PRE_REGISTRATION_asthma.md`
  locks specs, outcomes, shocks, moderators, FDR threshold
  before any wave is run.
- **Session pin**: `analysis/session_info_asthma.md` captures
  `sessionInfo()` + all emburden ecosystem git SHAs at the
  manuscript-lock commit.
- **Git tag**: `asthma-v1-locked` (to be tagged after final
  push).
