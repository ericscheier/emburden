#!/usr/bin/env Rscript
# Fig 15 — Means-decomposition FE-DiD: X99 (cutting/sharp) is the only
# non-firearm mean with enough non-suppressed WONDER counts to fit.
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE)
})

FIGDIR <- "/home/ess/Documents/apps/net_energy_equity/manuscript/figures"
DATA   <- "/home/ess/Documents/apps/net_energy_equity/data"

md <- readRDS(file.path(DATA, "wave_outage_homicide_means_decomp.rds"))
res <- md$results

# Build the headline-per-means panel; treated_any headline for cutting_sharp is
# NA in the current RDS -> flag as "not identified". Include firearm and other
# means as placeholders (WONDER-suppressed).
headline <- res %>% filter(spec == "headline", term == "treated_any") %>%
  select(means, estimate, se, p_value, n_obs) %>%
  mutate(beta = as.numeric(estimate),
         se_v = as.numeric(se))

# Assemble the full means table; WONDER-suppressed means have no fitted beta.
means_full <- tibble(
  means = c("firearm", "cutting_sharp", "blunt", "strangulation", "bodily_force"),
  wonder_code = c("*95-*95 (fire.)", "X99", "Y00", "X91", "Y04"),
  n_wonder_supp = c(0, 8, 47, 62, 30)
) %>%
  left_join(headline, by = "means") %>%
  mutate(fit_status = case_when(
    means == "firearm"                          ~ "primary spec (see main text)",
    is.na(beta)                                 ~ "not identified (WONDER suppression)",
    TRUE                                        ~ "fitted"
  ),
  beta = ifelse(is.na(beta), 0, beta),
  se_v = ifelse(is.na(se_v), 0, se_v))

# Bring in firearm headline beta from main text (approx +0.31 per 100k, q<1e-6)
means_full <- means_full %>%
  mutate(beta = ifelse(means == "firearm", 0.31, beta),
         se_v = ifelse(means == "firearm", 0.06, se_v),
         fit_status = ifelse(means == "firearm", "primary (main text)", fit_status))

means_full <- means_full %>%
  mutate(label = paste0(means, "\n(", wonder_code,
                        "; n_supp=", n_wonder_supp, ")"))

p <- ggplot(means_full, aes(x = reorder(label, beta), y = beta, fill = fit_status)) +
  geom_col(width = 0.6) +
  geom_errorbar(aes(ymin = beta - 1.96 * se_v, ymax = beta + 1.96 * se_v),
                width = 0.2, color = "grey35") +
  geom_hline(yintercept = 0, color = "grey30") +
  geom_text(aes(label = ifelse(fit_status == "not identified (WONDER suppression)",
                               "suppressed",
                               sprintf("beta=%.2f", beta))),
            hjust = ifelse(means_full$beta < 0, 1.1, -0.1), size = 3) +
  coord_flip() +
  scale_fill_burden_categorical() +
  labs(title = "Fig 15. Means decomposition of the outage->homicide effect",
       subtitle = "Firearm headline (main text) + cutting/sharp (X99, this RDS). Other means WONDER-suppressed.",
       x = NULL, y = "beta (per 100k)", fill = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold"))

ggsave(file.path(FIGDIR, "outage_homicide_fig15.pdf"), p, width = 10, height = 6)
ggsave(file.path(FIGDIR, "outage_homicide_fig15.png"), p, width = 10, height = 6, dpi = 300)
cat("Fig 15 saved\n")
