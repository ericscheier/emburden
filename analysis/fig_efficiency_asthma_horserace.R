#!/usr/bin/env Rscript
# =====================================================================
# fig_efficiency_asthma_horserace.R
# ---------------------------------------------------------------------
# Horse-race figure for the asthma × efficiency intersection: for each
# efficiency-family moderator, plot the interaction beta averaged
# across shocks (or a single shock chosen for interpretability),
# faceted by outcome, with FDR-based highlighting.
#
# Consumes: data/intersection_matrix_asthma_efficiency.rds
# Emits:    manuscript/figures/efficiency_asthma_horserace.{pdf,png}
# =====================================================================

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2); library(data.table)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)
OUT_DIR <- file.path(REPO, "manuscript/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

summ <- setDT(readRDS("data/intersection_matrix_asthma_efficiency.rds"))

# Focus on treated_any (broadest shock) + heat_break spec (where signal
# concentrates) unless empty, else 2way.
prefer_spec <- "heat_break"
dat <- summ[shock == "treated_any" & spec == prefer_spec & !is.na(estimate)]
if (nrow(dat) < 10L) {
  dat <- summ[shock == "treated_any" & spec == "2way" & !is.na(estimate)]
}

fam <- function(m) {
  dplyr::case_when(
    grepl("^adapt_index", m)        ~ "Composite adaptation index",
    grepl("^ee_savings_kwh",   m)   ~ "EE savings per hh (kWh)",
    grepl("^ee_direct_cost",   m)   ~ "EE direct cost per hh ($)",
    grepl("^ee_peak_savings",  m)   ~ "EE peak MW / hh",
    grepl("^ee_savings_mwh",   m)   ~ "EE state savings (MWh)",
    grepl("^ee_lifecycle",     m)   ~ "EE lifecycle savings (MWh)",
    grepl("^ee_weighted_avg",  m)   ~ "EE weighted avg life (yrs)",
    grepl("^n_utilities",      m)   ~ "Utilities reporting EE",
    grepl("^has_energy",       m)   ~ "Has EE program (0/1)",
    grepl("^pct_built_pre",    m)   ~ "Housing built pre-1980",
    grepl("^pct_built_1980",   m)   ~ "Housing built 1980-1999",
    grepl("^pct_built_post",   m)   ~ "Housing built post-2000",
    TRUE                            ~ m
  )
}

dat[, family := fam(moderator)]

# Standardize the beta scale — the EE-magnitude moderators have wildly
# different units (kWh vs MWh vs $). Rescale by within-moderator SD so
# each bar represents β per 1-SD change of the moderator.
panel <- fread("data/tract_panel_enhanced_with_asthma_ders_ee_adapt.csv",
               select = unique(dat$moderator))
mod_sd <- vapply(names(panel), function(nm) stats::sd(panel[[nm]], na.rm=TRUE),
                 numeric(1))
dat[, beta_per_sd := estimate * mod_sd[moderator]]
dat[, family := factor(family, levels = rev(sort(unique(family))))]
dat[, moderator_lbl := factor(family, levels = levels(family))]

outcome_label <- function(o) {
  dplyr::recode(o,
    places_asthma_prev = "PLACES tract prevalence",
    asthma_hosp_rate   = "EPHT hospitalizations",
    asthma_ed_rate     = "EPHT ED visits",
    wonder_asthma_rate = "WONDER mortality")
}
dat[, outcome_pretty := outcome_label(outcome)]

pal_hex <- c(
  "Composite adaptation index"   = "#000000",
  "EE savings per hh (kWh)"      = "#4477AA",
  "EE direct cost per hh ($)"    = "#66CCEE",
  "EE peak MW / hh"              = "#228833",
  "EE state savings (MWh)"       = "#CCBB44",
  "EE lifecycle savings (MWh)"   = "#EE6677",
  "EE weighted avg life (yrs)"   = "#AA3377",
  "Utilities reporting EE"       = "#BBBBBB",
  "Has EE program (0/1)"         = "#888888",
  "Housing built pre-1980"       = "#EE9944",
  "Housing built 1980-1999"      = "#DDAA55",
  "Housing built post-2000"      = "#BBDD99"
)

p <- ggplot(dat, aes(x = family, y = beta_per_sd, fill = family)) +
  geom_col(width = 0.7, colour = "grey20", linewidth = 0.15) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  geom_text(aes(label = ifelse(sig_fdr_10 == TRUE, "*", "")),
            hjust = -0.3, size = 3.5, colour = "grey20") +
  scale_fill_manual(values = pal_hex, guide = "none") +
  coord_flip() +
  facet_wrap(~ outcome_pretty, scales = "free_x", ncol = 2) +
  labs(
    title = "Efficiency × shock × asthma: interaction betas per 1-SD moderator",
    subtitle = sprintf("shock = treated_any; spec = %s; asterisk = BH-FDR q<0.10", prefer_spec),
    x = NULL,
    y = "beta per 1 SD of moderator"
  ) +
  theme_minimal(base_size = 11) +
  theme(strip.text = element_text(face = "bold"),
        panel.grid.major.y = element_blank(),
        plot.title.position = "plot")

ggsave(file.path(OUT_DIR, "efficiency_asthma_horserace.pdf"),
       plot = p, width = 12, height = 8, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "efficiency_asthma_horserace.png"),
       plot = p, width = 12, height = 8, dpi = 300)
message(sprintf("[fig] wrote %s.{pdf,png}",
                file.path(OUT_DIR, "efficiency_asthma_horserace")))
