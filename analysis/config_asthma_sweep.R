# Config for the asthma intersection sweep.
# Consumed by analysis/run_intersection_sweep.R
CONFIG <- list(
  slug        = "asthma",
  panel_path  = "data/tract_panel_enhanced_with_asthma_ders.csv",

  outcomes = c(
    "places_asthma_prev",   # tract-native prevalence (PLACES 2020/2022)
    "asthma_hosp_rate",     # county age-adj hospitalizations (EPHT)
    "asthma_ed_rate",       # county age-adj ED visits (EPHT)
    "wonder_asthma_rate"    # county mortality (WONDER MCOD J45/J46)
  ),

  shocks = c(
    "treated_any",           # any FEMA disaster (Ida + Uri + Harvey + PSPS)
    "treated_uri",           # Winter Storm Uri (TX 2021)
    "treated_ida",           # Hurricane Ida 2021
    "treated_harvey",        # Hurricane Harvey 2017
    "treated_psps",          # CA PSPS events
    "treated_heat_wave",     # heat-wave binary (Wave-F/asthma B4)
    "treated_smoke_event"    # wildfire-smoke binary (currently all zero
                             # pending NOAA HMS pull; retained for spec)
  ),

  moderators = c(
    # Utility-scale storage (Wave F: emburdender::build_county_year_bess)
    "bess_operating_mwh", "bess_operating_mw", "bess_capacity_mwh",
    "bess_plant_count", "bess_any_storage",
    # Residential storage
    "res_storage_kwh", "res_storage_count",
    "nem_storage_installations", "nem_storage_capacity_mw",
    "dg_storage_capacity_kw",
    # SGIP (CA-only variation, zero elsewhere)
    "sgip_residential_kwh", "sgip_residential_count",
    "sgip_equity_kwh", "sgip_equity_count",
    # Other DER families
    "cs_total_projects", "cs_lmi_projects", "cs_total_capacity_mw",
    "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
    "dp_tou_res", "dp_rtp_res", "dp_vpp_res",
    "ami_penetration_pct",
    # CDC HHI (Wave L2)
    "hhi_heat_burden_rank", "hhi_sociodem_rank",
    "hhi_sensitivity_rank", "hhi_nbe_rank", "hhi_overall_rank",
    # Air-quality drivers (Wave-asthma B3)
    "pm25_annual_ugm3", "pm25_days_pct", "ozone_days_count",
    # Building tech (heating fuel)
    "pct_heat_gas", "pct_heat_electric", "electric_heat_dominant",
    # Demographic + socio (from base panel)
    "pct_below_poverty", "avg_income"
  ),

  specs        = c("2way", "heat_break", "burden_break"),
  fe_vars      = c("geoid", "year"),
  cluster_var  = "geoid",
  heat_col     = "extreme_heat_days",
  burden_col   = "avg_energy_burden.x",
  min_obs      = 100L,
  out_dir      = "data"
)
