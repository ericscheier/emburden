#!/usr/bin/env Rscript
# ============================================================================
# merge_ders_into_tract_panel.R
# ----------------------------------------------------------------------------
# Formalized pipeline step: enrich the homicide tract panel with the full
# ecosystem DER inventory. Produces `data/tract_panel_enhanced_with_ders.csv`
# for downstream wave scripts to consume.
#
# Inputs (produced by upstream steps):
#   1. data/tract_panel_enhanced_with_homicide.csv
#         (from analysis/merge_homicide_into_tract_panel.R)
#   2. ~/.cache/emburdender/der_panel_tract_2009_2024.rds
#         (from emburdender::build_der_panel() — regenerate if stale)
#   3. data/county_year_eia860_storage.rds
#         (from analysis/build_county_year_eia860_storage.R)
#   4. data/county_year_eia860_storage_by_owner.rds
#         (from analysis/build_county_year_eia860_storage_by_owner.R;
#          adds IOU vs merchant BESS split)
#   5. data/tract_year_residential_storage.rds
#         (from analysis/build_tract_year_residential_storage.R;
#          LBNL-only view kept for auditability alongside DER-panel columns)
#
# Output:
#   data/tract_panel_enhanced_with_ders.csv
#
# Column additions (documented in data/PANEL_SCHEMA.md):
#   RESIDENTIAL STORAGE (LBNL TTS)
#     res_storage_count, res_storage_kwh
#   UTILITY-SCALE BESS (EIA-860)
#     bess_plant_count, bess_capacity_mw, bess_capacity_mwh,
#     bess_operating_mw, bess_operating_mwh, bess_any_storage
#   BESS BY OWNERSHIP (EIA-860 Schedule 4 + Schedule 1)
#     bess_mw_IOU, bess_mw_IPP-non-CHP, bess_mw_muni, bess_mw_coop,
#     bess_iou_pct, bess_merchant_pct, bess_mw_unknown
#   NET METERING STORAGE (EIA-861)
#     nem_storage_installations, nem_storage_capacity_mw,
#     nem_virtual_capacity_mw, nem_virtual_customers
#   DISTRIBUTED GENERATION
#     dg_system_count, dg_capacity_kw, dg_storage_capacity_kw,
#     dg_pv_capacity_kw
#   COMMUNITY SOLAR
#     cs_total_projects, cs_total_capacity_mw, cs_lmi_projects
#   USPVDB (utility PV)
#     uspvdb_cumulative_plants, uspvdb_cumulative_mw_dc
#   DYNAMIC PRICING (EIA-861)
#     dp_has_tou, dp_has_rtp, dp_has_vpp, dp_has_cpp, dp_has_cpr,
#     dp_tou_res, dp_rtp_res, dp_vpp_res, dp_cpp_res, dp_cpr_res
#   AMI penetration
#     ami_penetration_pct
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(dplyr)
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
  # residential storage
  "lbnl_storage_paired_count", "lbnl_storage_paired_kwh",
  # utility net-metering storage + virtual NM
  "nem_number_of_systems", "nem_capacity_kw", "nem_storage_installations",
  "nem_storage_capacity_mw", "nem_virtual_capacity_mw", "nem_virtual_customers",
  # distributed generation
  "dg_system_count", "dg_capacity_kw", "dg_storage_capacity_kw", "dg_pv_capacity_kw",
  # community solar
  "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
  # utility-scale PV (USPVDB)
  "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
  # dynamic pricing
  "dp_has_tou", "dp_has_rtp", "dp_has_vpp", "dp_has_cpp", "dp_has_cpr",
  "dp_tou_res", "dp_rtp_res", "dp_vpp_res", "dp_cpp_res", "dp_cpr_res",
  # AMI penetration ratio
  "ami_penetration_pct"
)
new_der_cols <- intersect(new_der_cols, names(der))
der_slim <- der[, c("geoid", "year", new_der_cols), with = FALSE]

# Rename LBNL storage cols to res_* for clarity
setnames(der_slim,
         old = c("lbnl_storage_paired_count", "lbnl_storage_paired_kwh"),
         new = c("res_storage_count", "res_storage_kwh"))

# ---- 3. Load utility BESS (base) ----------------------------------------
message("Loading utility BESS (base)...")
bess <- as.data.table(readRDS(file.path(DATA, "county_year_eia860_storage.rds")))
bess[, year := as.integer(year)]
bess[, county_fips := as.character(county_fips)]

# Broadcast EIA-860 years -> panel waves (2019->2018 wave; 2022->2022 wave)
broadcast_bess <- function(dt) {
  dt <- copy(dt)
  dt[, panel_year := fifelse(year == 2019, 2018L,
                     fifelse(year == 2022, 2022L, NA_integer_))]
  dt <- dt[!is.na(panel_year)]
  dt[, year := NULL]; setnames(dt, "panel_year", "year")
  dt
}
bess_bc <- broadcast_bess(bess)

# ---- 4. Load utility BESS by owner class (optional) ---------------------
bess_own_path <- file.path(DATA, "county_year_eia860_storage_by_owner.rds")
if (file.exists(bess_own_path)) {
  message("Loading utility BESS by owner class...")
  bess_own <- as.data.table(readRDS(bess_own_path))
  bess_own[, year := as.integer(year)]
  bess_own[, county_fips := as.character(county_fips)]
  bess_own_bc <- broadcast_bess(bess_own)
} else {
  message("(Optional) BESS-by-owner file not found — skipping ownership split.")
  bess_own_bc <- NULL
}

# ---- 4a. CDC HHI county-level Heat & Health Index (P3, national) --------
hhi_path <- file.path(DATA, "county_cdc_hhi_2024.rds")
if (file.exists(hhi_path)) {
  message("Loading CDC HHI county rollup (Wave L2, static 2024)...")
  hhi <- as.data.table(readRDS(hhi_path))
  hhi[, county_fips := as.character(county_fips)]
  # HHI is single-vintage (2024); broadcast to all panel years so each
  # panel row picks up its county's static HHI. HHI ranks are structural
  # (heat vulnerability), so time-invariance across 2014/2018/2022 is a
  # reasonable simplification.
  hhi_slim <- hhi[, .(county_fips, hhi_overall_rank, hhi_heat_burden_rank,
                       hhi_sensitivity_rank, hhi_nbe_rank, hhi_sociodem_rank)]
} else {
  message("(Optional) CDC HHI file not found — skipping.")
  hhi_slim <- NULL
}

# ---- 4b. CA SGIP county-year residential storage (P2, CA only) ---------
sgip_path <- file.path(DATA, "county_year_ca_sgip.rds")
if (file.exists(sgip_path)) {
  message("Loading CA SGIP county-year (CA only)...")
  sgip <- as.data.table(readRDS(sgip_path))
  sgip[, year := as.integer(year)]
  sgip[, county_fips := as.character(county_fips)]
  # SGIP waves already match panel years 2014/2018/2022; no broadcast needed
  sgip_bc <- sgip[, .(county_fips, year, sgip_battery_all_count,
                       sgip_battery_all_kwh, sgip_residential_count,
                       sgip_residential_kwh, sgip_equity_count,
                       sgip_equity_kwh)]
} else {
  message("(Optional) CA SGIP file not found — skipping.")
  sgip_bc <- NULL
}

# ---- 5. LBNL-only tract-year residential storage view (audit) -----------
res_only_path <- file.path(DATA, "tract_year_residential_storage.rds")
if (file.exists(res_only_path)) {
  message("Loading LBNL-only residential storage view (audit)...")
  res_only <- as.data.table(readRDS(res_only_path))
  res_only[, geoid := as.character(geoid)]
  res_only[, year  := as.integer(year)]
  audit_cols <- setdiff(names(res_only),
                        c("geoid", "year", "res_storage_count", "res_storage_kwh"))
  audit_cols <- intersect(audit_cols, names(res_only))
  audit_slim <- res_only[, c("geoid", "year", audit_cols), with = FALSE]
  # Rename with lbnl_ prefix to distinguish from DER-panel-sourced res_*
  setnames(audit_slim, audit_cols, paste0("lbnl_audit_", audit_cols))
} else {
  audit_slim <- NULL
}

# ---- 6. Join all sources ------------------------------------------------
message("Joining DER + BESS + audit onto panel...")
merged <- der_slim[panel, on = c("geoid", "year")]
merged <- bess_bc[merged,      on = c("county_fips", "year")]
if (!is.null(bess_own_bc)) {
  merged <- bess_own_bc[merged, on = c("county_fips", "year")]
}
if (!is.null(sgip_bc)) {
  merged <- sgip_bc[merged, on = c("county_fips", "year")]
}
if (!is.null(hhi_slim)) {
  # HHI is time-invariant; join on county_fips only, broadcast to all years
  merged <- hhi_slim[merged, on = "county_fips"]
}
if (!is.null(audit_slim)) {
  merged <- audit_slim[merged, on = c("geoid", "year")]
}

# ---- 7. Zero-fill "absence = 0, not missing" columns --------------------
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
message(sprintf("  DER columns added: %d",  length(new_der_cols)))
message(sprintf("  BESS columns (base): %d",
                length(grep("^bess_", names(bess_bc), value = TRUE))))
if (!is.null(bess_own_bc)) {
  message(sprintf("  BESS-by-owner columns: %d",
                  length(grep("^bess_", names(bess_own_bc), value = TRUE))))
}

# ---- 8. Write output ----------------------------------------------------
out_path <- file.path(DATA, "tract_panel_enhanced_with_ders.csv")
fwrite(merged, out_path)
message(sprintf("\nWrote %s (%s MB)\n",
                out_path,
                round(file.size(out_path) / 1024^2, 1)))
