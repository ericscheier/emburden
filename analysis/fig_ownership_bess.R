#!/usr/bin/env Rscript
# Fig 11 — BESS / storage moderators (only `bess_mw_unknown` exists in current
# mitigation output for ownership; fall back to all bess_* / storage moderators)
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE)
})

FIGDIR <- "/home/ess/Documents/apps/net_energy_equity/manuscript/figures"
DATA   <- "/home/ess/Documents/apps/net_energy_equity/data"

mit <- readRDS(file.path(DATA, "wave_outage_homicide_mitigation_full_ders.rds"))

# TODO(fig11): only bess_mw_unknown available among ownership classes;
# widen filter to all bess_*/storage moderators until upstream generator emits
# bess_mw_IOU/IPP/muni/coop rows.
storage_pat <- "^(bess_|res_storage|nem_storage|dg_storage)"

df <- bind_rows(
  mit$interactions_2way %>% mutate(spec_lab = "2-way (main)"),
  mit$interactions_heat_break %>% mutate(spec_lab = "heat-break")
) %>%
  filter(grepl(storage_pat, moderator)) %>%
  mutate(beta = as.numeric(estimate),
         se_v = as.numeric(se),
         qv   = as.numeric(q_bh),
         sign = ifelse(beta < 0, "protective", "aggravating"),
         lab  = paste0(moderator, " (", spec_lab, ")"))

p <- ggplot(df, aes(x = reorder(lab, beta), y = beta, fill = sign)) +
  geom_col() +
  geom_errorbar(aes(ymin = beta - 1.96 * se_v, ymax = beta + 1.96 * se_v),
                width = 0.25, color = "grey35") +
  geom_hline(yintercept = 0, color = "grey30") +
  geom_text(aes(label = sprintf("q=%.1e", qv)),
            hjust = ifelse(df$beta < 0, -0.1, 1.1), size = 2.6, color = "grey25") +
  coord_flip() +
  scale_fill_manual(values = c(protective = "#1b9e77", aggravating = "#d73027")) +
  labs(title = "Fig 11. Storage / BESS moderators of the outage->homicide effect",
       subtitle = paste("Bars: beta per SD, per 100k. Errorbars: 1.96 x SE.",
                        "Only `bess_mw_unknown` present among ownership classes."),
       x = NULL, y = "beta (per SD, per 100k)", fill = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold"))

ggsave(file.path(FIGDIR, "outage_homicide_fig11.pdf"), p, width = 10, height = 9)
ggsave(file.path(FIGDIR, "outage_homicide_fig11.png"), p, width = 10, height = 9, dpi = 300)
cat("Fig 11 saved\n")
