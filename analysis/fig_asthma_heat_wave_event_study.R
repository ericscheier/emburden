#!/usr/bin/env Rscript
# =====================================================================
# fig_asthma_heat_wave_event_study.R
#   →  manuscript/figures/asthma_fig4.{pdf,png}
# ---------------------------------------------------------------------
# Event-study-style plot around heat-wave treatment year.
# EPHT county rates are available only at 2014, 2018, 2022 (4-year
# cadence); we plot cohort mean rate at all available EPHT years with
# a vline at each cohort's first treatment year.
#   * cohorts: tracts first treated_heat_wave==1 in 2018 or 2022
#   * outcome: asthma_hosp_rate (county age-adj hospitalizations)
# =====================================================================

suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(ggplot2)
  try(devtools::load_all("/home/ess/Documents/apps/emburdenpub", quiet = TRUE),
      silent = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
setwd(REPO)
OUT_DIR <- file.path(REPO, "manuscript/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

pnl <- fread("data/tract_panel_enhanced_with_asthma_ders.csv",
             select = c("geoid", "year", "treated_heat_wave",
                        "asthma_hosp_rate", "asthma_ed_rate"),
             showProgress = FALSE)

# Identify treatment year(s) per tract - first year with treated_heat_wave==1
trt <- pnl[treated_heat_wave == 1L,
           .(treat_year = min(year, na.rm = TRUE)),
           by = geoid]

# Restrict to cohorts treated in 2018 or 2022 (adequate pre/post windows)
trt <- trt[treat_year %in% c(2018L, 2022L)]
message(sprintf("[fig4] cohorts: 2018 n=%d tracts, 2022 n=%d tracts",
                sum(trt$treat_year == 2018L),
                sum(trt$treat_year == 2022L)))

pnl <- merge(pnl, trt, by = "geoid")
pnl[, rel_year := year - treat_year]
pnl <- pnl[year %in% c(2014L, 2018L, 2022L) & !is.na(asthma_hosp_rate)]

agg <- pnl[, .(
  mean_rate = mean(asthma_hosp_rate, na.rm = TRUE),
  se_rate   = sd(asthma_hosp_rate, na.rm = TRUE) / sqrt(sum(!is.na(asthma_hosp_rate))),
  n_tracts  = uniqueN(geoid)
), by = .(treat_year, year, rel_year)]
agg[, cohort := factor(paste0("First treated ", treat_year, " (n=",
                              format(pnl[treat_year == treat_year, uniqueN(geoid)],
                                     big.mark = ","), " tracts)"))]
# Simpler cohort label per row
agg[, cohort := factor(sprintf("First treated %d", treat_year))]
agg[, ci_lo := mean_rate - 1.96 * se_rate]
agg[, ci_hi := mean_rate + 1.96 * se_rate]
setorder(agg, cohort, year)
message("[fig4] agg table:"); print(agg)

pal <- c("First treated 2018" = "#4477AA", "First treated 2022" = "#EE6677")
if (exists("get_categorical_palette", mode = "function")) {
  pal <- tryCatch({
    v <- get_categorical_palette(n = 2)
    setNames(v, levels(agg$cohort))
  }, error = function(e) pal)
}

# Vlines at cohort treatment year, colour-matched to cohort line
treat_lines <- unique(agg[, .(cohort, treat_year)])

p <- ggplot(agg, aes(x = year, y = mean_rate,
                     colour = cohort, group = cohort)) +
  geom_vline(data = treat_lines,
             aes(xintercept = treat_year, colour = cohort),
             linetype = "dashed", linewidth = 0.5, show.legend = FALSE) +
  geom_line(linewidth = 0.9) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi, fill = cohort),
              alpha = 0.15, colour = NA) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = c(2014L, 2018L, 2022L)) +
  scale_colour_manual(values = pal, name = NULL) +
  scale_fill_manual(values = pal, guide = "none") +
  labs(
    title = "Asthma hospitalization around heat-wave treatment year",
    subtitle = sprintf(
      "Tract cohorts first-treated 2018 (n=%s) vs. 2022 (n=%s); vertical dashes = cohort treatment year",
      format(sum(trt$treat_year == 2018L), big.mark = ","),
      format(sum(trt$treat_year == 2022L), big.mark = ",")),
    x = "EPHT reporting year (2014, 2018, 2022 available)",
    y = "County age-adj asthma hospitalization rate\n(mean across cohort tracts, 95% CI)",
    caption = "Source: CDC EPHT county rates joined to tract panel; treated_heat_wave from Wave-asthma B4."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title.position = "plot")

ggsave(file.path(OUT_DIR, "asthma_fig4.pdf"),
       plot = p, width = 8, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "asthma_fig4.png"),
       plot = p, width = 8, height = 6, dpi = 300)
message(sprintf("[fig4] wrote %s.{pdf,png}", file.path(OUT_DIR, "asthma_fig4")))
