#!/usr/bin/env Rscript
# Build a proper county-year outage+homicide panel (2018-2022)
# for annual event-study identification around Uri/Ida/PSPS.
#
# Homicide: data/wonder_violence_county_year_2018_2023.rds (WONDER 2018-2023)
# Outage:   data/county_month_eagle_i.rds  → aggregate to county-year
# Events:   data/event_outages_county_2014_2024.csv (FEMA exposure indicators)
# Climate:  extract from tract panel — heat_wave_days, extreme_heat_days at
#           county-year (population-weighted mean across tracts in county)
# Baseline covariates: population, poverty, urban_rural — average across
#           tracts in county at 2018 wave.
#
# Output: data/county_year_outage_homicide_panel.rds
#         columns: county_fips, year, state_fips,
#                  wonder_homicide_deaths, wonder_homicide_pop, wonder_homicide_rate,
#                  outage_customer_days_year, outage_days_year, outage_peak_year,
#                  exposed_uri, exposed_ida, exposed_harvey, exposed_psps,
#                  post_uri (year >= 2021), etc.,
#                  extreme_heat_days (county-year avg), heat_wave_days,
#                  avg_energy_burden, saidi, saifi,
#                  urban_rural_code, pct_below_poverty

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(readr)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

# -----------------------------------------------------------------------------
#  Homicide (county-year)
# -----------------------------------------------------------------------------
hom <- readRDS(file.path(DATA, "wonder_violence_county_year_2018_2023.rds"))
setDT(hom)
hom[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
setnames(hom,
         old = c("homicide_deaths", "homicide_population", "homicide_rate_per_100k",
                 "homicide_suppressed"),
         new = c("wonder_homicide_deaths", "wonder_homicide_pop",
                 "wonder_homicide_rate", "wonder_homicide_suppressed"))
hom_slim <- hom[, .(state_fips, county_fips, county_name, year,
                    wonder_homicide_deaths, wonder_homicide_pop,
                    wonder_homicide_rate, wonder_homicide_suppressed)]
hom_slim[, year := as.integer(year)]
cat(sprintf("Homicide: %s county-years, %d counties, years %s\n",
            format(nrow(hom_slim), big.mark = ","),
            uniqueN(hom_slim$county_fips),
            paste(range(hom_slim$year, na.rm=TRUE), collapse = "-")))

# -----------------------------------------------------------------------------
#  Outage intensity (county-year from county-month)
# -----------------------------------------------------------------------------
outage_cm <- readRDS(file.path(DATA, "county_month_eagle_i.rds"))
setDT(outage_cm)
outage_cm[, county_fips := as.character(county_fips)]
outage_cy <- outage_cm[, .(
  outage_customer_days_year = sum(outage_customer_days, na.rm = TRUE),
  outage_days_year          = sum(outage_days, na.rm = TRUE),
  outage_peak_year          = max(outage_peak_customers, na.rm = TRUE)
), by = .(county_fips, year)]
cat(sprintf("Outage intensity: %s county-years, %d counties, years %s\n",
            format(nrow(outage_cy), big.mark = ","),
            uniqueN(outage_cy$county_fips),
            paste(range(outage_cy$year), collapse = "-")))

# -----------------------------------------------------------------------------
#  FEMA event exposure — county-year with per-event indicators + post-flag
# -----------------------------------------------------------------------------
fema <- fread(file.path(DATA, "event_outages_county_2014_2024.csv"))
fema[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]

# Build county × event indicator table
uri_counties    <- unique(fema[event_name == "Winter Storm Uri 2021", county_fips])
ida_counties    <- unique(fema[event_name == "Hurricane Ida 2021",   county_fips])
harvey_counties <- unique(fema[event_name == "Hurricane Harvey 2017", county_fips])
psps_counties   <- unique(fema[grepl("PSPS", event_name),             county_fips])

# All counties observed anywhere in either homicide or outage data
all_counties <- unique(c(hom_slim$county_fips, outage_cy$county_fips))
years <- 2018:2023
cy_grid <- CJ(county_fips = all_counties, year = years)
cy_grid[, `:=`(
  exposed_uri    = as.integer(county_fips %in% uri_counties),
  exposed_ida    = as.integer(county_fips %in% ida_counties),
  exposed_harvey = as.integer(county_fips %in% harvey_counties),
  exposed_psps   = as.integer(county_fips %in% psps_counties),
  post_uri    = as.integer(year >= 2021),
  post_ida    = as.integer(year >= 2021),
  post_harvey = as.integer(year >= 2017),
  post_psps   = as.integer(year >= 2019)
)]
cy_grid[, `:=`(
  treated_uri    = exposed_uri * post_uri,
  treated_ida    = exposed_ida * post_ida,
  treated_harvey = exposed_harvey * post_harvey,
  treated_psps   = exposed_psps * post_psps
)]
cy_grid[, treated_any := pmax(treated_uri, treated_ida, treated_harvey, treated_psps)]

# -----------------------------------------------------------------------------
#  Climate + moderators (from tract panel — aggregate to county-year)
# -----------------------------------------------------------------------------
tract <- fread(file.path(DATA, "tract_panel_enhanced_for_analysis.csv"),
               showProgress = FALSE)
tract[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]

# Extract relevant tract-level moderators for county-year aggregation
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

# Population-weighted county-year moderators
if ("total_pop" %in% names(tract_slim)) {
  tract_slim[, w := pmax(total_pop, 1L)]
  cy_mod <- tract_slim[, lapply(.SD, function(x) {
    ok <- is.finite(x) & is.finite(w)
    if (sum(ok) == 0) return(NA_real_)
    sum(x[ok] * w[ok]) / sum(w[ok])
  }), by = .(county_fips, year), .SDcols = value_cols]
} else {
  cy_mod <- tract_slim[, lapply(.SD, mean, na.rm = TRUE),
                       by = .(county_fips, year), .SDcols = value_cols]
}

# The tract panel only has 2014/2018/2022. To broadcast to all 2018-2023 years,
# use 2018 values for 2018-2020 and 2022 values for 2021-2023. This is a
# best-available crosswalk; wave-level moderators change slowly.
crosswalk_wave <- function(y) {
  ifelse(y %in% c(2018, 2019, 2020), 2018,
         ifelse(y %in% c(2021, 2022, 2023), 2022, y))
}
cy_grid[, mod_year := crosswalk_wave(year)]
cy_mod2 <- copy(cy_mod)
setnames(cy_mod2, "year", "mod_year")
cy_mod2 <- cy_mod2[mod_year %in% c(2018, 2022)]

# -----------------------------------------------------------------------------
#  Assemble
# -----------------------------------------------------------------------------
panel <- cy_grid[hom_slim, on = c("county_fips", "year"), nomatch = NULL]
panel <- outage_cy[panel, on = c("county_fips", "year")]
panel <- cy_mod2[panel, on = c("county_fips", "mod_year")]

# Fill NA outage columns with 0 (no outage days = 0 customer-days out)
for (v in c("outage_customer_days_year", "outage_days_year", "outage_peak_year")) {
  if (v %in% names(panel)) panel[is.na(get(v)), (v) := 0]
}

panel[, `:=`(
  log_outage_cd = log1p(outage_customer_days_year),
  event_time_uri    = year - 2021L,
  event_time_ida    = year - 2021L,
  event_time_psps   = year - 2019L,
  event_time_harvey = year - 2017L
)]

# Cap homicide rate at 99.9 pct for outlier resilience
qc <- quantile(panel$wonder_homicide_rate, 0.999, na.rm = TRUE)
panel[, wonder_homicide_rate_w := pmin(wonder_homicide_rate, qc)]

saveRDS(as.data.frame(panel),
        file.path(DATA, "county_year_outage_homicide_panel.rds"))

cat(sprintf("\n✓ Wrote data/county_year_outage_homicide_panel.rds\n"))
cat(sprintf("  %s county-years, %d counties, %d states, years %s\n",
            format(nrow(panel), big.mark = ","),
            uniqueN(panel$county_fips),
            uniqueN(panel$state_fips),
            paste(range(panel$year), collapse = "-")))
cat(sprintf("  Rows with unsuppressed homicide: %s (%.1f%%)\n",
            format(sum(!is.na(panel$wonder_homicide_rate)), big.mark = ","),
            100 * mean(!is.na(panel$wonder_homicide_rate))))
