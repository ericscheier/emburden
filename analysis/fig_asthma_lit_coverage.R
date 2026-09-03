#!/usr/bin/env Rscript
# =====================================================================
# fig_asthma_lit_coverage.R
#   →  manuscript/figures/asthma_fig5.{pdf,png}
# ---------------------------------------------------------------------
# Bar/dot chart: n abstracts per triad_arm x study_type combination
# from data/lit/asthma_triad_classified.rds. Annotate per-arm ecosystem
# plumbing coverage (from manuscript/asthma_lit_review.md).
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

lit <- readRDS("data/lit/asthma_triad_classified.rds")

# Ecosystem plumbing coverage (from asthma_lit_review.md table 2)
coverage <- tibble::tribble(
  ~triad_arm,       ~plumbing,          ~note,
  "outage",         "READY",            "FEMA + PSPS + EAGLE-I",
  "wildfire_smoke", "PARTIAL",          "NOAA HMS loader exists; cache incomplete",
  "air_quality",    "READY",            "EPHT PM2.5 + O3 2001-2020; EPA AQS avail.",
  "heat",           "READY",            "CDC EPHT extreme-heat + Wave-B4 binary",
  "filtration_hepa","MISSING",          "No national HEPA uptake loader"
)
plumb_pal <- c(READY = "#228833", PARTIAL = "#CCBB44", MISSING = "#EE6677")

# Order arms by paper count then attach plumbing
arm_counts <- lit %>%
  count(triad_arm, name = "n_papers") %>%
  arrange(desc(n_papers))
coverage <- coverage %>% left_join(arm_counts, by = "triad_arm") %>%
  mutate(triad_arm = factor(triad_arm, levels = arm_counts$triad_arm))

# Study-type distribution per arm
by_st <- lit %>%
  mutate(triad_arm = factor(triad_arm, levels = arm_counts$triad_arm)) %>%
  count(triad_arm, study_type, name = "n")

# Category palette for study types
st_levels <- sort(unique(by_st$study_type))
st_pal_default <- c("#4477AA", "#EE6677", "#228833", "#CCBB44",
                    "#66CCEE", "#AA3377", "#BBBBBB", "#EE9944")
st_pal <- head(st_pal_default, length(st_levels))
if (exists("get_categorical_palette", mode = "function")) {
  st_pal <- tryCatch(get_categorical_palette(n = length(st_levels)),
                     error = function(e) st_pal)
}
names(st_pal) <- st_levels

# Layered stacked bar + coverage annotation strip
p_main <- ggplot(by_st, aes(x = triad_arm, y = n, fill = study_type)) +
  geom_col(width = 0.72, colour = "grey20", linewidth = 0.15) +
  geom_text(data = arm_counts,
            aes(x = triad_arm, y = n_papers, label = paste0("n=", n_papers)),
            inherit.aes = FALSE, vjust = -0.4, size = 3.4, fontface = "bold") +
  scale_fill_manual(values = st_pal, name = "Study type") +
  labs(
    title = "Asthma x ecosystem-shock literature: 116 abstracts across 5 arms",
    subtitle = "Stack = study-type mix per triad arm (PubMed 2015-2026, English)",
    x = NULL, y = "Papers (n)",
    caption = "Source: analysis/lit_review/pubmed_client.R; classified via Claude subagent."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title.position = "plot",
        panel.grid.major.x = element_blank())

# Coverage strip below (as a second plot glued via patchwork if available)
p_cov <- ggplot(coverage, aes(x = triad_arm, y = 1, fill = plumbing)) +
  geom_tile(colour = "white", linewidth = 1) +
  geom_text(aes(label = paste0(plumbing, "\n", note)),
            colour = "black", size = 3.0, lineheight = 0.9) +
  scale_fill_manual(values = plumb_pal, name = "Ecosystem plumbing") +
  scale_y_continuous(breaks = NULL, expand = c(0, 0)) +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom",
        axis.text.x = element_blank(),
        panel.grid = element_blank())

if (requireNamespace("patchwork", quietly = TRUE)) {
  p <- p_main / p_cov + patchwork::plot_layout(heights = c(4, 1))
} else {
  p <- p_main   # fallback
}

ggsave(file.path(OUT_DIR, "asthma_fig5.pdf"),
       plot = p, width = 9, height = 7, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "asthma_fig5.png"),
       plot = p, width = 9, height = 7, dpi = 300)
message(sprintf("[fig5] wrote %s.{pdf,png}", file.path(OUT_DIR, "asthma_fig5")))
