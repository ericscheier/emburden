#!/usr/bin/env Rscript
# ============================================================================
# build_adaptation_index.R
# ----------------------------------------------------------------------------
# Compose a Yuetong-style composite adaptation index from the enriched panel.
# See proposal_adaptation_index.pdf / Slide-18 (Zhang 2026 correspondence):
#
#   "Measure adaptation capacity as per unit of climatic exposure, since
#    places with milder climates require less cooling or heating capacity.
#    Accordingly, resource-based indicators would be normalized by long-run
#    measures of climate need."
#
# Slide-18 components used here:
#   - Solar + storage: res_storage_kwh (paired), nem_capacity_kw
#   - Demand response: dp_vpp_res (share of residential DR-eligible customers)
#   - Time-of-use pricing: dp_tou_res
#   - Advanced metering: ami_penetration_pct
#   - Energy efficiency: ee_savings_kwh_per_hh_state (Phase 1 output)
#   - eGRID mix / low-carbon share: (absent — leave NULL for now)
#
# Climate-need denominator:
#   - HDD + CDD is not in the panel; substitute `extreme_heat_days` (proxy
#     for climate need), with a lower bound to avoid divide-by-zero
#     amplification.
#
# Composition:
#   1. Winsorize each raw component at [1%, 99%] to guard against right-skew
#   2. z-score within panel-year (so DER build-up over waves is not
#      absorbed into the baseline capacity signal)
#   3. Equal-weight mean of available components
#   4. Divide by log1p(climate_need) with lower bound
#   5. z-score the final index within panel-year (moderator scale)
#
# Output columns appended to the enriched panel:
#   adapt_index_raw    (composite pre-normalization)
#   adapt_index_perND  (raw / log1p(need))
#   adapt_index_z      (z-scored within year — primary moderator)
#
# Companion helpers:
#   adapt_index_ncomp  (count of non-NA components used per cell)
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(dplyr)
})

REPO  <- "/home/ess/Documents/apps/net_energy_equity"
DATA  <- file.path(REPO, "data")
IN    <- file.path(DATA, "tract_panel_enhanced_with_asthma_ders_ee.csv")
OUT   <- file.path(DATA, "tract_panel_enhanced_with_asthma_ders_ee_adapt.csv")

panel <- fread(IN, showProgress = FALSE)
panel[, year := as.integer(year)]
panel[, geoid := as.character(geoid)]

# Slide-18 component names (tract-level unless suffixed _state)
COMPONENTS <- c(
  "res_storage_kwh",              # solar+storage (paired residential)
  "nem_capacity_kw",              # residential solar
  "dp_vpp_res",                   # DR share
  "dp_tou_res",                   # TOU share
  "ami_penetration_pct",          # AMI share
  "ee_savings_kwh_per_hh_state"   # EE (state-broadcast, this wave)
)
COMPONENTS <- intersect(COMPONENTS, names(panel))
message("Using ", length(COMPONENTS), " components: ",
        paste(COMPONENTS, collapse = ", "))

winsorize <- function(x, probs = c(0.01, 0.99)) {
  if (all(is.na(x))) return(x)
  qs <- stats::quantile(x, probs = probs, na.rm = TRUE)
  pmin(pmax(x, qs[[1L]]), qs[[2L]])
}

zscore <- function(x) {
  s <- stats::sd(x, na.rm = TRUE)
  if (!is.finite(s) || s == 0) return(rep(NA_real_, length(x)))
  (x - mean(x, na.rm = TRUE)) / s
}

# ---- 1. Winsorize + z-score each component within panel-year ---------------
for (cn in COMPONENTS) {
  win_col <- paste0("_win_", cn)
  z_col   <- paste0("_z_", cn)
  panel[, (win_col) := winsorize(get(cn)), by = year]
  panel[, (z_col)   := zscore(get(win_col)), by = year]
}

# ---- 2. Equal-weight mean of z-scored components ---------------------------
z_cols <- paste0("_z_", COMPONENTS)
panel[, adapt_index_ncomp := rowSums(!is.na(.SD)), .SDcols = z_cols]
panel[, adapt_index_raw   := rowMeans(.SD, na.rm = TRUE), .SDcols = z_cols]
panel[is.nan(adapt_index_raw), adapt_index_raw := NA_real_]

# ---- 3. Normalize by climate need ------------------------------------------
if ("extreme_heat_days" %in% names(panel)) {
  panel[, adapt_index_perND := adapt_index_raw /
          log1p(pmax(extreme_heat_days, 1, na.rm = TRUE))]
} else {
  panel[, adapt_index_perND := adapt_index_raw]
}

# ---- 4. z-score the normalized index within year for use as moderator ------
panel[, adapt_index_z := zscore(adapt_index_perND), by = year]

# ---- 5. Drop intermediate winsorize / z columns ----------------------------
scratch <- grep("^_(win|z)_", names(panel), value = TRUE)
panel[, (scratch) := NULL]

# ---- 6. Diagnostics --------------------------------------------------------
cat("Adaptation index diagnostics:\n")
cat(sprintf("  adapt_index_ncomp     : mean=%.2f, min=%d, max=%d\n",
            mean(panel$adapt_index_ncomp, na.rm = TRUE),
            min(panel$adapt_index_ncomp,  na.rm = TRUE),
            max(panel$adapt_index_ncomp,  na.rm = TRUE)))
cat(sprintf("  adapt_index_raw       : %s\n",
            paste(round(range(panel$adapt_index_raw,   na.rm = TRUE), 3), collapse=" .. ")))
cat(sprintf("  adapt_index_perND     : %s\n",
            paste(round(range(panel$adapt_index_perND, na.rm = TRUE), 3), collapse=" .. ")))
cat(sprintf("  adapt_index_z         : %s\n",
            paste(round(range(panel$adapt_index_z,     na.rm = TRUE), 3), collapse=" .. ")))
cat(sprintf("  coverage (adapt_index_z non-NA): %.1f%%\n",
            100 * mean(!is.na(panel$adapt_index_z))))

fwrite(panel, OUT)
message(sprintf("Wrote %s (%.1f MB)", OUT, file.size(OUT) / 1024^2))
