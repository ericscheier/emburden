#!/usr/bin/env Rscript
# =====================================================================
# fig_asthma_polar_matrix.R  →  manuscript/figures/asthma_fig1.{pdf,png}
# ---------------------------------------------------------------------
# 4x3 polar-matrix: rows = shocks (treated_any, treated_heat_wave,
# treated_ida, treated_uri); columns = 3 top storage moderators
# (bess_operating_mwh, res_storage_kwh, sgip_residential_kwh).
# Each cell shows the 4 asthma outcomes as radial axes with 3 specs
# (2way, heat_break, burden_break) as overlaid polygon layers.
# =====================================================================

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2)
  devtools::load_all("/home/ess/Documents/apps/emburdenvis", quiet = TRUE)
  try(devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE), silent = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)
OUT_DIR <- file.path(REPO, "manuscript/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

summ_path <- "data/intersection_matrix_asthma.rds"
stopifnot(file.exists(summ_path))
summ <- readRDS(summ_path)

# Filter to selected shocks x storage moderators (drop shocks/mods missing
# from the summary so plot_intersection_matrix does not error on empty cells).
shocks_want <- c("treated_any", "treated_heat_wave", "treated_ida",
                 "treated_uri", "treated_smoke_event")
mods_want   <- c("bess_operating_mwh", "res_storage_kwh", "sgip_residential_kwh")

shocks_keep <- intersect(shocks_want, unique(summ$shock))
mods_keep   <- intersect(mods_want,   unique(summ$moderator))

sub <- summ %>%
  filter(shock %in% shocks_keep, moderator %in% mods_keep)

# Drop (shock, moderator) combinations with no rows so patchwork does not
# blow up on an empty cell.
present <- sub %>%
  distinct(shock, moderator) %>%
  mutate(k = paste(shock, moderator))
shocks_keep <- intersect(shocks_keep, unique(present$shock))
mods_keep   <- intersect(mods_keep,   unique(present$moderator))
sub <- sub %>%
  filter(paste(shock, moderator) %in% present$k) %>%
  mutate(shock     = factor(shock,     levels = shocks_keep),
         moderator = factor(moderator, levels = mods_keep))

message(sprintf("[fig1] filtered summary rows: %d (%d cells: %d shocks x %d moderators)",
                nrow(sub), length(unique(paste(sub$shock, sub$moderator))),
                length(shocks_keep), length(mods_keep)))

p <- plot_intersection_matrix(
  as.data.frame(sub),
  row_var    = "shock",
  col_var    = "moderator",
  title      = "Asthma outcomes: shock x storage-moderator polar matrix"
)

ggsave(file.path(OUT_DIR, "asthma_fig1.pdf"),
       plot = p, width = 12, height = 14, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "asthma_fig1.png"),
       plot = p, width = 12, height = 14, dpi = 300)
message(sprintf("[fig1] wrote %s.{pdf,png}", file.path(OUT_DIR, "asthma_fig1")))
