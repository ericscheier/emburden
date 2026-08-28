#!/usr/bin/env Rscript
# Full-DER mitigation sweep: merges the missing DER columns from
# emburdender's tract-year DER panel (2009-2024) into the tract panel and
# reruns the outage x moderator FE-DiD. Adds residential storage (LBNL),
# net-metering storage, community solar, USPVDB utility PV, and dynamic-
# pricing enrollment (TOU/RTP/VPP/CPP), on top of the utility-scale BESS
# already merged in wave_outage_homicide_mitigation_with_storage.R.

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(fixest); library(tidyr); library(data.table)
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

# ---- Load panel + DER supplement ----
panel <- fread(file.path(DATA, "tract_panel_enhanced_with_homicide.csv"),
               showProgress=FALSE)
panel[, county_fips := formatC(as.integer(county_fips), width=5, flag="0")]
panel[, year := as.integer(year)]
panel[, geoid := as.character(geoid)]

der  <- as.data.table(readRDS("~/.cache/emburdender/der_panel_tract_2009_2024.rds"))
der[, geoid := as.character(geoid)]
der[, year  := as.integer(year)]

# LBNL storage — clip sentinel negatives to 0
der[, lbnl_storage_paired_kwh := pmax(lbnl_storage_paired_kwh, 0, na.rm=TRUE)]
der[is.na(lbnl_storage_paired_kwh), lbnl_storage_paired_kwh := 0]
der[is.na(lbnl_storage_paired_count), lbnl_storage_paired_count := 0L]

# Pull just the columns not already in panel
new_der_cols <- c(
  # residential storage
  "lbnl_storage_paired_count", "lbnl_storage_paired_kwh",
  # utility net-metering storage (distinct from EIA-860 utility BESS)
  "nem_number_of_systems", "nem_capacity_kw", "nem_storage_installations",
  "nem_storage_capacity_mw", "nem_virtual_capacity_mw", "nem_virtual_customers",
  # distributed generation w/ storage subcomponent
  "dg_system_count", "dg_capacity_kw", "dg_storage_capacity_kw", "dg_pv_capacity_kw",
  # community solar
  "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
  # utility-scale PV (USPVDB) — non-BESS but a solar peer
  "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
  # dynamic pricing (peak-shifting programs)
  "dp_has_tou", "dp_has_rtp", "dp_has_vpp", "dp_has_cpp", "dp_has_cpr",
  "dp_tou_res", "dp_rtp_res", "dp_vpp_res", "dp_cpp_res", "dp_cpr_res",
  # AMI penetration ratio
  "ami_penetration_pct"
)
new_der_cols <- intersect(new_der_cols, names(der))
der_slim <- der[, c("geoid", "year", new_der_cols), with=FALSE]

# Rename to avoid clashes with panel cols (esp. those we already have)
setnames(der_slim,
         old = c("lbnl_storage_paired_count", "lbnl_storage_paired_kwh"),
         new = c("res_storage_count", "res_storage_kwh"))

# Merge on (geoid, year)
merged <- der_slim[panel, on = c("geoid", "year")]

# Also merge utility BESS (from prior wave)
bess <- as.data.table(readRDS(file.path(DATA, "county_year_eia860_storage.rds")))
bess[, year := as.integer(year)]
bess[, county_fips := as.character(county_fips)]
bess_broadcast <- bess[, .(county_fips, year, bess_plant_count, bess_capacity_mw,
                           bess_capacity_mwh, bess_operating_mw, bess_operating_mwh,
                           bess_any_storage)]
bess_broadcast[, panel_year := fifelse(year == 2019, 2018L,
                                fifelse(year == 2022, 2022L, NA_integer_))]
bess_broadcast <- bess_broadcast[!is.na(panel_year)][, year := NULL]
setnames(bess_broadcast, "panel_year", "year")
merged <- bess_broadcast[merged, on = c("county_fips", "year")]

# Zero-fill: residential storage / utility BESS = "0 = none, not missing"
zero_fill_cols <- c("res_storage_count", "res_storage_kwh",
                    "nem_storage_installations", "nem_storage_capacity_mw",
                    "dg_storage_capacity_kw",
                    "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
                    "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
                    grep("^dp_", names(merged), value=TRUE),
                    grep("^bess_", names(merged), value=TRUE))
zero_fill_cols <- intersect(zero_fill_cols, names(merged))
for (cc in zero_fill_cols) set(merged, which(is.na(merged[[cc]])), cc, 0)

# ---- Analysis frame ----
STORAGE_MODS <- c(
  # RESIDENTIAL STORAGE (new)
  "res_storage_count", "res_storage_kwh",
  # UTILITY BESS (from prior wave)
  "bess_plant_count", "bess_capacity_mw", "bess_capacity_mwh",
  "bess_operating_mw", "bess_operating_mwh", "bess_any_storage",
  # NEM STORAGE / VIRTUAL NM
  "nem_storage_installations", "nem_storage_capacity_mw",
  "nem_virtual_capacity_mw", "nem_virtual_customers",
  # DISTRIBUTED GENERATION STORAGE
  "dg_storage_capacity_kw"
)
OTHER_DER_MODS <- c(
  "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
  "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
  "dp_tou_res", "dp_rtp_res", "dp_vpp_res", "dp_cpp_res", "dp_cpr_res",
  "ami_penetration_pct"
)
COMPARE_MODS <- intersect(c("solar_penetration_pct", "grid_solar_pct",
                            "pv_capacity_mw_total", "dr_total", "ami_total",
                            "der_count", "der_diversity"),
                          names(merged))
ALL_MODS <- unique(c(STORAGE_MODS, OTHER_DER_MODS, COMPARE_MODS))
ALL_MODS <- intersect(ALL_MODS, names(merged))

dat <- merged[, c("geoid","county_fips","year","wonder_homicide_rate",
                  "extreme_heat_days","avg_energy_burden.x",
                  "treated_uri_final","treated_ida","treated_harvey","treated_psps",
                  ALL_MODS), with=FALSE]
setnames(dat,
         c("wonder_homicide_rate","extreme_heat_days","avg_energy_burden.x",
           "treated_uri_final"),
         c("y","heat","burden","treated_uri"))
dat <- dat[!is.na(y) & is.finite(y)]
dat[, treated_any := pmax(as.integer(treated_uri), as.integer(treated_ida),
                          as.integer(treated_harvey), as.integer(treated_psps),
                          na.rm=TRUE)]

qc <- quantile(dat$y, 0.999, na.rm=TRUE); dat[, y := pmin(y, qc)]
dat[, heat_z   := zscore(med_imp(as.numeric(heat)))]
dat[, burden_z := zscore(med_imp(as.numeric(burden)))]
for (m in ALL_MODS) {
  vals <- med_imp(as.numeric(dat[[m]]))
  set(dat, j = paste0(m, "_z"), value = zscore(vals))
}

cat(sprintf("Analysis frame: %s rows | %d moderators\n",
            format(nrow(dat), big.mark=","), length(ALL_MODS)))
cat(sprintf("  Residential storage tract-years with any BESS: %s (%.2f%%)\n",
            format(sum(dat$res_storage_count > 0, na.rm=TRUE), big.mark=","),
            100 * mean(dat$res_storage_count > 0, na.rm=TRUE)))
cat(sprintf("  Utility BESS tract-years: %s (%.2f%%)\n",
            format(sum(dat$bess_any_storage > 0, na.rm=TRUE), big.mark=","),
            100 * mean(dat$bess_any_storage > 0, na.rm=TRUE)))

# ---- Fitting ----
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
  # 2-way
  rhs <- sprintf("treated_any + treated_any:%s + %s", mz, mz)
  results[[paste0("2w_", mod)]] <- fit_one(rhs, "2way", mod)
  # 3-way heat-break
  rhs3 <- sprintf(
    "treated_any + treated_any:heat_z + treated_any:%s + treated_any:heat_z:%s + heat_z + %s",
    mz, mz, mz)
  results[[paste0("hb_", mod)]] <- fit_one(rhs3, "heat_break", mod)
  # 3-way burden-break
  rhs4 <- sprintf(
    "treated_any + treated_any:burden_z + treated_any:%s + treated_any:burden_z:%s + burden_z + %s",
    mz, mz, mz)
  results[[paste0("bb_", mod)]] <- fit_one(rhs4, "burden_break", mod)
}
all_res <- bind_rows(results) %>% filter(!is.na(term))

int_2w <- all_res %>% filter(spec == "2way", grepl(":", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)
int_hb <- all_res %>% filter(spec == "heat_break", grepl("treated_any:heat_z:", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)
int_bb <- all_res %>% filter(spec == "burden_break", grepl("treated_any:burden_z:", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)

cat("\n=== RESIDENTIAL STORAGE mitigation (2-way) ===\n\n")
print(int_2w %>% filter(moderator %in% c("res_storage_count","res_storage_kwh",
                                          "nem_storage_installations","nem_storage_capacity_mw",
                                          "dg_storage_capacity_kw")) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

cat("\n=== UTILITY BESS mitigation (2-way, for context) ===\n\n")
print(int_2w %>% filter(moderator %in% c("bess_plant_count","bess_capacity_mw",
                                          "bess_operating_mw","bess_operating_mwh")) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

cat("\n=== OTHER NEW DERs (community solar, USPVDB, dynamic pricing) ===\n\n")
print(int_2w %>% filter(moderator %in% OTHER_DER_MODS) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

cat("\n=== ALL storage — HEAT-PATHWAY BREAKERS (triple interaction) ===\n\n")
print(int_hb %>% filter(moderator %in% STORAGE_MODS) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

cat("\n=== ALL storage — BURDEN-PATHWAY BREAKERS (triple interaction) ===\n\n")
print(int_bb %>% filter(moderator %in% STORAGE_MODS) %>%
      arrange(estimate) %>%
      select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))

saveRDS(list(
  storage_moderators = STORAGE_MODS,
  other_der_moderators = OTHER_DER_MODS,
  comparison_moderators = COMPARE_MODS,
  interactions_2way = int_2w,
  interactions_heat_break = int_hb,
  interactions_burden_break = int_bb,
  n_moderators_fit = length(unique(all_res$moderator)),
  ran_at = Sys.time()
), file.path(DATA, "wave_outage_homicide_mitigation_full_ders.rds"))
write_csv(int_2w,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_mitigation_full_ders_2way.csv"))
write_csv(int_hb,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_mitigation_full_ders_heat.csv"))
write_csv(int_bb,
          file.path(REPO, "manuscript/tables/SI_outage_homicide_mitigation_full_ders_burden.csv"))
cat("\nWrote data/wave_outage_homicide_mitigation_full_ders.rds and 3 SI CSVs.\n")
