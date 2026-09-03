#!/usr/bin/env Rscript
# ============================================================================
# merge_asthma_full_panel.R  —  Chain asthma outcomes + DER + AQ + shocks
# ----------------------------------------------------------------------------
# Wave F/L fleet-integration primitives cascade into a single asthma-ready
# enriched tract panel:
#
#   tract_panel_enhanced_with_asthma.csv     (295k × 164)   [B1]
#   +  tract_panel_enhanced_with_ders.csv    DER columns    [Wave F]
#   +  county_year_air_quality.rds            AQ drivers    [B3]
#   +  tract_year_shock_indicators.rds        heat/smoke    [B4]
# ---------------------------------------------------------------------------→
#   tract_panel_enhanced_with_asthma_ders.csv (~295k × ~250 cols)
#
# The output is the panel that `wave_asthma_intersection_sweep.R` reads.
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

# ---- 1. Load asthma-enriched base ---------------------------------------
message("Loading asthma-enriched base panel...")
asthma <- fread(file.path(DATA, "tract_panel_enhanced_with_asthma.csv"),
                showProgress = FALSE)
asthma[, geoid := as.character(geoid)]
asthma[, year  := as.integer(year)]
if ("county_fips" %in% names(asthma))
  asthma[, county_fips := formatC(suppressWarnings(as.integer(county_fips)),
                                    width = 5, flag = "0")]

# ---- 2. Load DER-enriched panel; pick up ONLY the DER columns -----------
message("Loading DER-enriched panel; extracting DER columns...")
ders <- fread(file.path(DATA, "tract_panel_enhanced_with_ders.csv"),
              showProgress = FALSE)
ders[, geoid := as.character(geoid)]
ders[, year  := as.integer(year)]
# The two panels share the base; keep only NEW columns from DER
new_from_ders <- setdiff(names(ders), names(asthma))
new_from_ders <- setdiff(new_from_ders, c("geoid", "year"))  # keys already present
message(sprintf("  DER-only columns to add: %d", length(new_from_ders)))
ders_slim <- ders[, c("geoid", "year", new_from_ders), with = FALSE]
# Dedupe on (geoid, year) — DER panel may have multiple rows per key from the
# broadcast joins in merge_ders_into_tract_panel.R; keep the first.
ders_slim <- unique(ders_slim, by = c("geoid", "year"))

merged <- ders_slim[asthma, on = c("geoid", "year")]

# ---- 3. Air-quality county-year -----------------------------------------
message("Merging air-quality (county × year)...")
aq <- as.data.table(readRDS(file.path(DATA, "county_year_air_quality.rds")))
aq[, county_fips := as.character(county_fips)]
aq[, year        := as.integer(year)]
aq_slim <- aq[, .(county_fips, year,
                    pm25_annual_ugm3, pm25_days_pct, ozone_days_count,
                    smoke_days_heavy, smoke_days_medium)]
aq_slim <- unique(aq_slim, by = c("county_fips", "year"))
merged <- aq_slim[merged, on = c("county_fips", "year")]

# ---- 4. Shock indicators (tract × year) ---------------------------------
message("Merging shock indicators (tract × year)...")
si <- as.data.table(readRDS(file.path(DATA, "tract_year_shock_indicators.rds")))
si[, geoid := as.character(geoid)]
si[, year  := as.integer(year)]
si_slim <- si[, .(geoid, year, treated_heat_wave, treated_smoke_event)]
si_slim <- unique(si_slim, by = c("geoid", "year"))
merged <- si_slim[merged, on = c("geoid", "year")]

# ---- 5. Zero-fill absence-is-zero shocks --------------------------------
zero_fill <- c("treated_heat_wave", "treated_smoke_event")
for (cc in zero_fill) {
  if (cc %in% names(merged))
    set(merged, which(is.na(merged[[cc]])), cc, 0L)
}

message(sprintf("\nFinal panel: %s rows × %d cols",
                format(nrow(merged), big.mark = ","), ncol(merged)))
message(sprintf("  asthma outcome cols:  %d",
                length(grep("^(places_)?asthma|wonder_asthma", names(merged)))))
message(sprintf("  AQ driver cols:       %d",
                length(grep("^(pm25|ozone|smoke)", names(merged)))))
message(sprintf("  shock indicator cols: %d",
                length(grep("^treated_", names(merged)))))

out_path <- file.path(DATA, "tract_panel_enhanced_with_asthma_ders.csv")
fwrite(merged, out_path)
message(sprintf("\nWrote %s  (%s MB)",
                out_path, round(file.size(out_path) / 1024^2, 1)))
