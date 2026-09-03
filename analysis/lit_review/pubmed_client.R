# pubmed_client.R
# Small httr2-based client for NCBI E-utilities (esearch + efetch).
# Politeness: 0.35s hard sleep between calls; 3-attempt exponential backoff
# on 429/5xx. Uses NCBI_API_KEY env var if set (raises 3->10 req/sec limit).

suppressPackageStartupMessages({
  library(httr2)
  library(xml2)
  library(tibble)
  library(dplyr)
})

.PUBMED_TOOL  <- "emburdenlit"
.PUBMED_EMAIL <- "hello@emrgi.com"
.PUBMED_BASE  <- "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

.pubmed_common_query <- function() {
  q <- list(tool = .PUBMED_TOOL, email = .PUBMED_EMAIL)
  key <- Sys.getenv("NCBI_API_KEY", unset = "")
  if (nzchar(key)) q$api_key <- key
  q
}

.pubmed_sleep <- function() {
  # 0.35s = ~2.86 req/s (safe under 3 req/s unauthenticated limit).
  Sys.sleep(0.35)
}

.pubmed_req <- function(url, query) {
  req <- httr2::request(url) |>
    httr2::req_url_query(!!!query) |>
    httr2::req_user_agent(sprintf("%s (%s)", .PUBMED_TOOL, .PUBMED_EMAIL)) |>
    httr2::req_retry(
      max_tries = 3,
      backoff = function(attempt) 2 ^ attempt,
      is_transient = function(resp) {
        s <- httr2::resp_status(resp)
        s == 429L || (s >= 500L && s < 600L)
      }
    ) |>
    httr2::req_error(is_error = function(resp) httr2::resp_status(resp) >= 400L)
  resp <- httr2::req_perform(req)
  .pubmed_sleep()
  resp
}

#' PubMed esearch
#'
#' @param query character. Raw PubMed query. Date/language filters are appended
#'   only if `mindate`/`maxdate` are non-NULL — pass e.g. `"2015"` / `"2026"`.
#' @param retmax integer. Max PMIDs to return (PubMed caps at 100000).
#' @param mindate,maxdate character or NULL. Publication-date range.
#' @param ... additional query params passed to esearch.
#' @return list(pmids, query_translation, count, raw_json)
pubmed_esearch <- function(query, retmax = 500L,
                           mindate = "2015", maxdate = "2026", ...) {
  stopifnot(is.character(query), length(query) == 1L, nzchar(query))
  q <- c(
    .pubmed_common_query(),
    list(
      db = "pubmed",
      term = query,
      retmode = "json",
      retmax = as.integer(retmax),
      ...
    )
  )
  if (!is.null(mindate)) q$mindate <- mindate
  if (!is.null(maxdate)) q$maxdate <- maxdate
  if (!is.null(mindate) || !is.null(maxdate)) q$datetype <- "pdat"
  resp <- .pubmed_req(file.path(.PUBMED_BASE, "esearch.fcgi"), q)
  body <- httr2::resp_body_string(resp)
  parsed <- jsonlite::fromJSON(body, simplifyVector = TRUE)
  res <- parsed$esearchresult
  list(
    pmids = if (is.null(res$idlist)) character(0) else as.character(res$idlist),
    query_translation = if (is.null(res$querytranslation)) NA_character_ else res$querytranslation,
    count = if (is.null(res$count)) NA_integer_ else as.integer(res$count),
    raw_json = body
  )
}

.text1 <- function(x, xpath) {
  n <- xml2::xml_find_first(x, xpath)
  if (inherits(n, "xml_missing")) NA_character_ else xml2::xml_text(n, trim = TRUE)
}

.textn <- function(x, xpath, sep = "; ") {
  ns <- xml2::xml_find_all(x, xpath)
  if (length(ns) == 0L) return(NA_character_)
  paste(xml2::xml_text(ns, trim = TRUE), collapse = sep)
}

.parse_article <- function(node) {
  pmid <- .text1(node, ".//PMID")
  title <- .text1(node, ".//ArticleTitle")
  abs_parts <- xml2::xml_find_all(node, ".//Abstract/AbstractText")
  abstract <- if (length(abs_parts) == 0L) NA_character_ else {
    labels <- xml2::xml_attr(abs_parts, "Label")
    texts <- xml2::xml_text(abs_parts, trim = TRUE)
    chunks <- ifelse(is.na(labels) | !nzchar(labels),
                     texts, paste0(labels, ": ", texts))
    paste(chunks, collapse = " ")
  }
  auths <- xml2::xml_find_all(node, ".//AuthorList/Author")
  authors <- if (length(auths) == 0L) NA_character_ else {
    parts <- vapply(auths, function(a) {
      last <- .text1(a, "./LastName")
      init <- .text1(a, "./Initials")
      coll <- .text1(a, "./CollectiveName")
      if (!is.na(coll)) return(coll)
      trimws(paste(na.omit(c(last, init)), collapse = " "))
    }, character(1))
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0L) NA_character_ else paste(parts, collapse = "; ")
  }
  journal <- .text1(node, ".//Journal/Title")
  year <- .text1(node, ".//Journal/JournalIssue/PubDate/Year")
  if (is.na(year)) {
    med <- .text1(node, ".//Journal/JournalIssue/PubDate/MedlineDate")
    if (!is.na(med)) {
      m <- regmatches(med, regexpr("\\d{4}", med))
      if (length(m) && nzchar(m)) year <- m
    }
  }
  doi_nodes <- xml2::xml_find_all(node, ".//ArticleId[@IdType='doi']")
  doi <- if (length(doi_nodes) == 0L) NA_character_ else xml2::xml_text(doi_nodes[[1]], trim = TRUE)
  mesh_terms <- .textn(node, ".//MeshHeadingList/MeshHeading/DescriptorName")
  pub_types <- .textn(node, ".//PublicationTypeList/PublicationType")
  tibble::tibble(
    pmid = pmid, title = title, abstract = abstract,
    authors = authors, journal = journal,
    year = suppressWarnings(as.integer(year)),
    doi = doi, mesh_terms = mesh_terms, pub_types = pub_types
  )
}

#' PubMed efetch (batched)
#'
#' @param pmids character vector of PubMed IDs.
#' @param chunk_size integer, <= 200 per NCBI etiquette.
#' @param ... additional query params.
#' @return tibble with pmid, title, abstract, authors, journal, year, doi,
#'   mesh_terms, pub_types. Also carries attribute `raw_xml` = list of chunked
#'   XML strings for archiving.
pubmed_efetch <- function(pmids, chunk_size = 200L, ...) {
  pmids <- unique(as.character(pmids))
  pmids <- pmids[nzchar(pmids)]
  if (length(pmids) == 0L) {
    out <- tibble::tibble(
      pmid = character(0), title = character(0), abstract = character(0),
      authors = character(0), journal = character(0),
      year = integer(0), doi = character(0),
      mesh_terms = character(0), pub_types = character(0)
    )
    attr(out, "raw_xml") <- list()
    return(out)
  }
  chunk_size <- min(as.integer(chunk_size), 200L)
  groups <- split(pmids, ceiling(seq_along(pmids) / chunk_size))
  frames <- vector("list", length(groups))
  raws <- vector("list", length(groups))
  for (i in seq_along(groups)) {
    q <- c(
      .pubmed_common_query(),
      list(
        db = "pubmed",
        id = paste(groups[[i]], collapse = ","),
        rettype = "abstract",
        retmode = "xml",
        ...
      )
    )
    resp <- .pubmed_req(file.path(.PUBMED_BASE, "efetch.fcgi"), q)
    xml_str <- httr2::resp_body_string(resp)
    raws[[i]] <- xml_str
    doc <- xml2::read_xml(xml_str)
    arts <- xml2::xml_find_all(doc, ".//PubmedArticle")
    if (length(arts) == 0L) {
      frames[[i]] <- tibble::tibble()
    } else {
      frames[[i]] <- dplyr::bind_rows(lapply(arts, .parse_article))
    }
  }
  out <- dplyr::bind_rows(frames)
  attr(out, "raw_xml") <- raws
  out
}
