#!/usr/bin/env Rscript
# ============================================================================
# run_intersection_sweep.R  —  Outcome-agnostic driver
# ----------------------------------------------------------------------------
# Reads a config list of outcomes × shocks × moderators × specs, loads the
# enriched tract panel, runs `emburdenstats::sweep_intersections()`, and
# writes a standardized long-form result RDS + polar-matrix-ready
# summarized RDS.
#
# Callers:
#   Rscript analysis/run_intersection_sweep.R <config_R_file>
#
# Config file structure (an R file that defines a `CONFIG` list):
#   CONFIG <- list(
#     slug        = "asthma",
#     panel_path  = "data/tract_panel_enhanced_with_asthma_ders.csv",
#     outcomes    = c("asthma_hosp_rate", "asthma_ed_rate", ...),
#     shocks      = c("treated_any", "treated_heat_wave", ...),
#     moderators  = c("bess_operating_mwh", "sgip_residential_kwh", ...),
#     specs       = c("2way", "heat_break", "burden_break"),
#     fe_vars     = c("geoid", "year"),
#     cluster_var = "geoid",
#     heat_col    = "extreme_heat_days",
#     burden_col  = "avg_energy_burden.x",
#     min_obs     = 100L,
#     out_dir     = "data"
#   )
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(dplyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenstats", quiet = TRUE)
})
`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
  cat("Usage: Rscript analysis/run_intersection_sweep.R <config_R_file>\n")
  cat("Config file must define a CONFIG list — see script header.\n")
  quit(status = 1L)
}

config_file <- args[[1L]]
if (!file.exists(config_file)) stop("Config file not found: ", config_file)
source(config_file, local = TRUE)
if (!exists("CONFIG")) stop("Config file did not define a `CONFIG` list.")

REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)

# ---- Load enriched panel ------------------------------------------------
message(sprintf("[intersection-sweep:%s] loading panel: %s",
                CONFIG$slug, CONFIG$panel_path))
panel <- fread(CONFIG$panel_path, showProgress = FALSE)
message(sprintf("  panel: %s rows × %d cols", format(nrow(panel), big.mark=","),
                ncol(panel)))

# Build treated_any + treated_uri (aliases the panel doesn't ship natively)
if (!"treated_any" %in% names(panel)) {
  panel[, treated_any := pmax(
    as.integer(treated_uri_final), as.integer(treated_ida),
    as.integer(treated_harvey),    as.integer(treated_psps),
    na.rm = TRUE)]
}
if (!"treated_uri" %in% names(panel) && "treated_uri_final" %in% names(panel)) {
  panel[, treated_uri := as.integer(treated_uri_final)]
}

# Coerce keys expected by sweep_intersections()
if ("county_fips" %in% names(panel))
  panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
if ("year" %in% names(panel))     panel[, year := as.integer(year)]
if ("geoid" %in% names(panel))    panel[, geoid := as.character(geoid)]

# ---- Column presence audit ---------------------------------------------
required <- unique(c(CONFIG$outcomes, CONFIG$shocks, CONFIG$moderators,
                     CONFIG$fe_vars, CONFIG$cluster_var,
                     CONFIG$heat_col, CONFIG$burden_col))
missing <- setdiff(required, names(panel))
if (length(missing) > 0L) {
  message(sprintf("[intersection-sweep:%s] WARNING — panel missing %d columns:",
                  CONFIG$slug, length(missing)))
  message("  ", paste(missing, collapse = ", "))
  # Drop missing outcomes/shocks/moderators from the sweep; keep the run alive
  CONFIG$outcomes   <- intersect(CONFIG$outcomes,   names(panel))
  CONFIG$shocks     <- intersect(CONFIG$shocks,     names(panel))
  CONFIG$moderators <- intersect(CONFIG$moderators, names(panel))
}

message(sprintf("[intersection-sweep:%s] running: %d outcomes × %d shocks × %d moderators × %d specs = %d cells",
                CONFIG$slug,
                length(CONFIG$outcomes), length(CONFIG$shocks),
                length(CONFIG$moderators), length(CONFIG$specs),
                length(CONFIG$outcomes) * length(CONFIG$shocks) *
                length(CONFIG$moderators) * length(CONFIG$specs)))

# ---- Sweep --------------------------------------------------------------
res <- sweep_intersections(
  panel       = as.data.frame(panel),
  outcomes    = CONFIG$outcomes,
  shocks      = CONFIG$shocks,
  moderators  = CONFIG$moderators,
  specs       = CONFIG$specs,
  fe_vars     = CONFIG$fe_vars,
  cluster_var = CONFIG$cluster_var,
  heat_col    = CONFIG$heat_col,
  burden_col  = CONFIG$burden_col,
  min_obs     = CONFIG$min_obs %||% 100L,
  verbose     = TRUE
)

# ---- Write ---------------------------------------------------------------
out_dir <- CONFIG$out_dir %||% "data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
res_path  <- file.path(out_dir, sprintf("intersection_sweep_%s.rds", CONFIG$slug))
summ_path <- file.path(out_dir, sprintf("intersection_matrix_%s.rds", CONFIG$slug))
saveRDS(list(config = CONFIG, results = res, ran_at = Sys.time()), res_path)

summ <- summarize_intersection_matrix(res)
saveRDS(summ, summ_path)

message(sprintf("\n[intersection-sweep:%s] wrote %s  (%d rows)",
                CONFIG$slug, res_path, nrow(res)))
message(sprintf("[intersection-sweep:%s] wrote %s  (%d matrix cells)",
                CONFIG$slug, summ_path, nrow(summ)))

# ---- Top-line summary ---------------------------------------------------
cat(sprintf("\n=== TOP 20 FDR-SIGNIFICANT INTERACTION TERMS (across all specs) ===\n"))
top20 <- res %>%
  filter(grepl(":", term), !is.na(q_bh), sig_fdr_10) %>%
  arrange(q_bh) %>%
  head(20) %>%
  select(outcome, shock, moderator, spec, estimate, se, q_bh)
print(top20)
