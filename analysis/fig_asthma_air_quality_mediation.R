#!/usr/bin/env Rscript
# =====================================================================
# fig_asthma_air_quality_mediation.R
#   →  manuscript/figures/asthma_fig3.{pdf,png}
# ---------------------------------------------------------------------
# Point-CI plot: beta and 95% CI for the pm25_annual_ugm3 moderator,
# across all 4 asthma outcomes x all shocks, for 2way and heat_break
# specs.
# =====================================================================

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2)
  try(devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE),
      silent = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)
OUT_DIR <- file.path(REPO, "manuscript/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

summ <- readRDS("data/intersection_matrix_asthma.rds")

dat <- summ %>%
  filter(moderator == "pm25_annual_ugm3",
         spec %in% c("2way", "heat_break"),
         !is.na(estimate), !is.na(se))

# Order shocks (rows) and outcomes (cols)
outcome_labels <- c(
  places_asthma_prev = "PLACES prevalence",
  asthma_hosp_rate   = "Hospitalization rate",
  asthma_ed_rate     = "ED visit rate",
  wonder_asthma_rate = "Mortality rate"
)
dat <- dat %>%
  mutate(outcome_lbl = factor(outcome_labels[outcome],
                              levels = outcome_labels),
         ci_lo = estimate - 1.96 * se,
         ci_hi = estimate + 1.96 * se,
         sig   = ifelse(!is.na(q_bh) & q_bh < 0.10, "q<0.10", "n.s."))

# Colors
tol <- c("2way" = "#4477AA", "heat_break" = "#EE6677")
if (exists("get_categorical_palette", mode = "function")) {
  tol <- tryCatch({
    v <- get_categorical_palette(n = 2)
    setNames(v, c("2way", "heat_break"))
  }, error = function(e) tol)
}

p <- ggplot(dat, aes(x = estimate, y = shock, colour = spec, shape = sig)) +
  geom_vline(xintercept = 0, colour = "grey40", linetype = "dashed") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi),
                 height = 0.15, position = position_dodge(width = 0.55),
                 linewidth = 0.4) +
  geom_point(size = 2.3, position = position_dodge(width = 0.55)) +
  scale_colour_manual(values = tol, name = "Specification") +
  scale_shape_manual(values = c("q<0.10" = 16, "n.s." = 21), name = "FDR") +
  facet_wrap(~ outcome_lbl, ncol = 2, scales = "free_x") +
  labs(
    title = "PM2.5 annual mean as effect modifier of shock -> asthma",
    subtitle = "Beta with 95% CI; interaction term shock x pm25_annual_ugm3_z",
    x = expression(beta ~ "(interaction)"),
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"),
        panel.grid.major.y = element_blank())

ggsave(file.path(OUT_DIR, "asthma_fig3.pdf"),
       plot = p, width = 10, height = 7, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "asthma_fig3.png"),
       plot = p, width = 10, height = 7, dpi = 300)
message(sprintf("[fig3] wrote %s.{pdf,png}", file.path(OUT_DIR, "asthma_fig3")))
