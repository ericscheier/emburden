#!/usr/bin/env Rscript
# Extended county-year outage-homicide panel with ALL FEMA events
# (all 41 events in event_outages_county_2014_2024.csv), grouped as:
#   - Named hurricanes: Harvey (2017), Irma (2017), Michael (2018), Ida (2021),
#                       Maria (2017, PR excluded), Helene (2024)
#   - Hurricane-season umbrella: Hurricane YYYY (all counties in hurricane
#     disasters that year excluding the named ones above where applicable)
#   - Winter Storm Uri (2021, TX)
#   - CA PSPS (2019+)
#   - Severe storms, floods, ice storms, tornadoes, fires — as separate
#     indicators per event
#
# Output: data/county_year_all_events_homicide_panel.rds
suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(readr)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

# -----------------------------------------------------------------------------
#  Homicide + outage baseline (same as build_county_year_outage_homicide.R)
# -----------------------------------------------------------------------------
hom <- readRDS(file.path(DATA, "wonder_violence_county_year_2018_2023.rds"))
setDT(hom)
hom[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
setnames(hom,
         old = c("homicide_deaths", "homicide_population",
                 "homicide_rate_per_100k", "homicide_suppressed"),
         new = c("wonder_homicide_deaths", "wonder_homicide_pop",
                 "wonder_homicide_rate", "wonder_homicide_suppressed"))
hom[, year := as.integer(year)]
hom_slim <- hom[, .(state_fips, county_fips, county_name, year,
                    wonder_homicide_deaths, wonder_homicide_pop,
                    wonder_homicide_rate, wonder_homicide_suppressed)]

outage_cm <- readRDS(file.path(DATA, "county_month_eagle_i.rds"))
setDT(outage_cm)
outage_cm[, county_fips := as.character(county_fips)]
outage_cy <- outage_cm[, .(
  outage_customer_days_year = sum(outage_customer_days, na.rm = TRUE),
  outage_days_year          = sum(outage_days, na.rm = TRUE),
  outage_peak_year          = max(outage_peak_customers, na.rm = TRUE)
), by = .(county_fips, year)]

# -----------------------------------------------------------------------------
#  FEMA event catalog — extract per-event exposed county lists
# -----------------------------------------------------------------------------
fema <- fread(file.path(DATA, "event_outages_county_2014_2024.csv"))
fema[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
fema[, event_year := as.integer(substr(event_start, 1, 4))]

# Build a table of (event_key, event_year, counties)
event_counties <- fema[, .(counties = list(unique(county_fips))),
                       by = .(event_name, event_year)]
event_counties[, event_key := gsub("[^A-Za-z0-9]+", "_", tolower(event_name))]
event_counties[, event_key := sub("_+$", "", event_key)]
setorder(event_counties, event_year, event_key)
cat(sprintf("Building indicators for %d events:\n", nrow(event_counties)))
for (i in seq_len(nrow(event_counties))) {
  cat(sprintf("  %-40s (%d counties)\n",
              event_counties$event_key[i],
              length(event_counties$counties[[i]])))
}

# -----------------------------------------------------------------------------
#  Build county × year grid + per-event exposure and treated indicators
# -----------------------------------------------------------------------------
all_counties <- unique(c(hom_slim$county_fips, outage_cy$county_fips))
years <- 2018:2023
cy_grid <- CJ(county_fips = all_counties, year = years)

for (i in seq_len(nrow(event_counties))) {
  ek  <- event_counties$event_key[i]
  ey  <- event_counties$event_year[i]
  cts <- event_counties$counties[[i]]
  cy_grid[, paste0("exposed_",  ek) := as.integer(county_fips %in% cts)]
  cy_grid[, paste0("post_",     ek) := as.integer(year >= ey)]
  cy_grid[, paste0("treated_",  ek) := as.integer(
    county_fips %in% cts & year >= ey)]
}

# Aggregate hurricane vs non-hurricane treated_any
hurricane_keys <- event_counties$event_key[
  grepl("hurricane|tropical", event_counties$event_name, ignore.case = TRUE)]
treated_hurr_cols <- paste0("treated_", hurricane_keys)
treated_hurr_cols <- intersect(treated_hurr_cols, names(cy_grid))
cy_grid[, treated_any_hurricane := as.integer(
  rowSums(as.matrix(.SD)) > 0), .SDcols = treated_hurr_cols]

# Overall treated_any (all events combined)
treated_all_cols <- grep("^treated_", names(cy_grid), value = TRUE)
treated_all_cols <- setdiff(treated_all_cols,
                            c("treated_any_hurricane", "treated_any"))
cy_grid[, treated_any := as.integer(
  rowSums(as.matrix(.SD)) > 0), .SDcols = treated_all_cols]

cat(sprintf("\nCounty × year grid: %s rows, %d exposure indicators\n",
            format(nrow(cy_grid), big.mark = ","),
            length(grep("^exposed_", names(cy_grid)))))

# -----------------------------------------------------------------------------
#  Climate + moderators (from tract panel)
# -----------------------------------------------------------------------------
tract <- fread(file.path(DATA, "tract_panel_enhanced_for_analysis.csv"),
               showProgress = FALSE)
tract[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
mod_cols <- intersect(c("year", "county_fips", "extreme_heat_days",
                        "heat_wave_days", "avg_energy_burden.x",
                        "solar_penetration_pct", "dr_total",
                        "renewable_proportion_total_pct",
                        "saidi", "saifi", "caidi",
                        "pct_below_poverty", "urban_rural_code",
                        "overall_health_burden", "total_pop"),
                     names(tract))
tract_slim <- tract[, ..mod_cols]
if ("avg_energy_burden.x" %in% names(tract_slim)) {
  setnames(tract_slim, "avg_energy_burden.x", "avg_energy_burden")
}
value_cols <- setdiff(names(tract_slim), c("year", "county_fips", "total_pop"))
tract_slim[, w := pmax(total_pop, 1L)]
cy_mod <- tract_slim[, lapply(.SD, function(x) {
  ok <- is.finite(x) & is.finite(w)
  if (sum(ok) == 0) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}), by = .(county_fips, year), .SDcols = value_cols]

# Broadcast tract wave (2018 → 2018-2020; 2022 → 2021-2023)
cy_grid[, mod_year := ifelse(year %in% 2018:2020, 2018L, 2022L)]
cy_mod2 <- copy(cy_mod)
setnames(cy_mod2, "year", "mod_year")
cy_mod2 <- cy_mod2[mod_year %in% c(2018L, 2022L)]

# -----------------------------------------------------------------------------
#  Assemble
# -----------------------------------------------------------------------------
panel <- cy_grid[hom_slim, on = c("county_fips", "year"), nomatch = NULL]
panel <- outage_cy[panel, on = c("county_fips", "year")]
panel <- cy_mod2[panel, on = c("county_fips", "mod_year")]

for (v in c("outage_customer_days_year", "outage_days_year", "outage_peak_year")) {
  if (v %in% names(panel)) panel[is.na(get(v)), (v) := 0]
}
panel[, log_outage_cd := log1p(outage_customer_days_year)]

qc <- quantile(panel$wonder_homicide_rate, 0.999, na.rm = TRUE)
panel[, wonder_homicide_rate_w := pmin(wonder_homicide_rate, qc)]

saveRDS(as.data.frame(panel),
        file.path(DATA, "county_year_all_events_homicide_panel.rds"))
cat(sprintf("\n✓ Wrote data/county_year_all_events_homicide_panel.rds\n"))
cat(sprintf("  %s county-years, %d counties, %d exposure indicators\n",
            format(nrow(panel), big.mark = ","),
            uniqueN(panel$county_fips),
            length(grep("^exposed_", names(panel)))))
