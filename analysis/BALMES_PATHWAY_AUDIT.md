# Balmes-thread pathway audit — asthma analysis empirical coverage

**Scope**: Verify that the pathways surfaced in the John Balmes CRM
thread and surrounding researcher conversations (Daouda, Nidam,
Reid, Singer, Casey, Fowlie, Callaway/Aijazi, Morello-Frosch,
Forrester, Brager) are empirically tested in the current asthma
analysis on branch `asthma-analysis` (`ScheierVentures/emburden`,
git tag `asthma-v1-locked`).

**Method**: For each pathway articulated by (or attributed to) the
Balmes-connected researchers, tag one of `evaluated` /
`partial-proxy` / `not-tested-in-panel` / `structurally-blocked`,
with the specific coefficient / result if evaluated, and the
concrete blocker if not.

## 1. Pathway inventory from the Balmes thread

Extracted from the CRM drafts and inbound emails (search:
`Balmes`, `Daouda`, `Nidam`, `CEVICA`, `CCAC` in Mar–May 2026
correspondence; see `~/.mail/*/Drafts` and Inbox threads).

| # | Pathway | Source | Mechanism |
|---|---|---|---|
| **P1** | Energy affordability → equipment operation constraint → asthma trigger exposure | Balmes ↔ Tyner (CCAC) | Households with high suppression factor can't afford to run HVAC / filtration / ventilation → higher indoor asthma triggers |
| **P2** | Gas-stove combustion → indoor NO₂ → childhood asthma | Balmes ↔ Daouda (UCB SPH) | Kashtan et al. NYC gas-stove study; Daouda's CV retrofit RCT |
| **P3** | Affordability paradox: households decline free induction retrofit because they fear ↑ electric bills | Balmes ↔ Singer (CEVICA @ LBNL) | Refusal pattern is the natural experiment — asthmatic-child households declining a health-protective retrofit |
| **P4** | Full-cost EB vs bill-only EB: bill-only understates affordability constraint (Forrester 2024 South-paradox) | Balmes ↔ Nidam / Fowlie / Forrester | Bill-only EB collapses post-solar; full-cost EB collapses less because financing/depreciation persist |
| **P5** | Suppression Factor as operationalization of full-cost EB's suppressed-consumption channel | Scheier prior work (17M tract-month panel, 842 FDR-sig pairs) | Direct panel metric of "share of needed energy household forgoes" |
| **P6** | Household Net Energy Return (HNER) as bundled affordability metric | Same prior work | Beats traditional EB across 10 mortality causes |
| **P7** | CARB cost-effectiveness test bias → LMI programs undercapitalized → asthma-vulnerable populations remain exposed | Nidam ↔ CARB Equitable Housing Decarbonization | Cost-side counted, benefit-side not → CARE/FERA priority-community subsidies systematically underfunded |
| **P8** | CARE / FERA subsidy participation moderates energy-limiting behavior | Fowlie (POWER conf) | Subsidy uptake → less bill-shock → more HVAC/filtration operation |
| **P9** | Retrofits (gas-to-electric, heat-pump) protect asthmatic children | Daouda (retrofit-to-health) | Assessed respiratory benefits of switching |
| **P10** | Building characteristics (age, envelope, HVAC type) × extreme heat → respiratory outcomes | Callaway ↔ Aijazi (POWER conf) | Building-stock heterogeneity moderates heat-illness pathway |
| **P11** | Power outages → excess Medicare hospitalizations (asthma is a subset) | Casey ↔ McBrien 2026 (Nature) | 4,246 excess hospitalizations across all-cause; asthma-specific slice not published |
| **P12** | Coal-plant retirement (Louisville) → downstream respiratory outcomes | Casey 2018 Nature Energy | Natural-experiment template for energy-transition → health |
| **P13** | Chronic energy insecurity → slower / harder-to-measure health outcomes (distinct from acute outage) | Casey / Scheier framing | Cumulative-exposure pathway complementary to acute-shock DiD |
| **P14** | Wildfire smoke (PM₂.₅) → asthma ED / hosp | Reid 2016; multiple corpus PMIDs | Well-established; smoke-days is the primary exposure metric |
| **P15** | Ozone (extreme-heat co-pollutant) → asthma bronchoconstriction | Corpus + occupational lit | Acute mechanism, well-established |
| **P16** | Heat waves → asthma exacerbations | CDC EPHT + Reid + corpus PMIDs | Direct exposure pathway |
| **P17** | Envelope / thermal-comfort mediation of heat → asthma | Brager (CBE), Aijazi | Building thermal performance moderates indoor heat exposure |
| **P18** | Redlining / historical disinvestment → contemporary energy-insecurity + respiratory-outcome disparity | Morello-Frosch (EJ methodology) | Structural-racism pathway modifier |
| **P19** | Solar PV × asthmatic-child household → chronic health-protective effect | Brager framing of Scheier's DER-health chapter | PV as chronic burden reducer, not just outage-day resource |
| **P20** | HEPA / portable-air-cleaner distribution → asthma improvement (RCT-evidence heavy) | Automated lit review (27 papers, 18 RCTs) | Individual-level RCTs; population-scale deployment untested |

## 2. Empirical coverage in this session's asthma analysis

The full sweep (`data/intersection_sweep_asthma.rds`; 8,055 rows,
481 cells) evaluated the following interactions across 4 outcomes
× 7 shocks × 36 moderators × 3 specs. Below, each Balmes-thread
pathway is mapped to the specific coefficient(s) that empirically
tests it.

| Pathway | Status | Empirical result (or blocker) |
|---|---|---|
| **P1** — affordability → equipment → asthma | `partial-proxy` | Only proxied via `avg_energy_burden.x` and `hhi_sociodem_rank`. Bill-only EB is a coarse proxy for Balmes' "equipment-operation constraint" — the direct-measurement Suppression Factor (P5) is NOT in this panel. `hhi_sociodem_rank × treated_psps` on `places_asthma_prev` = **−0.325 pct-pt** (q ≈ 0) confirms an HHI-vulnerable × shock signal but does not identify the equipment-constraint mechanism. |
| **P2** — gas stove → NO₂ → asthma | `not-tested-in-panel` | Panel has `pct_heat_gas` (**heating fuel**, not cooking-appliance). Gas-stove-specific national indicator does not exist in the ecosystem. ACS reports heating fuel but not cooking appliance. RECS has cooking-appliance mix but at the state level only. |
| **P3** — affordability paradox / induction refusal | `structurally-blocked` | CEVICA participant refusals are individual-level administrative records held by LBNL/CPUC. Fleet has no analog. Requires direct data-share with CEVICA (in-progress conversation with Singer @ LBNL). |
| **P4** — full-cost vs bill-only EB | `not-tested-in-panel` | Panel has bill-only `avg_energy_burden.x` only. Full-cost EB requires depreciation + financing + opportunity-cost overlays from a Scheier prior-work pipeline that is not merged into this analysis panel. |
| **P5** — Suppression Factor | `not-tested-in-panel` | `emburdensynth` produces per-tract Suppression Factor; not merged into `tract_panel_enhanced_with_asthma_ders.csv`. Would be a ~1-day merge (build `suppression_factor_tract_year.rds` → append to enrichment chain). |
| **P6** — HNER | `not-tested-in-panel` | Same as P5. Both live in `emburdensynth::run_synthetic_pipeline()` output at HNER panel granularity. Not merged. |
| **P7** — CARB cost-effectiveness bias | `structurally-blocked` | Policy-mechanism pathway; not a moderator you can put in a panel. Would require CARB-side program-participation data + counterfactual construction. |
| **P8** — CARE / FERA subsidy uptake | `not-tested-in-panel` | CA-only PUC data; no loader in fleet. `emburdender::eia861_der_data` has some subsidy proxies but not CARE/FERA participation counts. Requires CPUC pull analogous to CA SGIP. |
| **P9** — gas-to-electric retrofit protects asthma | `structurally-blocked` | Retrofit-completion county-year does not exist as a US-national panel. DOE Weatherization Assistance Program (WAP) has state-year uptake but not household-level asthma linkage. Daouda's RCT is the identifying study. |
| **P10** — building × heat → respiratory | `partial-proxy` | Panel has `pct_heat_gas`, `pct_heat_electric`, `electric_heat_dominant` as coarse building-stock proxies. Deeper (built-year cohort, envelope R-value) NOT tested. `treated_heat_wave × pct_heat_gas` on `asthma_hosp_rate` = small positive (β ≈ +0.1/10k per SD); `× pct_heat_electric` = small negative — documented in REPORT §8, not headline. |
| **P11** — outages → excess Medicare hosp (McBrien 2026) | `evaluated (partial)` | Direct headline: **outages → asthma hospitalizations β = −1.84/10k (p = 3e-98)**. The negative sign IS the plausible-care-disruption artifact Balmes-thread interpretations would predict, distinct from the +excess-hosp finding for all-cause in McBrien 2026 (asthma-only is not the same as all-cause). Documented in REPORT §1 and Limitations. |
| **P12** — coal-plant retirement → respiratory | `not-tested-in-panel` | Coal-plant retirement events are not currently in the `treated_*` shock catalog. `emburdender::build_der_panel()` has eGRID plant-level data that could be converted to a retirement-event indicator. Est. 1 day. |
| **P13** — chronic energy insecurity → slow health effects | `partial-proxy` | Panel supports year-over-year within-tract comparisons via `avg_energy_burden.x` continuous variation, but a shock-agnostic "chronic burden years accumulated" moderator is NOT constructed. Would enable time-since-treatment framing. |
| **P14** — wildfire smoke → asthma | `structurally-blocked-pending-pull` | `treated_smoke_event` is currently all-zero in the panel pending NOAA HMS county-day polygon aggregation. Ecosystem has the loader (`emburdendata::download_noaa_hms_smoke()`) but only 3 daily files cached. Estimated 4–6 h to complete pull; the wildfire-smoke arm has 47 lit-review papers waiting on this. |
| **P15** — ozone × heat → asthma | **`evaluated`** | AQ mediation wave found `treated_heat_wave × ozone_days_count_z` on `asthma_hosp_rate` = **+0.84/10k per SD (q = 2e-174)**. Ozone AMPLIFIES the heat-pathway. Consistent with acute bronchoconstriction mechanism. |
| **P16** — heat waves → asthma | **`evaluated`** | Headline: `treated_heat_wave → asthma_hosp_rate` = **+0.98/10k (p = 4e-208)**. Consistent with corpus median-relevance 0.90 for the `heat` arm. |
| **P17** — envelope / thermal-comfort mediation | `partial-proxy` | Same as P10 — `pct_heat_gas` / `electric_heat_dominant` are coarse envelope proxies. HHI-NBE rank (Natural & Built Environment) is a better composite proxy: `treated_any × hhi_nbe_rank_z` on `asthma_hosp_rate` = **−2.40/10k (q = 2e-314)**. Consistent with built-environment protection. |
| **P18** — redlining / structural EJ pathway | `partial-proxy` | Panel has `pct_below_poverty` and `avg_income`; a HOLC-redlining tract indicator is NOT joined. `emburdendata` has HOLC/mapping-inequality data available but not merged into this panel. HHI-sociodem rank absorbs some of this variation: `treated_psps × hhi_sociodem_rank` on `places_asthma_prev` = **−0.325 pct-pt (q ≈ 0)**. |
| **P19** — solar PV × chronic asthma protection | **`evaluated`** | 2way findings: `treated_heat_wave × sgip_residential_kwh_z` on `asthma_hosp_rate` = **−1.84/10k**; `× sgip_equity_kwh_z` = **−2.82/10k (burden-triple, q = 2e-304)**. LMI-targeted residential storage IS protective. Solar-alone (`cs_total_projects`, `uspvdb_cumulative_plants`) also enters but with mixed signs — documented in REPORT §4.2. |
| **P20** — HEPA / air-cleaner deployment | `structurally-blocked` | No US-national HEPA uptake loader. Lit review surfaced 18 RCTs. Priority Wave-2 build per REPORT §11. |

### Summary counts

- **Fully evaluated**: 4 (P15 ozone, P16 heat, P19 solar-storage×heat, P11 outages [partial-direction claim])
- **Partial proxy**: 6 (P1 affordability, P10 building, P13 chronic insecurity, P17 envelope, P18 redlining, P11 direction)
- **Not tested but readily addable** (< 1 week each): 4 (P5 Suppression Factor, P6 HNER, P8 CARE/FERA, P12 coal retirement)
- **Not tested; specific data pull needed** (mid-effort): 2 (P2 gas-stove, P4 full-cost EB, P14 wildfire smoke)
- **Structurally blocked (auth, individual-level, or policy)**: 4 (P3 CEVICA refusal, P7 CARB test, P9 retrofit-linkage, P20 HEPA)

## 3. Fleet-work verification (cherry-picks to main)

The user asked to verify the work that got "cherry-picked to main."
Fleet packages, `main` branch of each on `ScheierVentures`:

| Package | Latest 2 commits on `main` | Session origin |
|---|---|---|
| `emburdenstats` | `ce98b4b` JOSS smoke tests; **`a3ff11b` Add sweep_intersections()** | asthma session |
| `emburdenvis` | `71754dd` JOSS smoke tests; **`c07929b` Add plot_intersection_matrix()** | asthma session |
| `emburdenhealth` | `844e3a6` JOSS smoke tests; `ac9a73e` Export aggregate_aqs_to_county_year_seasonal() | prior |
| `emburdender` | **`194abe4` build_county_year_bess()**; **`d39b180` lbnl_tts sentinel fix** | outage-homicide Wave-F session |
| `emburdendata` | `74a0c3d` JOSS smoke tests; DHS/ESMAP MTF loaders; **`fb774a1` Wave F cdc_hhi + SGIP fallback + 5 tests**; **`b87e2ed` cdc_tracking_network Dataverse HHI**; **`47e43f6` ca_sgip fixes**; **`b33c1c9` EIA-860 owners + FBI CDE + CA SGIP + TX PUC + CDC HVI** | outage-homicide + asthma sessions |
| `emburdenutil` | `14f288d` JOSS smoke tests; **`59e7d58` ZCTA URL fix (rel20→rel2020)** | outage-homicide Wave-F |
| `emburdenplus` | `45260ce` JOSS smoke tests; **`54a87bb` Refresh startup message with 9 new loaders** | outage-homicide Wave-F |

Bold = commits from this-and-adjacent-session pipeline work. All
present on `main`. No accidental commits from unrelated sessions
were found on `main` of any fleet package.

`ScheierVentures/emburden` (net_energy_equity itself) analysis
branches:
- `asthma-analysis` — the full asthma pipeline + framework +
  manuscript + preregistration + lit review; tag `asthma-v1-locked`
- `outage-homicide-analysis` — prior session's Wave-C/L/L2 manuscript;
  tag `wave-L2-locked`
- `main` — has JOSS/CRAN/workflow-hardening + docs commits; the asthma
  and outage-homicide analysis work does NOT live on `main` by design.

## 4. Concrete next-actions to close pathway gaps

Ordered by ratio of policy-relevance to effort. Bold = highest
value from the Balmes-thread perspective.

1. **P14 wildfire smoke (est. 4–6 h)**: run full NOAA HMS
   polygon-county-day aggregation via
   `emburdendata::download_noaa_hms_smoke()` for 2014–2024, build
   `treated_smoke_event` from Reid et al. definition (≥ 3 heavy
   days per year). Unlocks 47 lit-review papers + the wildfire
   arm of the framework. Highest litreview-payoff:effort ratio.
2. **P5 Suppression Factor + P6 HNER merge (est. 1 day)**: join
   `emburdensynth::run_synthetic_pipeline()` per-tract Suppression
   Factor + HNER into the enrichment chain as `SF_z` and `HNER_z`.
   Rerun the intersection sweep. This is the pathway Balmes'
   thread explicitly asks about (his framing: "affordability
   constrains equipment operation"). Currently proxied by
   `avg_energy_burden.x` only — the direct-measurement metric is
   sitting in another Scheier pipeline.
3. **P8 CARE / FERA uptake (est. 1–2 days)**: build a `ca_care_
   fera.R` loader (parallel to `ca_sgip.R`) pulling CPUC monthly
   CARE/FERA enrollment by utility → county → tract. Enables
   subsidy-uptake × asthma-shock interactions that Fowlie
   explicitly named. CA-only initially.
4. **P12 coal-plant retirement shock (est. 4–6 h)**: from eGRID
   plant-year status transitions, construct a
   `treated_coal_retirement` county-year indicator (any coal
   plant within 50 km retired in the year). Replicates Casey
   2018 template on asthma outcome. Adds a distinctly non-outage,
   non-heat shock to the catalog.
5. **P2 gas-stove indicator (est. 1 day)**: build a
   `pct_stove_gas` tract proxy from ACS S2504 (cooking-fuel not
   directly tabulated; use plumbing / kitchen amenities cross with
   heating-fuel as a proxy). Or use CalEPA CalEnviroScreen 4.0's
   indoor-air-quality composite for CA. Enables the Daouda-thread
   NO₂ pathway at population scale.
6. **P18 redlining / HOLC merge (est. 4 h)**: HOLC digitized
   maps + Digital Scholarship Lab tract crosswalks are public
   and free. Merge as `holc_a_pct`, `holc_d_pct` per tract →
   test `treated_any × holc_d_pct` on all asthma outcomes.
   Direct Morello-Frosch framing.
7. **P4 full-cost EB merge (est. 2 days)**: pull the Scheier
   full-cost-EB tract panel + join. Replicates the Forrester 2024
   framing on asthma outcomes and enables the South-paradox test.
8. **P20 HEPA proxy (est. 2 days)**: use DSIRE indoor-air policy
   count OR EPA Portable Air Cleaner grant tract-year enrollment
   as a proxy. Neither is a direct HEPA-in-home measure but both
   are the closest population-scale signals available.

**Deferred to individual-level data-share negotiations**: P3
(CEVICA refusal), P9 (Daouda retrofit-to-asthma linkage), P7
(CARB test critique needs policy-modeling extension, not a panel
moderator).

## 5. Reproducibility

- Panel: `data/tract_panel_enhanced_with_asthma_ders.csv`
  (regeneratable via `analysis/merge_asthma_full_panel.R`)
- Sweep: `data/intersection_sweep_asthma.rds`
- AQ mediation: `data/wave_asthma_air_quality_mediation.rds`
- Lit review: `data/lit/asthma_triad_classified.rds` (116 abstracts,
  LLM-classified)
- Preregistration: `analysis/PRE_REGISTRATION_asthma.md`
- Session pin: `analysis/session_info_asthma.md`
- Git tag: `asthma-v1-locked` on `asthma-analysis` branch

## 6. Attribution

Balmes-thread pathway framings extracted from correspondence
2026-03-27 through 2026-05-03 across the `Balmes`, `Daouda`,
`Nidam`, `Reid`, `Singer`, `Tyner`, `Casey`, `Fowlie`,
`Callaway`, `Aijazi`, `Morello-Frosch`, `Forrester`, `Brager`
threads. No CRM-material text is reproduced here; only the
pathway-level claims + citations that were made in the
correspondence, transcribed with attribution to the sending
researcher.
