#!/usr/bin/env Rscript
# W1c: Build WONDER violence panels for the outage-homicide analysis.
#
# Reads the raw cause-specific pulls saved by
#   scratchpad/pull_wonder_violence.R
# for causes: homicide, all_external, undetermined
# across 4 layer/tags:
#   state_year_2014_2023, state_month_2018_2023,
#   county_year_2014_2023, county_month_2018_2023
#
# Writes 4 tidy panels to data/:
#   wonder_violence_state_year_2014_2023.rds
#   wonder_violence_state_month_2018_2023.rds
#   wonder_violence_county_year_2014_2023.rds
#   wonder_violence_county_month_metros_2018_2023.rds  (metros only)
#
# Column schema per panel:
#   geo_fips (state or county), year (or year_month), state_fips, state_name,
#   [county_fips, county_name for county panels],
#   homicide_deaths, homicide_population, homicide_rate_per_100k, homicide_suppressed,
#   all_external_deaths, ..., all_external_suppressed,
#   undetermined_deaths, ..., undetermined_suppressed

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
})

REPO    <- "/home/ess/Documents/apps/net_energy_equity"
DATA    <- file.path(REPO, "data")
CAUSES  <- c("homicide", "all_external", "undetermined")
TAGS    <- c("state_year_2014_2023",
             "state_month_2018_2023",
             "county_year_2014_2023",
             "county_month_2018_2023")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

load_pull <- function(cause_name, tag) {
  path <- file.path(DATA, sprintf("wonder_violence_%s_%s.rds", cause_name, tag))
  if (!file.exists(path)) {
    warning(sprintf("Missing pull: %s", basename(path)))
    return(NULL)
  }
  df <- readRDS(path)
  attr(df, "cause_name") <- cause_name
  attr(df, "tag") <- tag
  df
}

# Standardize into a tidy long form with (geo_fips, time_key, deaths, pop, supp)
normalize_pull <- function(df, geography) {
  if (is.null(df) || nrow(df) == 0) return(NULL)
  nms <- names(df)

  # Geo columns depend on geography
  if (geography == "state") {
    if (!"state_fips" %in% nms) stop("state_fips missing from state pull")
    geo <- df %>% mutate(geo_fips = as.character(state_fips))
  } else {
    if (!"county_fips" %in% nms) stop("county_fips missing from county pull")
    geo <- df %>% mutate(geo_fips = as.character(county_fips))
  }

  # Time key
  if ("month_num" %in% nms) {
    geo <- geo %>% mutate(year = as.integer(year),
                          month_num = as.integer(month_num),
                          year_month = sprintf("%04d-%02d", year, month_num))
  } else {
    geo <- geo %>% mutate(year = as.integer(year),
                          year_month = NA_character_)
  }

  # Standard metric columns
  # Different WONDER pulls may return `deaths`, `population`, `mortality_rate`, `suppressed`
  # (all four are documented in the loader's roxygen).
  metric_cols <- intersect(c("deaths", "population", "mortality_rate", "suppressed"), nms)
  if (!"deaths" %in% metric_cols || !"population" %in% metric_cols) {
    warning(sprintf("Missing deaths/population columns for %s / %s",
                    geography, attr(df, "cause_name") %||% "?"))
  }

  keep_cols <- c(
    "geo_fips", "year", "year_month",
    "state_fips",
    if (geography == "state") c("state_name") else c("county_fips", "county_name", "state_name"),
    metric_cols
  )
  keep_cols <- intersect(keep_cols, names(geo))

  geo %>% select(all_of(keep_cols))
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---------------------------------------------------------------------------
# Build a merged panel for one tag
# ---------------------------------------------------------------------------

build_panel_for_tag <- function(tag) {
  cat(sprintf("\n=== Building panel: %s ===\n", tag))

  geography <- if (grepl("^state_", tag)) "state" else "county"
  is_monthly <- grepl("_month_", tag)

  cause_dfs <- list()
  for (cn in CAUSES) {
    raw <- load_pull(cn, tag)
    if (is.null(raw)) next
    cat(sprintf("  Loaded %s: %s rows\n", cn, format(nrow(raw), big.mark = ",")))
    norm <- normalize_pull(raw, geography)
    if (is.null(norm)) next
    # Prefix metric columns with cause name
    metric_cols <- intersect(c("deaths", "population", "mortality_rate", "suppressed"),
                             names(norm))
    norm <- norm %>% rename_with(~ sprintf("%s_%s", cn, .x), all_of(metric_cols))
    cause_dfs[[cn]] <- norm
  }

  if (length(cause_dfs) == 0) {
    warning(sprintf("No data loaded for tag %s", tag))
    return(NULL)
  }

  # Join by geo_fips × year (× year_month if monthly)
  join_keys <- c("geo_fips", "year")
  if (is_monthly) join_keys <- c(join_keys, "year_month")

  merged <- Reduce(function(a, b) {
    # Determine shared metadata columns (state_fips, state_name, county_*)
    meta_shared <- intersect(setdiff(names(a), c(join_keys, grep("^(homicide|all_external|undetermined)_",
                                                                 names(a), value = TRUE))),
                             setdiff(names(b), c(join_keys, grep("^(homicide|all_external|undetermined)_",
                                                                 names(b), value = TRUE))))
    # Use full_join on all shared columns to preserve rows from either side
    full_join(a, b, by = c(join_keys, meta_shared))
  }, cause_dfs)

  # Compute rates per 100k where missing (some pulls omit mortality_rate)
  for (cn in CAUSES) {
    deaths_col <- sprintf("%s_deaths", cn)
    pop_col    <- sprintf("%s_population", cn)
    rate_col   <- sprintf("%s_rate_per_100k", cn)
    if (all(c(deaths_col, pop_col) %in% names(merged))) {
      merged[[rate_col]] <- ifelse(is.na(merged[[pop_col]]) | merged[[pop_col]] == 0,
                                   NA_real_,
                                   merged[[deaths_col]] / merged[[pop_col]] * 1e5)
    }
  }

  merged
}

# ---------------------------------------------------------------------------
# Metros filter (for county-month layer 4)
# ---------------------------------------------------------------------------

metros_filter <- function(df, pop_threshold = 500000L) {
  # Use max population observed per county-year as the metro criterion.
  if (!"homicide_population" %in% names(df)) {
    # Try all_external as fallback
    pop_col <- intersect(c("all_external_population", "undetermined_population"),
                         names(df))[1]
    if (is.na(pop_col)) stop("No population column available for metros filter")
  } else {
    pop_col <- "homicide_population"
  }

  metros <- df %>%
    group_by(geo_fips) %>%
    summarise(max_pop = max(.data[[pop_col]], na.rm = TRUE), .groups = "drop") %>%
    filter(is.finite(max_pop), max_pop >= pop_threshold) %>%
    pull(geo_fips)

  cat(sprintf("  Metros filter (pop >= %s): %d counties retained\n",
              format(pop_threshold, big.mark = ","), length(metros)))

  df %>% filter(geo_fips %in% metros)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

cat("=========================================\n")
cat(" WAVE 1c: WONDER violence panel builder  \n")
cat("=========================================\n")

for (tag in TAGS) {
  panel <- build_panel_for_tag(tag)
  if (is.null(panel)) next

  # Determine output name
  out_stem <- sub("_month_", "_month_", tag)
  out_name <- sprintf("wonder_violence_%s.rds", tag)

  # Apply metros filter for county-month
  if (tag == "county_month_2018_2023") {
    panel <- metros_filter(panel)
    out_name <- "wonder_violence_county_month_metros_2018_2023.rds"
  }

  out_path <- file.path(DATA, out_name)
  saveRDS(panel, out_path)

  cat(sprintf("  ✓ Wrote %s: %s rows, %d cols\n",
              basename(out_path), format(nrow(panel), big.mark = ","), ncol(panel)))
}

cat("\n=== WAVE 1c complete ===\n")
