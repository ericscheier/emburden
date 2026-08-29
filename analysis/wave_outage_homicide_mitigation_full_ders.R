#!/usr/bin/env Rscript
# Full-DER mitigation sweep — consumes the formalized pre-merged panel.
#
# Reads: data/tract_panel_enhanced_with_ders.csv
#        (from analysis/merge_ders_into_tract_panel.R)
#
# Formerly did its own inline merges (moved to the merge script). This
# script now only does the FE-DiD sweep and reporting.

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

# ---- Load formalized panel ----
enriched_path <- file.path(DATA, "tract_panel_enhanced_with_ders.csv")
if (!file.exists(enriched_path)) {
  stop("Enriched panel missing: ", enriched_path,
       "\nRun: Rscript analysis/merge_ders_into_tract_panel.R")
}
merged <- fread(enriched_path, showProgress = FALSE)

STORAGE_MODS <- c(
  # RESIDENTIAL STORAGE
  "res_storage_count", "res_storage_kwh",
  # UTILITY BESS
  "bess_plant_count", "bess_capacity_mw", "bess_capacity_mwh",
  "bess_operating_mw", "bess_operating_mwh", "bess_any_storage",
  # NEM STORAGE / VIRTUAL NM
  "nem_storage_installations", "nem_storage_capacity_mw",
  "nem_virtual_capacity_mw", "nem_virtual_customers",
  # DISTRIBUTED GENERATION STORAGE
  "dg_storage_capacity_kw",
  # OWNERSHIP-TYPED BESS (new — from Wave B1)
  "bess_iou_pct", "bess_merchant_pct",
  "bess_mw_IOU", "bess_mw_IPP-non-CHP", "bess_mw_muni",
  "bess_mw_coop", "bess_mw_unknown"
)
OTHER_DER_MODS <- c(
  "cs_total_projects", "cs_total_capacity_mw", "cs_lmi_projects",
  "uspvdb_cumulative_plants", "uspvdb_cumulative_mw_dc",
  "dp_tou_res", "dp_rtp_res", "dp_vpp_res", "dp_cpp_res", "dp_cpr_res",
  "ami_penetration_pct",
  # CA SGIP residential storage (P2, CA-only variation)
  "sgip_residential_count", "sgip_residential_kwh",
  "sgip_equity_count", "sgip_equity_kwh",
  # CDC HHI (P3, national static — heat vulnerability moderators)
  "hhi_overall_rank", "hhi_heat_burden_rank", "hhi_sensitivity_rank",
  "hhi_nbe_rank", "hhi_sociodem_rank"
)
COMPARE_MODS <- intersect(c("solar_penetration_pct", "grid_solar_pct",
                            "pv_capacity_mw_total", "dr_total", "ami_total",
                            "der_count", "der_diversity"),
                          names(merged))
ALL_MODS <- unique(c(STORAGE_MODS, OTHER_DER_MODS, COMPARE_MODS))
ALL_MODS <- intersect(ALL_MODS, names(merged))

# Backtick-safe column selection for names with hyphens (bess_mw_IPP-non-CHP)
safe_col <- function(name) if (grepl("[^A-Za-z0-9_.]", name)) paste0("`", name, "`") else name

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
  cat(sprintf("[%s] fitting...\n", mod))
  mz  <- safe_col(paste0(mod, "_z"))
  raw <- dat[[paste0(mod, "_z")]]
  if (!is.finite(sd(raw, na.rm=TRUE)) || sd(raw, na.rm=TRUE) == 0) {
    cat("  skip (SD 0)\n"); next
  }
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
  # Aggressive GC + free memory between mods (fixest holds heavy fit objects)
  gc(verbose = FALSE)
}
all_res <- bind_rows(results) %>% filter(!is.na(term))

int_2w <- all_res %>% filter(spec == "2way", grepl(":", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)
int_hb <- all_res %>% filter(spec == "heat_break", grepl("treated_any:heat_z:", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)
int_bb <- all_res %>% filter(spec == "burden_break", grepl("treated_any:burden_z:", term)) %>%
  mutate(q_bh = p.adjust(p_value, method = "BH"), sig_fdr_10 = q_bh < 0.10)

# ---- Print groups ----
print_group <- function(int_df, label, mods) {
  cat(sprintf("\n=== %s ===\n\n", label))
  print(int_df %>% filter(moderator %in% mods) %>%
        arrange(estimate) %>%
        select(moderator, estimate, se, p_value, q_bh, sig_fdr_10))
}
print_group(int_2w, "RESIDENTIAL STORAGE mitigation (2-way)",
            c("res_storage_count","res_storage_kwh",
              "nem_storage_installations","nem_storage_capacity_mw",
              "dg_storage_capacity_kw"))
print_group(int_2w, "UTILITY BESS mitigation (2-way)",
            c("bess_plant_count","bess_capacity_mw","bess_operating_mw",
              "bess_operating_mwh"))
print_group(int_2w, "BESS BY OWNER (2-way — new from Wave B1)",
            c("bess_iou_pct","bess_merchant_pct",
              "bess_mw_IOU","bess_mw_IPP-non-CHP","bess_mw_muni",
              "bess_mw_coop","bess_mw_unknown"))
print_group(int_2w, "OTHER NEW DERs",  OTHER_DER_MODS)
print_group(int_2w, "CA SGIP residential storage (2-way, CA-only variation)",
            c("sgip_residential_count","sgip_residential_kwh",
              "sgip_equity_count","sgip_equity_kwh"))
print_group(int_bb, "CA SGIP — burden-pathway breakers",
            c("sgip_residential_count","sgip_residential_kwh",
              "sgip_equity_count","sgip_equity_kwh"))
print_group(int_2w, "CDC HHI heat-vulnerability (2-way)",
            c("hhi_overall_rank","hhi_heat_burden_rank","hhi_sensitivity_rank",
              "hhi_nbe_rank","hhi_sociodem_rank"))
print_group(int_hb, "CDC HHI × heat interaction (does high-HHI amplify?)",
            c("hhi_overall_rank","hhi_heat_burden_rank","hhi_sensitivity_rank",
              "hhi_nbe_rank","hhi_sociodem_rank"))
print_group(int_bb, "CDC HHI × burden interaction",
            c("hhi_overall_rank","hhi_heat_burden_rank","hhi_sensitivity_rank",
              "hhi_nbe_rank","hhi_sociodem_rank"))
print_group(int_hb, "ALL storage — HEAT-PATHWAY BREAKERS", STORAGE_MODS)
print_group(int_bb, "ALL storage — BURDEN-PATHWAY BREAKERS", STORAGE_MODS)

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
