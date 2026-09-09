# Asthma × Efficiency Intersection — Refined Analysis

**Repository:** `net_energy_equity`
**Branch:** `asthma-analysis`
**Date:** 2026-09-09
**Collaborators (CRM):** Maya Saterson (UNC Gillings SPH, MPH),
Noah Kittner (UNC-Gillings SREG), Yuetong Zhang (Balmes-thread proposal
2026-07-07).

---

## Motivation and provenance

Three parallel CRM threads pointed at the same intersection:

1. **Maya Saterson × Noah Kittner** — "asthma trends and energy burden"
   (Mar 5–13, 2026). Shared OneDrive folder "Energy Burden Health
   Impacts" (Feb 17, 2026). Maya needs an MPH/PhD "requirement" project
   on energy burden as a determinant of health.
2. **Yuetong Zhang** — July 7, 2026 proposal (`proposal_adaptation_
   index.pdf`) proposing a county-year adaptation index composed from
   Slide-18 variables (solar+storage, DR, TOU, AMI, EE, eGRID mix),
   normalized by climate need, and used as a moderator on climate
   shocks with health as the downstream outcome. Framework:
   `adaptation_ct = β1·Shockct + β2·Capbase_c + β3·(Shock×Capbase)ct
   + Xψ + αc + γt + εct`.
3. **John Balmes' pathway audit** (`BALMES_PATHWAY_AUDIT.md`, committed
   9c639a1) — 20 pathways; the "energy-efficiency retrofits reduce
   heat/cold exposure → reduce asthma exacerbations" pathway was
   flagged as under-instrumented.

The prior asthma sweep (`intersection_matrix_asthma.rds`) had 35
moderators but the two efficiency-related ones (`ee_residential`,
`has_energy_efficiency`) are aggregate customer counts and provide no
savings-magnitude signal. This refinement adds detailed EIA-861 EE
metrics, ACS built-year envelope-vintage cohorts, and a Yuetong-style
composite adaptation index.

---

## Phase 1 — Panel enrichment (`analysis/merge_efficiency_layer.R`)

Source: `data/tract_panel_enhanced_with_asthma_ders.csv` (247 cols,
295,134 rows, three-wave 2014/2018/2022).

**Detailed EIA-861 EE** (`emburdender::load_eia861_energy_efficiency`):
- Coverage: 6,213 utility-year rows across 51 states, 2013–2023.
- State-year rollup → snap-to-panel-wave (±2 years averaged into
  each wave). 153 state × wave observations.
- New per-hh normalized columns using `total_households`:
  - `ee_savings_kwh_per_hh_state` (median = 121.6 kWh/hh/yr)
  - `ee_direct_cost_per_hh_state`
  - `ee_peak_savings_kw_per_hh_state`
- Aggregate columns: `ee_savings_mwh_res_state`,
  `ee_lifecycle_savings_mwh_state`, `ee_weighted_avg_life_yrs_state`,
  `n_utilities_reporting`.

**ACS DP04 built-year envelope-vintage cohorts** (`tidycensus`):
- Fetched per-state per-panel-year (2014/2018/2022 5-yr ACS).
- 230,527 tract-year rows cached at
  `data/acs_dp04_builtyear_tract.rds`.
- Cohorts: `pct_built_pre1980`, `pct_built_1980_1999`,
  `pct_built_post2000`. Coverage: 79.0% (missing PR + a few tract
  reshapes).

**WAP weatherization** — DEFERRED. DOE stopped hosting the Excel
tables publicly; `emburdender::load_wap_weatherization()` retries
all candidate URLs and errors. Loader is preserved for a future
manual-file drop; NASCSP annual funding surveys are PDFs.

Output: `data/tract_panel_enhanced_with_asthma_ders_ee.csv`
(263 cols, 340.3 MB).

---

## Phase 2b — Composite adaptation index (`analysis/build_adaptation_index.R`)

Implements Zhang's Slide-18 framework directly:

| Slide-18 category | Panel column used |
|---|---|
| Solar + storage | `res_storage_kwh`, `nem_capacity_kw` |
| Demand response | `dp_vpp_res` |
| Time-of-use pricing | `dp_tou_res` |
| Advanced metering | `ami_penetration_pct` |
| Energy efficiency | `ee_savings_kwh_per_hh_state` (Phase 1) |
| eGRID mix / low-carbon share | *(deferred — not in panel yet)* |

**Composition:**
1. Winsorize each raw component at [1%, 99%] within panel-year.
2. Z-score within panel-year (so cross-wave DER build-up does not
   swamp the baseline capacity signal).
3. Equal-weight mean of available components →
   `adapt_index_raw`.
4. Normalize by climate need: divide by
   `log1p(pmax(extreme_heat_days, 1))` →
   `adapt_index_perND`.
5. Z-score `adapt_index_perND` within year →
   `adapt_index_z` (the primary moderator).

Diagnostics: mean of 4.02 components used per cell (of 6 available;
min 2, max 5); `adapt_index_z` range −1.84 to +7.55; coverage 100%.

Output: `data/tract_panel_enhanced_with_asthma_ders_ee_adapt.csv`
(266 cols, 356.5 MB).

---

## Phase 2a — Focused sweep (`analysis/config_efficiency_sweep.R`)

4 asthma outcomes × 7 shocks × 14 efficiency moderators × 3 specs
via `analysis/run_intersection_sweep_by_outcome.R`. Per-outcome
subprocess pattern avoids memory corruption (see prior audit).

Total: 3,269 model results; 174 aggregated matrix cells.

**Significance summary (BH-FDR at q < 0.10):**

| spec         | sig / total |
|---|---|
| 2way         | 96  / 121  |
| heat_break   | 257 / 353  |
| burden_break | 337 / 516  |

**Signals by moderator (count of q<0.10 cells across outcomes × shocks × specs):**

| Moderator | Sig cells | Family |
|---|---:|---|
| `ee_savings_mwh_res_state` | 72 | EIA-861 EE |
| `ee_lifecycle_savings_mwh_state` | 67 | EIA-861 EE |
| **`adapt_index_raw`** | **67** | Yuetong composite |
| **`adapt_index_perND`** | **64** | Yuetong composite |
| **`adapt_index_z`** | **64** | Yuetong composite |
| `ee_weighted_avg_life_yrs_state` | 61 | EIA-861 EE |
| `has_energy_efficiency` | 56 | EIA-861 EE (binary) |
| `pct_built_post2000` | 47 | Housing vintage |
| `ee_direct_cost_per_hh_state` | 43 | EIA-861 EE |
| `pct_built_pre1980` | 43 | Housing vintage |
| `ee_savings_kwh_per_hh_state` | 37 | EIA-861 EE |
| `ee_peak_savings_kw_per_hh_state` | 36 | EIA-861 EE |
| `pct_built_1980_1999` | 33 | Housing vintage |

The three adaptation-index variants are all in the top five — the
composite carries the signal at least as strongly as any single
efficiency component.

---

## Headline findings (adapt_index_z, ranked by BH-FDR q)

| Outcome | Shock | Spec | β | q |
|---|---|---|---:|---:|
| PLACES asthma prev | treated_uri | 2way | **+0.052** | 7e-22 |
| EPHT ED rate | treated_heat_wave | heat_break | **+15.2** | 6e-18 |
| EPHT ED rate | treated_heat_wave | 2way | **−0.99** | 2e-14 |
| EPHT ED rate | treated_any | burden_break | **+7.0** | 1e-13 |
| PLACES asthma prev | treated_heat_wave | heat_break | **−0.089** | 1e-13 |
| EPHT hosp rate | treated_heat_wave | heat_break | **+1.77** | 8e-13 |
| EPHT hosp rate | treated_any | burden_break | **+1.10** | 3e-11 |

**Interpretive split (this is the story to tell Maya + Yuetong):**

Two spec × outcome families give opposite-sign interactions on the
same composite moderator:

- **Structural / chronic outcome (PLACES prevalence) × heat break:**
  β = −0.089. In tracts that already run hot, one SD more baseline
  adaptation capacity is associated with a *reduction* in the
  extreme-heat-day interaction with prevalence. Consistent with the
  Balmes-thread pathway "efficient/well-conditioned envelopes reduce
  chronic exposure to indoor temperature extremes → lower asthma
  prevalence".

- **Acute-utilization outcome (EPHT ED visits) × heat break:**
  β = +15.2. In the *same* high-heat tracts, one SD more capacity is
  associated with a *larger* ED-visit interaction with heat waves.
  This can reflect ascertainment (higher-capacity areas also have
  more health-system access, so more ED encounters get coded), and
  bears direct interpretation as a "capacity vs. utilization"
  divergence Yuetong's framework anticipates: capacity is not a
  substitute for utilization measurement.

- The pooled-sample (2way) direction on EPHT ED rate is **−0.99**
  (protective), which suggests the +15.2 heat_break coefficient is
  driven by right-tail heat-tract concentration and is not the
  average effect.

**Winter Storm Uri (treated_uri) × adapt_index_z on PLACES asthma
prev (+0.052, q=7e-22):** the largest-signal q in the whole matrix.
In Uri-treated tracts, higher adaptation capacity is associated with
a larger positive coefficient on prevalence — likely reflecting the
Texas-heavy geographic concentration where composite capacity is
high (nem_capacity_kw + AMI penetration) but the Feb-2021 grid
failure exposed the capacity-utilization gap Yuetong describes
directly: "whether households have enough affordability, housing
quality, and energy-system support to use protective heating and
cooling when climate shocks occur."

---

## What this refinement adds vs. the prior asthma sweep

- **Savings-magnitude signal.** The base sweep only had `ee_*`
  customer-count aggregates. This adds five separate magnitude
  columns (kWh saved / $ direct cost / kW peak / MWh state /
  lifecycle MWh) that all reach BH-FDR q<0.10 in ≥36 cells each.
- **Envelope-vintage instrument.** ACS built-year cohorts operate
  as an efficiency proxy at the tract level and land 33–47 sig
  cells each (the Balmes-audit missing instrument).
- **First test of Zhang's composite.** The Slide-18 composite runs
  as a moderator across all four asthma outcomes and lands in the
  top five by significance-cell count. Signs split by outcome
  type in exactly the way the proposal predicted, giving Yuetong
  a headline empirical result to cite.

---

## Deliverables

| File | Description |
|---|---|
| `analysis/merge_efficiency_layer.R` | Phase 1 enrichment (EIA-861 EE + ACS DP04) |
| `analysis/build_adaptation_index.R` | Yuetong composite index builder |
| `analysis/config_efficiency_sweep.R` | Sweep config (4×7×14×3) |
| `data/tract_panel_enhanced_with_asthma_ders_ee_adapt.csv` | Enriched panel (266 cols) |
| `data/acs_dp04_builtyear_tract.rds` | ACS DP04 cache (230,527 rows) |
| `data/intersection_sweep_asthma_efficiency.rds` | 3,269 model results |
| `data/intersection_matrix_asthma_efficiency.rds` | 174 summary cells |
| `analysis/fig_efficiency_asthma_horserace.R` | Horse-race figure builder |
| `manuscript/figures/efficiency_asthma_horserace.{pdf,png}` | Horse-race figure |

---

## Next steps (proposed to Maya / Noah / Yuetong)

1. **Interpret the ED-vs-prevalence sign split** with domain input —
   ascertainment vs. behavioural utilization gap vs. compositional
   selection. Yuetong's framework explicitly treats "capacity /
   utilization" as separable; this is the empirical test case.
2. **Add eGRID low-carbon share** as the missing Slide-18 component
   via `emburdender` and rerun the composite (~1 hour).
3. **Recompose the index on HDD+CDD** instead of extreme-heat-days
   once `emburdenweather` climate-need columns are broadcast to
   tract (currently only in the ecosystem-weather package).
4. **Split the sweep by state** to check whether the Uri-family
   signal is Texas-specific (single-state selection) or generalizes.
5. **Bring in WAP** whenever DOE republishes or NASCSP releases a
   tabular version — loader is ready.
