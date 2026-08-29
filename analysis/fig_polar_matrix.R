#!/usr/bin/env Rscript
# Fig 14 — Pathway x moderator polar matrix.
# TODO(fig14): wave_outage_homicide_polar_matrix.rds is 0 bytes;
# using literals from REPORT section 13 as a stand-in.
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr)
  devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE)
})

FIGDIR <- "/home/ess/Documents/apps/net_energy_equity/manuscript/figures"
DATA   <- "/home/ess/Documents/apps/net_energy_equity/data"

`%||%` <- function(a, b) if (is.null(a)) b else a

polar_path <- file.path(DATA, "wave_outage_homicide_polar_matrix.rds")
have_rds <- file.exists(polar_path) && file.info(polar_path)$size > 0

if (have_rds) {
  pm <- readRDS(polar_path)
  df <- pm$long %||% pm
} else {
  warning("TODO(fig14): polar_matrix RDS empty; using literal REPORT section 13 numbers")
  df <- tribble(
    ~moderator,            ~pathway,       ~beta,   ~q,
    "community solar",     "outage",       -54.00,  2e-4,
    "community solar",     "heat",          -3.10,  0.02,
    "community solar",     "burden",        -1.20,  0.05,
    "net metering",        "outage",        -3.76,  6e-4,
    "net metering",        "heat",          -0.90,  0.05,
    "net metering",        "burden",        -0.42,  0.08,
    "SGIP residential",    "outage",       -10.17,  1e-30,
    "SGIP residential",    "burden",        -2.83,  1e-4,
    "SGIP residential",    "heat",           3.59,  2e-29,
    "HHI heat-burden",     "outage",        -6.29,  1e-30,
    "HHI heat-burden",     "heat",          -5.60,  1e-30,
    "HHI heat-burden",     "burden",        -1.10,  1e-4,
    "USPVDB PV plants",    "outage",        -0.50,  0.03,
    "USPVDB PV plants",    "burden",        -0.12,  0.08,
    "USPVDB PV plants",    "heat",          -0.05,  0.15,
    "residential storage", "outage",         0.12,  0.9,
    "residential storage", "burden",        -0.29,  1e-3,
    "residential storage", "heat",          -0.30,  0.02
  )
}

df <- df %>%
  mutate(abs_beta = abs(beta),
         sign_lab = ifelse(beta < 0, "protective", "aggravating"),
         pathway  = factor(pathway))

p <- ggplot(df, aes(x = pathway, y = abs_beta, fill = sign_lab)) +
  geom_col(width = 0.8, color = "white", linewidth = 0.3) +
  coord_polar(theta = "x") +
  facet_wrap(~ moderator, ncol = 3) +
  scale_fill_manual(values = c(protective = "#1b9e77", aggravating = "#d73027")) +
  scale_y_continuous(trans = "log1p", breaks = c(0, 1, 5, 20, 60)) +
  labs(title = "Fig 14. Pathway x moderator polar matrix",
       subtitle = paste("Radial = |beta| (log1p).",
                        if (!have_rds) "Literal REPORT numbers (polar RDS pending)." else ""),
       x = NULL, y = "|beta|", fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"),
        panel.grid.major.x = element_line(color = "grey80"),
        plot.title = element_text(face = "bold"))

ggsave(file.path(FIGDIR, "outage_homicide_fig14.pdf"), p, width = 11, height = 10)
ggsave(file.path(FIGDIR, "outage_homicide_fig14.png"), p, width = 11, height = 10, dpi = 300)
cat("Fig 14 saved (fallback=", !have_rds, ")\n")

`%||%` <- function(a, b) if (is.null(a)) b else a
