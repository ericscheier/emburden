#!/usr/bin/env Rscript
# ============================================================================
#  Outage → Homicide: full FE-DiD analysis suite
#  =============================================
#  Fitted on data/tract_panel_enhanced_with_homicide.csv
#  (295k tract-years x 162 cols; 42% have unsuppressed WONDER homicide).
#
#  Specifications:
#    A. Headline main effect (any-outage-event vs untreated)
#    B. Per-event effects (Uri, Ida, Harvey, PSPS)
#    C. Moderator interactions (heat, energy burden, grid reliability)
#    D. Sub-population heterogeneity (poverty, urbanicity, chronic disease)
#    E. Alternative treatment definition (continuous outage-customer-days)
#    F. Placebo tests (lag treatment 2 years — pre-event should be null)
#    G. Alternative FE structures
#    H. Event-study coefficients (annual pre/post around Uri, Ida)
#
#  Outputs:
#    data/outage_homicide_full_results.rds       — all coefficients
#    data/outage_homicide_event_study.rds        — event-time coefs
#    data/outage_homicide_daly_rollup.rds        — attributable homicides/DALYs
#    manuscript/tables/SI_outage_homicide_full_specs.csv
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(fixest)
  library(broom)
  library(purrr)
})

set.seed(20260814L)

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

cat("========================================================================\n")
cat("  Outage → Homicide — Full FE-DiD Suite  (US, 2018-2023)                \n")
cat("========================================================================\n\n")

# ---------------------------------------------------------------------------
#  Load and prep panel
# ---------------------------------------------------------------------------

panel <- read_csv(file.path(DATA, "tract_panel_enhanced_with_homicide.csv"),
                  show_col_types = FALSE, progress = FALSE)
cat(sprintf("Panel loaded: %s tract-years x %d cols\n",
            format(nrow(panel), big.mark = ","), ncol(panel)))

# Also load continuous county-month outage panel for the intensity spec
outage_cm <- readRDS(file.path(DATA, "county_month_eagle_i.rds"))
# Aggregate to county-year for the tract-year panel
outage_cy <- outage_cm %>%
  as_tibble() %>%
  group_by(county_fips, year) %>%
  summarise(
    outage_customer_days_year = sum(outage_customer_days, na.rm = TRUE),
    outage_days_year          = sum(outage_days,          na.rm = TRUE),
    outage_peak_year          = max(outage_peak_customers, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(county_fips = as.character(county_fips))
cat(sprintf("Continuous outage panel: %s county-years, %d unique counties\n",
            format(nrow(outage_cy), big.mark = ","),
            n_distinct(outage_cy$county_fips)))

# Coerce panel county_fips to 5-char string; join outages
panel <- panel %>%
  mutate(county_fips = formatC(as.integer(county_fips), width = 5, flag = "0")) %>%
  left_join(outage_cy, by = c("county_fips", "year"))

# ---------------------------------------------------------------------------
#  Variable prep
# ---------------------------------------------------------------------------

zscore <- function(x) {
  m <- mean(x, na.rm = TRUE); s <- sd(x, na.rm = TRUE)
  if (!is.finite(s) || s == 0) return(rep(NA_real_, length(x)))
  (x - m) / s
}

MEDIATORS <- c(
  "avg_energy_burden.x",
  "solar_penetration_pct",
  "dr_total",
  "extreme_heat_days",
  "heat_wave_days",
  "saidi",
  "saifi",
  "caidi",
  "renewable_proportion_total_pct"
)
SUB_POP <- c(
  "pct_below_poverty",
  "pct_0_50_fpl",
  "pct_150_200_fpl",
  "urban", "rural",
  "urban_rural_code",
  "overall_health_burden",
  "chronic_disease_score",
  "high_chronic_disease",
  "diabetes_prev",
  "electric_heat_dominant"
)
COVARS <- c(MEDIATORS, SUB_POP,
            "outage_customer_days_year", "outage_days_year", "outage_peak_year")

dat <- panel %>%
  transmute(
    geoid          = as.character(geoid),
    county_fips    = as.character(county_fips),
    state_fips     = as.character(state_fips),
    year           = as.integer(year),
    y              = wonder_homicide_rate,
    y_deaths       = wonder_homicide_deaths,
    y_pop          = wonder_homicide_pop,
    treated_uri    = as.integer(treated_uri_final),
    treated_ida    = as.integer(treated_ida),
    treated_harvey = as.integer(treated_harvey),
    treated_psps   = as.integer(treated_psps),
    exposed_uri    = as.integer(exposed_uri),
    exposed_ida    = as.integer(exposed_ida),
    exposed_harvey = as.integer(exposed_harvey),
    exposed_psps   = as.integer(exposed_psps),
    across(all_of(COVARS), ~ as.numeric(.x), .names = "{.col}")
  ) %>%
  filter(!is.na(y), is.finite(y)) %>%
  mutate(across(all_of(COVARS),
                ~ ifelse(is.na(.x) | !is.finite(.x),
                         median(.x[is.finite(.x)], na.rm = TRUE), .x)))

# z-scores for moderators
for (m in c(MEDIATORS, "outage_customer_days_year", "outage_days_year", "outage_peak_year")) {
  dat[[paste0(m, "_z")]] <- zscore(dat[[m]])
}

dat$treated_any <- pmax(dat$treated_uri, dat$treated_ida,
                        dat$treated_harvey, dat$treated_psps, na.rm = TRUE)

# Winsorize y at 99.9% for outlier resilience (WONDER small-county rate spikes)
qc <- quantile(dat$y, 0.999, na.rm = TRUE)
dat$y_w <- pmin(dat$y, qc)

cat(sprintf("Analysis frame: %s rows, %s tracts, %d states, y median=%.2f\n\n",
            format(nrow(dat), big.mark = ","),
            format(n_distinct(dat$geoid), big.mark = ","),
            n_distinct(dat$state_fips),
            median(dat$y, na.rm = TRUE)))

# ---------------------------------------------------------------------------
#  Helper: fit one spec
# ---------------------------------------------------------------------------

fit_one <- function(rhs, label = "", subset = NULL, cluster_var = "geoid", y_var = "y_w") {
  data_used <- if (is.null(subset)) dat else dat[subset, ]
  form <- as.formula(paste(y_var, "~", rhs))
  m <- tryCatch(
    feols(form, data = data_used,
          cluster = as.formula(paste("~", cluster_var)),
          warn = FALSE, notes = FALSE),
    error = function(e) NULL
  )
  if (is.null(m)) {
    return(tibble(spec = label, term = NA_character_, estimate = NA_real_,
                  se = NA_real_, t_stat = NA_real_, p_value = NA_real_, n_obs = 0L))
  }
  co <- coeftable(m)
  tibble(spec = label, term = rownames(co),
         estimate = co[,"Estimate"], se = co[,"Std. Error"],
         t_stat   = co[,"t value"], p_value = co[,"Pr(>|t|)"],
         n_obs    = nobs(m))
}

results <- list()

# ---------------------------------------------------------------------------
#  A. Headline main effect
# ---------------------------------------------------------------------------
cat("A. Headline main effect ...\n")
results[["A_any"]] <- fit_one("treated_any | geoid + year", label = "A_any_geoid_year")
results[["A_state_year"]] <- fit_one("treated_any | state_fips + year",
                                     label = "A_any_state_year", cluster_var = "state_fips")

# ---------------------------------------------------------------------------
#  B. Per-event effects (four events simultaneously)
# ---------------------------------------------------------------------------
cat("B. Per-event effects ...\n")
results[["B_per_event"]] <- fit_one(
  "treated_uri + treated_ida + treated_harvey + treated_psps | geoid + year",
  label = "B_per_event"
)

# ---------------------------------------------------------------------------
#  C. Moderator interactions (heat, burden, grid reliability)
# ---------------------------------------------------------------------------
cat("C. Moderator interactions ...\n")
for (mod in c("extreme_heat_days", "avg_energy_burden.x", "saidi", "saifi",
              "solar_penetration_pct", "dr_total")) {
  mod_z <- paste0(mod, "_z")
  if (!mod_z %in% names(dat)) next
  results[[paste0("C_x_", mod)]] <- fit_one(
    sprintf("treated_any + treated_any:%s + %s | geoid + year", mod_z, mod_z),
    label = sprintf("C_treated_x_%s", mod)
  )
}

# Combined heat + burden model
results[["C_heat_and_burden"]] <- fit_one(
  paste0("treated_any + extreme_heat_days_z + avg_energy_burden.x_z + ",
         "treated_any:extreme_heat_days_z + treated_any:avg_energy_burden.x_z | geoid + year"),
  label = "C_heat_and_burden"
)

# ---------------------------------------------------------------------------
#  D. Sub-population heterogeneity — split by quartiles of key indicators
# ---------------------------------------------------------------------------
cat("D. Sub-population heterogeneity ...\n")
for (dim_var in c("pct_below_poverty", "urban_rural_code",
                  "avg_energy_burden.x", "overall_health_burden")) {
  if (!dim_var %in% names(dat)) next
  # Skip if constant
  if (all(is.na(dat[[dim_var]])) || var(dat[[dim_var]], na.rm = TRUE) == 0) next
  # 4 bins by quantile (or by codebook for urban_rural_code)
  if (dim_var == "urban_rural_code") {
    # NCHS 2013 6-category (1=large central metro, 6=noncore)
    bins <- as.integer(cut(dat[[dim_var]], breaks = c(0, 1.5, 3.5, 5.5, 6.5),
                           labels = 1:4, include.lowest = TRUE))
  } else {
    br <- unique(quantile(dat[[dim_var]], seq(0, 1, 0.25), na.rm = TRUE))
    if (length(br) < 3) next   # can't split into >=2 bins if all values equal
    br[1] <- br[1] - 1; br[length(br)] <- br[length(br)] + 1
    bins <- as.integer(cut(dat[[dim_var]], breaks = br, include.lowest = TRUE))
  }
  for (q in sort(unique(bins))) {
    if (is.na(q)) next
    sub <- which(bins == q & !is.na(dat$treated_any))
    if (length(sub) < 500) next
    results[[sprintf("D_%s_Q%d", dim_var, q)]] <- fit_one(
      "treated_any | geoid + year", label = sprintf("D_%s_Q%d", dim_var, q),
      subset = sub
    )
  }
}

# ---------------------------------------------------------------------------
#  E. Continuous treatment (customer-days out, log-scaled)
# ---------------------------------------------------------------------------
cat("E. Continuous treatment intensity ...\n")
dat$log_outage_cd <- log1p(pmax(dat$outage_customer_days_year, 0))
results[["E_continuous"]] <- fit_one(
  "log_outage_cd | geoid + year", label = "E_continuous_log_cd"
)
results[["E_continuous_x_heat"]] <- fit_one(
  "log_outage_cd + log_outage_cd:extreme_heat_days_z + extreme_heat_days_z | geoid + year",
  label = "E_continuous_x_heat"
)
results[["E_continuous_x_burden"]] <- fit_one(
  "log_outage_cd + log_outage_cd:avg_energy_burden.x_z + avg_energy_burden.x_z | geoid + year",
  label = "E_continuous_x_burden"
)

# ---------------------------------------------------------------------------
#  F. Placebo tests (lag treatment by 2 years — pre-event pseudo-treatment)
#     If our design has parallel trends, β on lagged treatment should be ≈0.
# ---------------------------------------------------------------------------
cat("F. Placebo tests ...\n")

# Placebo: assign "treated" to 2014 (pre-treatment for ALL events) — should be null
# The panel has 3 waves (2014, 2018, 2022). Real treated_* fires in 2022 rows.
# For placebo, we pretend 2014 was the treatment year — no real outage yet, so β≈0.
dat <- dat %>%
  mutate(
    placebo_uri    = as.integer(exposed_uri == 1    & year == 2014),
    placebo_ida    = as.integer(exposed_ida == 1    & year == 2014),
    placebo_psps   = as.integer(exposed_psps == 1   & year == 2014),
    placebo_harvey = as.integer(exposed_harvey == 1 & year == 2014),
    placebo_any    = pmax(placebo_uri, placebo_ida, placebo_psps, placebo_harvey,
                          na.rm = TRUE)
  )

results[["F_placebo_2014"]] <- fit_one(
  "placebo_any | geoid + year", label = "F_placebo_2014_pre"
)
results[["F_placebo_per_event"]] <- fit_one(
  "placebo_uri + placebo_ida + placebo_psps + placebo_harvey | geoid + year",
  label = "F_placebo_per_event"
)

# ---------------------------------------------------------------------------
#  G. Alternative FE structures
# ---------------------------------------------------------------------------
cat("G. Alternative FE structures ...\n")
results[["G_state_x_year"]] <- fit_one(
  "treated_any | geoid + state_fips^year", label = "G_state_x_year_FE"
)
results[["G_county_x_year"]] <- fit_one(
  "treated_any | geoid + county_fips^year", label = "G_county_x_year_FE"
)

# ---------------------------------------------------------------------------
#  H. Event-study (annual coefficients around Uri and Ida)
# ---------------------------------------------------------------------------
cat("H. Event-study coefficients (limited by 3-wave panel: 2014, 2018, 2022) ...\n")

# The panel has only 3 waves. For each event, event-times reduce to a small set:
#   Uri/Ida  (event_year 2021): 2014 → k=-7, 2018 → k=-3, 2022 → k=+1
#   PSPS     (event_year 2019): 2014 → k=-5, 2018 → k=-1, 2022 → k=+3
#   Harvey   (event_year 2017): 2014 → k=-3, 2018 → k=+1, 2022 → k=+5
#
# Reference cell = untreated pre-period. Coefficients pool "pre" vs "post"
# for each exposed cohort.

event_years <- list(
  uri     = list(event_year = 2021, exposed_col = "exposed_uri"),
  ida     = list(event_year = 2021, exposed_col = "exposed_ida"),
  psps    = list(event_year = 2019, exposed_col = "exposed_psps"),
  harvey  = list(event_year = 2017, exposed_col = "exposed_harvey")
)

event_results <- list()
for (evname in names(event_years)) {
  ev <- event_years[[evname]]
  ex_col <- ev$exposed_col
  ey     <- ev$event_year

  d <- dat %>% mutate(event_time = year - ey)

  # Build per-year dummies for each observed event_time, dropping the earliest
  # observed one as reference (since we have no consistent pre-period).
  obs_ks <- sort(unique(d$event_time))
  if (length(obs_ks) < 2) next
  ref_k <- obs_ks[which.min(abs(obs_ks + 3))]   # pick k closest to -3 as ref
  k_seq <- setdiff(obs_ks, ref_k)

  rhs_terms <- character(0)
  for (k in k_seq) {
    col <- sprintf("evt_%s_%s%d", evname, ifelse(k < 0, "m", "p"), abs(k))
    d[[col]] <- as.integer(d[[ex_col]] == 1 & d$event_time == k)
    rhs_terms <- c(rhs_terms, col)
  }

  form <- as.formula(paste("y_w ~", paste(rhs_terms, collapse = " + "),
                           "| geoid + year"))
  m <- tryCatch(
    feols(form, data = d, cluster = ~ geoid, warn = FALSE, notes = FALSE),
    error = function(e) { message("event ", evname, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(m)) next
  co <- coeftable(m)
  event_tbl <- tibble(
    event    = evname,
    event_year = ey,
    term     = rownames(co),
    estimate = co[, "Estimate"],
    se       = co[, "Std. Error"],
    p_value  = co[, "Pr(>|t|)"]
  ) %>% mutate(
    k_char = sub(sprintf("evt_%s_", evname), "", term),
    k      = as.integer(sub("[mp]", "", k_char)) * ifelse(startsWith(k_char, "m"), -1, 1),
    ci_lo  = estimate - 1.96 * se,
    ci_hi  = estimate + 1.96 * se
  )
  # Add reference k row manually (β = 0 by construction)
  event_tbl <- bind_rows(
    tibble(event = evname, event_year = ey, term = "reference",
           estimate = 0, se = 0, p_value = NA_real_,
           k_char = ifelse(ref_k < 0, sprintf("m%d", abs(ref_k)),
                           sprintf("p%d", ref_k)),
           k = as.integer(ref_k), ci_lo = 0, ci_hi = 0),
    event_tbl
  ) %>% arrange(k)
  event_results[[evname]] <- event_tbl
  cat(sprintf("  %s (event_year=%d, ref k=%d): %d event-time coefs\n",
              evname, ey, ref_k, nrow(event_tbl)))
}
event_all <- bind_rows(event_results)

# ---------------------------------------------------------------------------
#  Collect all main results into a single tibble + FDR
# ---------------------------------------------------------------------------

all_results <- bind_rows(results) %>%
  filter(!is.na(term))

# BH-FDR across all interaction terms (":" in name) across all specs
int_rows <- all_results %>% filter(grepl(":", term))
int_rows$q_bh <- p.adjust(int_rows$p_value, method = "BH")
int_rows$sig_fdr_10 <- int_rows$q_bh < 0.10
int_rows$sig_fdr_05 <- int_rows$q_bh < 0.05

# ---------------------------------------------------------------------------
#  Report
# ---------------------------------------------------------------------------

cat("\n\n====================  RESULTS  ====================\n\n")

cat("A. Headline\n")
print(filter(all_results, grepl("^A_", spec), term == "treated_any"))

cat("\nB. Per-event\n")
print(filter(all_results, spec == "B_per_event"))

cat("\nC. Moderator interactions (interaction rows only, sorted by q_BH)\n")
print(int_rows %>% arrange(q_bh) %>%
      select(spec, term, estimate, se, p_value, q_bh, sig_fdr_10) %>% head(20))

cat("\nD. Sub-population heterogeneity (headline β per bin)\n")
print(all_results %>%
      filter(grepl("^D_", spec), term == "treated_any") %>%
      arrange(spec) %>%
      select(spec, estimate, se, p_value, n_obs))

cat("\nE. Continuous outage intensity\n")
print(filter(all_results, grepl("^E_", spec)))

cat("\nF. Placebo (lag-2 pre-event)\n")
print(filter(all_results, spec == "F_placebo_lag2"))

cat("\nG. Alternative FE structures\n")
print(filter(all_results, grepl("^G_", spec), term == "treated_any"))

cat("\nH. Event-study coefficients\n")
print(event_all %>% select(event, k, estimate, se, p_value, ci_lo, ci_hi))

# ---------------------------------------------------------------------------
#  Save
# ---------------------------------------------------------------------------

saveRDS(list(
  headline           = filter(all_results, grepl("^A_", spec)),
  per_event          = filter(all_results, spec == "B_per_event"),
  interactions_fdr   = int_rows,
  heterogeneity      = filter(all_results, grepl("^D_", spec)),
  continuous_intensity = filter(all_results, grepl("^E_", spec)),
  placebo            = filter(all_results, grepl("^F_", spec)),
  alt_fe             = filter(all_results, grepl("^G_", spec)),
  n_obs_frame        = nrow(dat),
  n_tracts           = n_distinct(dat$geoid),
  n_states           = n_distinct(dat$state_fips),
  ran_at             = Sys.time()
), file.path(DATA, "outage_homicide_full_results.rds"))

saveRDS(event_all, file.path(DATA, "outage_homicide_event_study.rds"))

# Write SI table
dir.create(file.path(REPO, "manuscript/tables"), recursive = TRUE, showWarnings = FALSE)
write_csv(all_results, file.path(REPO, "manuscript/tables/SI_outage_homicide_full_specs.csv"))
write_csv(event_all,   file.path(REPO, "manuscript/tables/SI_outage_homicide_event_study.csv"))

cat("\n✓ Wrote data/outage_homicide_full_results.rds\n")
cat("✓ Wrote data/outage_homicide_event_study.rds\n")
cat("✓ Wrote manuscript/tables/SI_outage_homicide_full_specs.csv\n")
cat("✓ Wrote manuscript/tables/SI_outage_homicide_event_study.csv\n")
cat("\n=== Full analysis complete ===\n")
