#!/usr/bin/env Rscript
# Build tract-year residential storage panel from LBNL Tracking-the-Sun
# (paired PV+battery installations, cached at ~/.cache/emburdender/).
#
# Output columns:
#   res_storage_count      systems w/ battery (LBNL, tract-year)
#   res_storage_kwh        aggregate paired kWh (clipped >=0; LBNL negatives
#                          are sentinel-driven and unreliable)
#   res_storage_penetration  count / lbnl_solar_systems

suppressPackageStartupMessages({
  library(dplyr); library(data.table)
})

DATA <- "/home/ess/Documents/apps/net_energy_equity/data"
LBNL <- path.expand("~/.cache/emburdender")

# Panel waves: 2014, 2018, 2022. Load matching TTS years exactly.
years <- c(2014L, 2018L, 2022L)
out <- list()
for (yr in years) {
  f <- file.path(LBNL, sprintf("lbnl_tts_tracts_%d.rds", yr))
  if (!file.exists(f)) {
    warning(sprintf("LBNL TTS %d not cached at %s", yr, f)); next
  }
  x <- readRDS(f)
  x$storage_paired_kwh_clip <- pmax(x$storage_paired_kwh, 0, na.rm = FALSE)
  x$storage_paired_kwh_clip[is.na(x$storage_paired_kwh_clip)] <- 0
  x$storage_paired_count[is.na(x$storage_paired_count)] <- 0L

  df <- data.frame(
    geoid                    = as.character(x$geoid),
    year                     = as.integer(yr),
    res_storage_count        = as.integer(x$storage_paired_count),
    res_storage_kwh          = as.numeric(x$storage_paired_kwh_clip),
    res_solar_count          = as.integer(x$solar_system_count),
    res_solar_capacity_kw    = as.numeric(x$total_capacity_kw),
    res_third_party_owned    = as.integer(x$third_party_owned_count),
    stringsAsFactors = FALSE)
  df$res_storage_penetration <- ifelse(df$res_solar_count > 0,
    df$res_storage_count / df$res_solar_count, 0)
  df$res_storage_any <- as.integer(df$res_storage_count > 0)
  out[[as.character(yr)]] <- df
}
res <- as.data.frame(rbindlist(out, use.names = TRUE, fill = TRUE))
setDT(res)

cat(sprintf("Residential storage panel: %s tract-year rows\n",
            format(nrow(res), big.mark=",")))
cat("Coverage by year:\n")
print(res[, .(n_tracts = uniqueN(geoid),
              tracts_w_bess = sum(res_storage_count > 0),
              total_systems = sum(res_storage_count),
              total_kwh = round(sum(res_storage_kwh))),
          by = year][order(year)])

saveRDS(as.data.frame(res),
        file.path(DATA, "tract_year_residential_storage.rds"))
cat(sprintf("\nWrote %s\n",
            file.path(DATA, "tract_year_residential_storage.rds")))
