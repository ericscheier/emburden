# ============================================================================
# config_efficiency_sweep.R
# ----------------------------------------------------------------------------
# Focused intersection sweep for the asthma × efficiency angle
# (Kittner / Saterson / Zhang collaboration line).
#
# Consumed by analysis/run_intersection_sweep_by_outcome.R.
#
# Design:
#   4 asthma outcomes × 7 climate/disaster shocks × ~14 moderators × 3 specs
#     = ~1,176 outcome×shock×moderator×spec cells (± those dropped for
#       zero-variance or coverage < 100 obs)
#
# Moderators split three ways:
#   (A) EIA-861 detailed EE state-broadcast (Phase 1): 8 metrics
#   (B) ACS DP04 envelope-vintage cohorts (Phase 1): 3 pct built cohorts
#   (C) Composite adaptation index (Phase 2b): raw / perND / z
#
# All specs = the emburdenstats::sweep_intersections() standard triple:
#   2way          — outcome ~ shock*moderator + FE
#   heat_break    — split at median of extreme_heat_days, interact with shock
#   burden_break  — split at median of avg_energy_burden, interact with shock
# ============================================================================
CONFIG <- list(
  slug        = "asthma_efficiency",
  panel_path  = "data/tract_panel_enhanced_with_asthma_ders_ee_adapt.csv",

  outcomes = c(
    "places_asthma_prev",
    "asthma_hosp_rate",
    "asthma_ed_rate",
    "wonder_asthma_rate"
  ),

  shocks = c(
    "treated_any",
    "treated_uri",
    "treated_ida",
    "treated_harvey",
    "treated_psps",
    "treated_heat_wave",
    "treated_smoke_event"
  ),

  moderators = c(
    # (A) EIA-861 detailed EE state-broadcast — savings magnitude
    "ee_savings_kwh_per_hh_state",
    "ee_direct_cost_per_hh_state",
    "ee_peak_savings_kw_per_hh_state",
    "ee_savings_mwh_res_state",
    "ee_lifecycle_savings_mwh_state",
    "ee_weighted_avg_life_yrs_state",
    "n_utilities_reporting",
    "has_energy_efficiency",           # base panel indicator
    # (B) ACS DP04 envelope-vintage cohorts (higher = older housing)
    "pct_built_pre1980",
    "pct_built_1980_1999",
    "pct_built_post2000",
    # (C) Composite adaptation index (Yuetong-style, Phase 2b)
    "adapt_index_raw",
    "adapt_index_perND",
    "adapt_index_z"
  ),

  specs        = c("2way", "heat_break", "burden_break"),
  fe_vars      = c("geoid", "year"),
  cluster_var  = "geoid",
  heat_col     = "extreme_heat_days",
  burden_col   = "avg_energy_burden.x",
  min_obs      = 100L,
  out_dir      = "data"
)
