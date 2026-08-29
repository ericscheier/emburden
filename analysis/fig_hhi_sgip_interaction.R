#!/usr/bin/env Rscript
# Fig 10 — HHI x SGIP super-linear protection (4 panels)
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE)
})

FIGDIR <- "/home/ess/Documents/apps/net_energy_equity/manuscript/figures"
DATA   <- "/home/ess/Documents/apps/net_energy_equity/data"
dir.create(FIGDIR, recursive = TRUE, showWarnings = FALSE)

theme_pub <- theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 12))

hhi <- readRDS(file.path(DATA, "wave_outage_homicide_hhi_x_sgip.rds"))
mit <- readRDS(file.path(DATA, "wave_outage_homicide_mitigation_full_ders.rds"))

# ----- Panel A: SGIP-CA vs LBNL-national burden pathway -----
panelA_df <- tibble(
  cohort   = c("CA SGIP residential", "LBNL national residential"),
  beta     = c(-2.83, -0.29),
  q        = c(1e-4, 1e-3)
)
pA <- ggplot(panelA_df, aes(x = cohort, y = beta, fill = cohort)) +
  geom_col(width = 0.55) +
  geom_hline(yintercept = 0, color = "grey30") +
  geom_text(aes(label = sprintf("beta=%.2f\nq=%.0e", beta, q)),
            vjust = ifelse(panelA_df$beta < 0, 1.2, -0.4), size = 3.2) +
  scale_fill_burden_categorical() +
  labs(title = "A. Burden-pathway beta: SGIP vs LBNL",
       x = NULL, y = "beta (per SD, per 100k)") +
  theme_pub + theme(legend.position = "none")

# ----- Panel B: HHI heat-triple betas from mitigation heat-break -----
hhi_heat <- mit$interactions_heat_break %>%
  filter(grepl("^hhi_", moderator)) %>%
  mutate(beta = as.numeric(estimate),
         se_v = as.numeric(se),
         qv   = as.numeric(q_bh)) %>%
  arrange(beta)
pB <- ggplot(hhi_heat, aes(x = reorder(moderator, beta), y = beta)) +
  geom_errorbar(aes(ymin = beta - 1.96 * se_v, ymax = beta + 1.96 * se_v),
                width = 0.2, color = "grey40") +
  geom_point(aes(color = beta), size = 3) +
  geom_hline(yintercept = 0, linetype = 2, color = "grey40") +
  coord_flip() +
  scale_color_gradientn(colors = get_burden_palette("diverging")) +
  labs(title = "B. HHI x heat x outage (heat-break spec)",
       x = NULL, y = "beta (per SD, per 100k)", color = "beta") +
  theme_pub

# ----- Panel C: top 5 terms from 3way HHI SGIP outage spec -----
three <- hhi$interactions %>%
  filter(spec == "3way_HHI_SGIP_outage") %>%
  mutate(beta = as.numeric(estimate),
         se_v = as.numeric(se),
         is_hero = grepl("heat_z:hhi_hb_z:sgip_res_z", term)) %>%
  arrange(beta) %>%
  head(5)
if (nrow(three) < 5) {
  three <- hhi$int_terms_fdr %>%
    filter(spec == "4way_full") %>%
    mutate(beta = as.numeric(estimate), se_v = as.numeric(se),
           is_hero = grepl("heat_z:hhi_hb_z:sgip_res_z", term)) %>%
    arrange(beta) %>% head(5)
}
pC <- ggplot(three, aes(x = reorder(term, beta), y = beta, fill = is_hero)) +
  geom_col() +
  geom_hline(yintercept = 0, color = "grey30") +
  geom_text(aes(label = sprintf("%.2f", beta)),
            hjust = ifelse(three$beta < 0, 1.1, -0.1), size = 3) +
  coord_flip() +
  scale_fill_manual(values = c(`FALSE` = "grey60", `TRUE` = "#1b9e77"),
                    labels = c("other", "hero triple")) +
  labs(title = "C. Top HHI x SGIP terms (3-way spec)",
       x = NULL, y = "beta", fill = NULL) +
  theme_pub

# ----- Panel D: scatter of SGIP kWh vs HHI heat-burden rank, colored by predicted marginal beta -----
panel <- data.table::fread("/home/ess/Documents/apps/net_energy_equity/data/tract_panel_enhanced_with_ders.csv",
                           select = c("state_abbr", "sgip_residential_kwh",
                                      "hhi_heat_burden_rank"))
ca <- panel[state_abbr == "CA" & !is.na(sgip_residential_kwh) & !is.na(hhi_heat_burden_rank)]
if (nrow(ca) > 0L) {
  ca[, sgip_z := scale(sgip_residential_kwh)[, 1]]
  ca[, hhi_z  := scale(hhi_heat_burden_rank)[, 1]]
  # Predicted marginal beta from hero-triple structure: b_main + b_hero*hhi*sgip
  ca[, predicted := -4.84 + (-10.17) * sgip_z + (-6.29) * hhi_z + (-9.94) * hhi_z * sgip_z]
  # Downsample to keep the plot readable
  set.seed(42)
  cs <- ca[sample.int(.N, min(.N, 4000L))]
  pD <- ggplot(cs, aes(x = sgip_residential_kwh + 1, y = hhi_heat_burden_rank,
                       color = predicted)) +
    geom_point(alpha = 0.55, size = 0.9) +
    scale_x_log10() +
    scale_color_gradientn(colors = get_burden_palette("diverging")) +
    labs(title = "D. CA tracts: SGIP kWh vs HHI heat-burden rank",
         x = "SGIP residential kWh (log)", y = "HHI heat-burden rank",
         color = "Predicted marginal beta") +
    theme_pub
} else {
  pD <- ggplot() + annotate("text", 0, 0, label = "CA panel unavailable") +
    theme_void()
}

fig <- patchwork::wrap_plots(pA, pB, pC, pD, ncol = 2) +
  patchwork::plot_annotation(title = "Fig 10. HHI x SGIP super-linear protection",
                             theme = theme(plot.title = element_text(face = "bold", size = 13)))

ggsave(file.path(FIGDIR, "outage_homicide_fig10.pdf"), fig,
       width = 12, height = 9)
ggsave(file.path(FIGDIR, "outage_homicide_fig10.png"), fig,
       width = 12, height = 9, dpi = 300)
cat("Fig 10 saved\n")
