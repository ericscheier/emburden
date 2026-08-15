#!/usr/bin/env Rscript
# Migrate WONDER cause-specific TSV output → tidy RDS panels
#
# Reads: sources/cdc_wonder_downloads_causes/mortality_{FIPS}_{state}_{cause}.txt
# Writes:
#   data/wonder_violence_county_year_2018_2023.rds       (combined all states + causes)
#   data/wonder_violence_state_year_2018_2023.rds        (state-year aggregate)
#   data/wonder_violence_county_year_metros_2018_2023.rds (metros: pop > 500k)
#
# The scraper's TSV format:
#   "Notes" | "County" | "County Code" | "Year" | "Year Code" | Deaths | Population |
#     Crude Rate | Crude Rate Lower 95% CI | Crude Rate Upper 95% CI
#   ... county-year rows ...
#   ---
#   "Dataset: ..."   ← metadata footer to strip

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

REPO   <- "/home/ess/Documents/apps/net_energy_equity"
SRCDIR <- file.path(REPO, "sources", "cdc_wonder_downloads_causes")
OUTDIR <- file.path(REPO, "data")

# ---------------------------------------------------------------------------
# TSV parser
# ---------------------------------------------------------------------------

parse_wonder_tsv <- function(path) {
  cause_key <- sub(".*_([a-z_]+)\\.txt$", "\\1", basename(path))
  fips_2    <- sub("^mortality_(\\d{2})_.*", "\\1", basename(path))

  raw <- readLines(path, warn = FALSE)
  # Data ends at the first blank line or "---" separator (metadata footer)
  end_row <- min(which(raw == "" | grepl("^---", raw) | grepl("^\"Dataset", raw)),
                 length(raw) + 1L) - 1L
  if (end_row < 2L) return(NULL)   # header only

  data_lines <- raw[1:end_row]
  dt <- tryCatch(
    fread(text = paste(data_lines, collapse = "\n"), sep = "\t",
          na.strings = c("", "Suppressed", "Not Applicable", "Missing"),
          showProgress = FALSE, quote = "\""),
    error = function(e) NULL
  )
  if (is.null(dt) || nrow(dt) == 0) return(NULL)

  # Normalize columns
  setnames(dt, old = intersect(c("County", "County Code", "Year", "Year Code",
                                 "Deaths", "Population", "Crude Rate"),
                               names(dt)),
           new = intersect(c("county_name", "county_fips", "year", "year_code",
                             "deaths", "population", "crude_rate"),
                           c("county_name", "county_fips", "year", "year_code",
                             "deaths", "population", "crude_rate"))[
             seq_len(sum(intersect(c("County", "County Code", "Year", "Year Code",
                                     "Deaths", "Population", "Crude Rate"),
                                   names(dt)) %in% names(dt)))])

  # WONDER outputs "Suppressed" for deaths<10; those become NA above.
  # Population is usually present even when deaths suppressed. Preserve both.
  dt <- dt[!is.na(county_fips) & county_fips != ""]
  if (nrow(dt) == 0) return(NULL)

  dt[, cause_key := cause_key]
  dt[, state_fips := fips_2]
  dt[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
  dt[, year := suppressWarnings(as.integer(year))]
  dt[, deaths := suppressWarnings(as.integer(deaths))]
  dt[, population := suppressWarnings(as.integer(population))]
  dt[, crude_rate := suppressWarnings(as.numeric(crude_rate))]
  dt[, suppressed := is.na(deaths)]

  dt[, .(state_fips, county_fips, county_name, year, cause_key,
         deaths, population, crude_rate, suppressed)]
}

# ---------------------------------------------------------------------------
# Load all TSVs + NODATA markers
# ---------------------------------------------------------------------------

tsvs   <- list.files(SRCDIR, pattern = "^mortality_\\d{2}_.*_[a-z_]+\\.txt$",
                    full.names = TRUE)
nodata <- list.files(SRCDIR, pattern = "^mortality_\\d{2}_.*_[a-z_]+\\.NODATA$",
                    full.names = TRUE)
cat(sprintf("Found %d TSVs and %d NODATA markers\n", length(tsvs), length(nodata)))
if (length(tsvs) == 0) stop("No TSV files found — scraper hasn't produced output yet.")

all_rows <- rbindlist(lapply(tsvs, parse_wonder_tsv), fill = TRUE)
cat(sprintf("  Parsed %s rows across %d state x cause files\n",
            format(nrow(all_rows), big.mark = ","), length(tsvs)))

# Long -> wide: one row per (state, county, year), columns per cause
by_cause <- split(all_rows, all_rows$cause_key)
wide <- Reduce(
  function(a, b) {
    b_key <- b$cause_key[1]
    b_narrow <- b[, .(state_fips, county_fips, county_name, year,
                      d = deaths, p = population, r = crude_rate, s = suppressed)]
    setnames(b_narrow, c("d","p","r","s"),
             c(paste0(b_key, "_deaths"),
               paste0(b_key, "_population"),
               paste0(b_key, "_rate_per_100k"),
               paste0(b_key, "_suppressed")))
    if (is.null(a)) return(b_narrow)
    merge(a, b_narrow,
          by = c("state_fips", "county_fips", "county_name", "year"),
          all = TRUE)
  },
  by_cause, accumulate = FALSE, init = NULL
)

cat(sprintf("Combined wide panel: %s rows x %d cols\n",
            format(nrow(wide), big.mark = ","), ncol(wide)))
cat(sprintf("  Year range: %s\n", paste(range(wide$year, na.rm = TRUE), collapse = "-")))
cat(sprintf("  States: %d, counties: %d\n",
            uniqueN(wide$state_fips), uniqueN(wide$county_fips)))

# Layer 1: county-year 2018-2023 (all counties)
saveRDS(as.data.frame(wide),
        file.path(OUTDIR, "wonder_violence_county_year_2018_2023.rds"))
cat(sprintf("  ✓ Wrote wonder_violence_county_year_2018_2023.rds\n"))

# Layer 2: metros only (population > 500k in any year)
if ("homicide_population" %in% names(wide)) {
  pop_col <- "homicide_population"
} else {
  pop_col <- grep("_population$", names(wide), value = TRUE)[1]
}
metros <- wide %>%
  group_by(county_fips) %>%
  summarise(max_pop = suppressWarnings(max(.data[[pop_col]], na.rm = TRUE)),
            .groups = "drop") %>%
  filter(is.finite(max_pop), max_pop >= 500000L) %>%
  pull(county_fips)
metros_panel <- wide[county_fips %in% metros, ]
saveRDS(as.data.frame(metros_panel),
        file.path(OUTDIR, "wonder_violence_county_year_metros_2018_2023.rds"))
cat(sprintf("  ✓ Wrote wonder_violence_county_year_metros_2018_2023.rds (%d counties)\n",
            length(metros)))

# Layer 3: state-year aggregate
state_year <- wide %>%
  group_by(state_fips, year) %>%
  summarise(
    across(matches("_deaths$|_population$"), ~ sum(.x, na.rm = TRUE)),
    n_counties_reported = n(),
    n_counties_unsuppressed = if ("homicide_deaths" %in% names(cur_data())) sum(!is.na(homicide_deaths)) else 0L,
    .groups = "drop"
  ) %>%
  mutate(across(matches("_deaths$"),
                ~ ifelse(get(sub("_deaths$", "_population", cur_column())) > 0,
                         .x / get(sub("_deaths$", "_population", cur_column())) * 1e5,
                         NA_real_),
                .names = "{sub('_deaths$', '_rate_per_100k', .col)}"))
`%||%` <- function(a, b) if (!is.null(a)) a else b
saveRDS(as.data.frame(state_year),
        file.path(OUTDIR, "wonder_violence_state_year_2018_2023.rds"))
cat(sprintf("  ✓ Wrote wonder_violence_state_year_2018_2023.rds (%d state-years)\n",
            nrow(state_year)))

cat("\n=== Migration complete ===\n")
`%||%` <- NULL  # cleanup — defined locally above
