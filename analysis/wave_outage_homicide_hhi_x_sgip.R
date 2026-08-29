#!/usr/bin/env Rscript
# ============================================================================
# wave_outage_homicide_hhi_x_sgip.R
# ----------------------------------------------------------------------------
# Wave X — HHI x SGIP triple/4-way interaction on the CA subset.
#
# Hypothesis (pre-registered in analysis/PRE_REGISTRATION.md):
#   Under heat conditions, adding SGIP residential storage protects the
#   outage-homicide effect MOST in high-HHI-heat-burden counties. That
#   is, the four-way interaction
#     treated_any:heat_z:hhi_heat_burden_rank_z:sgip_residential_kwh_z
#   is negative (super-linear protection).
#
# Rationale: Wave L found SGIP burden-pathway beta = -2.83/100k per SD
# (10x LBNL's -0.29); Wave L2 found HHI heat-pathway triple beta = -4.51
# per SD (protective interaction). If both signals reflect the same
# underlying "intervention landed on the right population" story, the
# four-way should be additionally negative when both moderators are high.
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(dplyr); library(readr)
})
REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

zscore <- function(x) {
  m <- mean(x, na.rm=TRUE); s <- sd(x, na.rm=TRUE)
  if (!is.finite(s) || s==0) return(rep(NA_real_, length(x)))
  (x-m)/s
}
med_imp <- function(x) ifelse(is.na(x) | !is.finite(x),
                              median(x[is.finite(x)], na.rm=TRUE), x)

# ---- Load formalized panel; filter to CA -------------------------------
panel <- fread(file.path(DATA, "tract_panel_enhanced_with_ders.csv"),
               showProgress = FALSE)
cat(sprintf("Panel: %s rows total\n", format(nrow(panel), big.mark=",")))

# The CSV coerces state_fips to "6" (leading zero stripped). Use state_abbr.
ca <- panel[state_abbr == "CA"]
cat(sprintf("CA subset: %s rows across %d unique tracts, years %s\n",
            format(nrow(ca), big.mark=","),
            uniqueN(ca$geoid),
            paste(sort(unique(ca$year)), collapse=", ")))

# ---- Feature engineering (CA-only z-scores) ----------------------------
ca[, treated_any := pmax(as.integer(treated_uri_final),
                          as.integer(treated_ida),
                          as.integer(treated_harvey),
                          as.integer(treated_psps), na.rm=TRUE)]
qc <- quantile(ca$wonder_homicide_rate, 0.999, na.rm=TRUE)
ca[, y := pmin(wonder_homicide_rate, qc)]
ca[, heat_z    := zscore(med_imp(as.numeric(extreme_heat_days)))]
ca[, hhi_hb_z  := zscore(med_imp(as.numeric(hhi_heat_burden_rank)))]
ca[, hhi_sd_z  := zscore(med_imp(as.numeric(hhi_sociodem_rank)))]
ca[, sgip_res_z    := zscore(med_imp(as.numeric(sgip_residential_kwh)))]
ca[, sgip_equity_z := zscore(med_imp(as.numeric(sgip_equity_kwh)))]

ca <- ca[!is.na(y) & is.finite(y)]
cat(sprintf("Analysis frame (CA, non-NA outcome): %s rows\n",
            format(nrow(ca), big.mark=",")))
cat(sprintf("SGIP residential kwh > 0 in %s tract-years (%.1f%%)\n",
            format(sum(ca$sgip_residential_kwh > 0, na.rm=TRUE), big.mark=","),
            100 * mean(ca$sgip_residential_kwh > 0, na.rm=TRUE)))

# ---- Fitting -----------------------------------------------------------
fit_and_tidy <- function(rhs, spec, label) {
  form <- as.formula(sprintf("y ~ %s | geoid + year", rhs))
  m <- tryCatch(feols(form, data=ca, cluster=~geoid, warn=FALSE, notes=FALSE),
                error=function(e) { cat("[",spec,"] error:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) return(NULL)
  co <- coeftable(m)
  tibble(spec = spec, label = label,
         term = rownames(co),
         estimate = co[,"Estimate"],
         se       = co[,"Std. Error"],
         p_value  = co[,"Pr(>|t|)"],
         n_obs    = nobs(m))
}

results <- list()

cat("\n=== 3-way: SGIP residential x HHI heat-burden x outage ===\n")
r1 <- fit_and_tidy(
  "treated_any * hhi_hb_z * sgip_res_z",
  "3way_HHI_SGIP_outage",
  "SGIP residential kWh x HHI heat-burden x outage (CA)")
results[["3w_hhi_sgip"]] <- r1
print(r1 %>% select(term, estimate, se, p_value))

cat("\n=== 3-way: SGIP equity x HHI sociodem x outage ===\n")
r2 <- fit_and_tidy(
  "treated_any * hhi_sd_z * sgip_equity_z",
  "3way_HHIsd_SGIPeq_outage",
  "SGIP equity kWh x HHI sociodem x outage (CA)")
results[["3w_hhisd_sgipeq"]] <- r2
print(r2 %>% select(term, estimate, se, p_value))

cat("\n=== 4-way: SGIP res x HHI heat-burden x outage x heat ===\n")
r3 <- fit_and_tidy(
  "treated_any * heat_z * hhi_hb_z * sgip_res_z",
  "4way_full",
  "SGIP residential kWh x HHI heat-burden x heat x outage (CA)")
results[["4w_full"]] <- r3
print(r3 %>% select(term, estimate, se, p_value))

# ---- Post-fit summary --------------------------------------------------
all_res <- bind_rows(results)

# FDR across interaction terms of the 4-way (the pre-registered spec)
target_term <- "treated_any:heat_z:hhi_hb_z:sgip_res_z"
hero <- all_res %>% filter(spec == "4way_full", term == target_term)

int_terms <- all_res %>% filter(spec == "4way_full", grepl(":", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"))

cat(sprintf("\n=== HERO 4-way interaction (pre-registered) ===\n"))
cat(sprintf("  term:     %s\n", target_term))
if (nrow(hero) == 0) {
  cat("  MISSING — 4-way likely collinear-dropped by fixest\n")
} else {
  cat(sprintf("  estimate: %.3f/100k per SD\n", hero$estimate))
  cat(sprintf("  se:       %.3f\n", hero$se))
  cat(sprintf("  p_value:  %.3e\n", hero$p_value))
  q <- int_terms$q_bh[int_terms$term == target_term]
  cat(sprintf("  q (BH):   %.3e\n", q))
  direction <- if (hero$estimate < 0 && hero$p_value < 0.10)
    "SUPER-LINEAR PROTECTION confirmed"
  else if (hero$estimate > 0 && hero$p_value < 0.10)
    "amplifier (unexpected — inverted hypothesis)"
  else "null (neither super-linear protection nor amplification)"
  cat(sprintf("  interpretation: %s\n", direction))
}

# ---- Save --------------------------------------------------------------
saveRDS(list(
  interactions = all_res,
  hero_term    = target_term,
  hero_result  = hero,
  int_terms_fdr = int_terms,
  ran_at       = Sys.time()
), file.path(DATA, "wave_outage_homicide_hhi_x_sgip.rds"))
write_csv(all_res,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_hhi_x_sgip.csv"))
cat("\nWrote data/wave_outage_homicide_hhi_x_sgip.rds and 1 SI CSV.\n")
