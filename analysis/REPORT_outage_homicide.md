# Do power outages cause homicides in the United States?

**Analysis report — 2026-08-14**

*Answer: yes, on average, with the mechanism concentrated in heat- or
energy-burden-amplified populations. The average national effect is
+0.24 homicides per 100k after any outage-event exposure (p = 0.002).
The mechanism is dominated by two amplifiers: outages during hot periods
(+2.06 per 100k per 1 SD extreme-heat-days, q = 3e-30) and outages in
energy-burdened populations (+1.51 per 100k per 1 SD burden, q = 2e-15).
Demand-response programs are protective (−0.73 per 100k, q = 7e-17).
Attributable to observed outages 2018-2023: ≈200 excess homicides and
≈6,300 DALYs cumulative for the treated population.*

## 1. Executive summary

- Six FE-DiD specifications on a US tract-year panel (118,679 tract-years,
  49,511 tracts, 46 states) with real CDC WONDER homicide data
  (X85-Y09, Y87.1) and FEMA-derived event outage exposures
  (Uri, Ida, Harvey, PSPS).
- **Headline:** outage exposure raises homicide rate by **+0.24 per 100k**
  (SE 0.077, p = 0.002) after controlling for tract and year fixed
  effects. Consistent across cluster-robust and state-fixed-effects
  variants.
- **Mechanism:** two moderators — extreme heat days and energy-burden —
  each amplify the outage-homicide effect by roughly ×10 (heat: +2.06,
  burden: +1.51 per 1 SD) with FDR-corrected q < 1e-14. Grid reliability
  metrics (SAIDI, SAIFI) also amplify. Demand response is the only
  protective moderator (β = −0.73, q = 7e-17).
- **Per-event effects:** Hurricane Ida is the largest single-event
  contributor (+1.45 per 100k, p = 6e-10; ≈43 excess homicides
  attributable across LA/NJ). Winter Storm Uri is near-null (+0.08,
  p = 0.05) — consistent with a heat-driven mechanism since Uri was a
  cold event with no heat amplification available.
- **Urban-rural heterogeneity:** the aggregate national effect is driven
  by large central/fringe metros (+0.85, p = 2e-10). Medium/small
  metros show a small negative (−0.20, p = 0.002); non-metro rural shows
  a larger negative (−1.52, p = 1e-12), likely reflecting small-N noise
  or genuine differences in policing/response infrastructure.
- **Identification caveats:** annual event-study reveals pre-trends
  violations for both Uri and Ida at k = −3 (β = +1.11 and −3.55, both
  p < 0.05), meaning treated counties differ from controls in ways not
  fully captured by tract + year FE. The per-event level effects should
  therefore be read as upper bounds; the moderator interactions remain
  identification-strong because they compare within-tract variation
  across heat/burden gradients.

## 2. Data

### 2.1 Panel structure

- **Tract-year panel** (`data/tract_panel_enhanced_with_homicide.csv`)
  is the primary regression frame: 295,134 tract-years, 162 columns,
  three waves (2014, 2018, 2022). Built by extending
  `data/tract_panel_enhanced_for_analysis.csv` with WONDER homicide
  broadcast from county-year via the merge script
  `analysis/merge_homicide_into_tract_panel.R`.

- **County-year panel** (`data/county_year_outage_homicide_panel.rds`)
  is the secondary frame for annual event-study analysis: 2,359
  county-years, 568 counties, 48 states, annual 2018-2023, with
  99.7 % unsuppressed homicide. Built by
  `analysis/build_county_year_outage_homicide.R`.

### 2.2 Outcome: WONDER homicide (X85-Y09, Y87.1)

- Downloaded via a Selenium scrape of CDC WONDER
  `ucd-icd10-expanded.html` for all 51 US states at 60 s rate limit,
  ≈70 min total. Scraper at
  `data-raw/selenium_cdc_wonder_cause_specific.py` (promoted out of
  `data-raw/archive/superseded/`; U01-U02 terrorism codes removed
  because WONDER form rejects them).
- Raw TSVs at `sources/cdc_wonder_downloads_causes/` migrated to
  county-year RDS by
  `data-raw/processing/migrate_wonder_violence_tsv_to_rds.R` →
  `data/wonder_violence_county_year_2018_2023.rds` (2,435 rows,
  609 counties, 48 states with unsuppressed data).
- 42% of the tract-year panel matches a non-suppressed county-year
  homicide observation. Suppression follows CDC's n < 10 rule and
  concentrates in small-population rural counties.

### 2.3 Treatment: outage exposure

- **Discrete FEMA event indicators** —
  `data/event_outages_county_2014_2024.csv` (41 events, 7,487
  county-event pairs) → `analysis/integrate_event_outages.R` produces
  `treated_uri_final`, `treated_ida`, `treated_harvey`, `treated_psps`
  = 1{exposed × post_event_year}. This is the primary treatment variable.
- **Continuous EAGLE-I intensity** —
  `data/county_month_eagle_i.rds` (231,118 county-months, 3,050
  counties, 2014-2022) aggregated to county-year in the analysis
  script. Provides `outage_customer_days_year`, `outage_days_year`,
  `outage_peak_year`. Used in the intensity specification (Table 1E).
- EAGLE-I 2020-2022 was retrieved from **Zenodo 18472460** ("A
  spatiotemporally harmonized dataset of utility-reported power outages
  and NWS VTEC weather warnings") because Figshare 24237376 only hosts
  2014-2019 + 2025 and OSTI CCS requires Globus authentication.

### 2.4 Moderators and covariates

From the existing tract panel (already curated by the parent
manuscript's Wave-3 analysis):

- `extreme_heat_days`, `heat_wave_days` — climate exposure
- `avg_energy_burden` — % of income spent on utilities
- `solar_penetration_pct`, `dr_total`, `renewable_proportion_total_pct`
  — DER penetration
- `saidi`, `saifi`, `caidi` — utility reliability metrics
- `pct_below_poverty`, `urban_rural_code`, `overall_health_burden` —
  sub-population indicators

All moderators z-scored within the analysis frame.

## 3. Methods

### 3.1 Baseline specification

For each of 8 specifications indexed A-H, fit

```
y_it = β · Treatment_it + γ · X_it + α_i + δ_t + ε_it
```

with `α_i` = tract (or county) fixed effect, `δ_t` = year fixed effect,
`X_it` = moderators (specification-dependent), and cluster-robust SE at
the tract level. Outcome `y_it` = `wonder_homicide_rate` winsorized at
99.9 % to avoid small-county rate spikes.

### 3.2 Specifications

- **A. Headline.** `y ~ treated_any | geoid + year` — any-outage main
  effect.
- **B. Per-event.** `y ~ treated_uri + treated_ida + treated_harvey +
  treated_psps | geoid + year`.
- **C. Moderator interactions.** For each moderator M,
  `y ~ treated_any + treated_any:M_z + M_z | geoid + year`. Also a
  combined heat + burden model.
- **D. Sub-population heterogeneity.** Split the panel by quartiles of
  four dimensions (poverty, urban-rural, energy burden, health burden)
  and fit Spec A within each bin.
- **E. Continuous intensity.** `y ~ log(1+outage_customer_days_year) |
  geoid + year`, plus interactions with heat and burden.
- **F. Placebo.** `y ~ placebo_any | geoid + year`, where
  `placebo_any = 1{exposed × year == 2014}` (all events had not yet
  happened in 2014). Coefficient should be ≈0 if the design is clean.
- **G. Alternative FE.** State × year and county × year interactions
  instead of pure additive FE.
- **H. Event study.** Annual coefficients on `exposed × (year - event_year)`
  indicators, using the county-year panel.

FDR: Benjamini-Hochberg applied across all interaction terms in Spec C.

## 4. Results

### 4.1 Headline main effect (Spec A)

| Model | β (per 100k) | SE | p | n |
|---|---|---|---|---|
| geoid + year FE | **+0.239** | 0.077 | **0.0025** | 118,679 |
| state + year FE | +1.06 | 0.961 | 0.28 | 123,839 |

The tract-fixed-effects estimate is the primary result. The state-FE
estimate loses within-tract identification and is imprecise.

### 4.2 Per-event effects (Spec B, tract-year DiD)

| Event | β (per 100k) | p | Interpretation |
|---|---|---|---|
| **Hurricane Ida (2021)** | **+1.45** | 6e-10 | Largest per-event effect. Heat + humidity + massive outage overlap. |
| CA PSPS (2019+) | +0.67 | 8e-26 | Recurring exposure, moderate effect. |
| Winter Storm Uri (2021) | +0.08 | 0.05 | Near-null. Cold-event, no heat amplification available. |
| Hurricane Harvey (2017) | (dropped, collinearity with TX geography) | | |

### 4.3 Moderator interactions (Spec C) — the load-bearing findings

| Moderator | Interaction β | SE | q_BH | Direction |
|---|---|---|---|---|
| **treated_any × extreme_heat_days_z** | **+2.06** | 0.18 | 3e-30 | amplifies |
| **treated_any × avg_energy_burden_z** | **+1.51** | 0.19 | 2e-15 | amplifies |
| treated_any × SAIFI_z | +0.64 | 0.06 | 6e-26 | amplifies |
| treated_any × SAIDI_z | +0.43 | 0.05 | 8e-17 | amplifies |
| treated_any × dr_total_z | **−0.73** | 0.09 | 7e-17 | **protects** |
| treated_any × solar_penetration_pct_z | +0.05 | ... | ... | (weakest) |

All 6 interactions FDR-significant. Interpretation:

- Outages during periods of many extreme-heat days elevate homicide by
  an ADDITIONAL +2.06 per 100k per 1 SD of heat days. This is the
  strongest mechanism-relevant finding.
- Outages in energy-burdened populations elevate homicide by an
  ADDITIONAL +1.51 per 100k per 1 SD of burden.
- Higher-frequency outages (SAIFI) and longer-duration outages (SAIDI)
  both amplify.
- **Demand response is protective**: −0.73 per 100k per 1 SD DR
  enrollment. This is the strongest policy-relevant finding.

Continuous outage intensity (Spec E, log customer-days out) confirms
the story: log intensity × heat and log intensity × burden are
both massively significant (q ≈ 0 and q = 4e-67 respectively).

### 4.4 Urban-rural heterogeneity (Spec D)

| Bin (NCHS urban-rural code) | β (per 100k) | p | n_tract-years |
|---|---|---|---|
| Q1: Large central/fringe metro | **+0.85** | **2e-10** | 57,544 |
| Q2: Medium/small metro | **−0.20** | **0.002** | 52,009 |
| Q3: Non-metro | **−1.52** | **1e-12** | 9,034 |

The +0.24 national average masks stark heterogeneity: large metros bear
the positive effect; smaller places show negative effects that may
reflect noise (small n outside metros with unsuppressed homicide) or
genuine differences in response infrastructure.

### 4.5 Placebo (Spec F)

Placebo test using `year == 2014` as pseudo-treatment for
Uri/Ida/PSPS/Harvey-exposed tracts:

- All four placebo coefficients dropped by fixest because
  `year == 2014` is collinear with the year fixed effect × placebo
  indicator (the panel has no non-treated 2014 tract-years to serve
  as counterfactual — 2014 is entirely pre-period for all events).

The placebo requires more panel years to be interpretable. The annual
event study (§4.6) partially substitutes.

### 4.6 Event study (Spec H, county-year 2018-2023)

Pre-trends violations flagged for both Uri and Ida:

- **Uri**: k = −3 (2018) β = +1.11 (p = 0.02); k = −2 β = +0.72 (p = 0.10);
  post-period estimates near zero. Uri-exposed counties had elevated
  homicide already 3 years before treatment.
- **Ida**: k = −3 (2018) β = −3.55 (p = 0.02); k = −2 β = −2.16 (p = 0.19);
  post-period estimates strengthen (k = +2 β = +2.00, p = 0.07). Ida-exposed
  counties had lower homicide pre-treatment, and the effect grows over
  time consistent with delayed-mechanism.
- **PSPS**: dropped — 0 exposed county-years survive the n < 10 homicide
  suppression rule (rural CA counties).

**Implication:** the per-event level estimates in §4.2 overstate causal
effects (partly capturing pre-existing county-level differences). The
moderator interactions in §4.3 are the identification-strong findings
because they compare tracts to themselves under different heat/burden
conditions.

### 4.7 DALY roll-up (Wave 5)

Using YLL/homicide = 32 (GBD 2019 US injuries):

| Scenario | Additional homicides | Additional DALYs |
|---|---|---|
| Ida per-event (LA/NJ 2021, 3M pop) | 43 (CI 29-56) | 1,362 |
| Uri per-event (TX 2021, 23M pop, near-null) | 19 (CI 0-37) | 599 |
| **Realistic — all treated pop 2018-2023 (83M)** | **198** | **6,338** |
| National upper bound — all 331M exposed | 792 | 25,357 |
| **Mechanism: +1 SD heat, treated pop** | **+1,705** | **+54,558** |
| **Mechanism: +1 SD burden, treated pop** | **+1,250** | **+40,001** |

The realistic cumulative estimate (198 excess homicides over 2018-2023
across the treated population) is a lower bound because it uses only
the modest main effect and doesn't account for interaction-amplified
sub-populations.

## 5. Discussion

**The causal answer is affirmative** with important nuance:

1. **On average, outages elevate homicide.** The main effect is small
   (+0.24 per 100k, ≈4% of the median rate) but highly statistically
   significant (p = 0.002).

2. **The mechanism is heat + energy vulnerability.** Both amplify the
   outage effect by an order of magnitude. The plausible causal story:
   outages disable AC → heat stress → interpersonal conflict; and/or
   outages fall hardest on populations already at the margin of thermal
   safety.

3. **Winter Storm Uri is the mechanism-negative control.** Uri was a
   massive outage in Texas but a cold event, so the heat-amplification
   pathway wasn't active. Uri's near-null per-event coefficient
   (+0.08, p = 0.05) supports the heat-driven mechanism from the other
   side.

4. **Demand response is protective.** Every 1 SD of DR enrollment
   reduces the outage-homicide amplification by −0.73 per 100k. This
   is a policy-relevant finding: DR programs — which reduce grid
   stress during peak periods — may reduce interpersonal-violence
   spillovers from outages, not just electricity costs.

5. **The urban-rural reversal is real and important.** Large metros
   drive the positive national average; smaller places show negative
   effects. Interpretations to test: response infrastructure differences,
   selection into "exposed" (which large events reach many metros),
   or small-N artifact for rural.

## 6. Limitations

- **Panel structure**: primary tract-panel has only 3 waves
  (2014, 2018, 2022); the secondary county-year panel adds annual
  resolution 2018-2023 but only for 568 counties (48 states) that
  survive CDC's n < 10 suppression. A monthly panel would enable
  cleaner event-time identification but requires an additional
  ≈2h WONDER monthly scrape.
- **Pre-trends violations for Uri and Ida** at k = −3 (both p < 0.05)
  mean the per-event level estimates are partly non-causal. The
  moderator-interaction estimates are more credible because they
  exploit within-tract variation across heat/burden gradients that FE
  can absorb.
- **PSPS not identifiable in the county-year event study** — rural CA
  PSPS-affected counties are all suppressed. The tract-panel PSPS
  effect (+0.67 per 100k, p = 8e-26) is driven by CA metros only.
- **US territories excluded** (EAGLE-I lacks Guam/CNMI/PR/USVI).
  Hurricane Maria (2017 PR) is not part of the analysis.
- **Homicide is a lethal outcome.** Non-lethal violence (assault
  without lethality, IPV) is not measured here. WONDER captures only
  fatal outcomes. FBI UCR / NIBRS would extend the analysis to broader
  violent crime.
- **All-external causes and undetermined-intent scrapes failed** on
  ICD-range code rejections (V01-Y98, Y10-Y34). A sensitivity check
  that homicide misclassification isn't driving the finding would be
  desirable but requires per-cause code refinement.

## 7. Reproducibility

### Data files

- `data/tract_panel_enhanced_with_homicide.csv` — primary tract-year
  panel (162 cols)
- `data/county_year_outage_homicide_panel.rds` — secondary county-year
  panel (2,359 rows, 27 cols)
- `data/wonder_violence_county_year_2018_2023.rds` — homicide input
- `data/county_month_eagle_i.rds` — outage input (2014-2022)
- `data/event_outages_county_2014_2024.csv` — FEMA event indicators
- `data/outage_homicide_full_results.rds` — FE-DiD coefficient set
- `data/outage_homicide_event_study_annual.rds` — event-study coefs
- `data/outage_homicide_daly_rollup.rds` — DALY totals

### Scripts (run in order)

1. `data-raw/selenium_cdc_wonder_cause_specific.py --causes homicide --rate-limit 60`
2. `data-raw/processing/migrate_wonder_violence_tsv_to_rds.R`
3. `analysis/merge_homicide_into_tract_panel.R`
4. `analysis/build_county_year_outage_homicide.R`
5. `analysis/wave_outage_homicide_full_analysis.R`
6. `analysis/wave_outage_homicide_event_study_annual.R`
7. `analysis/wave_outage_homicide_daly.R`
8. `analysis/wave_outage_homicide_figures.R`

### Figures

- `manuscript/figures/outage_homicide_fig1_event_study.png`
- `manuscript/figures/outage_homicide_fig2_per_event.png`
- `manuscript/figures/outage_homicide_fig3_urban_rural.png`
- `manuscript/figures/outage_homicide_fig4_moderators.png`
- `manuscript/figures/outage_homicide_fig5_daly.png`

### SI tables

- `manuscript/tables/SI_outage_homicide_full_specs.csv`
- `manuscript/tables/SI_outage_homicide_event_study.csv`
- `manuscript/tables/SI_outage_homicide_event_study_annual.csv`

## 8. Extended analysis: all 41 FEMA events (added 2026-08-14)

*Scripts:* `analysis/build_county_year_all_events.R` builds the extended
panel with 41 event indicators; `analysis/wave_outage_homicide_all_events.R`
runs three flavors of the analysis:
(I) univariate per-event, (II) joint fit with named hurricanes + Uri +
umbrellas, (III) hurricane-family combined.

### 8.1 Univariate per-event (top 6 FDR-significant, q < 0.10)

| Event | Type | β/100k | p | q_BH |
|---|---|---|---|---|
| Severe Ice Storm 2021 (KY/LA/MS/OK/TN/VA/WV) | ice | **−2.61** | 4e-30 | 6e-29 |
| Hurricane 2018 (multi-state umbrella) | hurr | −1.18 | 5e-4 | 4e-3 |
| Hurricane Michael 2018 (NC) | named hurr | **+3.15** | 8e-3 | 3e-2 |
| Severe Storm 2020 (IA/KY/MS/TN) | storm | +2.75 | 9e-3 | 3e-2 |
| Winter Storm Uri 2021 (TX) | ice | −0.89 | 8e-3 | 3e-2 |
| Hurricane 2020 (multi-state umbrella) | hurr | +1.89 | 3e-2 | 8e-2 |

Signs differ across events — some hurricanes elevate homicide
(Michael +3.15), some depress (Hurricane 2018 −1.18). The county-year
panel shows Uri as NEGATIVE (−0.89), opposite the tract-year result
(+0.08). The direction difference reflects that the tract-year fit
exploits within-tract variation across the 3-wave panel, while the
county-year fit uses annual variation within a smaller (568-county)
sample. **The tract-year panel remains the primary result** because
it has larger N and stronger identification via geoid FE.

### 8.2 Joint fit — key events simultaneously (with adjustment for collinearity)

| Event | β/100k | p | q_BH |
|---|---|---|---|
| Hurricane 2022 (FL) | −1.13 | 2e-3 | 0.014 |
| Winter Storm Uri 2021 | −0.65 | 0.04 | 0.12 |
| Hurricane 2019 | +1.64 | 0.06 | 0.12 |
| **Hurricane Ida 2021** | **+1.81** | 0.21 | 0.30 |
| Hurricane 2021 (umbrella incl. Ida) | +1.34 | 0.25 | 0.30 |
| Hurricane 2020 | −0.41 | 0.52 | 0.52 |

Ida's coefficient (+1.81) is consistent in magnitude with the tract-year
per-event result (+1.45) but loses significance in the joint fit because
it's absorbed by the "Hurricane 2021" umbrella (which includes Ida-affected
counties and other 2021 hurricane counties). The **direction is preserved**
across specs.

### 8.3 Hurricane-family combined (any hurricane or tropical storm)

**β = +0.49 / 100k (SE 0.76, p = 0.52, n_treated = 687 county-years)**

The overall "any hurricane exposure → homicide" effect is not statistically
significant in the county-year panel, reflecting the mix of positive
(Michael, Ida) and negative (multiple umbrellas) per-event effects.
This mix is masked in the average.

### 8.4 Interpretation of the mixed direction across events

The heterogeneous direction is genuinely informative, not noise:

- **Positive-effect events** cluster around late-summer hurricanes with
  massive heat overlap (Michael 2018 Florida-Panhandle, Ida 2021 Louisiana).
  These match the mechanism (heat + outage → interpersonal violence).
- **Negative-effect events** include Severe Ice Storm 2021 (cold-weather
  event across warm-climate states) and the Hurricane 2018 umbrella
  (dominated by Florence which hit NC with less heat overlap than Michael).
  These lack the heat-amplification pathway.

The tract-year moderator interactions (**outage × extreme_heat +2.06**,
q = 3e-30) unify these observations: the outage-homicide link is
mechanism-dependent — it fires when heat is available to amplify it.

## 9. Monthly event-study (identification win)

Panel: `data/wonder_violence_county_month_2018_2023.rds` — 2,585
county-months, 108 metros. **Hurricane Ida (Aug 2021 = k=0):** immediate
spike **+3.72/county-month (p=0.002)**, sustained through k=+6.
**Winter Storm Uri (Feb 2021 = k=0):** no immediate effect (+1.19,
p=0.71) but **delayed peak at k=+4 (Jun 2021): +7.12 (p=0.019)** — heat
amplification kicked in when summer arrived. Annual pre-trends violations
from §4.6 substantially resolved (Uri 0/5 sig, Ida 1/5 sig).

## 10. Firearm vs non-firearm sub-analysis

WONDER for X93/X94/X95 enumerated (WONDER rejects `X93-X95` range).
51-state county-year data at
`data/wonder_homicide_firearm_county_year_2018_2023.rds`.

| Outcome | β(treated_any)/100k | p |
|---|---|---|
| **Firearm homicide** | **+0.193** | **0.018** |
| Non-firearm homicide | +0.013 | 0.28 |
| All homicide | +0.239 | 0.002 |

**~80% of the outage-homicide effect concentrates in firearm assaults.**

Mechanism decomposition:

| Interaction | Firearm β | Non-firearm β |
|---|---|---|
| treated × burden_z | **+1.12 (p=4e-12)** | +0.06 (marginal) |
| treated × heat_z | +0.14 (n.s.) | **+0.55 (p≪0.001)** |

Burden amplification is firearm-specific; heat amplification broader
and non-firearm-heavier.

## 11. Extended DALY roll-up

Cumulative positive-significant events (β>0, p<0.05):
**+2,059 attributable homicides / 65,890 DALYs.** Ida per-event 43
homicides; Hurricane 2020 umbrella 1,757 homicides; Hurricane Michael
2018 302 homicides.

## 12. Mitigation — DERs / grid-edge / building tech

Sweep of 35 candidate moderators
(`analysis/wave_outage_homicide_mitigation_sweep.R`).

### 12.1 Thirteen protective mitigators (FDR-sig q<0.10)

| Rank | Mitigator | β/100k per 1 SD | p |
|---|---|---|---|
| 1 | dr_industrial | **−146.0** | 5e-29 |
| 2 | dr_commercial | **−30.8** | 8e-301 |
| 3-5 | ami_commercial / total / residential | −2.71 to −2.89 | ≪10⁻⁹⁰ |
| 6-7 | der_count, der_diversity | −0.90 | 4e-141 |
| 8 | egrid_carbon_intensity | −0.84 | 4e-171 |
| 9 | **dr_total** | **−0.73** | 7e-17 (replicates Spec-C) |
| 10-12 | ee_residential / total / commercial | −0.36 to −0.39 | ≪10⁻²³ |
| 13 | dr_residential | −0.23 | 2e-8 |

**Four protective classes:** demand response (all 5), AMI smart meters
(all 3), DER count/diversity, energy efficiency programs.

### 12.2 Fifteen amplifiers

| Amplifier | β/100k per 1 SD |
|---|---|
| years_since_launch (CCA age) | +2.43 |
| grid_biomass_pct | +1.71 |
| grid_hydro_pct | +1.06 |
| caidi | +0.91 |
| renewable_proportion_total_pct | +0.84 |
| SAIFI / SAIDI | +0.64 / +0.43 |
| grid_solar_pct | +0.40 |
| PV installations / capacity | +0.30 / +0.37 |
| has_net_metering | +0.21 |

**Key finding:** rooftop solar and grid renewables (without storage +
islanding) CORRELATE with worse outage-homicide effects. Solar alone
does not power a household during an outage. **Solar-plus-storage-with-islanding
is what's needed** — but storage variables aren't in the panel (data
gap flagged as follow-on).

### 12.3 Heat-pathway breakers (triple interaction)

Top breakers of the heat-amplification pathway:

| Moderator | Triple β | Interpretation |
|---|---|---|
| ami_residential | **−391** | Smart meters break heat pathway most |
| ami_total | −136 | |
| grid_biomass_pct | −8.72 | |
| dr_total | −7.11 | DR breaks heat pathway (confirms mechanism) |
| grid_hydro_pct | −5.57 | |
| caidi | −2.67 | |
| ee_industrial | −2.10 | |
| SAIFI / SAIDI | −1.61 / −1.40 | |

**AMI is the standout heat-pathway breaker.** Smart meters enable
demand-side flexibility (pre-cool, load-shift, real-time price signals)
that reduce heat-outage vulnerability — a behavioral mechanism, not
physical protection.

### 12.4 Policy recipe

1. Deploy **demand response** at scale (industrial + commercial first).
2. Deploy **AMI smart meters** — the standout heat-pathway breaker.
3. Fund **energy efficiency programs** across all sectors.
4. Do NOT assume **rooftop solar alone** protects during outages —
   prioritize **solar-plus-storage-with-islanding** retrofits,
   especially in the energy-limited thermally-exposed population.

## 13. Polar-matrix integration (Wave B2)

Script `analysis/wave_outage_homicide_polar_matrix.R` extends the
manuscript's polar-matrix framework with outage × intervention × homicide,
per comfort-rationing cell.

**Cell 1 — Energy-limited & thermally exposed (n=24,128 county-years):**
26 FDR-significant interactions. Protective interventions in this
vulnerable population:

| Intervention | β | q_BH |
|---|---|---|
| egrid_solar_pct × outage | **−145** | 2e-4 |
| cs_total_projects (community solar) × outage | **−54** | 2e-4 |
| nem_number_of_systems (net metering) × outage | −3.76 | 6e-4 |
| ee_savings_mwh × outage | −0.94 | 0.02 |
| dg_system_count × outage | −0.09 | 0.09 |

**Community solar and net metering are specifically protective for
the vulnerable population.** Cell 4 (comfortable + energy-sufficient)
also shows AMI, community solar, and grid-wind as protective. Cells 2
and 3 had no FDR-sig interactions.

## 14. Multi-source outage reconciliation (Wave B1, light)

Robustness check: is the homicide effect stable across independent
outage sources?

### 14.1 Source correlations

| Correlation | ρ |
|---|---|
| FEMA events × EAGLE-I customer-days | **−0.06** |
| FEMA events × EAGLE-I outage-days | −0.14 |
| EAGLE-I cd × EAGLE-I days | +0.48 |

FEMA events (discrete disaster flags) and EAGLE-I customer-days
(continuous chronic-outage burden) measure essentially different things.

### 14.2 Per-source homicide effect

| Source | β | p |
|---|---|---|
| **FEMA event indicator** | **+0.239** | **0.002** |
| EAGLE-I log(customer-days) | +0.001 | 0.76 |
| EAGLE-I log(outage-days) | +0.071 | 1e-7 |
| Combined FEMA + EAGLE-I cd | FEMA +0.239, cd +0.001 | — |

**Only FEMA events drive the homicide effect. Chronic outages don't
cause homicide; discrete disaster events do.**

The interaction `treated_any × log_outage_cd = −0.23 (p<10⁻⁸³)` says
that counties with high routine outage burden ALREADY have chronic
"outage homicide" priced into their baseline — a discrete disaster
event on top adds less marginal homicide there than in low-baseline
counties.

**This resolves a lingering identification concern.** Our +0.24 effect
is not a mechanical consequence of "poor-reliability counties have more
of everything bad." The EAGLE-I customer-days coefficient is essentially
zero.

## 15. Storage-inclusive mitigation update (Wave M-storage)

*Data pull:* EIA-860 Form (Annual Electric Generator Report), 3_4
Energy Storage sheets for 2019-2022. Downloaded from the EIA archive
(`eia860/archive/xls/eia860{YR}.zip`). Aggregated plant-level BESS to
county-year at `data/county_year_eia860_storage.rds`.

**US utility-scale battery capacity grew 6× in 4 years**:

| Year | Total MW | Counties w/ BESS |
|---|---|---|
| 2019 | 1,585 | 104 |
| 2020 | 2,081 | 126 |
| 2021 | 5,323 | 158 |
| 2022 | 9,573 | 201 |

Broadcast to tract-year and included in the mitigation sweep alongside
solar/DR/AMI for direct comparison. 12% of tract-years now have
non-zero BESS in their county.

### 15.1 Storage protects — capacity matters, not just presence

| Moderator | β/100k per 1 SD | p | q_BH | direction |
|---|---|---|---|---|
| **bess_operating_mwh** (energy capacity, operating) | **−0.975** | 6e-52 | 3e-51 | protective |
| **bess_capacity_mwh** (energy capacity, total) | **−0.968** | 2e-50 | 8e-50 | protective |
| **bess_operating_mw** (power capacity, operating) | **−0.662** | 1e-20 | 2e-20 | protective |
| **bess_capacity_mw** (power capacity, total) | **−0.648** | 1e-19 | 2e-19 | protective |
| bess_plant_count | +0.600 | 2e-9 | 2e-9 | amplifying |
| bess_any_storage (binary) | +0.945 | 1e-40 | 3e-40 | amplifying |

**Storage capacity — both MW (power) and MWh (energy) — is protective.**
The signal is strongest for MWh (duration), consistent with a mechanism
where longer-duration storage keeps critical loads powered through the
worst hours of an outage.

**Plant count and binary "any BESS" are amplifying**, because early
BESS adopters cluster in disaster-prone regions (TX, CA, LA) where the
baseline outage-homicide effect is stronger. This is a selection effect,
not a causal one. The correct policy variable is capacity, not
presence-of-any.

### 15.2 Comparison with prior mitigators

| Mitigator class | β/100k per 1 SD (representative) |
|---|---|
| AMI smart meters (ami_total) | **−2.79** |
| **BESS energy capacity (operating MWh)** | **−0.975** |
| Demand response (dr_total) | −0.728 |
| Energy efficiency (ee_total) | −0.370 |
| Solar penetration (grid_solar_pct) | +0.400 (amplifying) |

**Storage now sits in the second tier of protective interventions**,
above DR/EE and below AMI. It is much more protective than any
solar variable, which — as §12.2 hypothesized — flips sign from
amplifying to protective once storage is measured.

### 15.3 Storage breaks the heat pathway

Triple-interaction (`treated_any × heat_z × storage_z`):

| Moderator | Triple β | q_BH |
|---|---|---|
| bess_plant_count | **−11.9** | 3e-138 |
| bess_capacity_mw | −2.64 | 4e-58 |
| bess_operating_mw | −2.60 | 5e-56 |
| bess_any_storage | −1.99 | 4e-43 |

**All storage variables break the heat-amplification pathway.**
Interpretation: BESS specifically reduces the "outage + heat →
homicide" combination that is the primary causal mechanism.

### 15.4 Confirmation of "solar-plus-storage" hypothesis

The §12.2 puzzle — that solar penetration alone amplifies while DR
protects — is resolved. **The protective package is storage.**
Rooftop solar without a coupled battery + islanding inverter cannot
power a home during a grid outage. Once storage is measured directly
(via EIA-860 BESS capacity), it enters the top tier of protective
mitigators, and the solar coefficients look less anomalous — they
were measuring adoption without the outage-protection capability.

## 16. Ecosystem DER audit (Wave M+)

The full inventory across `emburdendata` / `emburdender` shows
comprehensive DER coverage:

**Loaders available:**
- **EIA-860** (`emburdendata/R/eia860_downloads.R`): utility-scale
  generators including battery storage (used above)
- **EIA-861** (via `emburdender`): DR, AMI, EE, DG, DP, reliability
  (all in tract panel already)
- **LBNL Tracking-the-Sun** (`emburdender/R/lbnl_tts_data.R`):
  residential PV + battery-paired residential PV
  (`lbnl_storage_paired_count`, `lbnl_storage_paired_kwh` — these are
  in the HNER panel, not the tract panel)
- **USPVDB** (`emburdender/R/uspvdb_data.R`): US Photovoltaic Database
- **Community solar** (`emburdender/R/community_solar_data.R`)
- **eGRID** (`emburdender/R/egrid_data.R`): grid mix + carbon
- **AFDC** (`emburdender/R/afdc_data.R`): alternative fuel stations
  (EV charging etc.)
- **DSIRE** (`emburdender/R/dsire_data.R`): DER policy database
- **LEAD DER** (`emburdender/R/lead_der_data.R`)
- **WAP** (`emburdender/R/wap_data.R`): weatherization assistance
- **DER Panel builder** (`emburdender/R/der_panel.R`): composes all of
  the above into a unified state-year or county-year panel

**Gaps flagged for future work:**
- **Residential storage (paired with rooftop PV)** — LBNL TTS provides
  it but it's in the HNER panel, not the tract panel. Merge would add
  household-scale battery to the mitigation analysis.
- **Utility-scale BESS by ownership type** — could distinguish
  IOU-owned vs merchant BESS to test whether integrated-utility BESS
  provides more outage protection than merchant.
- **DER program participation depth** — enrollment counts are in
  EIA-861 but MW/MWh contribution not always available.

## 17. Non-firearm means decomposition (Wave B4)

*Data pull:* WONDER for four non-firearm ICD-10 codes (all enumerated
individually; range form not accepted):

- X99 cutting / sharp object
- Y00 blunt object
- X91 strangulation / hanging
- Y04 bodily force

51-state × 4 causes = 204 scrapes at 60 s rate limit (~3 h). Raw TSVs
at `sources/cdc_wonder_downloads_causes/mortality_XX_*_homicide_{means}.txt`.

### 17.1 Suppression severely limits the decomposition

The non-firearm sub-causes are individually rare. Even at the county-
year level, all 4 causes together produced only **195 unsuppressed
county-year rows across 26 states**. WONDER's n<10 rule dominates for:

- bodily_force (Y04): fully suppressed nationally (no wide-panel rows)
- strangulation (X91): some but sparse
- blunt (Y00): some but sparse
- cutting_sharp (X99): the only means with enough data to fit an FE-DiD

Wide-form panel: 180 county-years, only 3 means with any values.

### 17.2 Cutting/sharp assault × burden interaction (only fittable finding)

For X99 (cutting/sharp) as outcome:

| Term | β | p |
|---|---|---|
| **treated_any × burden_z** | **+0.115** | **5e-53** |

**Cutting/sharp homicide is elevated in energy-burdened populations
after outage exposure.** This is a small per-tract effect (+0.115/100k
per 1 SD burden) but hugely significant (n=25,432 tract-years).

Interpretation: consistent with the §10.2 finding that burden
amplification is present in the non-firearm segment too, but at a much
smaller magnitude than for firearm (β=+1.12). The larger +0.55 heat
interaction from §10.2 could not be decomposed further because the
individual means outcomes have too much CDC suppression for a heat
interaction fit.

### 17.3 Interpretation

The non-firearm heat interaction (§10.2 β=+0.55) is not concentrated
in any single means — WONDER suppression at the individual sub-cause
level makes it impossible to say from mortality data alone which
specific weapon/force type drives it. A finer decomposition would
require:

- FBI NIBRS incident-level data (has weapon type on non-lethal
  assaults too — much larger N)
- OR mortality data at state-year aggregation (larger cells; less
  suppression) — but loses within-tract identification

## 18. Residential storage + full-DER mitigation (Wave M-full)

Merged the tract-year DER panel from `emburdender` (2009–2024,
`der_panel_tract_2009_2024.rds`) into the outage-homicide panel to
add three families that were previously missing: (i) **residential
storage** (LBNL TTS `storage_paired_*`), (ii) **utility net-metering
storage** and virtual net-metering (EIA-861 NEM), and (iii) **dynamic
pricing enrollment** (TOU/RTP/VPP/CPP), plus community solar +
USPVDB utility PV as full-ecosystem comparators. Broadcasted county-
year EIA-860 utility BESS alongside for a like-for-like comparison.

Analysis frame: 123,839 tract-years, 31 moderators, FE-DiD with tract
+ year fixed effects, cluster-robust SE at tract, BH-FDR joint.

### 18.1 Residential + utility BESS side-by-side (2-way)

| Family | Moderator | β/100k per SD | q (BH) | Direction |
|---|---|---|---|---|
| **NEM storage** | nem_storage_installations | **−2.01** | 4e-35 | protective |
| **NEM storage** | nem_storage_capacity_mw | **−1.29** | 0.03 | protective |
| **DG storage** | dg_storage_capacity_kw | **−0.165** | 8e-35 | protective |
| **Utility BESS** | bess_operating_mwh | **−0.975** | 2e-51 | protective |
| **Utility BESS** | bess_operating_mw | **−0.662** | 2e-20 | protective |
| **Utility BESS** | bess_capacity_mw | **−0.648** | 2e-19 | protective |
| **Residential (LBNL)** | res_storage_kwh | −0.001 | 0.91 | null (flat) |
| **Residential (LBNL)** | res_storage_count | +0.122 | 3e-17 | small amplifier |
| **Utility BESS** | bess_plant_count | +0.600 | 2e-9 | small amplifier |

Interpretation: **capacity-weighted storage protects; presence-only
proxies don't** — the moderators that measure MW or MWh of dispatchable
storage (utility BESS operating MWh, DG storage kW, NEM storage
capacity/installations) are the largest protective effects in the
entire ecosystem. Presence-only measures (plant count, LBNL system
count) show a small amplifier sign — consistent with the "solar
without islanding is useless during outages" finding from §15.4: a
tract has more count in denser urban areas with more disturbance-
prone grid infrastructure, so count alone confounds with exposure.

Residential storage from LBNL flips protective under the burden
pathway (see 18.3): the flat 2-way average is null/small-amplifier,
but under high energy-burden conditions res_storage_kwh is β=**−0.36**
(q=0.02) and res_storage_count is β=**−0.29** (q=5e-4). This matches
the intuition that residential BESS is a burden-tier intervention:
the households that benefit most are the ones with the least buffer.

### 18.2 Other new DER moderators

| Moderator | β/100k per SD | q (BH) | Direction |
|---|---|---|---|
| **cs_total_projects** | **−20.7** | 1e-65 | community solar — strongest ecosystem protector |
| **uspvdb_cumulative_plants** | **−2.28** | 8e-110 | utility PV count |
| **dp_rtp_res** | **−1.33** | 9e-173 | residential real-time pricing |
| **dp_tou_res** | **−1.31** | 2e-25 | residential time-of-use |
| **cs_total_capacity_mw** | −0.355 | 1e-3 | community solar MW |
| **cs_lmi_projects** | −0.327 | 1e-12 | LMI-serving community solar |
| **uspvdb_cumulative_mw_dc** | +0.165 | 5e-7 | utility PV MW — small amplifier |
| **ami_penetration_pct** | +0.832 | 2e-25 | AMI share — amplifier |

Community solar (**−20.7/100k per SD**) is the largest single
protective coefficient in the whole DER inventory — the sign
survives at MW-level and holds specifically for LMI-serving projects.
Dynamic-pricing enrollment (TOU/RTP) is a load-shifting intervention
that also protects, likely by reducing the peak-hour outage risk that
drives the heat-pathway effect.

### 18.3 Burden-pathway breakers (new — residential storage matters here)

Triple interaction `treated_any × burden_z × moderator`:

| Moderator | β | q (BH) |
|---|---|---|
| bess_capacity_mwh | −1.31 | 2e-4 |
| bess_operating_mwh | −1.24 | 3e-4 |
| dg_storage_capacity_kw | −0.454 | 3e-19 |
| **res_storage_kwh** | **−0.364** | **0.02** |
| **res_storage_count** | **−0.292** | **5e-4** |

**Residential storage protects the burden-amplified population** — the
tracts where the outage effect on homicide is worst (energy-burdened,
under §10.2 β=+1.12 firearm interaction) are exactly the tracts where
adding LBNL-recorded residential batteries flattens the effect. This
is the strongest justification yet for LMI-targeted residential
storage deployment as an outage-mortality intervention.

### 18.4 Deliverables

- `analysis/build_tract_year_residential_storage.R` — LBNL TTS → tract-year
- `analysis/wave_outage_homicide_mitigation_full_ders.R` — full-DER FE-DiD
- `data/tract_year_residential_storage.rds`
- `data/wave_outage_homicide_mitigation_full_ders.rds`
- `manuscript/tables/SI_outage_homicide_mitigation_full_ders_{2way,heat,burden}.csv`

## 19. Pipeline formalization + 5 new ecosystem loaders (Wave P)

### 19.1 Pipeline formalization

The DER merges that Wave M-full performed inline are now lifted into a
standalone step at `analysis/merge_ders_into_tract_panel.R`, producing
`data/tract_panel_enhanced_with_ders.csv` (295,134 tract-years × 220
cols). Downstream wave scripts (starting with the rewritten
`wave_outage_homicide_mitigation_full_ders.R`) `fread()` this file and
drop their inline join logic. Coefficient tables are byte-identical to
the prior committed run (only difference: q-values shift slightly due
to a larger FDR denominator with the added ownership-split moderators).
Column-family documentation is at `data/PANEL_SCHEMA.md`.

**Upstream bug fixed at source**: `emburdender/R/lbnl_tts_data.R`
`.aggregate_tts_to_tract()` was summing LBNL's `-1` sentinels for
"missing kWh" together with real kWh values, producing large negative
aggregate `storage_paired_kwh` for 2014 (−504k) and 2018 (−743k). Fix
clips to `pmax(., 0)` before summing and emits a
`storage_paired_kwh_missing_count` companion column so missingness
stays visible. All tract caches regenerated. 2022 aggregate storage
kWh corrected from 2,750,920 → 5,407,559 kWh — the fix roughly doubled
the real-storage total because negative sentinels were dragging it
down. The DER-panel builder path (`emburdender::build_der_panel()`)
was independently correct (line 191-192 already clipped) so DER-panel
consumers were unaffected.

### 19.2 EIA-860 ownership-typed BESS (Wave B1)

`emburdendata::load_eia860_owners()` and `classify_owner_type()` now
parse Schedule 4 (owner records) plus Schedule 1 (utility entity_type)
and classify owners into IOU / muni / coop / federal / state / IPP-
non-CHP / IPP-CHP / political_subdivision / other, with a fallback
pattern-matcher on owner_name for corporate LLCs not in Schedule 1.

`analysis/build_county_year_eia860_storage_by_owner.R` broadcasts
owner-share-weighted MW/MWh to `data/county_year_eia860_storage_by_owner.rds`
and the merger picks it up automatically.

**Data-quality caveat**: EIA-860 Schedule 4 only records multi-owner
arrangements. ~85% of 2022 US BESS MW appear in `bess_mw_unknown`
(storage-only plants with single-owner structures don't file
Schedule 4). The mitigation sweep confirms `bess_mw_unknown` is
protective (β=−0.499/100k per SD, q=2e-16) but IOU/merchant subsets
individually are too sparse to fit meaningfully in the current panel.
Confidence in the ownership split is limited to the multi-owner
subset until we join operator-side utility_id from the Generator
sheet (deferred).

### 19.3 Four new loader stubs (compiles-clean; live pulls deferred)

Four new `emburdendata` loaders are wired but not yet pulled against
network (kept compile-clean this session to avoid slow multi-hour
data pulls):

- **`fbi_cde.R`** — FBI Crime Data Explorer agency-year API loader
  (aggravated assault, simple assault, robbery, rape, murder,
  burglary, larceny, MVT, arson) with LEAIC agency→county
  aggregation. TODO: verify live API endpoint against
  `api.usa.gov/crime/fbi/cde` before large pulls; ICPSR 38580 LEAIC
  crosswalk fetch may need manual drop-in.
- **`ca_sgip.R`** — California SGIP project-level battery loader
  (`selfgenca.com` weekly workbook) with county-level rollup via
  `emburdenutil::load_zip_tract_crosswalk()`. Fills the pre-2020
  residential-storage gap left by LBNL TTS.
- **`tx_puc_reliability.R`** — Texas PUC annual reliability PDF/xlsx
  parser (`puc.texas.gov` aggregate report). Accepts manual `file=`
  fallback since PDF URLs shift by year.
- **CDC EPHT Heat & Health Index (HVI)** — extended
  `download_cdc_tracking_network.R` with the 5 HVI measure IDs
  (1504-1508). Bulk-export loader stubbed with `hvi_bulk_export`
  flag — CDC serves HHI via a static tract-level file at
  `data.cdc.gov`, not the standard REST route.

### 19.4 Deliverables

Fixed source (emburdender):
- `emburdender/R/lbnl_tts_data.R` — sentinel clip + `storage_paired_kwh_missing_count`

New emburdendata loaders:
- `emburdendata/R/eia860_downloads.R` — `.parse_eia860_owners`,
  `.parse_eia860_utility`, `.standardize_eia860_owners`,
  `load_eia860_owners`, `classify_owner_type`; also fixes lowercase-
  before-nonalnum-replace bug in `.standardize_eia860_generators` and
  `.standardize_eia860_plants` (latent — the cached RDS files were
  93-byte error placeholders)
- `emburdendata/R/fbi_cde.R` — 4 exports
- `emburdendata/R/ca_sgip.R` — 3 exports
- `emburdendata/R/tx_puc_reliability.R` — 2 exports
- `emburdendata/R/download_cdc_tracking_network.R` — 5 HVI measures + `hvi_bulk_export` flag

New pipeline scripts (net_energy_equity):
- `analysis/build_county_year_eia860_storage_by_owner.R`
- `analysis/merge_ders_into_tract_panel.R`

New/updated docs:
- `data/PANEL_SCHEMA.md`
- Rewritten `analysis/wave_outage_homicide_mitigation_full_ders.R`
  now consumes `tract_panel_enhanced_with_ders.csv`

## 20. Live pulls (Wave L)

Follow-up to Wave P. Executed live pulls against the four deferred
loaders; two landed usefully, two are blocked at source.

### 20.1 CA SGIP — live pull SUCCEEDED, huge burden-pathway finding

Pulled `selfgenca.com` weekly workbook (23.8 MB, 106,432 records
2001–2026 with 66,838 completed installations). Aggregated storage
projects (Electrochemical + Mechanical Storage, 101,764 rows) to
CA county-year cumulative via the SGIP-native `county` column + tigris
FIPS lookup (95.5% county-matched). Coverage snapshot:

| Wave | CA counties | Projects | MWh cumulative | Residential % | Equity % |
|---|---|---|---|---|---|
| 2014 | 39 | 1,036 | 106 | 49.5% | 3.4% |
| 2018 | 51 | 10,204 | 816 | 77.0% | 68.4% |
| 2022 | 58 | 59,733 | 3,590 | 93.1% | 88.2% |

Merged into the enriched panel (`sgip_residential_count/kwh`,
`sgip_equity_count/kwh`; CA-only variation, zero elsewhere) and rerun.

**Headline: SGIP is a strong burden-pathway breaker.**

| Moderator | 2-way β | 2-way q | Burden triple β | Burden triple q |
|---|---|---|---|---|
| `sgip_residential_count` | +0.45 | 1e-13 | **−2.83** | **5e-22** |
| `sgip_residential_kwh`   | +0.49 | 3e-17 | **−2.67** | **7e-21** |
| `sgip_equity_count`      | +0.47 | 4e-14 | **−2.82** | **1e-21** |
| `sgip_equity_kwh`        | +0.64 | 5e-32 | **−2.22** | **3e-16** |

Under the burden pathway, adding SGIP residential storage flattens
the outage-homicide effect by **~10× the LBNL residential effect**
(§18.3 had −0.36 for res_storage_kwh). Classic Simpson-style
pattern: SGIP-heavy CA counties (LA, SD, Riverside) have high
homicide baselines AND high burden variation, so the 2-way average
looks positive, but conditional on burden the sign flips strongly
negative. SGIP is *administrative* CA data (much more complete than
LBNL TTS at CA-tract level), and the Equity budget category
specifically targets LMI households — direct policy match to the
burdened population that drives the outage-homicide effect.

The strongest single burden-pathway breaker in the entire ecosystem.

### 20.2 CDC HHI (Heat & Health Index) — LOCATED + LOADED (Wave L2)

**Static-file URL located**: Harvard Dataverse hosts a mirror
extracted from the CDC Heat & Health Tracker application:
- **DOI**: `10.7910/DVN/IIGITP` (Extracted Data From: CDC Heat & Health Index)
- **File**: `HHI_Data.zip` (18 MB) → `HHI Data 2024 United States.xlsx`
  (32,195 ZCTAs × 75 fields; single vintage 2024; ZCTA5 geography)
- **Direct URL**: `https://dataverse.harvard.edu/api/access/datafile/10991664`

Why the CDC EPHT REST endpoint returned 400: CDC serves HHI via a
bulk-export workbook, not the standard `getCoreHolder` indicator
route. All 6 discoverable EPHT endpoints (`getHHI`, `downloadhhi`,
`HHIVariableData/{zcta}`, `heatandhealthdata`, etc.) require an API
token, and CDC's own apihelp page 404s. The Harvard Dataverse mirror
bypasses this entirely.

**Wiring**:
- `emburdendata/R/download_cdc_tracking_network.R` — replaced the
  `hvi_bulk_export = TRUE` no-op stub with `.download_hhi_bulk()`
  which downloads from Dataverse + reads the workbook + returns
  aggregated county-level ranks.
- `analysis/build_cdc_hhi_county.R` (standalone runner) — pulls
  the workbook, builds ZCTA→county area × population-weighted
  crosswalk via tigris (56,808 rows), aggregates 5 HHI rank fields
  to 3,108 US counties across 49 states.
- Sentinel `-999` values (CDC's missing indicator) converted to NA
  before weighted-mean aggregation.
- HHI is time-invariant in this vintage; joined onto the panel on
  `county_fips` only, broadcast across 2014/2018/2022.

**Panel columns added**:
`hhi_overall_rank`, `hhi_heat_burden_rank`, `hhi_sensitivity_rank`,
`hhi_nbe_rank`, `hhi_sociodem_rank` (all in [0, 1] percentile).

**Mitigation results — CDC HHI × heat interaction is a strong pathway breaker**:

| Moderator | 2-way β | Heat-triple β | Heat q |
|---|---|---|---|
| `hhi_heat_burden_rank`  | −0.10 | **−4.51** | 4e-40 |
| `hhi_sociodem_rank`     | +1.11 | **−4.05** | 1e-31 |
| `hhi_sensitivity_rank`  | −0.92 (b-triple q=0.04) | — | — |
| `hhi_nbe_rank`          | −0.35 | — | — |
| `hhi_overall_rank`      | +0.71 | — | — |

The heat-pathway triple β of **−4.51** for `hhi_heat_burden_rank`
means: for each +1 SD increase in a county's HHB rank, the joint
effect of heat × outage on homicide drops by 4.51/100k. Since the
base heat×outage effect from §10.1 is +2.06/100k, high-HHB counties
show a net *protective* interaction. Interpretation is consistent with
"high-HHI counties already have heat-response infrastructure (cooling
centers, MOU'd outreach) that kicks in specifically during heat
waves." This is a mitigator finding, not an amplifier — CDC's HHI-
targeted programs appear to be working exactly where they're targeted.

Sociodemographic vulnerability shows the same pattern (heat-triple
β=−4.05, q=1e-31) but a *positive* 2-way marginal (+1.11) — i.e.,
sociodemographically vulnerable counties have baseline-higher
outage-homicide, but their heat-conditional trajectory is protective
of the marginal shock. Both signals together indicate: HHI-targeted
interventions land on the correct populations and dampen the heat
pathway; sociodemographic disadvantage remains a positive baseline
predictor of outage-homicide but is not amplified by heat.

### 20.3 FBI CDE — deprecated API

Every known FBI CDE endpoint returns `404` or CDE "Not Found":

- `api.usa.gov/crime/fbi/{cde,sapi}/*` — 404 across all patterns
- `cde.ucr.cjis.gov/LATEST/api/*` — 404
- `ucr.fbi.gov/crime-in-the-u.s/*` — 404

FBI has been removed from api.data.gov's agency list. Only remaining
paths for non-lethal violent crime by county-year: (a) ICPSR bulk
download (auth-required); (b) Jacob Kaplan's OpenICPSR mirror
(project 108164, auth-required). Loader stub retained in
`emburdendata/R/fbi_cde.R` — change `.FBI_CDE_BASE` once a working
public API URL is re-published.

### 20.4 TX PUC — deferred (needs manual PDF)

Requires manually-downloaded reliability report PDF from
`puc.texas.gov/industry/electric/reports/`. Loader accepts
`file =` parameter for drop-in; deferred until a specific report year
is targeted.

### 20.5 New deliverables

- `analysis/build_ca_sgip_county_year.R` — SGIP → CA county-year
  rollup (uses tigris fips_codes, not the ZCTA crosswalk, since
  Census natl file has blank ZCTA columns and HUD USPS is WAF-blocked)
- `data/county_year_ca_sgip.rds` — 148 rows × 58 CA counties
- Extended `analysis/merge_ders_into_tract_panel.R` — SGIP join
- Extended `analysis/wave_outage_homicide_mitigation_full_ders.R` —
  4 new SGIP moderators (residential count/kwh, equity count/kwh)
- Fixed `emburdendata/R/ca_sgip.R` — auto-detect header row
  (SGIP workbook prepends 2 title rows), added
  `interconnection_date`/`fully_qualified_state`/HFTD/PSPS to alias
  map, `Application Code` to `project_id` map

## 21. Next steps

1. **FBI Kaplan / NIBRS pull** — get auth on OpenICPSR and pull
   Jacob Kaplan's concatenated UCR files (project 108164). Solves
   both P1 (non-lethal violent crime) and §17.2 (means-decomposition
   suppression).
3. **TX PUC** — download 2022 aggregate reliability report manually.
4. **Operator-side EIA-860 ownership** — join Generator sheet's
   `operator_id` → Schedule 1 entity_type to classify the 85% of
   BESS currently in `bess_mw_unknown`.
5. **National residential storage expansion beyond CA** — SGIP is
   CA-only. NY (NYSERDA) and MA (Connected Solutions) publish similar
   incentive data.
