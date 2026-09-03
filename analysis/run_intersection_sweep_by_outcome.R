#!/usr/bin/env Rscript
# Per-outcome subprocess sweep — avoids memory corruption on wide panels
# by running each outcome as a fresh R process, saving intermediate RDS,
# then merging in the driver.

suppressPackageStartupMessages({
  library(data.table); library(dplyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenstats", quiet = TRUE)
})
`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("Usage: <config_R_file> [outcome]")

config_file <- args[[1L]]
source(config_file, local = FALSE)   # populates global CONFIG
REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)
out_dir <- CONFIG$out_dir %||% "data"

# ------------------------------------------------------------------
# SUB-MODE: run one outcome and save intermediate
# ------------------------------------------------------------------
if (length(args) >= 2L) {
  outcome <- args[[2L]]
  message(sprintf("[sub] outcome=%s", outcome))

  panel <- fread(CONFIG$panel_path, showProgress = FALSE)
  if ("county_fips" %in% names(panel))
    panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
  panel[, year := as.integer(year)]
  panel[, geoid := as.character(geoid)]

  # Build treated_any + treated_uri aliases if missing
  if (!"treated_any" %in% names(panel)) {
    panel[, treated_any := pmax(as.integer(treated_uri_final), as.integer(treated_ida),
                                 as.integer(treated_harvey), as.integer(treated_psps),
                                 na.rm = TRUE)]
  }
  if (!"treated_uri" %in% names(panel) && "treated_uri_final" %in% names(panel)) {
    panel[, treated_uri := as.integer(treated_uri_final)]
  }

  # Drop missing cells from config
  outcomes_here   <- intersect(outcome, names(panel))
  shocks_here     <- intersect(CONFIG$shocks, names(panel))
  moderators_here <- intersect(CONFIG$moderators, names(panel))
  if (length(outcomes_here) == 0L) {
    message(sprintf("[sub] outcome %s not in panel, skipping", outcome))
    quit(save = "no", status = 0L)
  }

  res <- sweep_intersections(
    panel       = as.data.frame(panel),
    outcomes    = outcomes_here,
    shocks      = shocks_here,
    moderators  = moderators_here,
    specs       = CONFIG$specs,
    fe_vars     = CONFIG$fe_vars,
    cluster_var = CONFIG$cluster_var,
    heat_col    = CONFIG$heat_col,
    burden_col  = CONFIG$burden_col,
    min_obs     = CONFIG$min_obs %||% 100L,
    verbose     = TRUE
  )
  slug <- sprintf("%s_%s", CONFIG$slug, gsub("[^a-z0-9]+", "_", tolower(outcome)))
  saveRDS(list(config = CONFIG, results = res, ran_at = Sys.time()),
          file.path(out_dir, sprintf("intersection_sweep_%s.rds", slug)))
  saveRDS(summarize_intersection_matrix(res),
          file.path(out_dir, sprintf("intersection_matrix_%s.rds", slug)))
  message(sprintf("[sub] wrote intersection_sweep_%s.rds  (%d rows)",
                  slug, nrow(res)))
  quit(save = "no", status = 0L)
}

# ------------------------------------------------------------------
# DRIVER-MODE: spawn one subprocess per outcome, then merge
# ------------------------------------------------------------------
message(sprintf("[driver] spawning %d subprocesses...", length(CONFIG$outcomes)))
for (out in CONFIG$outcomes) {
  cmd <- sprintf("Rscript %s %s %s",
                  shQuote(file.path("analysis", "run_intersection_sweep_by_outcome.R")),
                  shQuote(config_file), shQuote(out))
  message("[driver] ", cmd)
  status <- system(cmd)
  if (status != 0L)
    warning(sprintf("[driver] %s exited with status %d", out, status))
}

# Merge intermediates
message("[driver] merging intermediates...")
results_all <- list(); matrix_all <- list()
for (out in CONFIG$outcomes) {
  slug <- sprintf("%s_%s", CONFIG$slug, gsub("[^a-z0-9]+", "_", tolower(out)))
  r_path <- file.path(out_dir, sprintf("intersection_sweep_%s.rds", slug))
  m_path <- file.path(out_dir, sprintf("intersection_matrix_%s.rds", slug))
  if (file.exists(r_path)) results_all[[out]] <- readRDS(r_path)$results
  if (file.exists(m_path)) matrix_all[[out]]  <- readRDS(m_path)
}
results_bound <- do.call(rbind, results_all)
matrix_bound  <- do.call(rbind, matrix_all)

# Re-apply BH-FDR globally
if (nrow(results_bound) > 0) {
  results_bound$q_bh       <- NA_real_
  results_bound$sig_fdr_10 <- NA
  for (sp in unique(results_bound$spec)) {
    ix <- results_bound$spec == sp & grepl(":", results_bound$term) &
          !is.na(results_bound$p_value)
    if (any(ix)) {
      results_bound$q_bh[ix]       <- stats::p.adjust(results_bound$p_value[ix], method = "BH")
      results_bound$sig_fdr_10[ix] <- results_bound$q_bh[ix] < 0.10
    }
  }
}

saveRDS(list(config = CONFIG, results = results_bound, ran_at = Sys.time()),
        file.path(out_dir, sprintf("intersection_sweep_%s.rds", CONFIG$slug)))
saveRDS(matrix_bound, file.path(out_dir, sprintf("intersection_matrix_%s.rds", CONFIG$slug)))

message(sprintf("[driver] wrote intersection_sweep_%s.rds  (%d rows)",
                CONFIG$slug, nrow(results_bound)))
message(sprintf("[driver] wrote intersection_matrix_%s.rds  (%d cells)",
                CONFIG$slug, nrow(matrix_bound)))

# Clean up intermediates
for (out in CONFIG$outcomes) {
  slug <- sprintf("%s_%s", CONFIG$slug, gsub("[^a-z0-9]+", "_", tolower(out)))
  file.remove(file.path(out_dir, sprintf("intersection_sweep_%s.rds", slug)))
  file.remove(file.path(out_dir, sprintf("intersection_matrix_%s.rds", slug)))
}
