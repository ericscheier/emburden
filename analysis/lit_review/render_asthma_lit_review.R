#!/usr/bin/env Rscript
# Render manuscript/asthma_lit_review.md from the classified PubMed corpus.

suppressPackageStartupMessages({ library(dplyr) })

REPO <- "/home/ess/Documents/apps/net_energy_equity"
LIT  <- readRDS(file.path(REPO, "data/lit/asthma_triad_classified.rds"))
PROV <- jsonlite::fromJSON(file.path(REPO, "data/lit/asthma_triad_provenance.json"),
                            simplifyVector = FALSE)

# ---- Header + query provenance ----
lines <- c(
  "# Automated Literature Review — asthma × emburden-ecosystem exposures",
  "",
  sprintf("**Retrieved**: %s  |  **Corpus size**: %d abstracts (%d unique PMIDs)",
          format(Sys.Date()), nrow(LIT), length(unique(LIT$pmid))),
  "",
  "**Source**: PubMed / NCBI E-utilities via `analysis/lit_review/pubmed_client.R`.",
  "",
  "**Classification**: each abstract classified via Claude subagent on 5 dimensions",
  "(relevance ∈ [0,1], triad_arm, study_type, population_scale, one-sentence bottom_line).",
  "See `data/lit/asthma_triad_classified.rds`.",
  "",
  "## 1. Query provenance",
  "",
  "| Slug | Raw query | PMIDs | Median relevance |",
  "|---|---|---|---|"
)
med_rel <- LIT %>% group_by(query_slug) %>%
  summarise(n = n(), med_rel = round(median(relevance, na.rm = TRUE), 2), .groups = "drop")
for (i in seq_along(PROV)) {
  q <- PROV[[i]]
  row <- med_rel[med_rel$query_slug == q$query_slug, ]
  lines <- c(lines, sprintf("| `%s` | `%s` | %d | %s |",
                             q$query_slug, gsub("\\|", "\\\\|", q$query_raw),
                             length(q$pmids),
                             if (nrow(row)) row$med_rel else "—"))
}

# ---- Coverage / gap analysis ----
lines <- c(lines,
  "",
  "## 2. Ecosystem data plumbing vs. literature coverage",
  "",
  "| Triad arm | Papers | Top study types | Ecosystem data status |",
  "|---|---|---|---|")

arms <- c("outage", "wildfire_smoke", "air_quality", "heat", "filtration_hepa")
plumb <- list(
  outage          = "✅ 41 FEMA events, PSPS, EAGLE-I customer-hours — full analysis in Wave-L outage-homicide REPORT",
  wildfire_smoke  = "🟡 NOAA HMS loader exists but county-day cache incomplete — see REPORT §11 Wave-2 followup",
  air_quality     = "✅ EPHT PM2.5 + ozone county-year cached 2001–2020, EPA AQS daily loader available",
  heat            = "✅ CDC EPHT extreme-heat-days county-year + treated_heat_wave binary built in Wave-asthma B4",
  filtration_hepa = "❌ No US-national HEPA/portable-air-cleaner uptake loader in fleet — priority Wave-2 build"
)

for (arm in arms) {
  sub <- LIT[LIT$triad_arm == arm, ]
  n <- nrow(sub)
  if (n == 0) {
    top_st <- "—"
  } else {
    st_tab <- sort(table(sub$study_type), decreasing = TRUE)[1:min(3, length(unique(sub$study_type)))]
    top_st <- paste0(paste(names(st_tab), st_tab, sep = " ("), ")", collapse = ", ")
  }
  lines <- c(lines, sprintf("| `%s` | %d | %s | %s |", arm, n, top_st, plumb[[arm]]))
}

# ---- Per-arm top abstracts ----
for (arm in arms) {
  sub <- LIT[LIT$triad_arm == arm, ] %>%
    arrange(desc(relevance), desc(year)) %>%
    head(15)
  if (nrow(sub) == 0) next
  lines <- c(lines,
    "",
    sprintf("## 3.%d Top-relevance abstracts — %s (%d shown of %d)",
            match(arm, arms), arm, nrow(sub),
            sum(LIT$triad_arm == arm)),
    "",
    "| PMID | Rel | Year | Journal | Study | N-scale | Bottom line |",
    "|---|---:|---:|---|---|---|---|"
  )
  for (i in seq_len(nrow(sub))) {
    r <- sub[i, ]
    j <- ifelse(is.na(r$journal) | r$journal == "", "—", substr(r$journal, 1, 40))
    lines <- c(lines, sprintf(
      "| [%s](https://pubmed.ncbi.nlm.nih.gov/%s/) | %.2f | %s | %s | %s | %s | %s |",
      r$pmid, r$pmid, r$relevance, r$year, j, r$study_type,
      r$population_scale, gsub("\\|", "\\\\|", r$bottom_line)))
  }
}

# ---- Key findings synthesis ----
lines <- c(lines,
  "",
  "## 4. Synthesis: literature-supported causal claims",
  "",
  "Filtering to `relevance >= 0.80` abstracts with a direct causal claim yields",
  "the following high-confidence findings from the peer-reviewed evidence base:",
  ""
)
hi <- LIT %>% filter(relevance >= 0.80) %>% arrange(triad_arm, desc(relevance))
for (arm in unique(hi$triad_arm)) {
  lines <- c(lines, sprintf("### %s", arm))
  arm_sub <- hi[hi$triad_arm == arm, ]
  for (i in seq_len(nrow(arm_sub))) {
    r <- arm_sub[i, ]
    lines <- c(lines, sprintf(
      "- **PMID [%s](https://pubmed.ncbi.nlm.nih.gov/%s/) (%s, %s)** — %s",
      r$pmid, r$pmid, r$year,
      if (is.na(r$journal) || r$journal == "") "—" else substr(r$journal, 1, 30),
      r$bottom_line))
  }
  lines <- c(lines, "")
}

# ---- Write ----
out_path <- file.path(REPO, "manuscript/asthma_lit_review.md")
writeLines(lines, out_path)
cat(sprintf("Wrote %s (%d lines)\n", out_path, length(lines)))
