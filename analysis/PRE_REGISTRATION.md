# Pre-registration — outage-homicide analysis

**Analysis lock commit**: `wave-L2-locked` git tag on
`outage-homicide-analysis` branch of `ScheierVentures/emburden`
(net_energy_equity SHA `808fede`).

**Reproducibility pin**: see `analysis/session_info.md` for R
`sessionInfo()` + all 13 emburden ecosystem package git SHAs at the
lock.

**Panel**: `data/tract_panel_enhanced_with_ders.csv` (295,134
tract-year rows × 234 columns) as produced by
`analysis/merge_ders_into_tract_panel.R` at the lock commit. Column
family documentation: `data/PANEL_SCHEMA.md`.

## Registered specifications

All FE-DiD models use tract + year fixed effects, cluster-robust
standard errors clustered at the tract level, and the base outcome
`wonder_homicide_rate` (deaths per 100,000, WONDER 2018–2023).
`treated_any = 1` if the tract-year falls in the post-event window
of Hurricane Ida, Winter Storm Uri, Hurricane Harvey, or a California
PSPS event; = 0 otherwise.

### R1. Headline (§4)

```
wonder_homicide_rate ~ treated_any | geoid + year
```

Registered hypothesis: β > 0 (outages cause homicides). Result:
+0.24/100k, p=0.002.

### R2. Mitigation sweep (§12, §18)

For each moderator `m` in the enriched panel's 47-moderator inventory:

```
wonder_homicide_rate ~ treated_any + treated_any:m_z + m_z | geoid + year
```

BH-FDR applied jointly across all interaction terms. Registered
significance threshold: q < 0.10.

### R3. Heat-pathway triple (§15, §18, §20.2)

For each moderator `m`:

```
wonder_homicide_rate ~ treated_any + treated_any:heat_z +
                       treated_any:m_z +
                       treated_any:heat_z:m_z + heat_z + m_z
                       | geoid + year
```

Registered hypothesis: the `treated_any:heat_z:m_z` coefficient is
negative for storage / HHI / SGIP moderators (protective) and
positive for solar-count / grid-penetration proxies (amplifier).

### R4. Burden-pathway triple (§18, §20.1)

Same as R3 with `heat_z` replaced by `burden_z` (`avg_energy_burden`).
Registered hypothesis: SGIP residential storage and LBNL residential
storage have negative burden-triple β (protective for burdened
populations); AMI penetration has positive burden-triple β
(amplifier).

### R5. HHI × SGIP super-linearity (Wave X, §22, CA-only)

Filter: `state_abbr == "CA"` (24,224 tract-years).

Registered hypothesis: the four-way term

```
treated_any:heat_z:hhi_heat_burden_rank_z:sgip_residential_kwh_z
```

is negative — SGIP protection concentrates in high-HHI heat-burden
counties under heat conditions.

Registered fallback (if 4-way is collinear-dropped): the 3-way

```
heat_z:hhi_heat_burden_rank_z:sgip_residential_kwh_z
```

serves as the interpretable proxy for super-linearity. Result: 4-way
dropped as collinear (SGIP is county-level, 100% of CA tract-years
have SGIP>0, degenerate against tract FE); 3-way β=−9.94/100k
(p=4e-292), super-linear protection confirmed.

## Multiple-testing correction

- **R2**: BH-FDR across all interaction terms from the 47-moderator
  sweep (`treated_any:m_z` × 47), threshold q < 0.10.
- **R3, R4**: BH-FDR across each pathway triple's set of interaction
  terms (~14 storage moderators per pathway), threshold q < 0.10.
- **R5**: single pre-registered hypothesis, no correction.

## Data source lock

Locked data-source commits (see `analysis/session_info.md`):
- Base homicide panel: `data/tract_panel_enhanced_with_homicide.csv`
  as of the branch lock
- LBNL Tracking-the-Sun consolidated file:
  `~/.cache/emburdender/lbnl_tts_all_raw.rds` (2025 release)
- EIA-860: `~/.cache/emburdendata/eia860/eia860_{2019..2022}_raw/`
- CDC HHI: Harvard Dataverse DOI `10.7910/DVN/IIGITP` (single vintage,
  2024)
- CA SGIP: `selfgenca.com` Weekly Statewide Report as of
  2026-08-23 (per file header)
- CDC WONDER homicide: scraped 2026-06 to
  `sources/cdc_wonder_downloads/mortality_*_homicide.txt`
- EAGLE-I: Figshare article `24237376` (2014–2024)
- FEMA Disaster Declarations: `~/.cache/emburdendata/fema/` as of
  the branch lock

## Deviations from pre-registration

Documented in `REPORT_outage_homicide.md`:

- **Wave X 4-way collinearity**: the pre-registered 4-way term
  `treated_any:heat_z:hhi_hb_z:sgip_res_z` was dropped by fixest as
  collinear against the tract FE. The 3-way fallback was invoked as
  per the registered contingency. Interpretation was appropriately
  narrowed to "the 3-way joint is super-linearly protective" rather
  than "the outage-conditional 4-way is super-linear".
- **CDC HHI time-invariance**: HHI is single-vintage 2024, broadcast
  across 2014/2018/2022 panel waves. Limitation noted in REPORT
  §20.2 and manuscript Limitations section.
- **SGIP CA-only**: only California has SGIP-scale residential-storage
  administrative data. NY (NYSERDA) and MA (Connected Solutions)
  publish similar programs but are not pulled in this analysis
  (documented as future work in REPORT §21.5).

## What was NOT pre-registered

The following analyses were exploratory, added after the pre-
registration lock, and are reported as such in the manuscript:

- Ownership-typed BESS (§19.2)
- Individual firearm/non-firearm means decomposition (§17)
- Source reconciliation (§14) — added as robustness after initial
  finding
- Extended 41-event FEMA sweep (§8) — added as robustness
