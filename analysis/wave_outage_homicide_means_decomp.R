#!/usr/bin/env Rscript
# Non-firearm assault means decomposition.
# Parse WONDER cause-specific TSVs for 4 non-firearm means and merge into
# tract panel. Then rerun the "outage × moderator" FE-DiD for each means
# outcome to identify which specific mechanism drives the +0.55 non-firearm
# heat interaction from REPORT §10.2.
#
# Means:
#   X99  cutting/sharp (assault by sharp object)
#   Y00  blunt object
#   X91  strangulation / hanging
#   Y04  bodily force

suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(readr); library(fixest); library(tidyr)
})
REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")
SRC  <- file.path(REPO, "sources", "cdc_wonder_downloads_causes")

MEANS <- list(
  cutting_sharp = "X99",
  blunt         = "Y00",
  strangulation = "X91",
  bodily_force  = "Y04"
)

parse_tsv <- function(path, means_key) {
  fips_2 <- sub("^mortality_(\\d{2})_.*", "\\1", basename(path))
  raw <- readLines(path, warn = FALSE)
  end_row <- min(which(raw == "" | grepl("^---", raw) | grepl("^\"Dataset", raw)),
                 length(raw)+1L) - 1L
  if (end_row < 2L) return(NULL)
  dt <- tryCatch(
    fread(text = paste(raw[1:end_row], collapse = "\n"), sep = "\t",
          na.strings = c("", "Suppressed", "Not Applicable", "Missing"),
          quote = "\"", showProgress = FALSE),
    error = function(e) NULL)
  if (is.null(dt) || nrow(dt) == 0) return(NULL)
  dt <- dt[!is.na(`County Code`) & `County Code` != ""]
  if (nrow(dt) == 0) return(NULL)
  data.frame(
    state_fips  = fips_2,
    county_fips = formatC(as.integer(dt$`County Code`), width = 5, flag = "0"),
    year        = as.integer(dt$Year),
    means       = means_key,
    deaths      = suppressWarnings(as.integer(dt$Deaths)),
    population  = suppressWarnings(as.integer(dt$Population)),
    rate        = suppressWarnings(as.numeric(dt$`Crude Rate`)),
    stringsAsFactors = FALSE)
}

# Load all means
all_means <- list()
for (mk in names(MEANS)) {
  tsvs <- list.files(SRC, pattern = sprintf("^mortality_\\d{2}_.*_homicide_%s\\.txt$", mk),
                     full.names = TRUE)
  cat(sprintf("Parsing %d TSVs for %s (%s)...\n", length(tsvs), mk, MEANS[[mk]]))
  rows <- do.call(rbind, lapply(tsvs, parse_tsv, means_key = mk))
  rows <- rows[!is.na(rows$county_fips) & rows$county_fips != "0000NA" & !is.na(rows$year), ]
  all_means[[mk]] <- rows
}

# Wide by means
long_all <- do.call(rbind, all_means)
cat(sprintf("Total non-firearm rows: %s across %d states\n",
            format(nrow(long_all), big.mark = ","),
            length(unique(long_all$state_fips))))

wide <- long_all %>%
  select(state_fips, county_fips, year, means, deaths, population, rate) %>%
  # Aggregate any duplicates by (county, year, means) — take max (typically same value)
  group_by(state_fips, county_fips, year, means) %>%
  summarise(deaths = suppressWarnings(max(deaths, na.rm=TRUE)),
            population = suppressWarnings(max(population, na.rm=TRUE)),
            rate = suppressWarnings(max(rate, na.rm=TRUE)),
            .groups = "drop") %>%
  mutate(across(c(deaths, population, rate),
                ~ ifelse(is.infinite(.x) | is.nan(.x), NA_real_, .x))) %>%
  pivot_wider(names_from = means, values_from = c(deaths, population, rate),
              names_glue = "{means}_{.value}") %>%
  as.data.frame()

cat(sprintf("Wide panel: %d rows, cols: %s\n",
            nrow(wide), paste(grep("_(deaths|rate)$", names(wide), value=TRUE), collapse=", ")))

saveRDS(wide, file.path(DATA, "wonder_homicide_nonfirearm_means_county_year_2018_2023.rds"))
cat("✓ Wrote data/wonder_homicide_nonfirearm_means_county_year_2018_2023.rds\n")

# Merge into tract panel
panel <- fread(file.path(DATA, "tract_panel_enhanced_with_homicide.csv"),
               showProgress = FALSE)
panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
panel[, year := as.integer(year)]
wide_dt <- as.data.table(wide)
wide_dt[, county_fips := as.character(county_fips)]
wide_dt[, year := as.integer(year)]
merged <- wide_dt[panel, on = c("county_fips", "year")]

# FE-DiD: for each means, run headline + heat interaction
zscore <- function(x) {
  m <- mean(x, na.rm=TRUE); s <- sd(x, na.rm=TRUE)
  if (!is.finite(s) || s==0) return(rep(NA_real_, length(x)))
  (x-m)/s
}
med_imp <- function(x) ifelse(is.na(x) | !is.finite(x),
                              median(x[is.finite(x)], na.rm=TRUE), x)

merged[, heat_z := zscore(med_imp(as.numeric(extreme_heat_days)))]
merged[, burden_z := zscore(med_imp(as.numeric(avg_energy_burden.x)))]
merged[, treated_any := pmax(as.integer(treated_uri_final), as.integer(treated_ida),
                             as.integer(treated_harvey), as.integer(treated_psps), na.rm=TRUE)]

results <- list()
for (mk in names(MEANS)) {
  outcome <- paste0(mk, "_rate")
  if (!outcome %in% names(merged)) next
  # Winsorize
  qc <- quantile(merged[[outcome]], 0.999, na.rm=TRUE)
  merged[[paste0(outcome, "_w")]] <- pmin(merged[[outcome]], qc)
  y <- paste0(outcome, "_w")

  # Headline
  form <- as.formula(sprintf("%s ~ treated_any | geoid + year", y))
  m1 <- tryCatch(feols(form, data=merged, cluster=~geoid, warn=FALSE, notes=FALSE),
                 error=function(e) NULL)
  if (!is.null(m1)) {
    co <- coeftable(m1)
    results[[paste0("head_", mk)]] <- tibble(
      means = mk, outcome_col = y, spec = "headline",
      term = rownames(co), estimate = co[,"Estimate"], se = co[,"Std. Error"],
      p_value = co[,"Pr(>|t|)"], n_obs = nobs(m1))
  }
  # Heat interaction
  form2 <- as.formula(sprintf(
    "%s ~ treated_any + treated_any:heat_z + heat_z | geoid + year", y))
  m2 <- tryCatch(feols(form2, data=merged, cluster=~geoid, warn=FALSE, notes=FALSE),
                 error=function(e) NULL)
  if (!is.null(m2)) {
    co <- coeftable(m2)
    results[[paste0("heat_", mk)]] <- tibble(
      means = mk, outcome_col = y, spec = "heat_interaction",
      term = rownames(co), estimate = co[,"Estimate"], se = co[,"Std. Error"],
      p_value = co[,"Pr(>|t|)"], n_obs = nobs(m2))
  }
  # Burden interaction
  form3 <- as.formula(sprintf(
    "%s ~ treated_any + treated_any:burden_z + burden_z | geoid + year", y))
  m3 <- tryCatch(feols(form3, data=merged, cluster=~geoid, warn=FALSE, notes=FALSE),
                 error=function(e) NULL)
  if (!is.null(m3)) {
    co <- coeftable(m3)
    results[[paste0("burden_", mk)]] <- tibble(
      means = mk, outcome_col = y, spec = "burden_interaction",
      term = rownames(co), estimate = co[,"Estimate"], se = co[,"Std. Error"],
      p_value = co[,"Pr(>|t|)"], n_obs = nobs(m3))
  }
}
all_res <- bind_rows(results)

cat("\n\n=== HEADLINE β BY MEANS (main effect of any-outage) ===\n\n")
print(all_res %>%
      filter(spec == "headline", term == "treated_any") %>%
      arrange(desc(abs(estimate))) %>%
      select(means, estimate, se, p_value, n_obs))

cat("\n=== HEAT × OUTAGE INTERACTION BY MEANS ===\n\n")
print(all_res %>%
      filter(spec == "heat_interaction", grepl(":", term)) %>%
      arrange(desc(estimate)) %>%
      select(means, term, estimate, se, p_value, n_obs))

cat("\n=== BURDEN × OUTAGE INTERACTION BY MEANS ===\n\n")
print(all_res %>%
      filter(spec == "burden_interaction", grepl(":", term)) %>%
      arrange(desc(estimate)) %>%
      select(means, term, estimate, se, p_value, n_obs))

saveRDS(list(
  results = all_res,
  means_dict = MEANS,
  ran_at = Sys.time()
), file.path(DATA, "wave_outage_homicide_means_decomp.rds"))
write_csv(all_res,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_means_decomp.csv"))
cat("\n✓ Wrote data/wave_outage_homicide_means_decomp.rds\n")
