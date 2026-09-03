# asthma_triad_sweep.R
# Pre-registered PubMed sweep across 5 asthma exposure queries covering
# emburden exposures: outage, air quality, wildfire smoke, filtration/HEPA,
# heat.  Caches raw esearch JSON + efetch XML and writes a union tibble.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(jsonlite)
})

.here <- function(...) {
  base <- "/home/ess/Documents/apps/net_energy_equity"
  do.call(file.path, c(list(base), list(...)))
}

source(.here("analysis/lit_review/pubmed_client.R"))

RAW_DIR <- .here("data/lit/raw")
OUT_DIR <- .here("data/lit")
dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

DATE_TAG <- format(Sys.Date(), "%Y%m%d")

QUERIES <- list(
  outage = paste(
    '(asthma[MeSH]) AND ("power outage"[tiab]',
    'OR blackout*[tiab] OR "grid failure"[tiab])'
  ),
  air_quality = paste(
    '(asthma[MeSH]) AND ("PM2.5"[tiab] OR ozone[tiab] OR "air quality"[tiab])',
    'AND ("census tract"[tiab] OR "environmental justice"[tiab]',
    'OR disparit*[tiab])'
  ),
  wildfire_smoke = paste(
    '(asthma[MeSH]) AND ("wildfire"[tiab] OR "smoke event"[tiab]',
    'OR "wildland fire"[tiab])'
  ),
  filtration_hepa = paste(
    '(asthma[MeSH]) AND ("air filtration"[tiab] OR HEPA[tiab]',
    'OR "portable air cleaner"[tiab])',
    'AND (randomized[tiab] OR trial[tiab] OR intervention[tiab])'
  ),
  heat = paste(
    '(asthma[MeSH]) AND ("heat wave"[tiab] OR "extreme heat"[tiab])',
    'AND (vulnerab*[tiab] OR sensitiv*[tiab])'
  )
)
# Common date + language filter applied via the raw term (esearch also
# supports mindate/maxdate, but embedding in the term makes it visible in
# the cached query_translation).
QUERY_SUFFIX <- ' AND ("2015"[PDAT] : "2026"[PDAT]) AND English[LA]'

run_query <- function(slug, raw_query) {
  message("[pubmed] ", slug)
  full_term <- paste0(raw_query, QUERY_SUFFIX)
  s <- pubmed_esearch(full_term, retmax = 500L,
                      mindate = NULL, maxdate = NULL)
  writeLines(
    s$raw_json,
    file.path(RAW_DIR, sprintf("esearch_%s_%s.json", slug, DATE_TAG))
  )
  message("  esearch: ", length(s$pmids), " PMIDs (count=", s$count, ")")

  fetched <- pubmed_efetch(s$pmids, chunk_size = 200L)
  raws <- attr(fetched, "raw_xml")
  if (length(raws) == 1L) {
    writeLines(
      raws[[1]],
      file.path(RAW_DIR, sprintf("efetch_%s_%s.xml", slug, DATE_TAG))
    )
  } else if (length(raws) > 1L) {
    for (i in seq_along(raws)) {
      writeLines(
        raws[[i]],
        file.path(RAW_DIR,
                  sprintf("efetch_%s_%s_part%02d.xml", slug, DATE_TAG, i))
      )
    }
  }

  if (nrow(fetched) > 0L) {
    fetched <- dplyr::mutate(fetched, query_slug = slug, .after = "pmid")
  } else {
    fetched <- tibble::tibble(
      pmid = character(0), query_slug = character(0),
      title = character(0), abstract = character(0),
      authors = character(0), journal = character(0),
      year = integer(0), doi = character(0),
      mesh_terms = character(0), pub_types = character(0)
    )
  }

  list(
    provenance = list(
      query_slug        = slug,
      query_raw         = full_term,
      query_translation = s$query_translation,
      count             = s$count,
      retrieval_date    = format(Sys.Date(), "%Y-%m-%d"),
      pmids             = s$pmids
    ),
    tbl = fetched
  )
}

results <- lapply(names(QUERIES), function(slug) run_query(slug, QUERIES[[slug]]))
names(results) <- names(QUERIES)

union_tbl <- dplyr::bind_rows(lapply(results, `[[`, "tbl"))
saveRDS(union_tbl, file.path(OUT_DIR, "asthma_triad.rds"))

provenance <- lapply(results, `[[`, "provenance")
jsonlite::write_json(
  provenance,
  file.path(OUT_DIR, "asthma_triad_provenance.json"),
  auto_unbox = TRUE, pretty = TRUE
)

# ---- verification --------------------------------------------------------
cat("\n=== VERIFICATION ===\n")
per_query <- union_tbl |>
  dplyr::group_by(query_slug) |>
  dplyr::summarise(n = dplyr::n_distinct(pmid), .groups = "drop")
print(per_query)

cat("\nUnique PMIDs across corpus: ",
    dplyr::n_distinct(union_tbl$pmid), "\n", sep = "")

cat("\nTop 3 journals (by article count, deduped by pmid):\n")
top_journals <- union_tbl |>
  dplyr::distinct(pmid, journal) |>
  dplyr::filter(!is.na(journal)) |>
  dplyr::count(journal, sort = TRUE) |>
  utils::head(3)
print(top_journals)

invisible(union_tbl)
