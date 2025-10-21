#' Format Number as Dollar Amount
#'
#' Converts numeric values to formatted dollar strings with appropriate
#' decimal places and thousand separators.
#'
#' @param x Numeric vector to format
#' @param latex Logical indicating whether to escape dollar sign for LaTeX
#'   (default: FALSE)
#'
#' @returns Character vector of formatted dollar amounts
#'
#' @export
#'
#' @examples
#' # Format dollar amounts
#' to_dollar(c(1000, 2500.50, 10000))
#'
#' # LaTeX-escaped format
#' to_dollar(c(1000, 2500.50), latex = TRUE)
to_dollar <- function(x, latex = FALSE) {
  # Handle NA before formatting
  if (all(is.na(x))) {
    return(rep("", length(x)))
  }

  if (latex) {
    y <- scales::label_dollar(largest_with_cents = 10, prefix = "\\$")(x)
  } else {
    y <- scales::label_dollar(largest_with_cents = 10)(x)
  }
  y[is.na(x)] <- ""
  return(y)
}

#' Format Number as Percentage
#'
#' Converts numeric values to formatted percentage strings with no decimal
#' places by default.
#'
#' @param x Numeric vector to format (as proportions, not percentages)
#' @param latex Logical indicating whether to escape percent sign for LaTeX
#'   (default: FALSE)
#'
#' @returns Character vector of formatted percentages
#'
#' @export
#'
#' @examples
#' # Format percentages
#' to_percent(c(0.25, 0.50, 0.123))
#'
#' # LaTeX-escaped format
#' to_percent(c(0.25, 0.50), latex = TRUE)
to_percent <- function(x, latex = FALSE) {
  # Handle NA before formatting
  if (all(is.na(x))) {
    return(rep("", length(x)))
  }

  if (latex) {
    y <- scales::label_percent(accuracy = 1, big.mark = ",", suffix = "\\%")(x)
  } else {
    y <- scales::label_percent(accuracy = 1, big.mark = ",")(x)
  }
  y[is.na(x)] <- ""
  return(y)
}

#' Format Large Numbers with Thousand Separators
#'
#' Converts numeric values to formatted strings with thousand separators (commas).
#'
#' @param x Numeric vector to format
#'
#' @returns Character vector of formatted numbers
#'
#' @export
#'
#' @examples
#' # Format large numbers
#' to_big(c(1000, 25000, 1000000))
to_big <- function(x) {
  # Handle NA before formatting
  if (all(is.na(x))) {
    return(rep("", length(x)))
  }

  y <- scales::label_comma(accuracy = 1, big.mark = ",")(x)
  y[is.na(x)] <- ""
  return(y)
}

#' Format Numbers in Millions
#'
#' Converts large numeric values to millions format with appropriate suffix.
#' Values less than 1 million are shown in thousands.
#'
#' @param x Numeric vector to format
#' @param suffix Character string to append after "million" (default: " million")
#' @param override_to_k Logical indicating whether to show values < 1M as
#'   thousands (default: TRUE)
#'
#' @returns Character vector of formatted numbers with "million" or "k" suffix
#'
#' @export
#'
#' @examples
#' # Format in millions
#' to_million(c(5000, 1000000, 2500000))
to_million <- function(x, suffix = " million", override_to_k = TRUE) {
  # Handle NA before formatting
  if (all(is.na(x))) {
    return(rep("", length(x)))
  }

  y <- ifelse(abs(x) < 10^6,
    scales::label_number(accuracy = 1, suffix = "k")(x * 10^-3),
    scales::label_number(accuracy = 0.1, suffix = suffix)(x * 10^-6)
  )
  y[is.na(x)] <- ""
  return(y)
}

#' Format Dollar Amounts in Billions
#'
#' Converts large dollar values to billions format with dollar sign prefix.
#' Values less than 1 billion are shown in millions.
#'
#' @param x Numeric vector to format
#' @param suffix Character string to append after "billion" (default: " billion")
#' @param override_to_k Logical (currently unused, kept for compatibility)
#'
#' @returns Character vector of formatted dollar amounts with "billion" or "m" suffix
#'
#' @export
#'
#' @examples
#' # Format in billions
#' to_billion_dollar(c(5000000, 1000000000, 2500000000))
to_billion_dollar <- function(x, suffix = " billion", override_to_k = TRUE) {
  # Handle NA before formatting
  if (all(is.na(x))) {
    return(rep("", length(x)))
  }

  y <- ifelse(abs(x) < 10^9,
    scales::label_number(accuracy = 1, suffix = "m", prefix = "$")(x * 10^-6),
    scales::label_number(accuracy = 0.1, suffix = suffix, prefix = "$")(x * 10^-9)
  )
  y[is.na(x)] <- ""
  return(y)
}

#' Colorize Text for Knitted Documents
#'
#' Wraps text in color formatting appropriate for the output format (LaTeX or HTML).
#' This function is intended for use within R Markdown/knitr documents.
#'
#' @param x Character string to colorize
#' @param color Character string specifying the color name (e.g., "red", "blue")
#'
#' @returns Character string wrapped in LaTeX or HTML color commands, or
#'   unchanged if output format is neither
#'
#' @details
#' This function detects the knitr output format and applies appropriate color
#' formatting. For LaTeX output, it uses `\\textcolor{}`. For HTML output, it
#' uses `<span style='color: ...'>`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # In an R Markdown document:
#' colorize("Important text", "red")
#' }
colorize <- function(x, color) {
  if (requireNamespace("knitr", quietly = TRUE)) {
    if (knitr::is_latex_output()) {
      sprintf("\\textcolor{%s}{%s}", color, x)
    } else if (knitr::is_html_output()) {
      sprintf("<span style='color: %s;'>%s</span>", color, x)
    } else {
      x
    }
  } else {
    x
  }
}
