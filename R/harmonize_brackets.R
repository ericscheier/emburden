#' Harmonize Income Brackets Across Vintages
#'
#' @description
#' Harmonizes income bracket categories when comparing data across different
#' vintage years. This is necessary because some datasets (particularly AMI)
#' have different bracket definitions across years.
#'
#' @details
#' ## Dataset-Specific Bracket Definitions
#'
#' ### AMI (Area Median Income)
#' - **2018**: 3 brackets
#'   - `very_low`: Very low income (typically <50% AMI)
#'   - `low_mod`: Low to moderate income (typically 50-80% AMI)
#'   - `mid_high`: Middle to high income (typically >80% AMI)
#' - **2022**: 5 brackets
#'   - `very_low`: Very low income (same as 2018)
#'   - `low_mod`: Low to moderate income (same as 2018)
#'   - `mid_high`: Middle to high income (narrower than 2018)
#'   - `100-150%`: 100-150% of AMI (new in 2022)
#'   - `150%+`: Above 150% of AMI (new in 2022)
#'
#' ### FPL (Federal Poverty Level)
#' - **Both 2018 and 2022**: 5 brackets
#'   - `0-100%`: Below poverty line
#'   - `100-150%`: 100-150% of FPL
#'   - `150-200%`: 150-200% of FPL
#'   - `200-400%`: 200-400% of FPL
#'   - `400%+`: Above 400% of FPL
#'
#' @param data A data frame containing income bracket data
#' @param dataset Character, either "ami" or "fpl"
#' @param vintage Integer, the year of the data vintage
#' @param strict_matching Logical, if TRUE (default) only keeps brackets that
#'   exist in both vintages being compared. If FALSE, keeps all brackets.
#' @param comparison_vintages Integer vector of length 2, the vintages being
#'   compared (e.g., c(2018, 2022)). Required when strict_matching = TRUE.
#'
#' @return A list with components:
#'   - `data`: The harmonized data frame
#'   - `warnings`: Character vector of any warnings about bracket mismatches
#'   - `dropped_brackets`: Character vector of brackets that were dropped
#'
#' @keywords internal
harmonize_income_brackets <- function(data,
                                       dataset,
                                       vintage,
                                       strict_matching = TRUE,
                                       comparison_vintages = NULL) {

  # Validate inputs
  if (!dataset %in% c("ami", "fpl")) {
    stop("dataset must be either 'ami' or 'fpl'")
  }

  if (!"income_bracket" %in% names(data)) {
    stop("data must contain an 'income_bracket' column")
  }

  # Define known bracket sets for each dataset and vintage
  known_brackets <- list(
    ami = list(
      `2018` = c("very_low", "low_mod", "mid_high"),
      `2022` = c("very_low", "low_mod", "mid_high", "100-150%", "150%+")
    ),
    fpl = list(
      `2018` = c("0-100%", "100-150%", "150-200%", "200-400%", "400%+"),
      `2022` = c("0-100%", "100-150%", "150-200%", "200-400%", "400%+")
    )
  )

  # Get expected brackets for this dataset/vintage
  expected_brackets <- known_brackets[[dataset]][[as.character(vintage)]]

  # Initialize results
  warnings_out <- character(0)
  dropped_brackets <- character(0)
  harmonized_data <- data

  # Check for unexpected brackets
  actual_brackets <- unique(data$income_bracket)
  unexpected <- setdiff(actual_brackets, expected_brackets)
  if (length(unexpected) > 0) {
    warnings_out <- c(
      warnings_out,
      sprintf(
        "Unexpected income brackets found in %s %d data: %s",
        toupper(dataset),
        vintage,
        paste(unexpected, collapse = ", ")
      )
    )
  }

  # Apply strict matching if requested
  if (strict_matching) {
    if (is.null(comparison_vintages) || length(comparison_vintages) != 2) {
      stop("comparison_vintages must be provided when strict_matching = TRUE")
    }

    # Get brackets for both vintages
    vintage1_brackets <- known_brackets[[dataset]][[as.character(comparison_vintages[1])]]
    vintage2_brackets <- known_brackets[[dataset]][[as.character(comparison_vintages[2])]]

    # Find common brackets
    common_brackets <- intersect(vintage1_brackets, vintage2_brackets)

    # Find brackets unique to each vintage
    only_vintage1 <- setdiff(vintage1_brackets, vintage2_brackets)
    only_vintage2 <- setdiff(vintage2_brackets, vintage1_brackets)

    # Create warning if there are mismatched brackets
    if (length(only_vintage1) > 0 || length(only_vintage2) > 0) {
      mismatch_msg <- sprintf(
        "Income bracket mismatch in %s dataset:",
        toupper(dataset)
      )

      if (length(only_vintage1) > 0) {
        mismatch_msg <- paste0(
          mismatch_msg,
          sprintf(
            "\n  - Only in %d: %s",
            comparison_vintages[1],
            paste(only_vintage1, collapse = ", ")
          )
        )
      }

      if (length(only_vintage2) > 0) {
        mismatch_msg <- paste0(
          mismatch_msg,
          sprintf(
            "\n  - Only in %d: %s",
            comparison_vintages[2],
            paste(only_vintage2, collapse = ", ")
          )
        )
      }

      mismatch_msg <- paste0(
        mismatch_msg,
        sprintf(
          "\n  - Keeping only common brackets: %s",
          paste(common_brackets, collapse = ", ")
        )
      )

      warnings_out <- c(warnings_out, mismatch_msg)
    }

    # Filter data to only common brackets
    brackets_to_drop <- setdiff(actual_brackets, common_brackets)
    if (length(brackets_to_drop) > 0) {
      dropped_brackets <- brackets_to_drop
      harmonized_data <- harmonized_data |>
        dplyr::filter(income_bracket %in% common_brackets)
    }
  }

  return(list(
    data = harmonized_data,
    warnings = warnings_out,
    dropped_brackets = dropped_brackets
  ))
}


#' Get Available Income Brackets for a Dataset and Vintage
#'
#' @description
#' Returns the expected income brackets for a given dataset and vintage year.
#' Useful for understanding what brackets are available before running analyses.
#'
#' @param dataset Character, either "ami" or "fpl"
#' @param vintage Integer, the year of the data vintage (e.g., 2018, 2022)
#'
#' @return Character vector of income bracket names
#'
#' @examples
#' # Get AMI brackets for 2022
#' get_income_brackets("ami", 2022)
#'
#' # Get FPL brackets for 2018
#' get_income_brackets("fpl", 2018)
#'
#' @export
get_income_brackets <- function(dataset, vintage) {
  # Validate inputs
  if (!dataset %in% c("ami", "fpl")) {
    stop("dataset must be either 'ami' or 'fpl'")
  }

  # Define known bracket sets
  known_brackets <- list(
    ami = list(
      `2018` = c("very_low", "low_mod", "mid_high"),
      `2022` = c("very_low", "low_mod", "mid_high", "100-150%", "150%+")
    ),
    fpl = list(
      `2018` = c("0-100%", "100-150%", "150-200%", "200-400%", "400%+"),
      `2022` = c("0-100%", "100-150%", "150-200%", "200-400%", "400%+")
    )
  )

  # Get brackets for this dataset/vintage
  brackets <- known_brackets[[dataset]][[as.character(vintage)]]

  if (is.null(brackets)) {
    stop(sprintf("No bracket definitions found for %s vintage %d", dataset, vintage))
  }

  return(brackets)
}
