#!/usr/bin/env Rscript
# Fig 12 — Ecosystem horse-race of all 2-way moderators, colored by family
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE)
})

FIGDIR <- "/home/ess/Documents/apps/net_energy_equity/manuscript/figures"
DATA   <- "/home/ess/Documents/apps/net_energy_equity/data"

mit <- readRDS(file.path(DATA, "wave_outage_homicide_mitigation_full_ders.rds"))

classify_family <- function(m) {
  case_when(
    grepl("^(bess|res_storage|nem_storage|dg_storage|sgip)", m) ~ "storage",
    grepl("^(uspvdb|pv_|solar|cs_|grid_solar)", m)              ~ "PV",
    grepl("^dp_", m)                                            ~ "dynamic_pricing",
    grepl("^ami", m)                                            ~ "AMI",
    grepl("^hhi_", m)                                           ~ "HHI",
    grepl("^nem_", m)                                           ~ "net_metering",
    grepl("^(dr|der)", m)                                       ~ "DR/DER",
    TRUE                                                        ~ "other"
  )
}

df <- mit$interactions_2way %>%
  mutate(beta = as.numeric(estimate),
         se_v = as.numeric(se),
         qv   = as.numeric(q_bh),
         family = classify_family(moderator)) %>%
  arrange(beta) %>%
  mutate(moderator = factor(moderator, levels = moderator))

p <- ggplot(df, aes(x = moderator, y = beta, fill = family)) +
  geom_col() +
  geom_errorbar(aes(ymin = beta - 1.96 * se_v, ymax = beta + 1.96 * se_v),
                width = 0.2, color = "grey35") +
  geom_hline(yintercept = 0, color = "grey30") +
  geom_text(aes(label = ifelse(qv < 0.001, "***",
                        ifelse(qv < 0.01, "**",
                        ifelse(qv < 0.1, "*", "")))),
            hjust = ifelse(df$beta < 0, 1.15, -0.15), size = 3) +
  coord_flip() +
  scale_fill_burden_categorical() +
  labs(title = "Fig 12. Horse-race - every DER/burden moderator, ordered by beta",
       subtitle = "2-way interaction spec (treated_any x moderator_z). * q<0.1, ** q<0.01, *** q<0.001.",
       x = NULL, y = "beta (per SD, per 100k)", fill = "family") +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 12))

ggsave(file.path(FIGDIR, "outage_homicide_fig12.pdf"), p, width = 10, height = 12)
ggsave(file.path(FIGDIR, "outage_homicide_fig12.png"), p, width = 10, height = 12, dpi = 300)
cat("Fig 12 saved\n")
