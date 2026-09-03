#!/usr/bin/env Rscript
# build_air_quality_county_year.R
# Roll up county-year air-quality drivers from ecosystem cached sources.
#
# Sources (cached, no new downloads):
#   - CDC EPHT PM2.5 annual mean (µg/m³): epht_pm25_annual.rds        [2001-2020]
#   - CDC EPHT PM2.5 % days over 35 µg/m³: epht_pm25_days.rds         [2001-2020]
#   - CDC EPHT ozone days over 70 ppb 8hr : epht_ozone_days.rds        [2001-2020]
#   - NOAA HMS wildfire smoke daily:       noaa_hms/hms_smoke_*.rds    [very sparse cache]
#
# Wave years requested: 2014, 2018, 2020, 2022, 2023
# NOTE: EPHT cached data ends at 2020; 2022/2023 will have NA PM/ozone.
# NOTE: NOAA HMS cache only holds 3 days (2020-09-10..12) — smoke_days set NA with TODO.
#
# Output: data/county_year_air_quality.rds

suppressPackageStartupMessages({
  library(dplyr)
})

CACHE  <- "~/.cache/emburdendata"
OUT    <- "/home/ess/Documents/apps/net_energy_equity/data/county_year_air_quality.rds"
WAVES  <- c(2014, 2018, 2020, 2022, 2023)

msg <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")

# -----------------------------------------------------------------------------
# PM2.5 annual + days
# -----------------------------------------------------------------------------
msg("Loading EPHT PM2.5 annual + days + ozone")
pm25_ann <- readRDS(file.path(CACHE, "epht_pm25_annual.rds")) |>
  transmute(county_fips, year, pm25_annual_ugm3 = pm25_annual_ug_m3)
pm25_dys <- readRDS(file.path(CACHE, "epht_pm25_days.rds")) |>
  transmute(county_fips, year, pm25_days_pct = pm25_days_above)
oz_dys   <- readRDS(file.path(CACHE, "epht_ozone_days.rds")) |>
  transmute(county_fips, year, ozone_days_count = ozone_days_above)

# -----------------------------------------------------------------------------
# NOAA HMS smoke: check for a rolled-up cache; the daily per-date cache
# (noaa_hms/hms_smoke_YYYYMMDD.rds) is too sparse to aggregate meaningfully.
# -----------------------------------------------------------------------------
smoke_note <- NA_character_
hms_files  <- list.files(file.path(CACHE, "noaa_hms"),
                         pattern = "^hms_smoke_\\d{8}\\.rds$", full.names = TRUE)
msg("NOAA HMS daily files cached: ", length(hms_files))

smoke_df <- tibble(county_fips = character(),
                   year = integer(),
                   smoke_days_heavy = integer(),
                   smoke_days_medium = integer())

if (length(hms_files) >= 300) {
  # Only aggregate if we have enough daily coverage (~1 year+)
  msg("Aggregating daily HMS into county-year smoke_days")
  hms <- bind_rows(lapply(hms_files, readRDS))
  hms$year <- as.integer(format(as.Date(hms$date), "%Y"))
  # smoke_level: 1=Light, 2=Medium, 3=Heavy (CDC convention)
  smoke_df <- hms |>
    group_by(county_fips, year) |>
    summarise(
      smoke_days_heavy  = sum(smoke_level >= 3, na.rm = TRUE),
      smoke_days_medium = sum(smoke_level == 2, na.rm = TRUE),
      .groups = "drop"
    )
} else {
  smoke_note <- sprintf("TODO: NOAA HMS cache holds only %d daily files; smoke_days_* set NA. Run emburdendata::download_noaa_hms_smoke() for a full annual archive.", length(hms_files))
  msg(smoke_note)
}

# -----------------------------------------------------------------------------
# Merge
# -----------------------------------------------------------------------------
msg("Merging on county_fips + year")
all_keys <- bind_rows(
  pm25_ann |> select(county_fips, year),
  pm25_dys |> select(county_fips, year),
  oz_dys   |> select(county_fips, year),
  smoke_df |> select(county_fips, year)
) |> distinct()

aq <- all_keys |>
  left_join(pm25_ann, by = c("county_fips", "year")) |>
  left_join(pm25_dys, by = c("county_fips", "year")) |>
  left_join(oz_dys,   by = c("county_fips", "year")) |>
  left_join(smoke_df, by = c("county_fips", "year")) |>
  mutate(aq_data_notes = if_else(is.na(smoke_days_heavy) & !is.na(smoke_note),
                                 smoke_note, NA_character_))

# Ensure smoke cols exist even when smoke_df is empty
if (!"smoke_days_heavy"  %in% names(aq)) aq$smoke_days_heavy  <- NA_integer_
if (!"smoke_days_medium" %in% names(aq)) aq$smoke_days_medium <- NA_integer_

aq <- aq |>
  select(county_fips, year,
         pm25_annual_ugm3, pm25_days_pct, ozone_days_count,
         smoke_days_heavy, smoke_days_medium, aq_data_notes)

# -----------------------------------------------------------------------------
# Coverage report for wave years
# -----------------------------------------------------------------------------
msg("Coverage by wave year:")
for (yr in WAVES) {
  sub <- aq |> filter(year == yr)
  cat(sprintf("  %d: n_counties=%d | pm25 non-NA=%d | ozone non-NA=%d | smoke non-NA=%d\n",
              yr, nrow(sub),
              sum(!is.na(sub$pm25_annual_ugm3)),
              sum(!is.na(sub$ozone_days_count)),
              sum(!is.na(sub$smoke_days_heavy))))
}

# -----------------------------------------------------------------------------
# Sanity check: PM2.5 4-15 µg/m³ range for US counties
# -----------------------------------------------------------------------------
pm_vals <- aq$pm25_annual_ugm3[!is.na(aq$pm25_annual_ugm3)]
cat(sprintf("\nPM2.5 annual sanity: min=%.2f  Q25=%.2f  median=%.2f  Q75=%.2f  max=%.2f  (expect ~4-15)\n",
            min(pm_vals), quantile(pm_vals, .25), median(pm_vals),
            quantile(pm_vals, .75), max(pm_vals)))
pct_in <- mean(pm_vals >= 4 & pm_vals <= 15) * 100
cat(sprintf("  %.1f%% of county-years fall in [4, 15] µg/m³\n", pct_in))
if (pct_in < 70) warning("PM2.5 distribution outside expected US range — inspect source")

# -----------------------------------------------------------------------------
# Write
# -----------------------------------------------------------------------------
dir.create(dirname(OUT), recursive = TRUE, showWarnings = FALSE)
saveRDS(aq, OUT)
msg("Wrote ", OUT, "  (", nrow(aq), " rows)")
