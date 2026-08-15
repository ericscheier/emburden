#!/usr/bin/env Rscript
# All-hurricanes / all-events FE-DiD analysis for outage → homicide
# Panel: data/county_year_all_events_homicide_panel.rds (2,359 county-years,
# 568 counties, 41 exposure indicators).
#
# Three flavors:
#   (I) Univariate per-event fits — each event's treated indicator alone
#   (II) Joint fit with all named hurricanes + Uri + PSPS umbrella
#   (III) Hurricane-family combined (any hurricane exposure → homicide)
#
# Output: data/wave_outage_homicide_all_events_results.rds
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(tidyr)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")
panel <- readRDS(file.path(DATA, "county_year_all_events_homicide_panel.rds"))
cat(sprintf("Panel: %s county-years, %d counties\n\n",
            format(nrow(panel), big.mark=","), n_distinct(panel$county_fips)))

# Event universe: extract from panel column names
exposed_cols <- grep("^exposed_", names(panel), value = TRUE)
treated_cols <- grep("^treated_", names(panel), value = TRUE)
treated_cols <- setdiff(treated_cols, c("treated_any", "treated_any_hurricane"))

# Named hurricanes (extract explicit named ones)
named_hurricanes <- treated_cols[
  grepl("harvey|irma|maria|michael|ida|helene", treated_cols)]
# Uri (winter storm classified as ice storm)
uri_key <- treated_cols[grepl("uri", treated_cols)]
# Season-umbrella hurricanes (Hurricane YYYY entries)
umbrella_hurricanes <- treated_cols[
  grepl("^treated_hurricane_\\d{4}$|^treated_tropical_storm_\\d{4}$", treated_cols)]
# PSPS (California)
psps_keys <- treated_cols[grepl("psps", treated_cols)]

cat("Named hurricanes:  ", paste(named_hurricanes, collapse=", "), "\n")
cat("Uri:              ", paste(uri_key, collapse=", "), "\n")
cat("Umbrella hurricanes:", paste(umbrella_hurricanes, collapse=", "), "\n")
cat("PSPS:             ", paste(psps_keys, collapse=", "), "\n\n")

# ---------------------------------------------------------------------------
#  (I) Univariate per-event FE-DiD  — each event on its own
# ---------------------------------------------------------------------------
fit_univariate <- function(tcol) {
  n_treat <- sum(panel[[tcol]] == 1, na.rm = TRUE)
  if (n_treat < 5) return(NULL)
  form <- as.formula(sprintf(
    "wonder_homicide_rate_w ~ %s | county_fips + year", tcol))
  m <- tryCatch(
    feols(form, data = panel, cluster = ~ county_fips,
          warn = FALSE, notes = FALSE),
    error = function(e) NULL)
  if (is.null(m)) return(NULL)
  co <- coeftable(m)
  tibble(
    event    = sub("^treated_", "", tcol),
    n_treat  = n_treat,
    estimate = co[1, "Estimate"],
    se       = co[1, "Std. Error"],
    p_value  = co[1, "Pr(>|t|)"],
    n_obs    = nobs(m)
  )
}

univ_all <- bind_rows(lapply(treated_cols, fit_univariate))
univ_all <- univ_all %>%
  mutate(
    q_bh = p.adjust(p_value, method = "BH"),
    sig_fdr_10 = q_bh < 0.10,
    sig_fdr_05 = q_bh < 0.05
  ) %>%
  arrange(q_bh)

cat("=== (I) UNIVARIATE PER-EVENT FE-DiD ===\n\n")
print(univ_all %>% head(20), n = 20)

# ---------------------------------------------------------------------------
#  (II) Joint fit — named hurricanes + Uri + PSPS + season umbrellas
# ---------------------------------------------------------------------------
key_events <- c(named_hurricanes, uri_key, psps_keys, umbrella_hurricanes)
# Deduplicate + drop events with <5 treated
key_events <- unique(key_events)
key_events <- key_events[sapply(key_events, function(k)
  sum(panel[[k]] == 1, na.rm = TRUE) >= 5)]

if (length(key_events) >= 2) {
  form_joint <- as.formula(sprintf(
    "wonder_homicide_rate_w ~ %s | county_fips + year",
    paste(key_events, collapse = " + ")))
  m_joint <- feols(form_joint, data = panel, cluster = ~ county_fips,
                   warn = FALSE, notes = FALSE)
  co <- coeftable(m_joint)
  joint <- tibble(
    event    = sub("^treated_", "", rownames(co)),
    estimate = co[, "Estimate"],
    se       = co[, "Std. Error"],
    p_value  = co[, "Pr(>|t|)"],
    n_obs    = nobs(m_joint)
  )
  joint$q_bh <- p.adjust(joint$p_value, method = "BH")
  joint$sig_fdr_10 <- joint$q_bh < 0.10
  cat("\n=== (II) JOINT FIT — all key events simultaneously ===\n\n")
  print(joint %>% arrange(q_bh))
} else {
  joint <- tibble()
  cat("\n(II) Joint fit skipped: too few key events\n")
}

# ---------------------------------------------------------------------------
#  (III) Hurricane-family combined
# ---------------------------------------------------------------------------
m_hurr <- feols(wonder_homicide_rate_w ~ treated_any_hurricane |
                  county_fips + year,
                data = panel, cluster = ~ county_fips,
                warn = FALSE, notes = FALSE)
co <- coeftable(m_hurr)
hurr_family <- tibble(
  event    = "any_hurricane_or_tropical_storm",
  estimate = co[1, "Estimate"], se = co[1, "Std. Error"],
  t_stat   = co[1, "t value"],  p_value = co[1, "Pr(>|t|)"],
  n_obs    = nobs(m_hurr),
  n_treat  = sum(panel$treated_any_hurricane == 1, na.rm = TRUE)
)
cat("\n=== (III) HURRICANE-FAMILY COMBINED ===\n\n")
print(hurr_family)

# ---------------------------------------------------------------------------
#  (IV) Hurricane × heat interaction (still positive amplification?)
# ---------------------------------------------------------------------------
if ("extreme_heat_days" %in% names(panel)) {
  panel$extreme_heat_z <- as.numeric(scale(panel$extreme_heat_days))
  m_hurr_heat <- tryCatch(
    feols(wonder_homicide_rate_w ~ treated_any_hurricane +
          treated_any_hurricane:extreme_heat_z + extreme_heat_z |
          county_fips + year, data = panel, cluster = ~ county_fips,
          warn = FALSE, notes = FALSE),
    error = function(e) NULL)
  if (!is.null(m_hurr_heat)) {
    co <- coeftable(m_hurr_heat)
    hurr_heat <- tibble(
      term = rownames(co),
      estimate = co[, "Estimate"], se = co[, "Std. Error"],
      p_value = co[, "Pr(>|t|)"], n_obs = nobs(m_hurr_heat))
    cat("\n=== (IV) HURRICANE × HEAT INTERACTION ===\n\n")
    print(hurr_heat)
  } else {
    hurr_heat <- tibble()
  }
} else {
  hurr_heat <- tibble()
}

# ---------------------------------------------------------------------------
#  Save
# ---------------------------------------------------------------------------
saveRDS(list(
  univariate = univ_all,
  joint = joint,
  hurricane_family = hurr_family,
  hurricane_x_heat = hurr_heat,
  n_events_considered = length(treated_cols),
  ran_at = Sys.time()
), file.path(DATA, "wave_outage_homicide_all_events_results.rds"))

write.csv(univ_all,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_univariate_all_events.csv"),
          row.names = FALSE)
if (nrow(joint) > 0) {
  write.csv(joint,
            file.path(REPO, "manuscript/tables/SI_outage_homicide_joint_key_events.csv"),
            row.names = FALSE)
}
cat(sprintf("\n✓ Wrote data/wave_outage_homicide_all_events_results.rds\n"))
cat(sprintf("✓ Wrote 2 SI CSVs to manuscript/tables/\n"))
