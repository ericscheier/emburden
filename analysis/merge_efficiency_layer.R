#!/usr/bin/env Rscript
# ============================================================================
# merge_efficiency_layer.R
# ----------------------------------------------------------------------------
# Enrich the asthma tract panel with:
#   (a) detailed EIA-861 residential energy-efficiency metrics via
#       emburdender::load_eia861_energy_efficiency() — savings MWh, direct
#       cost, peak-MW savings, weighted-avg life years — aggregated to
#       state-year and per-household normalized.
#   (b) ACS DP04 built-year cohorts (envelope-vintage proxy) — pct pre-1980,
#       1980-1999, and post-2000 housing at the tract level.
#   (c) WAP weatherization state-year (DOE) — DEFERRED: DOE Excel URLs are
#       no longer publicly hosted (2026-09 status). Loader stays available
#       for a future manual-file drop.
#
# Output: data/tract_panel_enhanced_with_asthma_ders_ee.csv (rewrites the
# efficiency-enriched panel that Phase 2 will consume).
#
# Motivation: the base panel's ee_* columns are aggregate customer-count
# indicators; this layer provides savings-magnitude signal (kWh saved,
# dollars invested, MW peak reduced) so the efficiency intersection can
# be identified in the sweep.
#
# Companion to the Yuetong-style adaptation-index moderator built in
# analysis/build_adaptation_index.R (Phase 2b).
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(dplyr)
  devtools::load_all("/home/ess/Documents/apps/emburdender",  quiet = TRUE)
  devtools::load_all("/home/ess/Documents/apps/emburdendata", quiet = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")
PANEL_YEARS <- c(2014L, 2018L, 2022L)

# ---- 0. State FIPS lookup ---------------------------------------------------
# EIA-861 uses two-letter postal codes; panel keys on state_fips integer.
state_lookup <- data.table(
  state    = c(state.abb, "DC"),
  state_fips_int = c(1,2,4,5,6,8,9,10,12,13,15,16,17,18,19,20,21,22,23,24,25,
                    26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,
                    46,47,48,49,50,51,53,54,55,56,11)
)

# ---- 1. Load base panel -----------------------------------------------------
panel_path <- file.path(DATA, "tract_panel_enhanced_with_asthma_ders.csv")
message("Loading base panel: ", panel_path)
panel <- fread(panel_path, showProgress = FALSE)
panel[, year := as.integer(year)]
panel[, state_fips := as.integer(state_fips)]
panel[, geoid := as.character(geoid)]
panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]

message(sprintf("Panel: %s rows × %d cols; years %s",
                format(nrow(panel), big.mark=","), ncol(panel),
                paste(sort(unique(panel$year)), collapse=", ")))

# ---- 2. Detailed EIA-861 energy-efficiency, state-year rollup ---------------
message("Loading detailed EIA-861 EE for 2013-2023 ...")
ee_utility <- setDT(load_eia861_energy_efficiency(years = 2013:2023))

ee_state_year <- ee_utility[, .(
  ee_savings_mwh_res_state       = sum(ee_savings_mwh_res, na.rm = TRUE),
  ee_savings_mwh_state           = sum(ee_savings_mwh, na.rm = TRUE),
  ee_peak_savings_mw_res_state   = sum(ee_peak_savings_mw_res, na.rm = TRUE),
  ee_peak_savings_mw_state       = sum(ee_peak_savings_mw, na.rm = TRUE),
  ee_lifecycle_savings_mwh_state = sum(ee_lifecycle_savings_mwh, na.rm = TRUE),
  ee_direct_cost_kusd_state      = sum(ee_direct_cost_usd, na.rm = TRUE),
  ee_other_costs_kusd_state      = sum(ee_other_costs_usd, na.rm = TRUE),
  ee_weighted_avg_life_yrs_state = stats::weighted.mean(
    ee_weighted_avg_life_yrs,
    w = pmax(ee_savings_mwh, 1, na.rm = TRUE),
    na.rm = TRUE),
  n_utilities_reporting          = .N,
  n_utilities_with_ee            = sum(has_ee_program == TRUE, na.rm = TRUE)
), by = .(state, year)]

# Attach state FIPS
ee_state_year <- state_lookup[ee_state_year, on = "state"]

# Snap EE reporting years to panel waves (nearest of 2014/2018/2022, within ±2)
snap_to_panel_year <- function(y) {
  vapply(y, function(yy) {
    d <- abs(PANEL_YEARS - yy)
    if (min(d) <= 2L) PANEL_YEARS[which.min(d)] else NA_integer_
  }, integer(1))
}
ee_state_year[, panel_year := snap_to_panel_year(year)]
ee_state_year <- ee_state_year[!is.na(panel_year)]

# Where a panel wave receives multiple reporting years (e.g., 2014 gets 2013+2014+2015),
# average the state-year magnitudes so the wave is 3-year-mean-anchored.
ee_state_wave <- ee_state_year[, .(
  ee_savings_mwh_res_state       = mean(ee_savings_mwh_res_state,       na.rm = TRUE),
  ee_savings_mwh_state           = mean(ee_savings_mwh_state,           na.rm = TRUE),
  ee_peak_savings_mw_res_state   = mean(ee_peak_savings_mw_res_state,   na.rm = TRUE),
  ee_peak_savings_mw_state       = mean(ee_peak_savings_mw_state,       na.rm = TRUE),
  ee_lifecycle_savings_mwh_state = mean(ee_lifecycle_savings_mwh_state, na.rm = TRUE),
  ee_direct_cost_kusd_state      = mean(ee_direct_cost_kusd_state,      na.rm = TRUE),
  ee_other_costs_kusd_state      = mean(ee_other_costs_kusd_state,      na.rm = TRUE),
  ee_weighted_avg_life_yrs_state = mean(ee_weighted_avg_life_yrs_state, na.rm = TRUE),
  n_years_averaged               = .N
), by = .(state_fips_int, panel_year)]
setnames(ee_state_wave, c("state_fips_int","panel_year"), c("state_fips","year"))

# ---- 3. Per-household normalized versions ----------------------------------
state_hh <- panel[, .(state_hh_total = sum(total_households, na.rm = TRUE)),
                  by = .(state_fips, year)]
ee_state_wave <- state_hh[ee_state_wave, on = c("state_fips", "year")]

ee_state_wave[, `:=`(
  ee_savings_kwh_per_hh_state     = 1000 * ee_savings_mwh_res_state / pmax(state_hh_total, 1),
  ee_direct_cost_per_hh_state     = 1000 * ee_direct_cost_kusd_state  / pmax(state_hh_total, 1),
  ee_peak_savings_kw_per_hh_state = 1000 * ee_peak_savings_mw_res_state / pmax(state_hh_total, 1)
)]

message(sprintf(
  "EE state-wave rollup: %d rows (state × wave); median residential kWh saved / hh = %.1f",
  nrow(ee_state_wave),
  median(ee_state_wave$ee_savings_kwh_per_hh_state, na.rm = TRUE)))

# ---- 4. ACS DP04 built-year cohorts ----------------------------------------
# DP04_0026E .. DP04_0033E span "Built 2020 or later" through "Built 1939 or earlier"
# on the 5-year ACS profile. Cohorts:
#   pre1980   = _0031 + _0032 + _0033 (1970-79 + <1940 buckets: pre-1970 + 1970-79)
#   1980_1999 = _0029 + _0030          (1980-89 + 1990-99)
#   post2000  = _0026 + _0027 + _0028  (2020+, 2010-19, 2000-09)
# Denominator: DP04_0025E "Total housing units by year structure built".
message("Loading ACS DP04 built-year cohorts ...")

acs_cache <- file.path(DATA, "acs_dp04_builtyear_tract.rds")
if (file.exists(acs_cache)) {
  message("  using cached: ", acs_cache)
  builtyear <- setDT(readRDS(acs_cache))
} else if (requireNamespace("tidycensus", quietly = TRUE) &&
           nzchar(Sys.getenv("CENSUS_API_KEY"))) {
  vars <- paste0("DP04_00", sprintf("%02d", 25:33), "E")
  states_needed <- unique(panel$state_fips)
  states_needed <- states_needed[!is.na(states_needed)]
  fetch_state_year <- function(st, yr) {
    st_fips <- formatC(as.integer(st), width = 2, flag = "0")
    tryCatch({
      dat <- tidycensus::get_acs(
        geography = "tract", variables = vars, year = yr,
        survey = "acs5", state = st_fips, output = "wide",
        cache_table = TRUE)
      dat$year <- yr
      dat
    }, error = function(e) {
      message("    ACS ", yr, " state ", st_fips, " fetch failed: ",
              conditionMessage(e))
      NULL
    })
  }
  parts <- list()
  for (yr in PANEL_YEARS) {
    message("  ACS ", yr, ": fetching ", length(states_needed), " states ...")
    for (st in states_needed) {
      parts[[length(parts) + 1L]] <- fetch_state_year(st, yr)
    }
  }
  parts <- parts[!vapply(parts, is.null, logical(1))]
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) > 0L) {
    builtyear_raw <- rbindlist(parts, fill = TRUE)
    builtyear <- builtyear_raw[, .(
      geoid = GEOID,
      year  = year,
      total_units = DP04_0025E,
      pre1980_units    = DP04_0031E + DP04_0032E + DP04_0033E,
      built80_99_units = DP04_0029E + DP04_0030E,
      post2000_units   = DP04_0026E + DP04_0027E + DP04_0028E
    )]
    builtyear[, `:=`(
      pct_built_pre1980   = 100 * pre1980_units    / pmax(total_units, 1),
      pct_built_1980_1999 = 100 * built80_99_units / pmax(total_units, 1),
      pct_built_post2000  = 100 * post2000_units   / pmax(total_units, 1)
    )]
    saveRDS(builtyear, acs_cache)
    message(sprintf("  cached %s rows to %s",
                    format(nrow(builtyear), big.mark = ","), acs_cache))
  } else {
    message("  no ACS years fetched — skipping built-year cohorts")
    builtyear <- NULL
  }
} else {
  message("  CENSUS_API_KEY or tidycensus missing — skipping built-year cohorts")
  builtyear <- NULL
}

# ---- 5. Merge into panel ---------------------------------------------------
message("Merging EE state-wave and built-year cohorts onto panel ...")

merged <- ee_state_wave[panel, on = c("state_fips", "year")]

if (!is.null(builtyear)) {
  builtyear[, year  := as.integer(year)]
  builtyear[, geoid := as.character(geoid)]
  bslim <- builtyear[, .(geoid, year,
                          pct_built_pre1980, pct_built_1980_1999,
                          pct_built_post2000)]
  merged <- bslim[merged, on = c("geoid", "year")]
}

# ---- 6. Diagnostic summary --------------------------------------------------
message("=== EE / built-year enrichment summary ===")
cat(sprintf("  rows merged             : %s\n",
            format(nrow(merged), big.mark = ",")))
cat(sprintf("  columns before/after    : %d -> %d\n",
            ncol(panel), ncol(merged)))
new_cols <- setdiff(names(merged), names(panel))
cat("  new columns             : ", paste(new_cols, collapse = ", "), "\n")

if (!is.null(builtyear)) {
  cat(sprintf("  pct_built_pre1980 coverage: %.1f%%\n",
              100 * mean(!is.na(merged$pct_built_pre1980))))
}
cat(sprintf("  ee_savings_kwh_per_hh_state coverage: %.1f%%\n",
            100 * mean(!is.na(merged$ee_savings_kwh_per_hh_state))))

# ---- 7. Write output --------------------------------------------------------
out_path <- file.path(DATA, "tract_panel_enhanced_with_asthma_ders_ee.csv")
fwrite(merged, out_path)
message(sprintf("Wrote %s (%.1f MB)",
                out_path, file.size(out_path) / 1024^2))
