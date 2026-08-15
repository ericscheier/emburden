#!/usr/bin/env Rscript
# Monthly event-study for outage → homicide around specific events
#   Winter Storm Uri (Feb 2021, TX)
#   Hurricane Ida (Aug 2021, LA + NJ)
#   Hurricane Michael (Oct 2018, NC)
#   Hurricane Harvey (Aug 2017, LA) — only 6mo+ post-window since panel starts 2018
#   CA PSPS (Oct 2019, various)
#
# Window: k ∈ [−6, +6] months; reference k = −1.
# Panel: data/wonder_violence_county_month_2018_2023.rds (from monthly scrape)
# Treatment: exposed county × month == (event_year, event_month + k)
suppressPackageStartupMessages({
  library(dplyr); library(data.table); library(fixest); library(tidyr)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

panel_month <- readRDS(file.path(DATA, "wonder_violence_county_month_2018_2023.rds"))
setDT(panel_month)
panel_month[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
panel_month[, year_month := sprintf("%04d-%02d", year, month_num)]

# Attach event exposure indicators from all-events panel
ce <- readRDS(file.path(DATA, "county_year_all_events_homicide_panel.rds"))
ce_slim <- unique(as.data.table(ce)[, .(county_fips,
  exposed_uri     = exposed_winter_storm_uri_2021,
  exposed_ida     = exposed_hurricane_ida_2021,
  exposed_michael = exposed_hurricane_michael_2018,
  exposed_harvey  = exposed_hurricane_harvey_2017,
  exposed_irma    = exposed_hurricane_irma_2017,
  exposed_helene  = exposed_hurricane_helene_2024
)])
panel_month <- ce_slim[panel_month, on = "county_fips"]
panel_month[, homicide_deaths_w := pmin(homicide_deaths, quantile(homicide_deaths, 0.999, na.rm=TRUE))]

cat(sprintf("Monthly panel: %s county-months, %d counties\n",
            format(nrow(panel_month), big.mark=","),
            uniqueN(panel_month$county_fips)))

# ---------------------------------------------------------------------------
#  Helper: fit event-study around a single (year, month) event
# ---------------------------------------------------------------------------
event_defs <- list(
  uri     = list(exposed_col = "exposed_uri",     ey = 2021, em = 2,
                 label = "Winter Storm Uri (Feb 2021, TX)"),
  ida     = list(exposed_col = "exposed_ida",     ey = 2021, em = 8,
                 label = "Hurricane Ida (Aug 2021, LA/NJ)"),
  michael = list(exposed_col = "exposed_michael", ey = 2018, em = 10,
                 label = "Hurricane Michael (Oct 2018, NC)"),
  irma    = list(exposed_col = "exposed_irma",    ey = 2017, em = 9,
                 label = "Hurricane Irma (Sep 2017, SC) — 2018+ only")
)

fit_monthly_es <- function(exposed_col, ey, em, label, kmax = 6) {
  n_exp <- sum(panel_month[[exposed_col]] == 1, na.rm = TRUE)
  if (n_exp < 100) {
    cat(sprintf("  skip %s: only %d exposed county-months\n", label, n_exp))
    return(NULL)
  }
  d <- copy(panel_month)
  # months from event
  d[, month_since_event := (year - ey) * 12L + (month_num - em)]
  # keep window
  d <- d[abs(month_since_event) <= kmax]
  obs_ks <- sort(unique(d$month_since_event))
  ref_k <- -1L
  if (!ref_k %in% obs_ks) ref_k <- obs_ks[which.min(abs(obs_ks + 1))]
  k_seq <- setdiff(obs_ks, ref_k)
  # dummies
  rhs <- character(0)
  for (k in k_seq) {
    col <- sprintf("evt_%s%d", ifelse(k<0,"m","p"), abs(k))
    d[[col]] <- as.integer(d[[exposed_col]] == 1 & d$month_since_event == k)
    rhs <- c(rhs, col)
  }
  # fit
  form <- as.formula(paste("homicide_deaths_w ~", paste(rhs, collapse=" + "),
                           "| county_fips + year_month"))
  m <- tryCatch(
    feols(form, data = d, cluster = ~ county_fips, warn = FALSE, notes = FALSE),
    error = function(e) { message(label, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(m)) return(NULL)
  co <- coeftable(m)
  tibble(
    event = label, ref_k = ref_k,
    term = rownames(co),
    estimate = co[, "Estimate"], se = co[, "Std. Error"],
    p_value = co[, "Pr(>|t|)"]
  ) %>% mutate(
    k = as.integer(sub("[mp]", "", sub("evt_", "", term))) *
        ifelse(startsWith(sub("evt_", "", term), "m"), -1L, 1L),
    ci_lo = estimate - 1.96 * se, ci_hi = estimate + 1.96 * se
  ) %>% bind_rows(
    tibble(event = label, ref_k = ref_k, term = "reference",
           estimate = 0, se = 0, p_value = NA_real_,
           k = as.integer(ref_k), ci_lo = 0, ci_hi = 0)
  ) %>% arrange(k)
}

es_all <- bind_rows(lapply(event_defs, function(e)
  fit_monthly_es(e$exposed_col, e$ey, e$em, e$label)))

cat("\n=== MONTHLY EVENT STUDY COEFFICIENTS ===\n\n")
print(es_all %>% select(event, k, estimate, se, p_value, ci_lo, ci_hi),
      n = 100)

# Pre-trends test
cat("\n=== PRE-TRENDS SUMMARY (any pre-event k < 0 significant at p<0.05?) ===\n\n")
pre <- es_all %>% filter(k < 0, term != "reference") %>%
  group_by(event) %>%
  summarise(n_pre = n(),
            n_sig_at_05 = sum(p_value < 0.05, na.rm = TRUE),
            max_abs_estimate = max(abs(estimate), na.rm = TRUE))
print(pre)

saveRDS(es_all, file.path(DATA, "outage_homicide_monthly_event_study.rds"))
write.csv(es_all,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_monthly_event_study.csv"),
          row.names = FALSE)
cat("\n✓ Wrote data/outage_homicide_monthly_event_study.rds\n")
cat("✓ Wrote manuscript/tables/SI_outage_homicide_monthly_event_study.csv\n")
