#!/usr/bin/env Rscript
# Air-quality mediation of shock -> asthma pathway (CA-only for smoke,
# national for PM2.5 + ozone).
#
# Tests whether the shock->asthma effect flows through elevated PM2.5,
# ozone, or wildfire smoke.

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(dplyr); library(readr)
})
REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

p <- fread(file.path(DATA, "tract_panel_enhanced_with_asthma_ders.csv"),
           showProgress = FALSE)
p[, treated_any := pmax(as.integer(treated_uri_final), as.integer(treated_ida),
                        as.integer(treated_harvey), as.integer(treated_psps),
                        na.rm = TRUE)]

zscore <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  m <- median(x[is.finite(x)], na.rm = TRUE); x[!is.finite(x)] <- m
  s <- sd(x, na.rm = TRUE); if (!is.finite(s) || s == 0) return(rep(NA_real_, length(x)))
  (x - mean(x, na.rm = TRUE)) / s
}

p[, pm25_z    := zscore(pm25_annual_ugm3)]
p[, ozone_z   := zscore(ozone_days_count)]
p[, pm25days_z:= zscore(pm25_days_pct)]

results <- list()

fit_and_stash <- function(form, label) {
  fit <- tryCatch(feols(as.formula(form), data = p, cluster = ~geoid,
                        warn = FALSE, notes = FALSE), error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  co <- coeftable(fit)
  data.frame(spec = label, term = rownames(co),
             estimate = co[, "Estimate"], se = co[, "Std. Error"],
             p_value = co[, "Pr(>|t|)"], n = nobs(fit),
             stringsAsFactors = FALSE)
}

# ---- PM2.5 mediation across outcomes ----
for (y in c("asthma_hosp_rate", "asthma_ed_rate", "places_asthma_prev")) {
  for (shock in c("treated_any", "treated_heat_wave", "treated_uri_final",
                  "treated_ida", "treated_psps")) {
    results[[paste0("pm25_", y, "_", shock)]] <- fit_and_stash(
      sprintf("%s ~ %s * pm25_z | geoid + year", y, shock),
      sprintf("pm25:%s:%s", y, shock))
  }
}

# ---- Ozone mediation ----
for (y in c("asthma_hosp_rate", "asthma_ed_rate")) {
  for (shock in c("treated_any", "treated_heat_wave")) {
    results[[paste0("ozone_", y, "_", shock)]] <- fit_and_stash(
      sprintf("%s ~ %s * ozone_z | geoid + year", y, shock),
      sprintf("ozone:%s:%s", y, shock))
  }
}

all_res <- bind_rows(results) %>%
  filter(!is.na(term)) %>%
  mutate(int_term = grepl(":", term))

# BH-FDR on interaction terms only
int_ix <- which(all_res$int_term)
all_res$q_bh <- NA_real_
all_res$q_bh[int_ix] <- p.adjust(all_res$p_value[int_ix], method = "BH")

saveRDS(list(results = all_res, ran_at = Sys.time()),
        file.path(DATA, "wave_asthma_air_quality_mediation.rds"))
write_csv(all_res, file.path(REPO, "manuscript/tables/SI_asthma_aq_mediation.csv"))

cat(sprintf("\n=== TOP 10 FDR-SIGNIFICANT MEDIATION INTERACTIONS ===\n"))
top <- all_res %>% filter(int_term, !is.na(q_bh), q_bh < 0.10) %>%
  arrange(q_bh) %>% head(10) %>%
  select(spec, term, estimate, se, p_value, q_bh, n)
print(top)

cat(sprintf("\nWrote wave_asthma_air_quality_mediation.rds and SI CSV.\n"))
