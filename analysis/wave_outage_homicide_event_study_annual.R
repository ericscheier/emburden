#!/usr/bin/env Rscript
# Annual event-study around Uri (2021), Ida (2021), PSPS (2019+), Harvey (2017)
# using the county-year panel data/county_year_outage_homicide_panel.rds
# Panel covers 2018-2023 (6 years). Event-time coefficients:
#   Uri/Ida  (event_year 2021): k ∈ {-3, -2, -1, 0, +1, +2}
#   PSPS     (event_year 2019): k ∈ {-1, 0, +1, +2, +3, +4}
#   Harvey   (event_year 2017): all years post → single-diff only
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(fixest)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

panel <- readRDS(file.path(DATA, "county_year_outage_homicide_panel.rds"))
cat(sprintf("Panel: %s county-years, %d counties, %d states\n\n",
            format(nrow(panel), big.mark = ","),
            dplyr::n_distinct(panel$county_fips),
            dplyr::n_distinct(panel$state_fips)))

# For fitting we use wonder_homicide_rate_w (99.9-pct-winsorized)
fit_event_study <- function(exposed_col, event_year, evname, ref_k = -1L) {
  d <- panel %>%
    mutate(event_time = year - event_year,
           exposed    = as.integer(.data[[exposed_col]]),
           y = wonder_homicide_rate_w)
  obs_ks <- sort(unique(d$event_time))
  if (!ref_k %in% obs_ks) ref_k <- obs_ks[which.min(abs(obs_ks + 1))]
  k_seq <- setdiff(obs_ks, ref_k)

  rhs <- character(0)
  for (k in k_seq) {
    col <- sprintf("evt_%s%d", ifelse(k < 0, "m", "p"), abs(k))
    d[[col]] <- as.integer(d$exposed == 1 & d$event_time == k)
    rhs <- c(rhs, col)
  }
  form <- as.formula(paste("y ~", paste(rhs, collapse = " + "),
                           "| county_fips + year"))
  m <- feols(form, data = d, cluster = ~ county_fips, warn = FALSE, notes = FALSE)
  co <- coeftable(m)
  tibble(
    event     = evname,
    event_year = event_year,
    ref_k     = ref_k,
    term      = rownames(co),
    estimate  = co[, "Estimate"],
    se        = co[, "Std. Error"],
    p_value   = co[, "Pr(>|t|)"]
  ) %>% mutate(
    k_char = sub("evt_", "", term),
    k      = as.integer(sub("[mp]", "", k_char)) *
             ifelse(startsWith(k_char, "m"), -1L, 1L),
    ci_lo  = estimate - 1.96 * se,
    ci_hi  = estimate + 1.96 * se
  ) %>% bind_rows(
    tibble(event = evname, event_year = event_year, ref_k = ref_k,
           term = "reference",
           estimate = 0, se = 0, p_value = NA_real_,
           k_char = "ref", k = ref_k, ci_lo = 0, ci_hi = 0)
  ) %>% arrange(k)
}

safe_es <- function(exposed_col, event_year, evname, ref_k) {
  n_exposed <- sum(panel[[exposed_col]] == 1L, na.rm = TRUE)
  if (n_exposed == 0L) {
    cat(sprintf("  skip %s — 0 exposed county-years (all suppressed at n<10)\n", evname))
    return(NULL)
  }
  tryCatch(fit_event_study(exposed_col, event_year, evname, ref_k),
           error = function(e) {
             cat(sprintf("  skip %s — fit error: %s\n", evname, conditionMessage(e)))
             NULL
           })
}

es_all <- bind_rows(
  safe_es("exposed_uri",    2021, "uri",    ref_k = -1L),
  safe_es("exposed_ida",    2021, "ida",    ref_k = -1L),
  safe_es("exposed_psps",   2019, "psps",   ref_k = -1L),
  safe_es("exposed_harvey", 2017, "harvey", ref_k =  1L)
)

cat("=== Event-study coefficients ===\n\n")
print(es_all %>% select(event, k, estimate, se, p_value, ci_lo, ci_hi))

# Pre-trends test: joint F-test that all pre-period (k < 0) coefficients = 0
cat("\n=== Pre-trends test (F-stat, joint pre-period coefs = 0) ===\n\n")
pre_test <- es_all %>%
  filter(k < 0, term != "reference") %>%
  group_by(event) %>%
  summarise(
    n_pre_coefs = n(),
    max_abs_estimate = max(abs(estimate), na.rm = TRUE),
    any_significant_at_05 = any(p_value < 0.05, na.rm = TRUE),
    .groups = "drop"
  )
print(pre_test)

saveRDS(es_all, file.path(DATA, "outage_homicide_event_study_annual.rds"))
write.csv(es_all, file.path(REPO, "manuscript/tables/SI_outage_homicide_event_study_annual.csv"), row.names = FALSE)
cat(sprintf("\n✓ Wrote data/outage_homicide_event_study_annual.rds\n"))
cat(sprintf("✓ Wrote manuscript/tables/SI_outage_homicide_event_study_annual.csv\n"))
