#!/usr/bin/env Rscript
# build_shock_indicators.R
# Build binary shock indicators for the enriched tract panel.
#
# Indicators:
#   treated_heat_wave  : county-year has extreme_heat_days > per-year 90th pctile
#                        across counties in the panel (relative-severity convention).
#   treated_smoke_event: county-year has smoke_days_heavy >= 3
#                        (Reid et al. 2016 — three heavy-smoke days = significant event).
#
# Output: data/tract_year_shock_indicators.rds

suppressPackageStartupMessages({
  library(dplyr)
})

PANEL <- "/home/ess/Documents/apps/net_energy_equity/data/tract_panel_enhanced_with_ders.csv"
AQ    <- "/home/ess/Documents/apps/net_energy_equity/data/county_year_air_quality.rds"
OUT   <- "/home/ess/Documents/apps/net_energy_equity/data/tract_year_shock_indicators.rds"

msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")

msg("Reading enriched tract panel")
panel <- read.csv(PANEL, colClasses = c(geoid = "character", county_fips = "character")) |>
  select(geoid, county_fips, year) |>
  mutate(county_fips = ifelse(nchar(county_fips) == 4,
                              paste0("0", county_fips), county_fips))

msg(sprintf("Panel: %d rows, %d tracts, years=%s",
            nrow(panel), length(unique(panel$geoid)),
            paste(sort(unique(panel$year)), collapse = ",")))

# -----------------------------------------------------------------------------
# treated_heat_wave — per-year 90th pctile of extreme_heat_days across all US
# counties (CDC EPHT full-year cache — richer distribution than the panel's
# California-only pre-aggregated heat field).
# -----------------------------------------------------------------------------
msg("Loading CDC EPHT extreme_heat_days_fullyear for national heat distribution")
epht_heat <- readRDS("~/.cache/emburdendata/epht_extreme_heat_days_fullyear.rds") |>
  select(county_fips, year, extreme_heat_days = extreme_heat_days_fullyear) |>
  filter(!is.na(extreme_heat_days))

thresholds <- epht_heat |>
  group_by(year) |>
  summarise(thresh_90 = quantile(extreme_heat_days, 0.90, na.rm = TRUE),
            n_counties = n(),
            .groups = "drop")
msg("Per-year 90th-percentile heat thresholds (CDC EPHT, national):")
print(thresholds)

heat_flag <- epht_heat |>
  left_join(thresholds |> select(year, thresh_90), by = "year") |>
  mutate(treated_heat_wave = as.integer(extreme_heat_days >= thresh_90)) |>
  select(county_fips, year, treated_heat_wave)

panel <- panel |>
  left_join(heat_flag, by = c("county_fips", "year"))

# -----------------------------------------------------------------------------
# treated_smoke_event — smoke_days_heavy >= 3
# -----------------------------------------------------------------------------
msg("Joining air quality panel for smoke")
aq <- readRDS(AQ) |>
  select(county_fips, year, smoke_days_heavy) |>
  mutate(county_fips = ifelse(nchar(county_fips) == 4,
                              paste0("0", county_fips), county_fips))

panel <- panel |>
  left_join(aq, by = c("county_fips", "year"))

if (all(is.na(panel$smoke_days_heavy))) {
  msg("TODO: smoke_days_heavy all NA (NOAA HMS cache empty) — treated_smoke_event set NA")
  panel$treated_smoke_event <- NA_integer_
} else {
  panel$treated_smoke_event <- as.integer(panel$smoke_days_heavy >= 3)
}

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
msg("Verification — treated_heat_wave share by wave year:")
verify <- panel |>
  group_by(year) |>
  summarise(
    n_tract_years        = n(),
    n_hw_non_na          = sum(!is.na(treated_heat_wave)),
    pct_treated_heat_wave = mean(treated_heat_wave, na.rm = TRUE) * 100,
    n_smoke_non_na       = sum(!is.na(treated_smoke_event)),
    pct_treated_smoke    = mean(treated_smoke_event, na.rm = TRUE) * 100,
    .groups = "drop"
  )
print(verify)

# Top 10 states by smoke-event count
if (any(!is.na(panel$treated_smoke_event))) {
  msg("Top 10 states by smoke-event tract-years:")
  top10 <- panel |>
    filter(treated_smoke_event == 1) |>
    mutate(state_fips = substr(county_fips, 1, 2)) |>
    count(state_fips, sort = TRUE) |>
    head(10)
  print(top10)
}

# -----------------------------------------------------------------------------
# Write
# -----------------------------------------------------------------------------
out <- panel |>
  select(geoid, county_fips, year, treated_heat_wave, treated_smoke_event)

dir.create(dirname(OUT), recursive = TRUE, showWarnings = FALSE)
saveRDS(out, OUT)
msg("Wrote ", OUT, "  (", nrow(out), " rows)")
