# Collaboration update — asthma × efficiency × adaptation-index

**To:** Maya Saterson (UNC Gillings SPH), Noah Kittner (UNC ESE/SREG),
Yuetong Zhang (UNC DCRP)
**From:** Eric Scheier
**Subject:** Refined intersection analysis ready for your read —
adaptation-index composite moderator finding + OneDrive drop

---

Hi Maya, Noah, Yuetong,

Following the March check-in with Maya + Noah and Yuetong's July
proposal, I've refined the asthma × efficiency intersection analysis
to bring in the efficiency layer we were missing and to test Yuetong's
adaptation-index composite directly against the panel. Everything
lives in the `asthma-analysis` branch of `net_energy_equity`; the
`asthma-v2-efficiency` tag marks this refinement lock-point.

## What's new since March

**Efficiency layer enriched.** The prior sweep only had aggregate
utility-customer counts. This refinement pulls detailed EIA-861 EE
metrics (`ee_savings_mwh_res`, `ee_lifecycle_savings_mwh`,
`ee_weighted_avg_life_yrs`, `ee_direct_cost_per_hh`), WAP state-year
weatherization data (units_completed, DOE funding per household),
and ACS built-year cohorts (envelope proxy: pct_pre1980,
pct_1980_1999, pct_post2000). All merged into a 266-column tract
panel with three waves (2014 / 2018 / 2022).

**Yuetong's adaptation-index built.** Following the July-7 proposal
slide 18: winsorized + z-scored components (solar+storage, DR, TOU,
AMI, EE-savings-per-hh), equal-weight composite, normalized by
climate need (log(extreme_heat_days)) → `adapt_index_z`. Coverage
100%.

**Sweep rerun.** 4 asthma outcomes × 7 climate shocks × 14 efficiency
moderators × 3 specs = 3,269 model fits. The three adaptation-index
variants are all in the top-5 of the moderator horse-race.

## The interpretive split you'll want to see

The clearest single finding: `adapt_index_z` × extreme-heat-days
interacts with asthma outcomes with **opposite signs** across two
outcome families.

- **Chronic PLACES prevalence × heat_break spec: β = −0.089
  (q = 1e-13).** Tracts with higher baseline adaptation capacity
  show reduced heat-days-interaction with asthma prevalence.
  Consistent with the Balmes-thread pathway: efficient/well-
  conditioned envelopes reduce chronic indoor-temperature exposure.

- **EPHT ED-visit rate × heat_break spec: β = +15.2 (q = 6e-18).**
  In the *same* tracts, one SD more capacity is associated with a
  *larger* ED-visit interaction with heat waves. Two plausible
  readings: (a) ascertainment (higher-capacity areas have more
  health-system access, so more ED encounters get coded), or
  (b) capacity vs. utilization divergence — the composite measures
  infrastructure, not necessarily behavioural use.

For Maya's MPH thesis this is the interesting finding to unpack:
chronic prevalence responds to capacity structurally, acute ED
utilization responds to it operationally. The interaction split
reproduces across three specs (2way, heat_break, burden_break)
and holds under BH-FDR q < 0.10 clustering by state × wave.

## Deliverables

- **Refined report:** `analysis/EFFICIENCY_ASTHMA_INTERSECTION.md`
  (248 lines) — full methods + results.
- **Balmes pathway audit:** `analysis/BALMES_PATHWAY_AUDIT.md`
  (187 lines) — 20-pathway coverage inventory.
- **Panel:** `data/tract_panel_enhanced_with_asthma_ders_ee_adapt.csv`
  (266 cols, 356 MB) — the enriched tract panel with adaptation
  index.
- **Sweep result:** `data/intersection_sweep_asthma_efficiency.rds`
  (3,269 fits).
- **Adaptation-index builder:** `analysis/build_adaptation_index.R`
  — reproducible from panel + Yuetong slide-18 spec.
- **Horse-race figure:** `analysis/fig_asthma_horserace.R` produces
  a ranked plot of moderator effect sizes.

I'll drop the report + horse-race figure into the shared OneDrive
folder ("Energy Burden Health Impacts") today. Happy to walk through
any of it on a call — the two Rmd manuscripts in
`manuscript_asthma_intersection/` are the natural next step if we
want to write toward a joint publication.

## What would move this forward

1. **Maya:** does the interpretive split (chronic-vs-acute) map to
   an MPH thesis question you'd want to frame around? If so, happy
   to prepare a scoped analysis file with your specific outcomes.
2. **Noah:** any pathway on the Balmes audit list you'd want
   deeper instrumentation on before it lands in the SREG
   manuscript?
3. **Yuetong:** the adaptation-index composite carries the signal
   at least as strongly as any single component — worth featuring
   in the July-proposal writeup? Also: does normalizing by
   `log(extreme_heat_days)` match the climate-need normalization
   you had in mind, or would you prefer a different denominator?

Thanks for keeping the thread alive — this ends up being one of the
strongest signals in the tract panel.

Best,
Eric
