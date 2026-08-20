#!/usr/bin/env Rscript
# Build county-year EIA-860 utility-scale battery storage (BESS) panel
# from 3_4_Energy_Storage_Y{2019-2022}.xlsx sheets.

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(data.table)
})

CACHE <- path.expand("~/.cache/emburdendata/eia860")
DATA  <- "/home/ess/Documents/apps/net_energy_equity/data"

parse_storage <- function(yr) {
  bess_f  <- Sys.glob(sprintf("%s/eia860_%d_raw/3_4_Energy_Storage_Y%d.xlsx", CACHE, yr, yr))
  plant_f <- Sys.glob(sprintf("%s/eia860_%d_raw/2___Plant_Y%d.xlsx", CACHE, yr, yr))
  if (length(bess_f) == 0 || length(plant_f) == 0) {
    warning(sprintf("EIA-860 %d files missing", yr)); return(NULL)
  }

  sheets <- excel_sheets(bess_f)
  op_sheet <- grep("^Operable", sheets, value = TRUE)[1]
  if (is.na(op_sheet)) op_sheet <- 1
  bess <- suppressMessages(read_excel(bess_f, sheet = op_sheet, skip = 1))
  names(bess) <- trimws(gsub("[\n\r]+", " ", names(bess)))

  plant_col  <- grep("^Plant Code$",       names(bess), value = TRUE)[1]
  state_col  <- grep("^State$",            names(bess), value = TRUE)[1]
  county_col <- grep("^County$",           names(bess), value = TRUE)[1]
  status_col <- grep("^Status$",           names(bess), value = TRUE)[1]
  cap_col    <- grep("Nameplate Capacity", names(bess), value = TRUE)[1]
  cape_col   <- grep("Nameplate Energy",   names(bess), value = TRUE)[1]

  # Load fips crosswalk
  data("fips_codes", package = "tigris", envir = environment())
  fips_lookup <- fips_codes %>%
    mutate(county_key = tolower(gsub("[[:punct:]]| County| Parish| Borough| Census Area| Municipality| City and Borough", "", county))) %>%
    transmute(state_abbr = state, county_key,
              state_fips_2 = state_code, county_fips_3 = county_code)

  bess_slim <- bess %>%
    transmute(
      plant_code = suppressWarnings(as.integer(.data[[plant_col]])),
      state      = .data[[state_col]],
      county     = .data[[county_col]],
      status     = .data[[status_col]],
      cap_mw     = suppressWarnings(as.numeric(.data[[cap_col]])),
      cap_mwh    = if (!is.na(cape_col)) suppressWarnings(as.numeric(.data[[cape_col]])) else NA_real_
    ) %>%
    filter(!is.na(plant_code)) %>%
    mutate(
      state_abbr = as.character(state),
      county_key = tolower(gsub("[[:punct:]]| County| Parish| Borough| Census Area| Municipality| City and Borough", "",
                                as.character(county)))
    ) %>%
    left_join(fips_lookup, by = c("state_abbr", "county_key")) %>%
    mutate(year = yr,
           county_fips = ifelse(is.na(state_fips_2) | is.na(county_fips_3), NA_character_,
                                paste0(state_fips_2, county_fips_3)),
           operable = grepl("^OP", status)) %>%
    filter(!is.na(county_fips))

  bess_slim
}

all_years <- lapply(2019:2022, parse_storage)
all_dt <- as.data.table(bind_rows(all_years))
cat(sprintf("EIA-860 storage rows loaded: %s (across 2019-2022)\n",
            format(nrow(all_dt), big.mark = ",")))

cy <- all_dt[, .(
  bess_plant_count   = .N,
  bess_capacity_mw   = sum(cap_mw,  na.rm = TRUE),
  bess_capacity_mwh  = sum(cap_mwh, na.rm = TRUE),
  bess_operating_mw  = sum(cap_mw  * as.integer(operable), na.rm = TRUE),
  bess_operating_mwh = sum(cap_mwh * as.integer(operable), na.rm = TRUE)
), by = .(county_fips, year)]
cy[, bess_any_storage := as.integer(bess_capacity_mw > 0)]
setorder(cy, county_fips, year)

saveRDS(as.data.frame(cy), file.path(DATA, "county_year_eia860_storage.rds"))
cat(sprintf("\n✓ Wrote data/county_year_eia860_storage.rds\n"))
cat(sprintf("  %s county-years, %d unique counties, years %s\n",
            format(nrow(cy), big.mark=","),
            uniqueN(cy$county_fips),
            paste(range(cy$year), collapse="-")))
cat("Total US utility-scale battery capacity by year (MW):\n")
print(cy[, .(total_MW = sum(bess_capacity_mw, na.rm=TRUE),
             counties_with_bess = uniqueN(county_fips)), by = year][order(year)])
