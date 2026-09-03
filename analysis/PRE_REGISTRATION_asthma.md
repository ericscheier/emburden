# Pre-registration — asthma × shock × moderator intersection analysis

**Locked commit**: (to be tagged as `asthma-v1-locked` at final push
on the `asthma-analysis` branch of `ScheierVentures/emburden`).

**Reproducibility pin**: `analysis/session_info_asthma.md` captures
R `sessionInfo()` + all 13 emburden ecosystem git SHAs at the lock.

**Panel**: `data/tract_panel_enhanced_with_asthma_ders.csv`
(295,134 tract-year rows × 247 columns; waves 2014, 2018, 2022;
built by `analysis/merge_asthma_full_panel.R`).

**Framework**: `emburdenstats::sweep_intersections()` (v0.2.0)
runs the outcome × shock × moderator × spec grid.

## Registered specifications

All FE-DiD models use tract + year fixed effects, cluster-robust SEs
at the tract level, and outcomes are winsorized at the 99.9th
percentile per cell.

### R1. Full intersection sweep

For each `(outcome, shock, moderator)` cell, fit three specs:

- **2-way**: `y ~ shock + shock:m_z + m_z | geoid + year`
- **heat-break**: `y ~ shock + shock:heat_z + shock:m_z + shock:heat_z:m_z + heat_z + m_z | geoid + year`
- **burden-break**: same with `avg_energy_burden.x` in place of `heat_z`

**Outcomes** (n = 4): `places_asthma_prev`, `asthma_hosp_rate`,
`asthma_ed_rate`, `wonder_asthma_rate`.

**Shocks** (n = 7): `treated_any` (FEMA union), `treated_uri`,
`treated_ida`, `treated_harvey`, `treated_psps`, `treated_heat_wave`,
`treated_smoke_event`.

**Moderators** (n = 36): utility BESS × 5, residential storage × 5,
SGIP × 4, community solar × 3, USPVDB × 2, dynamic pricing × 3,
AMI × 1, HHI × 5, air-quality × 3, building tech × 3, demographic × 2.
Full list at `analysis/config_asthma_sweep.R`.

**Total cells**: 4 × 7 × 36 × 3 = 3,024 model fits.

### R2. Air-quality mediation

Separate wave (`wave_asthma_air_quality_mediation.R`) tests whether
the shock → asthma pathway flows through elevated PM2.5, ozone, or
wildfire smoke. Registered forms:

```
y ~ shock * pm25_z    | geoid + year
y ~ shock * ozone_z   | geoid + year
```

for `y ∈ {asthma_hosp_rate, asthma_ed_rate, places_asthma_prev}` and
`shock ∈ {treated_any, treated_heat_wave, treated_uri_final,
treated_ida, treated_psps}`.

## Registered hypotheses + expected signs

1. **Heat waves increase asthma hospitalizations** (β > 0 for
   `asthma_hosp_rate ~ treated_heat_wave`). Prior: strong literature
   (§Lit Review, heat arm median relevance 0.90).
2. **Outages increase asthma ED visits at neighborhood scale** (β > 0
   for `asthma_ed_rate ~ treated_any` under heat conditions). Prior:
   PMID 41979329 (NYC 2019 outage, OR = 2.23). Alternate hypothesis:
   post-disaster care disruption may drive β < 0 for hospitalizations
   (documented as a measurement caveat).
3. **PM2.5 mediates the shock → asthma pathway** (β > 0 for
   `shock:pm25_z` interaction).
4. **Utility BESS + residential storage protect** against outage ×
   asthma (heat-break triple β < 0 for BESS and residential storage
   moderators × outage shocks).
5. **CDC HHI heat-burden rank protects** against heat × asthma
   (heat-break triple β < 0 for `hhi_heat_burden_rank`), replicating
   the Wave-L2 outage-homicide result on an asthma outcome.

## Multiple-testing correction

- **R1**: Benjamini-Hochberg FDR per-spec across all interaction
  terms (rows containing `":"`). Threshold: q < 0.10.
- **R2**: BH-FDR across all interaction terms from the AQ mediation
  fits.
- **R3–R5**: pre-registered specific hypotheses; no additional
  correction beyond R1.

## Data source lock

- Base panel: `tract_panel_enhanced_for_analysis.csv` frozen
  Dec 15 2025.
- CDC PLACES: 2020 + 2022 vintages via `emburdenhealth::load_cdc_places()`.
- CDC EPHT asthma: cached RDS `epht_asthma_{hospitalizations,ed_visits}.rds`,
  vintage 2000–2023 with 2020 as most recent complete year.
- CDC WONDER asthma MCOD (J45/J46): cached TSVs 2009–2017.
- CDC EPHT PM2.5: 2001–2020 (post-2020 not yet published).
- NOAA HMS smoke: **partial** — see limitations below.
- FEMA / EAGLE-I: as in the outage-homicide analysis lock.

## Deviations from pre-registration

To be documented in `REPORT_asthma.md` §11 and manuscript
Limitations:

- **Wildfire-smoke shock (`treated_smoke_event`)**: stubbed all-zero
  pending full NOAA HMS county-day aggregation. Six intersection
  cells with `treated_smoke_event` produce no useful information.
- **CDC PLACES pre-2020**: not published, so panel waves 2014 and
  2018 use PLACES 2020 vintage for prevalence.
- **CDC EPHT PM2.5 post-2020**: no data, panel wave 2022 has NA.
- **CDC WONDER asthma mortality**: cached only through 2017; panel
  wave 2018 uses the closest available.
- **HEPA / air filtration moderator**: not built (no US-national
  loader). Documented as a Wave-2 gap; the lit review surfaces
  the RCT evidence base as the compensating source.

## What was NOT pre-registered

- Ownership-typed BESS (inherited from outage-homicide analysis but
  not the primary focus of this study).
- Individual FEMA-event-specific effects beyond the 5 already-named
  shocks — the 41-event FEMA sweep is available in
  `data/event_outages_county_2014_2024.csv` but was not exercised
  for asthma outcomes in this analysis.
- Extension to COPD, CHD, mental-health, or mortality outcomes.
  The framework enables this; the specific analyses are future work.
