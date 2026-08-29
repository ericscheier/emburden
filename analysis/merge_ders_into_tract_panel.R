#!/usr/bin/env Rscript
# ============================================================================
# merge_ders_into_tract_panel.R
# ----------------------------------------------------------------------------
# Formalized pipeline step: enrich the homicide tract panel with the full
# ecosystem DER inventory. Produces `data/tract_panel_enhanced_with_ders.csv`
# for downstream wave scripts to consume.
#
# Inputs:
#   1. data/tract_panel_enhanced_with_homicide.csv
#         (from analysis/merge_homicide_into_tract_panel.R)
#   2. ~/.cache/emburdender/der_panel_tract_2009_2024.rds
#         (from emburdender::build_der_panel())
#   3. emburdender::build_county_year_bess(2019:2024, by_owner=TRUE)
#         (was: analysis/build_county_year_eia860_storage{,_by_owner}.R
#         — lifted to emburdender in Wave F fleet-cleanup)
#   4. emburdendata::aggregate_ca_sgip_to_county(c(2014, 2018, 2022))
#         (was: analysis/build_ca_sgip_county_year.R — lifted to
#         emburdendata in Wave F)
#   5. emburdendata::aggregate_cdc_hhi_to_county()
#         (was: analysis/build_cdc_hhi_county.R — lifted to
#         emburdendata in Wave F)
#   6. data/tract_year_residential_storage.rds (LBNL-only audit view)
#
# Output:
#   data/tract_panel_enhanced_with_ders.csv
#
# See data/PANEL_SCHEMA.md for column-family documentation.
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(dplyr)
  # Fleet packages (from ScheierVentures/emburden{data,er,util})
  devtools::load_all("/home/ess/Documents/apps/emburdendata", quiet = TRUE)
  devtools::load_all("/home/ess/Documents/apps/emburdender",  quiet = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

# ---- 1. Load base homicide panel ----------------------------------------
message("Loading base homicide panel...")
panel <- fread(file.path(DATA, "tract_panel_enhanced_with_homicide.csv"),
               showProgress = FALSE)
panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
panel[, year := as.integer(year)]
panel[, geoid := as.character(geoid)]

# ---- 2. Load ecosystem DER panel ----------------------------------------
der_path <- path.expand("~/.cache/emburdender/der_panel_tract_2009_2024.rds")
if (!file.exists(der_path)) {
  stop("DER panel cache missing: ", der_path,
       "\nRun: emburdender::build_der_panel(geography='tract', years=2009:2024)")
}
message("Loading DER panel from ", der_path, " ...")
der <- as.data.table(readRDS(der_path))
der[, geoid := as.character(geoid)]
der[, year  := as.integer(year)]

# Sentinel clip for LBNL storage-kWh column (see emburdender fix 2026-08-29)
der[, lbnl_storage_paired_kwh := pmax(lbnl_storage_paired_kwh, 0, na.rm=TRUE)]
der[is.na(lbnl_storage_paired_kwh), lbnl_storage_paired_kwh := 0]
der[is.na(lbnl_storage_paired_count), lbnl_storage_paired_count := 0L]

new_der_cols <- c(
  "lbnl_storage_paired_count", "lbnl_storage_paired_kwh",
  "nem_number_of_systems", "nem_capacity_kw", "nem_storage_installations",
  "nem_storage_capacity_mw", "nem_virtual_capacity_mw", "nem_virtual_customers",
  "dg_system_count", "dg_capacity_kw", "dg_storage_capacity_kw", "dg_pv_capacity_kw",
  "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
  "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
  "dp_has_tou", "dp_has_rtp", "dp_has_vpp", "dp_has_cpp", "dp_has_cpr",
  "dp_tou_res", "dp_rtp_res", "dp_vpp_res", "dp_cpp_res", "dp_cpr_res",
  "ami_penetration_pct"
)
new_der_cols <- intersect(new_der_cols, names(der))
der_slim <- der[, c("geoid", "year", new_der_cols), with = FALSE]
setnames(der_slim,
         old = c("lbnl_storage_paired_count", "lbnl_storage_paired_kwh"),
         new = c("res_storage_count", "res_storage_kwh"))

# ---- 3. Utility BESS (base + by owner) via emburdender ------------------
message("Loading utility BESS via emburdender::build_county_year_bess()...")
bess_own <- as.data.table(build_county_year_bess(
  years = 2019:2022, by_owner = TRUE, verbose = FALSE))
bess_own[, year := as.integer(year)]
bess_own[, county_fips := as.character(county_fips)]

# Broadcast EIA-860 years -> panel waves (2019->2018 wave; 2022->2022 wave)
broadcast_bess <- function(dt) {
  dt <- copy(dt)
  dt[, panel_year := fifelse(year == 2019, 2018L,
                     fifelse(year == 2022, 2022L, NA_integer_))]
  dt <- dt[!is.na(panel_year)]
  dt[, year := NULL]; setnames(dt, "panel_year", "year")
  dt
}
bess_bc <- broadcast_bess(bess_own)

# ---- 4. CDC HHI county rollup via emburdendata --------------------------
message("Loading CDC HHI (national, static 2024) via aggregate_cdc_hhi_to_county()...")
hhi <- as.data.table(aggregate_cdc_hhi_to_county(verbose = FALSE))
hhi[, county_fips := as.character(county_fips)]
hhi_slim <- hhi[, .(county_fips, hhi_overall_rank, hhi_heat_burden_rank,
                     hhi_sensitivity_rank, hhi_nbe_rank, hhi_sociodem_rank)]

# ---- 5. CA SGIP county rollup via emburdendata (CA only) ----------------
message("Loading CA SGIP county-year via aggregate_ca_sgip_to_county()...")
sgip <- as.data.table(aggregate_ca_sgip_to_county(
  vintage_year_end = c(2014, 2018, 2022), verbose = FALSE))
sgip[, county_fips := as.character(county_fips)]
setnames(sgip, "vintage_year_end", "year")
# Rename to preserve prior column names in the enriched panel
setnames(sgip,
         old = c("sgip_battery_count", "sgip_battery_kwh",
                 "sgip_low_income_count", "sgip_low_income_kwh"),
         new = c("sgip_battery_all_count", "sgip_battery_all_kwh",
                 "sgip_equity_count", "sgip_equity_kwh"))
sgip_slim <- sgip[, .(county_fips, year,
                       sgip_battery_all_count, sgip_battery_all_kwh,
                       sgip_residential_count, sgip_residential_kwh,
                       sgip_equity_count, sgip_equity_kwh)]

# ---- 6. LBNL-only tract-year residential storage view (audit) -----------
res_only_path <- file.path(DATA, "tract_year_residential_storage.rds")
if (file.exists(res_only_path)) {
  message("Loading LBNL-only residential storage view (audit)...")
  res_only <- as.data.table(readRDS(res_only_path))
  res_only[, geoid := as.character(geoid)]
  res_only[, year  := as.integer(year)]
  audit_cols <- setdiff(names(res_only),
                        c("geoid", "year", "res_storage_count", "res_storage_kwh"))
  audit_slim <- res_only[, c("geoid", "year", audit_cols), with = FALSE]
  setnames(audit_slim, audit_cols, paste0("lbnl_audit_", audit_cols))
} else {
  audit_slim <- NULL
}

# ---- 7. Join all sources ------------------------------------------------
message("Joining DER + BESS + HHI + SGIP + audit onto panel...")
merged <- der_slim[panel, on = c("geoid", "year")]
merged <- bess_bc[merged,   on = c("county_fips", "year")]
# HHI is time-invariant; join on county_fips only
merged <- hhi_slim[merged,   on = "county_fips"]
merged <- sgip_slim[merged,  on = c("county_fips", "year")]
if (!is.null(audit_slim)) {
  merged <- audit_slim[merged, on = c("geoid", "year")]
}

# ---- 8. Zero-fill "absence = 0, not missing" columns --------------------
zero_fill_cols <- c(
  "res_storage_count", "res_storage_kwh",
  "nem_storage_installations", "nem_storage_capacity_mw",
  "dg_storage_capacity_kw",
  "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
  "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
  grep("^dp_",   names(merged), value = TRUE),
  grep("^bess_", names(merged), value = TRUE),
  grep("^sgip_", names(merged), value = TRUE)  # CA-only; NA elsewhere OK
)
zero_fill_cols <- intersect(zero_fill_cols, names(merged))
for (cc in zero_fill_cols) set(merged, which(is.na(merged[[cc]])), cc, 0)

message(sprintf("Final panel: %s rows | %d cols\n",
                format(nrow(merged), big.mark = ","), ncol(merged)))
message(sprintf("  DER columns:        %d",  length(new_der_cols)))
message(sprintf("  BESS columns:       %d",  length(grep("^bess_", names(bess_bc), value = TRUE))))
message(sprintf("  HHI columns:        %d",  ncol(hhi_slim) - 1L))
message(sprintf("  SGIP columns:       %d",  ncol(sgip_slim) - 2L))

# ---- 9. Write output ----------------------------------------------------
out_path <- file.path(DATA, "tract_panel_enhanced_with_ders.csv")
fwrite(merged, out_path)
message(sprintf("\nWrote %s (%s MB)\n",
                out_path,
                round(file.size(out_path) / 1024^2, 1)))
