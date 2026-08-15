#!/usr/bin/env Rscript
# Migrate WONDER monthly cause-specific TSV output → county-month RDS panel
#
# Reads: sources/cdc_wonder_downloads_causes/mortality_monthly_{FIPS}_{state}_{cause}.txt
# Writes: data/wonder_violence_county_month_2018_2023.rds
#
# TSV format:
#   Notes | County | County Code | Year | Year Code | Month | Month Code |
#     Deaths | Population | Crude Rate | ...
# When grouped by month, WONDER reports Population = "Not Applicable" — we
# join annual population from the county-year RDS to derive rates.
suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

REPO   <- "/home/ess/Documents/apps/net_energy_equity"
SRCDIR <- file.path(REPO, "sources", "cdc_wonder_downloads_causes")
OUTDIR <- file.path(REPO, "data")

parse_monthly_tsv <- function(path) {
  fips_2 <- sub("^mortality_monthly_(\\d{2})_.*", "\\1", basename(path))
  cause_key <- sub(".*_([a-z_]+)\\.txt$", "\\1", basename(path))

  raw <- readLines(path, warn = FALSE)
  end_row <- min(which(raw == "" | grepl("^---", raw) |
                       grepl("^\"Dataset", raw)), length(raw) + 1L) - 1L
  if (end_row < 2L) return(NULL)

  dt <- tryCatch(
    fread(text = paste(raw[1:end_row], collapse = "\n"), sep = "\t",
          na.strings = c("", "Suppressed", "Not Applicable", "Missing"),
          quote = "\"", showProgress = FALSE),
    error = function(e) NULL
  )
  if (is.null(dt) || nrow(dt) == 0) return(NULL)

  # WONDER cols: County / County Code / Year / Year Code / Month / Month Code / Deaths / Population / Crude Rate
  # Some fields may be "Not Applicable" (character); numeric coercion turns those to NA
  cols_wanted <- c("County", "County Code", "Year", "Year Code",
                   "Month", "Month Code", "Deaths", "Population")
  cols_have <- intersect(cols_wanted, names(dt))
  dt <- dt[, ..cols_have]
  dt <- dt[!is.na(`County Code`) & `County Code` != ""]
  if (nrow(dt) == 0) return(NULL)

  dt[, `:=`(
    state_fips  = fips_2,
    cause_key   = cause_key,
    county_fips = formatC(as.integer(`County Code`), width = 5, flag = "0"),
    year        = suppressWarnings(as.integer(Year)),
    month_num   = suppressWarnings(as.integer(sub(".*/(\\d{2})$", "\\1", `Month Code`))),
    deaths      = suppressWarnings(as.integer(Deaths)),
    suppressed  = is.na(Deaths)
  )]

  dt[, .(state_fips, county_fips, county_name = County,
         year, month_num, cause_key, deaths, suppressed)]
}

tsvs <- list.files(SRCDIR, pattern = "^mortality_monthly_\\d{2}_.*\\.txt$",
                   full.names = TRUE)
cat(sprintf("Found %d monthly TSVs\n", length(tsvs)))
if (length(tsvs) == 0) stop("No monthly TSVs — scraper not started yet?")

all_rows <- rbindlist(lapply(tsvs, parse_monthly_tsv), fill = TRUE)
cat(sprintf("  Parsed %s rows (across %d files)\n",
            format(nrow(all_rows), big.mark = ","), length(tsvs)))
cat(sprintf("  Year range: %s\n",
            paste(range(all_rows$year, na.rm = TRUE), collapse = "-")))
cat(sprintf("  States: %d, counties: %d, causes: %s\n",
            uniqueN(all_rows$state_fips),
            uniqueN(all_rows$county_fips),
            paste(unique(all_rows$cause_key), collapse = ",")))

# Join annual population from county-year RDS to derive monthly rates
hom_cy <- readRDS(file.path(OUTDIR, "wonder_violence_county_year_2018_2023.rds"))
setDT(hom_cy)
hom_cy[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
pop_cy <- hom_cy[, .(county_fips, year = as.integer(year),
                     annual_pop = homicide_population)]

merged <- pop_cy[all_rows, on = c("county_fips", "year")]
merged[, homicide_rate_annualized_per_100k :=
       ifelse(is.na(annual_pop) | annual_pop == 0, NA_real_,
              deaths * 12 / annual_pop * 1e5)]   # annualized monthly rate

setnames(merged, "deaths", "homicide_deaths")
setnames(merged, "cause_key", "cause")
merged <- merged[!is.na(year) & !is.na(month_num)]

saveRDS(as.data.frame(merged),
        file.path(OUTDIR, "wonder_violence_county_month_2018_2023.rds"))

cat(sprintf("\n✓ Wrote data/wonder_violence_county_month_2018_2023.rds\n"))
cat(sprintf("  %s county-months, %d counties, %d unique (year × month) cells\n",
            format(nrow(merged), big.mark = ","),
            uniqueN(merged$county_fips),
            uniqueN(merged[, .(year, month_num)])))
