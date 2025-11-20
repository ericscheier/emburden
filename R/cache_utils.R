#' Cache and Database Management Utilities
#'
#' @name cache_utils
#' @keywords internal
NULL

#' Get the emburden cache directory
#' @keywords internal
get_cache_dir <- function() {
  rappdirs::user_cache_dir("emburden", "emburden")
}

#' Get the emburden database directory
#' @keywords internal
get_database_dir <- function() {
  rappdirs::user_data_dir("emburden", "emburden")
}

#' Get the full path to the emburden database file
#' @keywords internal
get_database_path <- function() {
  file.path(get_database_dir(), "emburden_db.sqlite")
}

#' Detect potentially corrupted database data
#'
#' Checks if loaded data appears corrupted (too small, missing states, missing columns).
#' **Does NOT automatically delete** - only warns and provides recommendations.
#'
#' @param data Data frame to check
#' @param dataset Character, "ami" or "fpl"
#' @param vintage Character, "2018" or "2022"
#' @param states Character vector of expected states (NULL = all US states)
#' @param verbose Logical, print warnings
#'
#' @return List with: is_corrupted (logical), issues (character vector), recommendation (character)
#' @keywords internal
detect_database_corruption <- function(data, dataset, vintage, states = NULL, verbose = TRUE) {

  if (is.null(data) || nrow(data) == 0) {
    return(list(
      is_corrupted = TRUE,
      issues = "Data is NULL or empty",
      recommendation = "Skip database and load from CSV/OpenEI"
    ))
  }

  issues <- character()

  # Expected states (all US if not specified)
  expected_states <- if (is.null(states)) 51 else length(unique(states))

  # Check 1: Suspiciously small dataset
  # Nationwide datasets should have >100k rows, single state >500 rows
  min_expected_rows <- if (expected_states == 1) 500 else 100000

  if (nrow(data) < min_expected_rows) {
    issues <- c(issues, sprintf(
      "Dataset too small: %s rows (expected >%s)",
      format(nrow(data), big.mark = ","),
      format(min_expected_rows, big.mark = ",")
    ))
  }

  # Check 2: Missing required columns
  required_cols <- c("geoid", "income_bracket", "households")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    issues <- c(issues, sprintf(
      "Missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Check 3: State coverage (if geoid available)
  if ("geoid" %in% names(data)) {
    state_fips <- unique(substr(as.character(data$geoid), 1, 2))
    actual_states <- length(state_fips)

    # For nationwide, expect at least 80% of states (40+ out of 51)
    if (expected_states > 10 && actual_states < expected_states * 0.8) {
      issues <- c(issues, sprintf(
        "Incomplete state coverage: %d states found (expected ~%d)",
        actual_states, expected_states
      ))
    }
  }

  # Check 4: state_abbr column exists and has data
  if ("state_abbr" %in% names(data)) {
    unique_states <- length(unique(data$state_abbr))
    if (expected_states > 10 && unique_states < expected_states * 0.8) {
      issues <- c(issues, sprintf(
        "state_abbr column shows only %d states (expected ~%d)",
        unique_states, expected_states
      ))
    }
  }

  is_corrupted <- length(issues) > 0

  # Generate recommendation
  recommendation <- if (is_corrupted) {
    paste(
      "Database data appears corrupted.",
      "Recommendation:",
      "  1. Delete database table for this dataset, OR",
      "  2. Delete entire database file if multiple datasets affected, OR",
      sprintf("  3. Run: clear_dataset_cache('%s', '%s')", dataset, vintage),
      sep = "\n"
    )
  } else {
    "Data appears valid"
  }

  # Print warning if corrupted
  if (is_corrupted && verbose) {
    message("\n\u26A0  WARNING: Potential database corruption detected")
    message("   Dataset: ", toupper(dataset), " ", vintage)
    message("   Issues:")
    for (issue in issues) {
      message("     - ", issue)
    }
    message("\n", recommendation, "\n")
  }

  list(
    is_corrupted = is_corrupted,
    issues = issues,
    recommendation = recommendation
  )
}

#' Validate data before caching to database
#'
#' Performs comprehensive validation BEFORE data is saved to database or cache.
#' Prevents corrupted data from being cached in the first place.
#'
#' @param data Data frame to validate
#' @param dataset Character, "ami" or "fpl"
#' @param vintage Character, "2018" or "2022"
#' @param expected_states Integer, expected number of states (51 for nationwide)
#' @param strict Logical, if TRUE throws errors; if FALSE returns list with validation results
#'
#' @return If strict=FALSE, returns list with: valid (logical), issues (character vector)
#'         If strict=TRUE, throws error on validation failure
#' @keywords internal
validate_before_caching <- function(data, dataset, vintage, expected_states = 51, strict = TRUE) {

  issues <- character()

  # Check 1: Data exists
  if (is.null(data) || nrow(data) == 0) {
    issues <- c(issues, "Data is NULL or empty")
  } else {

    # Check 2: Required columns present
    required_cols <- c("geoid", "income_bracket", "households",
                       "total_income", "total_electricity_spend")
    missing_cols <- setdiff(required_cols, names(data))

    if (length(missing_cols) > 0) {
      issues <- c(issues, sprintf(
        "Missing required columns: %s",
        paste(missing_cols, collapse = ", ")
      ))
    }

    # Check 3: Minimum row count (varies by scope)
    min_rows <- if (expected_states == 1) 500 else 100000
    if (nrow(data) < min_rows) {
      issues <- c(issues, sprintf(
        "Dataset too small: %s rows (expected >%s)",
        format(nrow(data), big.mark = ","),
        format(min_rows, big.mark = ",")
      ))
    }

    # Check 4: State coverage (for nationwide datasets)
    if (expected_states > 10 && "geoid" %in% names(data)) {
      state_fips <- unique(substr(as.character(data$geoid), 1, 2))
      actual_states <- length(state_fips)

      if (actual_states < expected_states * 0.9) {  # Require 90%+ coverage
        issues <- c(issues, sprintf(
          "Incomplete state coverage: %d states (expected %d)",
          actual_states, expected_states
        ))
      }
    }

    # Check 5: Income bracket has detailed values (not binary)
    if ("income_bracket" %in% names(data)) {
      unique_brackets <- length(unique(data$income_bracket))
      if (unique_brackets < 3) {
        issues <- c(issues, sprintf(
          "Income brackets appear binary (%d unique values, expected 5+)",
          unique_brackets
        ))
      }
    }

    # Check 6: No all-NA columns
    na_cols <- names(data)[sapply(data, function(x) all(is.na(x)))]
    if (length(na_cols) > 0) {
      issues <- c(issues, sprintf(
        "Columns with all NA values: %s",
        paste(na_cols, collapse = ", ")
      ))
    }
  }

  valid <- length(issues) == 0

  # Handle strict mode
  if (strict && !valid) {
    stop(
      "Data validation failed before caching:\n",
      paste("  -", issues, collapse = "\n"),
      "\n\nData will NOT be cached to prevent corruption."
    )
  }

  list(
    valid = valid,
    issues = issues
  )
}

#' Clear cache for a specific dataset
#'
#' Removes cached CSV files and database entries for a specific dataset/vintage.
#' Useful when you know a specific dataset is corrupted.
#'
#' @param dataset Character, "ami" or "fpl"
#' @param vintage Character, "2018" or "2022"
#' @param verbose Logical, print progress messages
#'
#' @return Invisibly returns number of items cleared
#' @export
#'
#' @examples
#' \dontrun{
#' # Clear corrupted AMI 2018 cache
#' clear_dataset_cache("ami", "2018")
#'
#' # Clear FPL 2022 cache
#' clear_dataset_cache("fpl", "2022", verbose = TRUE)
#' }
clear_dataset_cache <- function(dataset = c("ami", "fpl"), vintage = c("2018", "2022"), verbose = TRUE) {

  dataset <- match.arg(dataset)
  vintage <- match.arg(vintage)

  if (verbose) {
    message("Clearing cache for ", toupper(dataset), " ", vintage, "...")
  }

  cleared <- 0

  # 1. Clear CSV cache files
  cache_dir <- get_cache_dir()
  cache_files <- c(
    file.path(cache_dir, sprintf("lead_%s_%s.csv", vintage, dataset)),
    file.path(cache_dir, sprintf("lead_%s_%s_temp.zip", vintage, dataset))
  )

  for (f in cache_files) {
    if (file.exists(f)) {
      unlink(f)
      cleared <- cleared + 1
      if (verbose) message("  \u2713 Deleted: ", basename(f))
    }
  }

  # 2. Clear database table
  db_path <- get_database_path()

  if (file.exists(db_path)) {
    # Try multiple table name formats
    table_names <- c(
      sprintf("%s_cohorts_%s", dataset, vintage),
      sprintf("lead_%s_%s_cohorts", vintage, dataset),
      sprintf("lead_%s_cohorts_%s", dataset, vintage)
    )

    tryCatch({
      conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)

      for (table_name in table_names) {
        if (DBI::dbExistsTable(conn, table_name)) {
          DBI::dbExecute(conn, sprintf("DROP TABLE IF EXISTS %s", table_name))
          cleared <- cleared + 1
          if (verbose) message("  \u2713 Deleted database table: ", table_name)
        }
      }

      DBI::dbDisconnect(conn)
    }, error = function(e) {
      if (verbose) message("  \u26A0  Could not access database: ", e$message)
    })
  }

  if (verbose) {
    message("\u2713 Cleared ", cleared, " cache item(s) for ", toupper(dataset), " ", vintage)
  }

  invisible(cleared)
}

#' Clear all emburden cache and database
#'
#' Nuclear option: clears ALL cached data and database.
#' Use with caution - will require re-downloading all data.
#'
#' @param confirm Logical, must be TRUE to proceed (safety check)
#' @param verbose Logical, print progress messages
#'
#' @return Invisibly returns list with: cache_cleared (logical), db_cleared (logical)
#' @export
#'
#' @examples
#' \dontrun{
#' # Clear everything (requires confirm = TRUE)
#' clear_all_cache(confirm = TRUE)
#' }
clear_all_cache <- function(confirm = FALSE, verbose = TRUE) {

  if (!confirm) {
    stop(
      "This will delete ALL cached data and the database.\n",
      "All data will need to be re-downloaded from OpenEI.\n",
      "To proceed, call: clear_all_cache(confirm = TRUE)"
    )
  }

  if (verbose) {
    message("Clearing ALL emburden cache and database...")
  }

  results <- list(cache_cleared = FALSE, db_cleared = FALSE)

  # 1. Clear cache directory
  cache_dir <- get_cache_dir()
  if (dir.exists(cache_dir)) {
    unlink(cache_dir, recursive = TRUE)
    results$cache_cleared <- TRUE
    if (verbose) message("  \u2713 Deleted cache directory: ", cache_dir)
  }

  # 2. Clear database file
  db_path <- get_database_path()
  if (file.exists(db_path)) {
    unlink(db_path)
    results$db_cleared <- TRUE
    if (verbose) message("  \u2713 Deleted database: ", db_path)
  }

  if (verbose) {
    message("\u2713 All cache and database cleared")
    message("  Note: Data will be re-downloaded from OpenEI on next use")
  }

  invisible(results)
}
