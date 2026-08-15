#!/usr/bin/env Rscript
# Publication figures for the outage → homicide analysis.
# Output PNGs to manuscript/figures/outage_homicide_*.png

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tidyr)
  library(readr)
  library(scales)
})

REPO   <- "/home/ess/Documents/apps/net_energy_equity"
DATA   <- file.path(REPO, "data")
FIGDIR <- file.path(REPO, "manuscript", "figures")
dir.create(FIGDIR, recursive = TRUE, showWarnings = FALSE)

theme_pub <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(size = 14, face = "bold"),
    plot.subtitle    = element_text(size = 11, color = "grey40"),
    plot.caption     = element_text(size = 9, color = "grey40", hjust = 0),
    strip.text       = element_text(face = "bold")
  )

# ============================================================================
#  Fig 1 — Event-study coefficient plot (Uri, Ida, Harvey)
# ============================================================================
es <- readRDS(file.path(DATA, "outage_homicide_event_study_annual.rds"))
es$event_lab <- recode(es$event,
  uri = "Winter Storm Uri (Feb 2021)",
  ida = "Hurricane Ida (Aug-Sep 2021)",
  harvey = "Hurricane Harvey (Aug 2017)"
)
es$event_lab <- factor(es$event_lab,
  levels = c("Winter Storm Uri (Feb 2021)",
             "Hurricane Ida (Aug-Sep 2021)",
             "Hurricane Harvey (Aug 2017)"))

fig1 <- ggplot(es, aes(x = k, y = estimate)) +
  geom_hline(yintercept = 0, linetype = 2, color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = 3, color = "steelblue") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15, color = "grey40") +
  geom_point(aes(color = event, shape = term == "reference"),
             size = 3) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1)) +
  scale_color_manual(values = c(uri = "#4477AA", ida = "#EE6677", harvey = "#228833")) +
  facet_wrap(~ event_lab, scales = "free_x", ncol = 3) +
  labs(
    title = "Fig 1. Event-study — annual homicide-rate coefficients around outage events",
    subtitle = "Coefficients on interaction of (exposed) × (year - event_year). Reference = k=-1 (Uri/Ida) or k=+1 (Harvey).",
    x = "Years relative to event",
    y = "Δ homicide rate (per 100k)",
    color = NULL,
    caption = paste0(
      "N = 568 counties, 48 states, 2018-2023.  Cluster-robust SE at county level.  ",
      "95% CIs shown.  Reference year β = 0 by construction.\n",
      "Pre-trends violation flagged: Uri +1.11 (p=0.02) and Ida −3.55 (p=0.02) at k=−3 ",
      "suggest treated counties differ from controls before treatment; interpret per-event ",
      "level effects with caution."
    )
  ) +
  guides(shape = "none", color = "none") +
  theme_pub

ggsave(file.path(FIGDIR, "outage_homicide_fig1_event_study.png"),
       fig1, width = 12, height = 5, dpi = 150)
cat("✓ Fig 1 event study saved\n")

# ============================================================================
#  Fig 2 — Per-event effect estimates (main tract-year DiD)
# ============================================================================
res <- readRDS(file.path(DATA, "outage_homicide_full_results.rds"))
per_event <- res$per_event %>%
  mutate(
    event = sub("^treated_", "", term),
    event_lab = recode(event,
      uri     = "Winter Storm Uri\n(2021, TX)",
      ida     = "Hurricane Ida\n(2021, LA/NJ)",
      psps    = "CA PSPS\n(2019+, Nevada Co. etc.)",
      harvey  = "Hurricane Harvey\n(2017, TX)"
    ),
    ci_lo = estimate - 1.96 * se,
    ci_hi = estimate + 1.96 * se,
    p_lab = ifelse(p_value < 0.001, "p < 0.001",
             ifelse(p_value < 0.01,  sprintf("p = %.3f", p_value),
                    sprintf("p = %.2f", p_value))),
    sig = p_value < 0.05
  ) %>%
  arrange(estimate)
per_event$event_lab <- factor(per_event$event_lab, levels = per_event$event_lab)

fig2 <- ggplot(per_event, aes(x = event_lab, y = estimate, fill = sig)) +
  geom_hline(yintercept = 0, linetype = 2, color = "grey50") +
  geom_col(width = 0.6) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15) +
  geom_text(aes(label = sprintf("β = %.2f\n%s", estimate, p_lab),
                y = estimate + ifelse(estimate > 0, 0.05, -0.05) * max(abs(estimate))),
            vjust = ifelse(per_event$estimate > 0, 0, 1), size = 3.5) +
  scale_fill_manual(values = c(`TRUE` = "#EE6677", `FALSE` = "grey70")) +
  labs(
    title = "Fig 2. Per-event effect of outage exposure on homicide rate",
    subtitle = "Tract-year FE-DiD, cluster-robust at tract. Model:  y ~ treated_uri + treated_ida + treated_harvey + treated_psps | geoid + year",
    x = NULL,
    y = "Δ homicide rate (per 100k tract-years)",
    fill = "p < 0.05",
    caption = paste0(
      "N = 118,679 tract-years, 49,511 tracts, 46 states, 2014/2018/2022 waves.\n",
      "PSPS effect on CA metros ONLY — rural CA counties are suppressed at n<10.  ",
      "Uri near-null consistent with cold-event mechanism (no heat amplification)."
    )
  ) +
  theme_pub

ggsave(file.path(FIGDIR, "outage_homicide_fig2_per_event.png"),
       fig2, width = 9, height = 5.5, dpi = 150)
cat("✓ Fig 2 per-event saved\n")

# ============================================================================
#  Fig 3 — Heterogeneity by urban-rural (headline β per NCHS bin)
# ============================================================================
het <- res$heterogeneity %>%
  mutate(
    bin_type = sub("_Q\\d+$", "", spec),
    q        = sub(".*_Q(\\d+)$", "\\1", spec)
  ) %>%
  filter(bin_type == "D_urban_rural_code") %>%
  mutate(
    quintile_label = recode(q,
      `1` = "Large\ncentral/fringe\nmetro\n(NCHS 1-3)",
      `2` = "Medium\nsmall metro\n(NCHS 4-5)",
      `3` = "Non-metro\nmicropolitan\n(NCHS 6)",
      `4` = "Non-core\nrural\n(NCHS 6+)"
    ),
    ci_lo = estimate - 1.96 * se,
    ci_hi = estimate + 1.96 * se,
    p_lab = ifelse(is.na(p_value), "",
             ifelse(p_value < 0.001, "p < 0.001",
             ifelse(p_value < 0.01,  sprintf("p = %.3f", p_value),
                    sprintf("p = %.2f", p_value)))),
    sig = ifelse(is.na(p_value), FALSE, p_value < 0.05)
  )
het$quintile_label <- factor(het$quintile_label, levels = het$quintile_label)

fig3 <- ggplot(het, aes(x = quintile_label, y = estimate, fill = estimate)) +
  geom_hline(yintercept = 0, linetype = 2, color = "grey50") +
  geom_col(width = 0.6, color = "black") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15) +
  geom_text(aes(label = sprintf("β = %.2f\n%s\nn = %s",
                                estimate, p_lab, format(n_obs, big.mark = ",")),
                y = estimate + 0.15 * sign(estimate)),
            size = 3.2, vjust = ifelse(het$estimate > 0, 0, 1)) +
  scale_fill_gradient2(low = "#4477AA", mid = "grey90", high = "#EE6677",
                       midpoint = 0, guide = "none") +
  labs(
    title = "Fig 3. Urban-rural reversal — outage → homicide by NCHS 6-code",
    subtitle = "Headline treated_any effect fit separately within each urban-rural bin",
    x = NULL,
    y = "Δ homicide rate (per 100k) from any outage exposure",
    caption = paste0(
      "Large central/fringe metros bear the effect (+0.85/100k, p=2e-10); ",
      "medium/small metros show a small negative (−0.20, p=0.002); ",
      "non-metro rural shows a LARGER negative (−1.52, p=1e-12).\n",
      "The rural negative may reflect small-N noise or genuine differences in ",
      "response infrastructure. National +0.24 average is a weighted mix."
    )
  ) +
  theme_pub

ggsave(file.path(FIGDIR, "outage_homicide_fig3_urban_rural.png"),
       fig3, width = 9, height = 5.5, dpi = 150)
cat("✓ Fig 3 urban-rural heterogeneity saved\n")

# ============================================================================
#  Fig 4 — Moderator interaction magnitudes (heat, burden, saidi, saifi, dr)
# ============================================================================
int <- res$interactions_fdr %>%
  filter(grepl("^C_treated_x_", spec)) %>%
  mutate(
    moderator = sub("^C_treated_x_", "", spec),
    mod_lab = recode(moderator,
      extreme_heat_days     = "Extreme heat days\n(days > 95°F)",
      avg_energy_burden.x   = "Energy burden\n(% income on utilities)",
      saidi                 = "SAIDI\n(annual outage minutes)",
      saifi                 = "SAIFI\n(annual outage events)",
      solar_penetration_pct = "Solar penetration\n(% of households)",
      dr_total              = "Demand response\n(kW enrolled)"
    ),
    ci_lo = estimate - 1.96 * se,
    ci_hi = estimate + 1.96 * se,
    protective = estimate < 0
  ) %>%
  arrange(estimate)
int$mod_lab <- factor(int$mod_lab, levels = int$mod_lab)

fig4 <- ggplot(int, aes(x = mod_lab, y = estimate,
                        fill = protective)) +
  geom_hline(yintercept = 0, linetype = 2, color = "grey50") +
  geom_col(width = 0.6, color = "black") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15) +
  geom_text(aes(label = sprintf("+%.2f", estimate),
                y = estimate + 0.05 * sign(estimate)),
            data = ~ subset(., estimate > 0),
            vjust = 0, size = 3.5) +
  geom_text(aes(label = sprintf("%.2f", estimate),
                y = estimate + 0.05 * sign(estimate)),
            data = ~ subset(., estimate < 0),
            vjust = 1, size = 3.5) +
  scale_fill_manual(values = c(`TRUE` = "#228833", `FALSE` = "#EE6677"),
                    labels = c("Amplifies", "Protects")) +
  labs(
    title = "Fig 4. Moderator interactions with any-outage-event on homicide",
    subtitle = "Each bar = interaction β from y ~ treated_any + treated_any × moderator_z + moderator_z | geoid + year",
    x = NULL,
    y = "Δ (Δ homicide per outage) per 1 SD moderator",
    fill = "Effect on\noutage impact",
    caption = paste0(
      "All 6 interactions FDR-significant (q<10^-9).  Positive bars = higher moderator amplifies outage harm.  ",
      "Green (negative) = protective — DR enrollment reduces outage → homicide effect.\n",
      "Heat and burden amplify most strongly; solar has smaller but significant amplification."
    )
  ) +
  theme_pub +
  theme(legend.position = "top")

ggsave(file.path(FIGDIR, "outage_homicide_fig4_moderators.png"),
       fig4, width = 11, height = 5.5, dpi = 150)
cat("✓ Fig 4 moderators saved\n")

# ============================================================================
#  Fig 5 — Attributable homicides and DALYs by scenario
# ============================================================================
daly <- readRDS(file.path(DATA, "outage_homicide_daly_rollup.rds"))
scen <- bind_rows(
  daly$per_event %>%
    filter(!is.na(attributable_homicides)) %>%
    transmute(
      scenario   = paste0("Per-event: ", event),
      homicides  = attributable_homicides,
      lo         = conf_lo_hom,
      hi         = conf_hi_hom,
      type       = "per-event"
    ),
  tibble(
    scenario  = "Realistic\n(all treated 2018-2023)",
    homicides = daly$realistic$attributable_homicides,
    lo = NA_real_, hi = NA_real_,
    type = "cumulative"
  ),
  tibble(
    scenario  = "Heat-amplified\n(+1 SD extreme_heat)",
    homicides = daly$mechanism$additional_homicides[1],
    lo = NA_real_, hi = NA_real_,
    type = "mechanism"
  ),
  tibble(
    scenario  = "Burden-amplified\n(+1 SD energy_burden)",
    homicides = daly$mechanism$additional_homicides[2],
    lo = NA_real_, hi = NA_real_,
    type = "mechanism"
  )
) %>%
  mutate(dalys = homicides * 32)

fig5 <- scen %>%
  mutate(scenario = factor(scenario, levels = scenario)) %>%
  ggplot(aes(x = scenario, y = homicides, fill = type)) +
  geom_col(width = 0.6, color = "black") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15,
                data = ~ subset(., !is.na(lo))) +
  geom_text(aes(label = sprintf("%.0f homicides\n%s DALYs",
                                homicides, format(round(dalys), big.mark = ","))),
            vjust = -0.3, size = 3.3) +
  scale_fill_manual(values = c(`per-event` = "#4477AA", cumulative = "#EE6677",
                               mechanism = "#DDAA33")) +
  labs(
    title = "Fig 5. Attributable homicides and DALYs",
    subtitle = "GBD 2019 US injury YLL/death = 32.  Per-event = single-event population × β.  Realistic = full treated pop 2018-2023.",
    x = NULL,
    y = "Attributable homicides",
    fill = "Scenario type",
    caption = "Point estimates without SE bars for realistic/mechanism scenarios are lower bounds — sampling variance not propagated."
  ) +
  theme_pub

ggsave(file.path(FIGDIR, "outage_homicide_fig5_daly.png"),
       fig5, width = 11, height = 6, dpi = 150)
cat("✓ Fig 5 DALY roll-up saved\n")

cat("\n=== All figures saved to manuscript/figures/outage_homicide_*.png ===\n")
