#' Process raw LEAD data into clean format
#'
#' Converts raw LEAD data downloaded from OpenEI into a standardized clean format
#' suitable for analysis. Handles both 2016 (SH) and 2018+ ACS vintages.
#'
#' @param data A data frame of raw LEAD data from OpenEI
#' @param vintage Character string indicating the ACS vintage year ("2016", "2018", "2022", etc.)
#'
#' @return A data frame with standardized column names:
#'   \item{geoid}{11-digit census tract GEOID as character}
#'   \item{state_abbr}{2-letter state abbreviation (2018+ only)}
#'   \item{housing_tenure}{Housing tenure category}
#'   \item{year_constructed}{Year building was constructed category}
#'   \item{building_type}{Building type category}
#'   \item{min_units}{Minimum number of units in building}
#'   \item{detached}{Whether building is detached (1/0)}
#'   \item{primary_heating_fuel}{Primary heating fuel type}
#'   \item{income_bracket}{Income bracket category (depends on dataset: AMI, FPL, etc.)}
#'   \item{households}{Number of households}
#'   \item{income}{Annual income}
#'   \item{electricity_spend}{Annual electricity spending}
#'   \item{gas_spend}{Annual gas spending}
#'   \item{other_spend}{Annual other fuel spending}
#'
#' @keywords internal
#' @export
raw_to_lead <- function(data, vintage) {

  if (is.character(vintage)) {
    vintage <- as.integer(vintage)
  }

  # Handle 2018+ format (most common)
  if (vintage >= 2018) {

    # Extract building type ranges for min_units and detached
    bld_types <- unique(data$BLD)
    bld_ranges <- stringr::str_extract_all(bld_types, "[0-9]+", simplify = TRUE)
    bld_ranges <- apply(bld_ranges, c(1, 2), as.numeric)
    bld_ranges <- data.frame(bld_ranges)
    names(bld_ranges) <- c("min_units", "max_units")
    bld_ranges$BLD <- bld_types
    bld_ranges$detached <- as.numeric(stringr::str_detect(bld_ranges$BLD, "DETACHED"))

    # Merge building attributes
    data <- merge(data, bld_ranges[c("BLD", "min_units", "detached")],
                  by = "BLD",
                  all.x = TRUE)

    # Identify income bracket column (AMI68, FPL15, SMI, etc.)
    possible_colnames <- c("AMI68", "FPL15", "SMI")
    income_bracket_colname <- names(data)[stringr::str_detect(names(data), paste(possible_colnames, collapse = "|"))]

    # Ensure geoid (FIP) is properly formatted as 11-digit character
    data$FIP <- stringr::str_pad(as.character(data$FIP), width = 11, side = "left", pad = "0")

    # Select and rename columns to standard names
    data <- dplyr::select(data,
                          geoid = `FIP`,
                          state_abbr = `ABV`,
                          housing_tenure = `TEN`,
                          year_constructed = `YBL6`,
                          building_type = `BLD`,
                          min_units,
                          detached,
                          primary_heating_fuel = `HFL`,
                          income_bracket = !!rlang::sym(income_bracket_colname),
                          households = `UNITS`,
                          income = `HINCP`,
                          electricity_spend = `ELEP`,
                          gas_spend = `GASP`,
                          other_spend = `FULP`)

  } else {
    # Handle 2016 (SH) format
    # Note: This is a simplified version - full implementation would include
    # data dictionary parsing and more complex transformations
    stop("2016 vintage processing not fully implemented yet. Please use 2018+ data.")
  }

  return(data)
}


#' Aggregate LEAD data by poverty status
#'
#' Consolidates LEAD cohort data by poverty status, aggregating households
#' and computing weighted averages for income and spending.
#'
#' @param data A data frame of processed LEAD data (output from raw_to_lead)
#' @param dataset Character string indicating income metric: "ami", "fpl", or "smi"
#'
#' @return A data frame aggregated by geoid, poverty status, housing attributes
#'
#' @keywords internal
#' @export
lead_to_poverty <- function(data, dataset) {

  # Determine poverty cutoff based on income metric
  if (tolower(dataset) %in% c("fpl", "fpl15")) {
    poverty_cutoff <- "0-100%"
    poverty_label_below <- "Below Federal Poverty Line"
    poverty_label_above <- "Above Federal Poverty Line"
  } else if (tolower(dataset) %in% c("ami", "ami68")) {
    poverty_cutoff <- "very_low"  # Below 80% of AMI
    poverty_label_below <- "Below AMI Poverty Line"
    poverty_label_above <- "Above AMI Poverty Line"
  } else {
    stop("Unknown dataset type: ", dataset, ". Must be 'ami' or 'fpl'.")
  }

  # Create binary poverty indicator
  data$income_bracket <- as.factor(ifelse(
    data$income_bracket == poverty_cutoff,
    poverty_label_below,
    poverty_label_above
  ))

  # Consolidate housing tenure
  data$housing_tenure <- dplyr::recode_factor(data$housing_tenure,
                                              `OWNER` = "owned",
                                              `RENTER` = "rented")

  # Create number of units category
  data$number_of_units <- as.factor(ifelse(
    data$min_units > 1,
    "multi-family",
    "single-family"
  ))

  # Group columns for aggregation
  group_columns <- c("geoid",
                     "primary_heating_fuel",
                     "income_bracket",
                     "number_of_units",
                     "housing_tenure")

  # Aggregate by group, computing weighted averages
  data <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_columns))) |>
    dplyr::mutate(group_households = sum(as.numeric(households), na.rm = TRUE)) |>
    dplyr::summarise(
      households = sum(as.numeric(households), na.rm = TRUE),
      income = sum(as.numeric(income) * group_households, na.rm = TRUE) /
        sum(group_households, na.rm = TRUE),
      electricity_spend = sum(as.numeric(electricity_spend) * group_households, na.rm = TRUE) /
        sum(group_households, na.rm = TRUE),
      gas_spend = sum(as.numeric(gas_spend) * group_households, na.rm = TRUE) /
        sum(group_households, na.rm = TRUE),
      other_spend = sum(as.numeric(other_spend) * group_households, na.rm = TRUE) /
        sum(group_households, na.rm = TRUE),
      pct_detached = sum(as.numeric(detached) * group_households, na.rm = TRUE) /
        sum(group_households, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::ungroup()

  return(data)
}


#' Process raw LEAD data into analysis-ready format with energy metrics
#'
#' This is the main processing workflow that:
#' 1. Converts raw OpenEI data to clean format
#' 2. Optionally aggregates by poverty status
#' 3. Adds energy burden and related metrics
#' 4. Filters out zero-energy records
#'
#' @param data A data frame of raw LEAD data from OpenEI
#' @param dataset Character string indicating dataset type ("ami" or "fpl")
#' @param vintage Character string indicating ACS vintage year
#' @param aggregate_poverty Logical; if TRUE, aggregate to poverty status level
#'
#' @return A data frame ready for analysis with all energy metrics
#'
#' @keywords internal
#' @export
process_lead_cohort_data <- function(data, dataset, vintage, aggregate_poverty = FALSE) {

  # Step 1: Convert raw → clean format
  data <- raw_to_lead(data, vintage)

  # Step 2: Optionally aggregate by poverty status
  if (aggregate_poverty) {
    data <- lead_to_poverty(data, dataset)
  }

  # Step 3: Calculate derived metrics
  # Ensure numeric columns
  data <- data |>
    dplyr::mutate(
      income = as.numeric(income),
      electricity_spend = as.numeric(electricity_spend),
      gas_spend = as.numeric(gas_spend),
      other_spend = as.numeric(other_spend),
      households = as.numeric(households)
    )

  # Calculate total energy cost
  data$energy_cost <- rowSums(dplyr::select(data, electricity_spend, gas_spend, other_spend), na.rm = TRUE)
  data$energy_cost <- ifelse(abs(data$energy_cost) < 1, 0, data$energy_cost)

  # Calculate energy burden (as fraction, not percentage)
  data$energy_burden <- ifelse(data$income > 0, data$energy_cost / data$income, NA_real_)

  # Filter out zero-energy records (required for analysis)
  data <- data[data$energy_cost != 0, ]

  return(data)
}
