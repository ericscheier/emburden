# FIPS / GEOID utilities
# =====================
# Internal helpers that restore the leading zero stripped from numeric FIPS
# codes (states 01–09 = AL/AK/AZ/AR/CA/CO/CT). Without this, `substr(9001,
# 1, 2)` returns "90" instead of "09" and every CT row is silently
# misclassified — see issue + 2026-05-29 regression in test-fips-leading-
# zero.R.

#' Pad a numeric or character GEOID/FIPS to its inferred width (internal)
#'
#' Width inferred from the longest input value: >5 chars = 11-digit tract
#' GEOID; >2 chars = 5-digit county FIPS; otherwise 2-digit state FIPS.
#'
#' @param geoid Numeric or character vector.
#' @return Character vector zero-padded to the inferred width.
#' @keywords internal
.pad_fips <- function(geoid) {
  g <- as.character(geoid)
  if (!length(g)) return(character(0))
  mx <- suppressWarnings(max(nchar(g), na.rm = TRUE))
  if (!is.finite(mx)) return(g)
  width <- if (mx > 5) 11L else if (mx > 2) 5L else 2L
  needs_pad <- !is.na(g) & nchar(g) < width
  if (any(needs_pad)) {
    g[needs_pad] <- formatC(suppressWarnings(as.numeric(g[needs_pad])),
                            width = width, flag = "0", format = "d")
  }
  g
}

#' Extract the 2-digit state FIPS from a GEOID or county FIPS
#'
#' Pads numeric inputs first so states 01-09 (AL, AK, AZ, AR, CA, CO, CT)
#' are not silently misclassified.
#'
#' @param geoid Character or numeric vector of GEOIDs / county FIPS.
#' @return Character vector of 2-digit state FIPS codes.
#' @keywords internal
.extract_state_fips <- function(geoid) substr(.pad_fips(geoid), 1, 2)

#' Extract the 5-digit county FIPS from a GEOID
#'
#' Pads numeric inputs first.
#'
#' @param geoid Character or numeric vector.
#' @return Character vector of 5-digit county FIPS codes.
#' @keywords internal
.extract_county_fips <- function(geoid) substr(.pad_fips(geoid), 1, 5)
