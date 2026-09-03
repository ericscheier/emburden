#!/usr/bin/env Rscript
# =====================================================================
# fig_asthma_shock_grid.R
#   →  manuscript/figures/asthma_fig6.{pdf,png}
# ---------------------------------------------------------------------
# 5-row x 4-col heatmap:
#   rows = 5 shocks (treated_any, treated_heat_wave, treated_uri,
#          treated_ida, treated_psps)
#   cols = 4 asthma outcomes
#   cells = 2way beta on the shock main effect from the raw sweep
#           results if available, else the median interaction beta
#           across moderators from intersection_matrix_asthma.rds.
# Color by direction + magnitude.
# =====================================================================

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2); library(tidyr)
  try(devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE),
      silent = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)
OUT_DIR <- file.path(REPO, "manuscript/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

shocks_keep <- c("treated_any", "treated_heat_wave", "treated_uri",
                 "treated_ida", "treated_psps")
outcomes_keep <- c("places_asthma_prev", "asthma_hosp_rate",
                   "asthma_ed_rate", "wonder_asthma_rate")

outcome_labels <- c(
  places_asthma_prev = "PLACES prev.",
  asthma_hosp_rate   = "Hosp. rate",
  asthma_ed_rate     = "ED rate",
  wonder_asthma_rate = "Mortality"
)
shock_labels <- c(
  treated_any       = "Any FEMA",
  treated_heat_wave = "Heat wave",
  treated_uri       = "Winter Storm Uri (TX)",
  treated_ida       = "Hurricane Ida",
  treated_psps      = "CA PSPS"
)

# 1) Prefer main effect from raw sweep results (term == shock)
raw <- readRDS("data/intersection_sweep_asthma.rds")
res <- raw$results
main_hits <- res %>%
  filter(spec == "2way",
         outcome %in% outcomes_keep,
         shock %in% shocks_keep,
         term == shock)

if (nrow(main_hits) > 0L) {
  cells <- main_hits %>%
    group_by(outcome, shock) %>%
    summarise(estimate = median(estimate, na.rm = TRUE),
              q_bh     = median(q_bh, na.rm = TRUE),
              n_cells  = n(),
              source   = "shock main effect (raw)",
              .groups = "drop")
} else {
  message("[fig6] No shock-main-effect terms found; falling back to summarized interaction median.")
  summ <- readRDS("data/intersection_matrix_asthma.rds")
  cells <- summ %>%
    filter(spec == "2way",
           outcome %in% outcomes_keep, shock %in% shocks_keep) %>%
    group_by(outcome, shock) %>%
    summarise(estimate = median(estimate, na.rm = TRUE),
              q_bh     = median(q_bh, na.rm = TRUE),
              n_cells  = n(),
              source   = "interaction median (fallback)",
              .groups = "drop")
}

cells <- cells %>%
  mutate(outcome_lbl = factor(outcome_labels[outcome],
                              levels = outcome_labels),
         shock_lbl   = factor(shock_labels[shock],
                              levels = rev(shock_labels)),
         est_label   = ifelse(is.na(estimate), "",
                              formatC(estimate, digits = 2, format = "g")))

lim <- max(abs(cells$estimate), na.rm = TRUE)

p <- ggplot(cells, aes(x = outcome_lbl, y = shock_lbl, fill = estimate)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = est_label), size = 3.2, colour = "grey10") +
  scale_fill_gradient2(low = "#228833", mid = "#F7F7F7", high = "#EE6677",
                       midpoint = 0, limits = c(-lim, lim),
                       name = expression(beta ~ "(2way)")) +
  labs(
    title = "Shock -> asthma outcome: 2way DiD beta grid",
    subtitle = paste(unique(cells$source), collapse = " / "),
    x = "Asthma outcome",
    y = NULL,
    caption = "Cells = median across moderators when raw shock main-effect terms unavailable."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.grid = element_blank(),
        plot.title.position = "plot")

ggsave(file.path(OUT_DIR, "asthma_fig6.pdf"),
       plot = p, width = 9, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "asthma_fig6.png"),
       plot = p, width = 9, height = 6, dpi = 300)
message(sprintf("[fig6] wrote %s.{pdf,png}", file.path(OUT_DIR, "asthma_fig6")))
