#!/usr/bin/env Rscript
# Layer 4 asthma outcome families onto the base tract panel:
#   1. places_asthma_prev              (CDC PLACES tract-native prevalence)
#   2. asthma_hosp_rate/_count         (CDC EPHT county-year hospitalizations)
#   3. asthma_ed_rate                  (CDC EPHT county-year ED visits)
#   4. wonder_asthma_deaths/_rate      (CDC WONDER MCOD J45/J46 mortality)
#
# Input:  data/tract_panel_enhanced_for_analysis.csv
# Output: data/tract_panel_enhanced_with_asthma.csv

suppressPackageStartupMessages({
  library(data.table)
  library(bit64)  # so fread's integer64 geoid coerces to character safely
  devtools::load_all("/home/ess/Documents/apps/emburdenhealth", quiet = TRUE)
})

REPO       <- "/home/ess/Documents/apps/net_energy_equity"
CACHE_DIR  <- "~/.cache/emburdendata"
PANEL_IN   <- file.path(REPO, "data", "tract_panel_enhanced_for_analysis.csv")
PANEL_OUT  <- file.path(REPO, "data", "tract_panel_enhanced_with_asthma.csv")

landed <- character(0)
todo   <- character(0)

# ---- Base panel ------------------------------------------------------------
cat("Reading tract panel ...\n")
panel <- fread(PANEL_IN, showProgress = FALSE)
cat(sprintf("  %s tract-years, %d cols\n",
            format(nrow(panel), big.mark = ","), ncol(panel)))

# geoid → 11-char string (handle integer64 from fread); county_fips → 5-char string
zpad <- function(x, n) {
  x <- as.character(x)
  paste0(strrep("0", pmax(0L, n - nchar(x))), x)
}
panel[, geoid := zpad(geoid, 11L)]
if ("county_fips" %in% names(panel)) {
  panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
} else {
  panel[, county_fips := substr(geoid, 1, 5)]
}

before <- nrow(panel)

# ---- 1. CDC PLACES asthma prevalence (tract-native) ------------------------
# Panel years 2014, 2018, 2022; PLACES covers 2020-2023.
# Map 2022 → PLACES 2022; 2018 & 2014 → PLACES 2020 (earliest available).
year_map <- c("2014" = 2020L, "2018" = 2020L, "2022" = 2022L)
places_needed <- unique(year_map[as.character(unique(panel$year))])
places_needed <- places_needed[!is.na(places_needed)]

places_stack <- rbindlist(lapply(places_needed, function(y) {
  p <- try(load_cdc_places(year = y), silent = TRUE)
  if (inherits(p, "try-error") || !"asthma_prev" %in% names(p)) return(NULL)
  data.table(geoid = as.character(p$geoid),
             places_vintage = y,
             places_asthma_prev = as.numeric(p$asthma_prev))
}), use.names = TRUE, fill = TRUE)

if (nrow(places_stack) > 0) {
  panel[, places_vintage := year_map[as.character(year)]]
  panel <- merge(panel, places_stack,
                 by = c("geoid", "places_vintage"), all.x = TRUE)
  panel[, places_vintage := NULL]
  landed <- c(landed, "places_asthma_prev")
  cat(sprintf("  PLACES asthma: %s tract-years matched\n",
              format(sum(!is.na(panel$places_asthma_prev)), big.mark = ",")))
} else {
  todo <- c(todo, "places_asthma_prev (PLACES loader returned nothing)")
}

# ---- 2. EPHT asthma hospitalizations (county-year) -------------------------
hosp_path <- file.path(CACHE_DIR, "epht_asthma_hospitalizations.rds")
hosp_path <- path.expand(hosp_path)
if (file.exists(hosp_path)) {
  hosp <- as.data.table(readRDS(hosp_path))
  hosp[, county_fips := as.character(county_fips)]
  hosp[, year := as.integer(year)]
  hosp_slim <- hosp[, .(county_fips, year,
                        asthma_hosp_rate  = as.numeric(asthma_hosp_rate),
                        asthma_hosp_count = as.numeric(asthma_hosp_count))]
  panel <- merge(panel, hosp_slim, by = c("county_fips", "year"), all.x = TRUE)
  landed <- c(landed, "asthma_hosp_rate", "asthma_hosp_count")
  cat(sprintf("  EPHT hospitalizations: %s tract-years matched\n",
              format(sum(!is.na(panel$asthma_hosp_rate)), big.mark = ",")))
} else {
  todo <- c(todo, "asthma_hosp_rate/_count (EPHT RDS missing)")
}

# ---- 3. EPHT asthma ED visits (county-year) --------------------------------
ed_path <- path.expand(file.path(CACHE_DIR, "epht_asthma_ed_visits.rds"))
if (file.exists(ed_path)) {
  ed <- as.data.table(readRDS(ed_path))
  ed[, county_fips := as.character(county_fips)]
  ed[, year := as.integer(year)]
  ed_slim <- ed[, .(county_fips, year,
                    asthma_ed_rate = as.numeric(asthma_ed_rate))]
  panel <- merge(panel, ed_slim, by = c("county_fips", "year"), all.x = TRUE)
  landed <- c(landed, "asthma_ed_rate")
  cat(sprintf("  EPHT ED visits: %s tract-years matched\n",
              format(sum(!is.na(panel$asthma_ed_rate)), big.mark = ",")))
} else {
  todo <- c(todo, "asthma_ed_rate (EPHT RDS missing)")
}

# ---- 4. CDC WONDER MCOD asthma mortality (county-year) ---------------------
# Cached per-state RDS files: wonder_XX_YYYY_YYYY_asthma.rds
wonder_dir <- path.expand(file.path(CACHE_DIR, "cdc_wonder"))
wonder_files <- list.files(wonder_dir, pattern = "^wonder_\\d{2}_\\d{4}_\\d{4}_asthma\\.rds$",
                           full.names = TRUE)
if (length(wonder_files) > 0) {
  wonder <- rbindlist(lapply(wonder_files, function(f) {
    x <- try(as.data.table(readRDS(f)), silent = TRUE)
    if (inherits(x, "try-error") || !nrow(x)) return(NULL)
    x
  }), use.names = TRUE, fill = TRUE)
  if (nrow(wonder) > 0 && all(c("county_fips","year","deaths","mortality_rate")
                              %in% names(wonder))) {
    wonder[, county_fips := as.character(county_fips)]
    wonder[, year := as.integer(year)]
    won_slim <- wonder[, .(wonder_asthma_deaths = as.numeric(deaths),
                           wonder_asthma_rate   = as.numeric(mortality_rate)),
                       by = .(county_fips, year)]
    panel <- merge(panel, won_slim, by = c("county_fips", "year"), all.x = TRUE)
    # Zero-fill deaths (matches homicide merger convention); leave rate NA
    panel[is.na(wonder_asthma_deaths), wonder_asthma_deaths := 0]
    landed <- c(landed, "wonder_asthma_deaths", "wonder_asthma_rate")
    cat(sprintf("  WONDER asthma: %s tract-years matched (rate); %d files loaded\n",
                format(sum(!is.na(panel$wonder_asthma_rate)), big.mark = ","),
                length(wonder_files)))
  } else {
    todo <- c(todo, "wonder_asthma_deaths/_rate (unexpected schema)")
  }
} else {
  todo <- c(todo, "wonder_asthma_deaths/_rate (no cached RDS)")
}

# ---- Assertions + write ----------------------------------------------------
stopifnot(nrow(panel) == before)

fwrite(panel, PANEL_OUT)
cat(sprintf("\nWrote: %s\n  rows=%s cols=%d\n",
            PANEL_OUT, format(nrow(panel), big.mark = ","), ncol(panel)))

cat("\n=== Verification ===\n")
new_cols <- c("places_asthma_prev", "asthma_hosp_rate", "asthma_hosp_count",
              "asthma_ed_rate", "wonder_asthma_deaths", "wonder_asthma_rate")
for (col in new_cols) {
  if (col %in% names(panel)) {
    v <- panel[[col]]
    nn <- sum(!is.na(v))
    if (nn > 0) {
      cat(sprintf("  %-24s  non-NA=%s/%s (%.1f%%)  min=%.3g  med=%.3g  max=%.3g\n",
                  col, format(nn, big.mark = ","),
                  format(length(v), big.mark = ","), 100 * nn / length(v),
                  min(v, na.rm = TRUE), median(v, na.rm = TRUE),
                  max(v, na.rm = TRUE)))
    } else {
      cat(sprintf("  %-24s  ALL NA\n", col))
    }
  } else {
    cat(sprintf("  %-24s  COLUMN NOT PRESENT\n", col))
  }
}

cat("\nLanded outcomes: ", paste(landed, collapse = ", "), "\n")
if (length(todo)) {
  cat("TODOs (skipped):\n")
  for (t in todo) cat("  - ", t, "\n")
} else {
  cat("TODOs: none\n")
}
