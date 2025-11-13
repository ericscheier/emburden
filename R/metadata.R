#' List Available Income Brackets
#'
#' Returns the income brackets available for a given dataset and vintage.
#'
#' @param dataset Character, either "ami" or "fpl"
#' @param vintage Character, "2018" or "2022"
#'
#' @return Character vector of income bracket labels
#' @export
#'
#' @examples
#' list_income_brackets("ami", "2022")
#' list_income_brackets("fpl", "2018")
list_income_brackets <- function(dataset = c("ami", "fpl"),
                                  vintage = "2022") {
  dataset <- match.arg(dataset)

  if (!vintage %in% c("2018", "2022")) {
    stop("vintage must be '2018' or '2022'")
  }

  # Income brackets by dataset and vintage
  brackets <- list(
    ami_2022 = c(
      "0-30% AMI",
      "30-50% AMI",
      "50-80% AMI",
      "80-100% AMI",
      "100-120% AMI",
      "120%+ AMI"
    ),
    ami_2018 = c(
      "very_low",
      "low_mod",
      "moderate",
      "above_mod"
    ),
    fpl_2022 = c(
      "0-100%",
      "100-150%",
      "150-200%",
      "200-400%",
      "400%+"
    ),
    fpl_2018 = c(
      "0-100%",
      "100-150%",
      "150-200%",
      "200%+"
    )
  )

  key <- paste0(dataset, "_", vintage)
  return(brackets[[key]])
}


#' List Available States
#'
#' Returns all state abbreviations available in the LEAD dataset.
#'
#' @return Character vector of 51 state abbreviations (50 states + DC)
#' @export
#'
#' @examples
#' list_states()
list_states <- function() {
  c(
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL",
    "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
    "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
    "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI",
    "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
  )
}


#' List Available Columns in Cohort Data
#'
#' Returns column names and descriptions for LEAD cohort datasets.
#'
#' @param dataset Character, either "ami" or "fpl" (optional, affects available columns)
#' @param vintage Character, "2018" or "2022" (optional, affects available columns)
#'
#' @return Data frame with columns: column_name, description, data_type
#' @export
#'
#' @examples
#' list_cohort_columns()
#' list_cohort_columns("ami", "2022")
list_cohort_columns <- function(dataset = NULL, vintage = NULL) {
  # Core columns present in all datasets
  core_cols <- data.frame(
    column_name = c(
      "geoid",
      "income_bracket",
      "households",
      "total_income",
      "total_electricity_spend",
      "total_gas_spend",
      "total_other_spend"
    ),
    description = c(
      "11-digit census tract identifier (FIPS code)",
      "Income bracket category",
      "Number of households in this cohort",
      "Total household income ($)",
      "Total electricity spending ($)",
      "Total natural gas spending ($)",
      "Total other fuel spending (oil, propane, etc.) ($)"
    ),
    data_type = c(
      "character",
      "character",
      "numeric",
      "numeric",
      "numeric",
      "numeric",
      "numeric"
    ),
    stringsAsFactors = FALSE
  )

  return(core_cols)
}


#' Get Dataset Information
#'
#' Returns metadata about available LEAD datasets.
#'
#' @return Data frame with dataset information
#' @export
#'
#' @examples
#' get_dataset_info()
get_dataset_info <- function() {
  data.frame(
    dataset = c("ami", "ami", "fpl", "fpl"),
    vintage = c("2018", "2022", "2018", "2022"),
    full_name = c(
      "Area Median Income 2018",
      "Area Median Income 2022",
      "Federal Poverty Line 2018",
      "Federal Poverty Line 2022"
    ),
    income_brackets = c(4, 6, 4, 5),
    states_available = rep(51, 4),
    census_tracts = c(
      "~72,000",
      "~73,000",
      "~72,000",
      "~73,000"
    ),
    source_url = c(
      "https://data.openei.org/submissions/573",
      "https://data.openei.org/submissions/6219",
      "https://data.openei.org/submissions/573",
      "https://data.openei.org/submissions/6219"
    ),
    stringsAsFactors = FALSE
  )
}
