#!/usr/bin/env Rscript
# Storage-inclusive mitigation sweep — adds EIA-860 utility-scale battery
# storage (BESS) variables to the moderator inventory. Broadcasts
# county-year storage to all tracts in the county.

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(fixest); library(tidyr)
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

# Load panels
panel <- read_csv(file.path(DATA, "tract_panel_enhanced_with_homicide.csv"),
                  show_col_types=FALSE, progress=FALSE)
panel <- panel %>%
  mutate(county_fips = formatC(as.integer(county_fips), width=5, flag="0"),
         year = as.integer(year))

bess <- readRDS(file.path(DATA, "county_year_eia860_storage.rds"))
bess$year <- as.integer(bess$year)
bess$county_fips <- as.character(bess$county_fips)

# Broadcast: 2019 BESS → 2018 wave; 2022 BESS → 2022 wave; 2014 wave = 0
bess_broadcast <- bess %>%
  mutate(panel_year = case_when(
    year == 2019 ~ 2018L,
    year == 2022 ~ 2022L,
    TRUE ~ NA_integer_
  )) %>%
  filter(!is.na(panel_year)) %>%
  select(county_fips, panel_year, starts_with("bess_"))

merged <- panel %>%
  left_join(bess_broadcast, by = c("county_fips", "year" = "panel_year")) %>%
  mutate(across(starts_with("bess_"), ~ ifelse(is.na(.x), 0, .x)))

cat(sprintf("Panel: %s rows\n", format(nrow(merged), big.mark=",")))
cat(sprintf("Rows with any BESS: %s (%.1f%%)\n",
            format(sum(merged$bess_any_storage > 0), big.mark=","),
            100 * mean(merged$bess_any_storage > 0)))

STORAGE_MODS <- c("bess_plant_count", "bess_capacity_mw", "bess_capacity_mwh",
                  "bess_operating_mw", "bess_operating_mwh", "bess_any_storage")
COMPARE_MODS <- intersect(c("solar_penetration_pct", "grid_solar_pct",
                            "pv_capacity_mw_total", "dr_total", "ami_total"),
                          names(merged))
ALL_MODS <- unique(c(STORAGE_MODS, COMPARE_MODS))

dat <- merged %>%
  transmute(
    geoid, county_fips, year,
    y = wonder_homicide_rate,
    heat = as.numeric(extreme_heat_days),
    burden = as.numeric(avg_energy_burden.x),
    treated_uri = as.integer(treated_uri_final),
    treated_ida = as.integer(treated_ida),
    treated_harvey = as.integer(treated_harvey),
    treated_psps = as.integer(treated_psps),
    across(all_of(ALL_MODS), ~ as.numeric(.x), .names="{.col}")
  ) %>%
  filter(!is.na(y), is.finite(y)) %>%
  mutate(treated_any = pmax(treated_uri, treated_ida, treated_harvey, treated_psps, na.rm=TRUE))

qc <- quantile(dat$y, 0.999, na.rm=TRUE); dat$y <- pmin(dat$y, qc)
dat$heat_z <- zscore(med_imp(dat$heat))
dat$burden_z <- zscore(med_imp(dat$burden))
for (m in ALL_MODS) {
  vals <- med_imp(dat[[m]])
  dat[[paste0(m, "_z")]] <- zscore(vals)
}

cat(sprintf("\nAnalysis frame: %s rows\n", format(nrow(dat), big.mark=",")))

fit_one <- function(rhs, spec, mod) {
  form <- as.formula(sprintf("y ~ %s | geoid + year", rhs))
  m <- tryCatch(feols(form, data=dat, cluster=~geoid, warn=FALSE, notes=FALSE),
                error=function(e) NULL)
  if (is.null(m)) return(NULL)
  co <- coeftable(m)
  tibble(spec=spec, moderator=mod,
         term=rownames(co), estimate=co[,"Estimate"], se=co[,"Std. Error"],
         p_value=co[,"Pr(>|t|)"], n_obs=nobs(m))
}

results <- list()
for (mod in ALL_MODS) {
  mz <- paste0(mod, "_z")
  if (!is.finite(sd(dat[[mz]], na.rm=TRUE)) || sd(dat[[mz]], na.rm=TRUE) == 0) next
  # 2-way interaction
  rhs <- sprintf("treated_any + treated_any:%s + %s", mz, mz)
  results[[paste0("2w_", mod)]] <- fit_one(rhs, "2way", mod)
  # 3-way heat-break
  rhs3 <- sprintf(
    "treated_any + treated_any:heat_z + treated_any:%s + treated_any:heat_z:%s + heat_z + %s",
    mz, mz, mz)
  results[[paste0("hb_", mod)]] <- fit_one(rhs3, "heat_break", mod)
}
all_res <- bind_rows(results) %>% filter(!is.na(term))

int_2w <- all_res %>% filter(spec == "2way", grepl(":", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)
int_hb <- all_res %>% filter(spec == "heat_break", grepl("treated_any:heat_z:", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)

cat("\n=== STORAGE mitigation (2-way interactions) ===\n\n")
print(int_2w %>% filter(moderator %in% STORAGE_MODS) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

cat("\n=== SOLAR/DR/AMI comparison (2-way, for context) ===\n\n")
print(int_2w %>% filter(moderator %in% COMPARE_MODS) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

cat("\n=== STORAGE heat-pathway breakers (triple interaction) ===\n\n")
print(int_hb %>% filter(moderator %in% STORAGE_MODS) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

saveRDS(list(
  storage_moderators = STORAGE_MODS,
  comparison_moderators = COMPARE_MODS,
  interactions_2way = int_2w,
  interactions_heat_break = int_hb,
  ran_at = Sys.time()
), file.path(DATA, "wave_outage_homicide_mitigation_storage.rds"))
write_csv(int_2w,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_mitigation_storage_2way.csv"))
write_csv(int_hb,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_mitigation_storage_heat.csv"))
cat("\n✓ Wrote data/wave_outage_homicide_mitigation_storage.rds\n")
