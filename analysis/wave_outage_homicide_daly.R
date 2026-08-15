#!/usr/bin/env Rscript
# W5: DALY / lives-lost roll-up for the outage → homicide analysis.
#
# Approach:
#   attributable_homicides = β_main × pop_exposed / 1e5
#   attributable_DALYs = attributable_homicides × YLL_per_homicide (32, per GBD 2019 US)
#
# Two flavors:
#   (a) Average main-effect: use β = +0.24/100k across all treated tract-years
#   (b) Mechanism-attributable: use β_heat = +2.07 × avg_heat_days_z; β_burden = +1.52 × avg_burden_z
#
# Also compute event-specific totals from the per-event coefficients.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

YLL_HOMICIDE <- 32.0   # GBD 2019 US injury YLL/death — homicide is high-YLL

# Read results
res <- readRDS(file.path(DATA, "outage_homicide_full_results.rds"))
panel <- readRDS(file.path(DATA, "county_year_outage_homicide_panel.rds"))

# ---------------------------------------------------------------------------
#  Exposure counts
# ---------------------------------------------------------------------------
event_counts <- list(
  uri     = list(n_counties = sum(panel$exposed_uri    == 1L & panel$year == 2022),
                 pop        = sum(panel$wonder_homicide_pop[
                                    panel$exposed_uri == 1L & panel$year == 2022],
                                  na.rm = TRUE)),
  ida     = list(n_counties = sum(panel$exposed_ida    == 1L & panel$year == 2022),
                 pop        = sum(panel$wonder_homicide_pop[
                                    panel$exposed_ida == 1L & panel$year == 2022],
                                  na.rm = TRUE)),
  harvey  = list(n_counties = sum(panel$exposed_harvey == 1L & panel$year == 2022),
                 pop        = sum(panel$wonder_homicide_pop[
                                    panel$exposed_harvey == 1L & panel$year == 2022],
                                  na.rm = TRUE))
)

# ---------------------------------------------------------------------------
#  Per-event attributable homicides (using B_per_event coefficients)
# ---------------------------------------------------------------------------
per_event <- res$per_event
per_event_daly <- per_event %>%
  mutate(
    event = sub("^treated_", "", term),
    beta_per_100k = estimate,
    pop_exposed = sapply(event, function(e) event_counts[[e]]$pop %||% NA_real_),
    attributable_homicides = beta_per_100k * pop_exposed / 1e5,
    attributable_DALYs     = attributable_homicides * YLL_HOMICIDE,
    conf_lo_hom = (estimate - 1.96 * se) * pop_exposed / 1e5,
    conf_hi_hom = (estimate + 1.96 * se) * pop_exposed / 1e5
  )
cat("=== PER-EVENT ATTRIBUTABLE HOMICIDES + DALYs ===\n\n")
print(per_event_daly %>%
      select(event, beta_per_100k, pop_exposed,
             attributable_homicides, conf_lo_hom, conf_hi_hom,
             attributable_DALYs))

# ---------------------------------------------------------------------------
#  Average-effect: ANNUAL national estimate assuming a hypothetical
#  100% of US population exposed to any-outage-event
# ---------------------------------------------------------------------------
headline <- res$headline %>%
  filter(spec == "A_any_geoid_year", term == "treated_any")
US_POP_2022 <- 331e6  # approximate

national_daly <- tibble(
  spec = "national_100pct_exposed_upper_bound",
  beta = headline$estimate,
  pop  = US_POP_2022,
  attributable_homicides = headline$estimate * US_POP_2022 / 1e5,
  attributable_DALYs     = attributable_homicides * YLL_HOMICIDE
)

cat("\n=== NATIONAL BOUND — if all 331M Americans exposed to any-outage-event ===\n\n")
print(national_daly)

# Realistic exposed-only bound: total treated tract-years' population
realistic_pop <- sum(panel$wonder_homicide_pop[panel$treated_any == 1],
                     na.rm = TRUE)
realistic_daly <- tibble(
  spec = "realistic_treated_only",
  beta = headline$estimate,
  pop  = realistic_pop,
  attributable_homicides = headline$estimate * realistic_pop / 1e5,
  attributable_DALYs     = attributable_homicides * YLL_HOMICIDE
)
cat("\n=== REALISTIC — only actually-treated county-years, summed 2018-2023 ===\n\n")
print(realistic_daly)

# ---------------------------------------------------------------------------
#  Mechanism-attributable: outage × heat + outage × burden components
# ---------------------------------------------------------------------------
int_rows <- res$interactions_fdr
heat_int <- int_rows %>%
  filter(spec == "C_heat_and_burden",
         term  == "treated_any:extreme_heat_days_z")
burden_int <- int_rows %>%
  filter(spec == "C_heat_and_burden",
         term  == "treated_any:avg_energy_burden.x_z")

# For a tract 1 SD above average in extreme heat days, the outage effect adds
#   Δβ_heat = +2.07 per 100k
# Similarly for +1 SD burden: +1.52 per 100k
mechanism_daly <- tibble(
  moderator = c("heat_1sd_above", "burden_1sd_above"),
  delta_beta_per_100k = c(heat_int$estimate, burden_int$estimate),
  pop_treated = realistic_pop,
  additional_homicides = delta_beta_per_100k * pop_treated / 1e5,
  additional_DALYs     = additional_homicides * YLL_HOMICIDE
)
cat("\n=== MECHANISM-ATTRIBUTABLE — added burden per 1 SD moderator ===\n\n")
print(mechanism_daly)

# ---------------------------------------------------------------------------
#  Save
# ---------------------------------------------------------------------------
saveRDS(list(
  per_event = per_event_daly,
  national_bound = national_daly,
  realistic = realistic_daly,
  mechanism = mechanism_daly,
  YLL_per_homicide = YLL_HOMICIDE,
  source = "GBD 2019 US injuries (YLL ≈ 32/death); FE-DiD coefficients from wave_outage_homicide_full_analysis.R",
  ran_at = Sys.time()
), file.path(DATA, "outage_homicide_daly_rollup.rds"))

cat("\n✓ Wrote data/outage_homicide_daly_rollup.rds\n")
