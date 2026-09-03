#!/usr/bin/env Rscript
# =====================================================================
# fig_asthma_horserace.R  →  manuscript/figures/asthma_fig2.{pdf,png}
# ---------------------------------------------------------------------
# Horizontal bar: all ~35 moderators for
# asthma_hosp_rate ~ treated_any (2way spec).
# Bars sorted by beta, colored by moderator family; q-values annotated.
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
  filter(outcome == "asthma_hosp_rate",
         shock   == "treated_any",
         spec    == "2way") %>%
  filter(!is.na(estimate))

# Assign family
fam <- function(m) {
  case_when(
    grepl("^bess_",  m) ~ "Utility storage",
    grepl("^res_storage|^nem_storage|^dg_storage", m) ~ "Residential storage",
    grepl("^sgip_", m) ~ "SGIP (CA equity)",
    grepl("^uspvdb|^cs_", m) ~ "Solar (PV/community)",
    grepl("^dp_|^ami_", m) ~ "Demand-flex / AMI",
    grepl("^hhi_", m) ~ "CDC HHI ranks",
    grepl("^pm25|^ozone", m) ~ "Air quality",
    grepl("^pct_heat|^electric_heat", m) ~ "Heating fuel",
    TRUE ~ "Demographic / other"
  )
}
dat <- dat %>%
  mutate(family = fam(moderator),
         moderator = factor(moderator, levels = moderator[order(estimate)]),
         q_label = ifelse(!is.na(q_bh),
                          formatC(q_bh, digits = 2, format = "g"), ""),
         sig_star = ifelse(!is.na(q_bh) & q_bh < 0.10, "*", ""))

pal_hex <- c("#4477AA", "#EE6677", "#228833", "#CCBB44",
             "#66CCEE", "#AA3377", "#BBBBBB", "#EE9944", "#88CCAA")
family_levels <- sort(unique(dat$family))
names(pal_hex) <- head(pal_hex, length(family_levels))
if (exists("get_categorical_palette", mode = "function")) {
  pal_hex <- tryCatch(get_categorical_palette(n = length(family_levels)),
                      error = function(e) head(pal_hex, length(family_levels)))
}
names(pal_hex) <- family_levels

p <- ggplot(dat, aes(x = moderator, y = estimate, fill = family)) +
  geom_col(width = 0.75, colour = "grey20", linewidth = 0.15) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  geom_text(aes(label = paste0(sig_star, " q=", q_label),
                y = estimate + sign(estimate) * (max(abs(estimate), na.rm = TRUE) * 0.02)),
            hjust = ifelse(dat$estimate >= 0, -0.05, 1.05),
            size = 2.6, colour = "grey20") +
  scale_fill_manual(values = pal_hex, name = "Moderator family") +
  coord_flip() +
  labs(
    title = "Interaction beta: asthma hospitalization x (treated_any x moderator)",
    subtitle = "2way spec; FDR q-values (BH); asterisk = q<0.10",
    x = NULL,
    y = expression(beta ~ "(interaction, treated_any x moderator_z)")
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.grid.major.y = element_blank(),
        plot.title.position = "plot")

ggsave(file.path(OUT_DIR, "asthma_fig2.pdf"),
       plot = p, width = 9, height = 8, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "asthma_fig2.png"),
       plot = p, width = 9, height = 8, dpi = 300)
message(sprintf("[fig2] wrote %s.{pdf,png}", file.path(OUT_DIR, "asthma_fig2")))
