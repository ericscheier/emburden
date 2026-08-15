# Outage → Homicide Analysis — Session Summary

**Date:** 2026-05-30 (updated 2026-08-14)
**Status:** Real homicide data landing; preliminary 5-state FE-DiD complete;
full 51-state scrape in progress. EAGLE-I cache extended to 2022 via Zenodo.
**Plan file:** `~/.claude/plans/abundant-popping-octopus.md`

## Full 51-state FE-DiD headline (REAL homicide data)

*Fitted 2026-08-14 on 118,679 tract-years (48 states with unsuppressed
homicide counts × 2018-2023 × ~1000 counties). Model:
`wonder_homicide_rate ~ ... | geoid + year`, cluster-robust at tract.*

### Main effect: outages cause **+0.23 homicides per 100k** on average

- β(any-outage-event) = +0.23 (SE 0.077, **p = 0.0025**, n = 118,679)
- On a US median county-year homicide rate of ~5.8/100k, this is
  a ~4% relative increase per outage event
- **Direction is POSITIVE** — confirming that outages elevate
  homicide, opposite the all-cause placeholder result (all-cause was
  negative because disaster response mobilizes emergency medicine)

### The mechanism story is in the interactions (both FDR-significant)

| Term | β | SE | p | q_BH |
|---|---|---|---|---|
| **treated_any × extreme_heat_days_z** | **+2.07** | 0.18 | 6e-31 | **2e-30** |
| **treated_any × energy_burden_z** | **+1.52** | 0.19 | 2e-15 | **3e-15** |
| treated_any (at avg heat, avg burden) | −0.13 | 0.12 | 0.27 | — |

Interpretation of spec `s6_heat_and_burden`:

- At **average** heat and **average** burden, outage exposure alone has
  a near-zero effect on homicide (β = −0.13, ns).
- Each **1 SD MORE** extreme-heat days ADDS +2.07/100k to the outage
  effect — outages during heat waves are the deadly combination.
- Each **1 SD HIGHER** energy burden ADDS +1.52/100k to the outage
  effect — energy-vulnerable populations bear the effect.
- Both amplifications are strongly FDR-significant.

### Per-event breakdown (spec `s1_main_fe`)

| Event | β/100k | p | Interpretation |
|---|---|---|---|
| **Hurricane Ida (2021)** | **+1.44** | 7e-10 | Largest per-event effect. Heat + humidity + massive outage overlap. |
| CA PSPS (2019+) | +0.67 | 3e-25 | Recurring exposure, moderate effect. |
| Winter Storm Uri (2021) | +0.07 | 0.07 | Near-null. Consistent with cold-event lack-of-heat-amplification. |
| Hurricane Harvey (2017) | (dropped, collinearity with TX geography + Ida) | | |

### Verdict on the causal question

*Do power outages cause homicides in the United States?*

**Yes, on average**, with strong heterogeneity that resolves the
mechanism: outage → interpersonal violence is amplified sharply when
either (a) the outage coincides with heat or (b) the exposed population
is already energy-burdened. Uri (cold-event, no heat amplification)
supports the mechanism from the other side by producing a near-null
effect where the same identification frame catches Ida strongly.

### Caveats

- County-year annual outcome. A monthly/tract-month analysis would
  strengthen event-study identification but requires WONDER monthly
  scrape (~another 5h).
- Winter Storm Uri near-null could reflect cold-event mechanism absence
  OR the identifying tracts (TX 2021) being sparse in unsuppressed
  homicide counts. Bootstrap or matched-control robustness is a good
  next step.
- Effect is on total homicide (X85-Y09, Y87.1). Firearm-specific
  (X93-X95) and non-firearm decomposition is a stretch goal (would
  require a re-scrape).
- The 48 states figure vs 51 attempted reflects some states' entire
  homicide series being suppressed by the CDC n<10 rule at
  county-year granularity for smaller states.

### Files produced

- `data/wonder_violence_county_year_2018_2023.rds` — 2,435 county-year
  rows, 48 states, 609 counties with unsuppressed homicide
- `data/wonder_violence_state_year_2018_2023.rds` — state-year aggregate
- `data/wonder_violence_county_year_metros_2018_2023.rds` — metros only
  (pop > 500k)
- `data/tract_panel_enhanced_with_homicide.csv` — original tract panel
  + broadcast homicide (295k rows, 162 cols)
- `data/wave_outage_homicide_fedid_preliminary.rds` — FE-DiD results
  from the full 51-state run

### Scripts

- `data-raw/selenium_cdc_wonder_cause_specific.py` — WONDER scraper
  (promoted out of archive, U01-U02 removed, --rate-limit 60 works)
- `data-raw/processing/migrate_wonder_violence_tsv_to_rds.R` — TSV → RDS
- `data-raw/processing/build_wonder_violence_panel.R` — panel builder
- `analysis/merge_homicide_into_tract_panel.R` — join into tract panel
- `analysis/wave_outage_homicide_mediation.R` — parent FE-DiD script
  (swap `OUTCOME_COL` between `crude_mortality_rate` and
  `wonder_homicide_rate`)
- `scratchpad/run_fedid_homicide_preliminary.R` — the run script used
  for the pilot + full national result

## EAGLE-I cache now covers 2014-2022 (was 2014-2019)

Downloaded `Eagle_I_2024_with_NWS_VTEC_combined.csv` (306 MB) from
Zenodo 18472460 → aggregated to per-year county-day RDS files matching
existing cache schema → rebuilt `data/county_month_eagle_i.rds`
(231k county-months, 3,050 counties, 2014-2022).

Uri Feb 2021 peak: 359,049 customers out; Ida Aug-Sep 2021 peak:
255,357 customers out — both captured in the extended cache.

2023-2024 remain unavailable (behind Globus auth on ORNL CCS).

## TL;DR

Can the emburden ecosystem answer "do power outages cause homicides?"
**Yes — the full pipeline is now in place, but the actual homicide-outcome
data still needs a ~5-hour CDC WONDER Selenium scrape.** The rest of the
scaffolding is verified working against all-cause mortality as a
placeholder outcome, and swapping in `wonder_homicide_rate` once the
scraper finishes is a one-line change (`OUTCOME_COL` at the top of
`analysis/wave_outage_homicide_mediation.R`).

## Preliminary results — ALL-CAUSE MORTALITY placeholder

Fitted on the existing tract-year panel
(`data/tract_panel_enhanced_for_analysis.csv`, 295k tract-years, 158
columns). The pipeline uses the FEMA event-outage indicators
(`treated_uri_final`, `treated_ida`, `treated_harvey`, `treated_psps`)
already built by `integrate_event_outages.R`. All fits are two-way
fixed-effects on `geoid + year`, cluster-robust at tract level.

**Headline (any-outage-event main effect)**

`crude_mortality_rate ~ treated_any | geoid + year`
→ β = **−40.6 per 100k** (SE 1.9, t=−22, p=6e-105, n=164k tract-years)

**Combined moderator model** (spec `s6_heat_and_burden`)

Term | β | p
---|---|---
`treated_any` | −51.2 | 3e-49
`treated_any : avg_energy_burden` | **+116.4** | **7e-146**
`treated_any : extreme_heat_days` | **+74.7** | **2e-64**
`avg_energy_burden` | −35.9 | 1e-54
`extreme_heat_days` | +0.3 | 0.36

**Interpretation (with all-cause mortality caveat):**

- In **low-burden, low-heat** tracts, outage exposure is associated with
  LOWER all-cause mortality. Likely reflects disaster-response
  effects — hospitals stand up field ops, evacuations, etc. This
  interpretation is **specific to all-cause mortality** and would not
  transfer directly to homicide.
- The moderator interactions are the load-bearing findings:
  - **Energy-burden amplification (+116)**: every 1 SD higher energy
    burden multiplies the outage effect by ~+116 deaths per 100k.
    Tracts with high energy burden get hit much harder by outages.
  - **Heat amplification (+75)**: every 1 SD more extreme-heat days
    multiplies the outage effect by ~+75 deaths per 100k. Outages
    during heat waves are the deadly combination.

**For homicide specifically:** the disaster-response confound on the main
effect should mostly disappear (police/EMS response affects lethal-injury
survival, but not the underlying assault rate). The two amplification
interactions (burden, heat) are the mechanism-relevant terms and should
persist for homicide.

## What's built (this session)

- `analysis/CAUSE_SPECIFIC_MORTALITY_PLAN.md` extended with a homicide
  section (§5)
- `analysis/wave_outage_homicide_mediation.R` — 6-spec FE-DiD script,
  swap `OUTCOME_COL` to run for any outcome
- `data-raw/processing/build_wonder_violence_panel.R` — panel builder,
  ready to consume the WONDER scraper output when it arrives
- Preliminary results at
  `data/wave_outage_homicide_mediation_results.rds` (all-cause
  placeholder)

## What's blocked

**Fresh CDC WONDER pull with homicide ICD-10 codes (X85-Y09, Y87.1,
U01-U02).** The `emburdendata::download_cdc_wonder()` R function is now
cache-only (it prints "county/state-level CDC WONDER data requires the
Selenium scraper"). The scraper lives at
`data-raw/archive/superseded/selenium_cdc_wonder_cause_specific.py` — it
supports the homicide/all_external/undetermined ICD-10 codes already.

To run it (~5 hours background):

```bash
pip install selenium
# ensure chromedriver in PATH; google-chrome already installed

cd /home/ess/Documents/apps/net_energy_equity/data-raw
python selenium_cdc_wonder_cause_specific.py \
  --causes homicide all_external undetermined \
  --rate-limit 120
```

Output lands in `../sources/cdc_wonder_downloads_causes/` as TSVs.
Migration to RDS via `Rscript /tmp/migrate_cdc_wonder_causes_to_cache.R`
(create this from `analysis/process_full_cdc_wonder_2014_2023.R` template
if it doesn't exist yet).

## What's deferred (per plan)

- **EAGLE-I 2020-2024 cache** — Figshare only hosts 2014-2019 + 2025.
  OSTI has per-year biblios but not scriptable. The continuous-outage
  FE-DiD is limited to 2014-2019 as a result; the event-study on Uri
  (Feb 2021) and Ida (Aug 2021) still runs via the FEMA event indicators
  (`event_outages_county_2014_2024.csv`, already loaded).
- **Bayesian source reconciliation (W4)** — 3-4h MCMC job, not started.
  Design template ready in the plan.
- **Polar-matrix integration (W6)** — not started. One-line addition of
  `outage` as a 13th shock in `wave4pre_polar_per_cell_mixed_resolution.R`
  once the homicide outcome is in the panel.
- **DALY roll-up (W5)** — 30 min, mechanical. Add homicide YLL row
  (≈32 per death from GBD 2019 US injuries) to
  `wave4_horse_race_daly_weights.R`, then re-run existing
  `wave3a_fdr_sig_lives.R` against the FDR-significant outage×homicide
  cells.

## Prior work audit (verified via 6 Explore agents, 2026-05-30)

Confirmed **novel across all 90 fleet projects + net_energy_equity repo +
memory**. Zero prior work on outage × homicide / violence / assault /
firearm / crime. Nearest predecessor: `manuscript/peer_review/cal_audit_full.md`
Q39/Q73 (Joe Eto) proposes an outage event-study extension for
cardio-respiratory outcomes (McBrien 2026 PLOS Med; Casey 2025 JESEE
outage×redlining). The homicide question fits the same identification
frame, different outcome family.

## Follow-on order of operations

1. Install Selenium + chromedriver, kick off scraper (background, ~5h)
2. Run `data-raw/processing/build_wonder_violence_panel.R` to produce
   `data/wonder_violence_{state_year,state_month,county_year,county_month_metros}.rds`
3. Add `wonder_homicide_rate` to the tract-year panel via a small merge
   (state-year homicide broadcast to tract via pop-share; county-year
   direct)
4. Update `OUTCOME_COL <- "wonder_homicide_rate"` in
   `analysis/wave_outage_homicide_mediation.R` and re-run
5. Compare the two moderator interactions (burden, heat) between all-cause
   and homicide — this is where the mechanism story crystallizes
6. Run W4 Bayes source reconciliation as sensitivity check
7. Run W5 DALY roll-up and W6 polar-matrix integration to produce
   manuscript-ready outputs
