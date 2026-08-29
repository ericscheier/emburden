#!/usr/bin/env Rscript
# Build county-level CDC Heat & Health Index (HHI) rollup from the
# Harvard Dataverse mirror of the CDC Heat & Health Tracker bulk export.
#
# Source: Harvard Dataverse DOI 10.7910/DVN/IIGITP
#         file HHI_Data.zip → HHI Data 2024 United States.xlsx
#         (32,195 ZCTAs, 75 fields, single vintage 2024, static)
#
# Output columns (county_fips):
#   hhi_overall_rank      OVERALL_RANK   — overall HHI percentile
#   hhi_heat_burden_rank  HHB_RANK       — Historical Heat & Health Burden
#   hhi_sensitivity_rank  SEN_RANK       — Sensitivity (chronic conditions)
#   hhi_nbe_rank          NBE_RANK       — Natural & Built Environment
#   hhi_sociodem_rank     SOCIODEM_RANK  — Sociodemographic
#   hhi_pop_total         POP            — sum of ZCTA-level POP within county
#
# ZCTA→county via tigris zctas() ∩ counties() area intersection,
# population-weighted (each ZCTA's rank weighted by POP × area-share).

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(data.table); library(tigris); library(sf)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")
CACHE <- path.expand("~/.cache/emburdendata/cdc_hhi")

# ---- 1. Load HHI xlsx --------------------------------------------------
xlsx_path <- file.path(CACHE, "HHI Data 2024 United States.xlsx")
if (!file.exists(xlsx_path)) {
  # Download if missing
  dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)
  message("Downloading CDC HHI from Harvard Dataverse (18 MB)...")
  download.file("https://dataverse.harvard.edu/api/access/datafile/10991664",
                file.path(CACHE, "HHI_Data.zip"), mode = "wb")
  unzip(file.path(CACHE, "HHI_Data.zip"), exdir = CACHE)
}
message("Reading HHI xlsx...")
raw <- as.data.table(read_excel(xlsx_path, sheet = 1, guess_max = 50000))
message(sprintf("Loaded %s ZCTAs across %d states", format(nrow(raw), big.mark=","),
                uniqueN(raw$STATE)))

# Sentinel: -999 → NA
hhi_cols <- c("OVERALL_RANK","HHB_RANK","SEN_RANK","NBE_RANK","SOCIODEM_RANK")
for (cc in hhi_cols) {
  raw[[cc]][raw[[cc]] == -999] <- NA_real_
}
raw[, zcta5 := sprintf("%05s", as.character(ZCTA))]
raw[, POP   := suppressWarnings(as.numeric(POP))]

# ---- 2. Build ZCTA→county crosswalk via tigris (cached) ----------------
xw_path <- file.path(CACHE, "zcta_county_xw_2020.rds")
if (!file.exists(xw_path)) {
  options(tigris_use_cache = TRUE)
  message("Fetching tigris ZCTAs + counties (2020, one-time build)...")
  zctas <- suppressMessages(tigris::zctas(cb = TRUE, year = 2020, progress_bar = FALSE))
  ctys  <- suppressMessages(tigris::counties(cb = TRUE, year = 2020, resolution = "20m",
                                              progress_bar = FALSE))
  zctas <- sf::st_transform(zctas, 5070)
  ctys  <- sf::st_transform(ctys,  5070)
  zctas$zip_area <- as.numeric(sf::st_area(zctas))
  message("Intersecting ZCTAs × counties (this takes 1-2 min)...")
  inter <- suppressWarnings(sf::st_intersection(
    zctas[, c("ZCTA5CE20","zip_area")],
    ctys[, "GEOID"]))
  inter$part_area <- as.numeric(sf::st_area(inter))
  xw <- as.data.table(sf::st_drop_geometry(inter))
  setnames(xw, c("ZCTA5CE20","GEOID"), c("zcta5","county_fips"))
  xw[, weight := part_area / zip_area]
  xw <- xw[weight > 0.001, .(zcta5, county_fips, weight)]
  xw[, zcta5 := sprintf("%05s", zcta5)]
  xw[, county_fips := sprintf("%05s", county_fips)]
  saveRDS(xw, xw_path)
  message(sprintf("Wrote %s (%d rows)", xw_path, nrow(xw)))
} else {
  xw <- as.data.table(readRDS(xw_path))
}

# ---- 3. Population × area weighted aggregation -------------------------
m <- xw[raw, on = "zcta5", nomatch = NULL]
m[, wpop := weight * ifelse(is.na(POP), 1, POP)]

cy <- m[, .(
  hhi_overall_rank     = weighted.mean(OVERALL_RANK,  wpop, na.rm = TRUE),
  hhi_heat_burden_rank = weighted.mean(HHB_RANK,      wpop, na.rm = TRUE),
  hhi_sensitivity_rank = weighted.mean(SEN_RANK,      wpop, na.rm = TRUE),
  hhi_nbe_rank         = weighted.mean(NBE_RANK,      wpop, na.rm = TRUE),
  hhi_sociodem_rank    = weighted.mean(SOCIODEM_RANK, wpop, na.rm = TRUE),
  hhi_pop_total        = sum(POP * weight, na.rm = TRUE),
  n_zctas              = uniqueN(zcta5)
), by = county_fips]
setorder(cy, county_fips)

out_path <- file.path(DATA, "county_cdc_hhi_2024.rds")
saveRDS(as.data.frame(cy), out_path)
message(sprintf("\nWrote %s (%d unique counties, %d states)",
                out_path, nrow(cy),
                uniqueN(substr(cy$county_fips, 1, 2))))

cat("\nCoverage summary:\n")
cat(sprintf("  counties w/ overall rank: %s\n", format(sum(!is.na(cy$hhi_overall_rank)), big.mark=",")))
cat(sprintf("  counties w/ heat burden : %s\n", format(sum(!is.na(cy$hhi_heat_burden_rank)), big.mark=",")))
cat(sprintf("  counties w/ sociodem    : %s\n", format(sum(!is.na(cy$hhi_sociodem_rank)), big.mark=",")))

cat("\nSummary stats (percentile rank):\n")
for (cc in c("hhi_overall_rank","hhi_heat_burden_rank","hhi_sensitivity_rank",
             "hhi_nbe_rank","hhi_sociodem_rank")) {
  s <- summary(cy[[cc]])
  cat(sprintf("  %-24s min=%.2f  median=%.2f  max=%.2f\n",
              cc, s[["Min."]], s[["Median"]], s[["Max."]]))
}
