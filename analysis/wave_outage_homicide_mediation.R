#!/usr/bin/env Rscript
# W3a: Outage -> mortality FE-DiD analysis
# =========================================
# Wave "outage-homicide" script — fitted on the existing tract-year panel
# (`data/tract_panel_enhanced_for_analysis.csv`) with the FEMA event-outage
# indicators (`treated_uri_final`, `treated_ida`, `treated_harvey`,
# `treated_psps`) and DER/energy-burden mediators.
#
# Current run uses `crude_mortality_rate` (all-cause) as the OUTCOME because
# cause-specific homicide data from WONDER requires a 5-hour Selenium scrape
# that is a follow-on step (see plan file abundant-popping-octopus.md, W1b).
#
# Once the scraper finishes, swap the OUTCOME_COL constant below to
# `wonder_homicide_rate` and re-run — no other changes needed.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(fixest)
})

REPO   <- "/home/ess/Documents/apps/net_energy_equity"
PANEL  <- file.path(REPO, "data", "tract_panel_enhanced_for_analysis.csv")
OUT    <- file.path(REPO, "data", "wave_outage_homicide_mediation_results.rds")

# CONFIG — switch outcome once WONDER homicide pull completes
OUTCOME_COL   <- "crude_mortality_rate"   # -> "wonder_homicide_rate" post-pull
OUTCOME_LABEL <- "All-cause mortality (per 100k) — PLACEHOLDER for homicide"

# ---------------------------------------------------------------------------
# Load + prep
# ---------------------------------------------------------------------------

cat("=================================================================\n")
cat("  Wave outage-homicide FE-DiD — ", OUTCOME_LABEL, "\n")
cat("=================================================================\n\n")

panel <- read_csv(PANEL, show_col_types = FALSE)
cat(sprintf("Loaded panel: %s rows x %d cols\n",
            format(nrow(panel), big.mark = ","), ncol(panel)))

required <- c(OUTCOME_COL, "geoid", "state_fips", "year",
              "treated_uri_final", "treated_ida", "treated_harvey", "treated_psps")
missing <- setdiff(required, names(panel))
if (length(missing) > 0) {
  stop("Missing required columns: ", paste(missing, collapse = ", "))
}

# Candidate mediator/moderator columns (use whichever are present)
MEDIATOR_CANDIDATES <- c(
  "avg_energy_burden.x",         # energy-limiting proxy
  "solar_penetration_pct",       # DER penetration
  "renewable_proportion_total_pct",
  "dr_total",                     # demand response
  "extreme_heat_days",            # heat moderator
  "heat_wave_days"
)
mediators <- intersect(MEDIATOR_CANDIDATES, names(panel))
cat(sprintf("Mediators available: %s\n", paste(mediators, collapse = ", ")))

# Standardize outcome + mediators
zscore <- function(x) {
  m <- mean(x, na.rm = TRUE)
  s <- sd(x, na.rm = TRUE)
  if (!is.finite(s) || s == 0) return(rep(NA_real_, length(x)))
  (x - m) / s
}

dat <- panel %>%
  transmute(
    geoid       = as.character(geoid),
    state_fips  = as.character(state_fips),
    year        = as.integer(year),
    y           = .data[[OUTCOME_COL]],
    treated_uri = as.integer(treated_uri_final),
    treated_ida = as.integer(treated_ida),
    treated_harvey = as.integer(treated_harvey),
    treated_psps   = as.integer(treated_psps),
    across(all_of(mediators), ~ as.numeric(.x), .names = "{.col}")
  ) %>%
  filter(!is.na(y), is.finite(y)) %>%
  # Median-impute mediators so full-moderator spec has enough rows
  mutate(across(all_of(mediators),
                ~ ifelse(is.na(.x) | !is.finite(.x),
                         median(.x[is.finite(.x)], na.rm = TRUE),
                         .x)))

# Cap extreme outcome values (Winsorize at 99.5 pct — mortality-rate spikes)
qc <- quantile(dat$y, 0.995, na.rm = TRUE)
dat$y <- pmin(dat$y, qc)

# Z-score mediators
for (m in mediators) dat[[paste0(m, "_z")]] <- zscore(dat[[m]])

cat(sprintf("Analysis frame: %s rows, y range [%.2f, %.2f]\n",
            format(nrow(dat), big.mark = ","),
            min(dat$y, na.rm = TRUE), max(dat$y, na.rm = TRUE)))

# Combined outage exposure = any treated_*
dat$treated_any <- pmax(dat$treated_uri, dat$treated_ida,
                        dat$treated_harvey, dat$treated_psps, na.rm = TRUE)

# ---------------------------------------------------------------------------
# Model fits — five specifications, each returning a coefficient table
# ---------------------------------------------------------------------------

fit_one <- function(rhs, cluster = "geoid", label = "") {
  form <- as.formula(paste("y ~", rhs))
  m <- tryCatch(
    feols(form, data = dat, cluster = as.formula(paste("~", cluster)),
          warn = FALSE, notes = FALSE),
    error = function(e) NULL
  )
  if (is.null(m)) {
    return(tibble(spec = label, term = NA_character_, estimate = NA_real_,
                  se = NA_real_, t_stat = NA_real_, p_value = NA_real_,
                  n_obs = 0L))
  }
  co <- coeftable(m)
  tibble(
    spec     = label,
    term     = rownames(co),
    estimate = co[, "Estimate"],
    se       = co[, "Std. Error"],
    t_stat   = co[, "t value"],
    p_value  = co[, "Pr(>|t|)"],
    n_obs    = nobs(m)
  )
}

cat("\n--- Model fits ---\n")

results <- bind_rows(
  # Spec 1: Main effect, geoid + year FE (identification-strong)
  fit_one("treated_uri + treated_ida + treated_harvey + treated_psps | geoid + year",
          label = "s1_main_fe"),

  # Spec 2: Combined "any outage event" indicator
  fit_one("treated_any | geoid + year", label = "s2_any_fe"),

  # Spec 3: Interaction with heat (if extreme_heat_days present)
  if ("extreme_heat_days_z" %in% names(dat)) {
    fit_one("treated_any + treated_any:extreme_heat_days_z + extreme_heat_days_z | geoid + year",
            label = "s3_treated_x_heat")
  } else NULL,

  # Spec 4: Interaction with energy burden (mediator proxy)
  if ("avg_energy_burden.x_z" %in% names(dat)) {
    fit_one("treated_any + treated_any:avg_energy_burden.x_z + avg_energy_burden.x_z | geoid + year",
            label = "s4_treated_x_burden")
  } else NULL,

  # Spec 5: Interaction with DER (solar penetration) — only if data present
  {
    if ("solar_penetration_pct_z" %in% names(dat) &&
        sum(is.finite(dat$solar_penetration_pct_z)) > 1000L) {
      fit_one("treated_any + treated_any:solar_penetration_pct_z + solar_penetration_pct_z | geoid + year",
              label = "s5_treated_x_solar")
    } else NULL
  },

  # Spec 6: heat + burden moderators combined (identification of pathway)
  fit_one("treated_any + extreme_heat_days_z + treated_any:extreme_heat_days_z + avg_energy_burden.x_z + treated_any:avg_energy_burden.x_z | geoid + year",
          label = "s6_heat_and_burden")
)

# ---------------------------------------------------------------------------
# BH-FDR across the interaction terms in the full-moderators model
# ---------------------------------------------------------------------------

interaction_rows <- results %>%
  filter(spec %in% c("s6_full_moderators", "s3_treated_x_heat",
                     "s4_treated_x_burden", "s5_treated_x_solar"),
         grepl(":", term))

if (nrow(interaction_rows) > 0) {
  interaction_rows$q_bh <- p.adjust(interaction_rows$p_value, method = "BH")
  interaction_rows$sig_fdr_10 <- interaction_rows$q_bh < 0.10
  interaction_rows$sig_fdr_05 <- interaction_rows$q_bh < 0.05
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

cat("\n=== HEADLINE — Main effect of any-outage-event ===\n\n")
headline <- results %>%
  filter(spec == "s2_any_fe", term == "treated_any")
if (nrow(headline) > 0) {
  cat(sprintf("  β(treated_any) = %+.4f  (SE %.4f, t=%.2f, p=%.3g, n=%s)\n",
              headline$estimate, headline$se, headline$t_stat, headline$p_value,
              format(headline$n_obs, big.mark = ",")))
  cat(sprintf("  Interpretation: on average, any-outage-event exposure moves\n"))
  cat(sprintf("  %s by %+.4f per 100k after controlling for tract + year FE.\n",
              OUTCOME_LABEL, headline$estimate))
} else {
  cat("  (spec s2_any_fe did not converge)\n")
}

cat("\n=== INTERACTION SIGNIFICANCE (BH-FDR joint) ===\n\n")
if (nrow(interaction_rows) > 0) {
  print(interaction_rows %>%
          select(spec, term, estimate, se, p_value, q_bh, sig_fdr_10) %>%
          arrange(q_bh))
} else {
  cat("  (no interaction terms fitted)\n")
}

cat("\n=== ALL SPECIFICATIONS ===\n\n")
print(results %>% arrange(spec, p_value))

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

output <- list(
  outcome_col   = OUTCOME_COL,
  outcome_label = OUTCOME_LABEL,
  n_obs_frame   = nrow(dat),
  results       = results,
  interaction_fdr = interaction_rows,
  ran_at        = Sys.time()
)
saveRDS(output, OUT)
cat(sprintf("\n✓ Wrote %s\n", basename(OUT)))
cat("\n=== FE-DiD complete ===\n")
