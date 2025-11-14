# Database Helper Functions
# Functions for managing production and test databases safely

#' Get Database Path
#'
#' Returns the path to the database, with protection against accidental deletion.
#' For tests, use a separate test database.
#'
#' @param test Logical, whether to use test database (default FALSE)
#' @return Path to database file
#' @keywords internal
get_db_path <- function(test = FALSE) {
  cache_dir <- rappdirs::user_cache_dir("emburden")

  if (test) {
    # Test database - safe to delete
    db_name <- "emburden_test_db.sqlite"
  } else {
    # Production database - PROTECTED
    db_name <- "emburden_db.sqlite"
  }

  file.path(cache_dir, db_name)
}

#' Check if Database Exists
#'
#' @param test Logical, check test database instead of production
#' @return Logical, TRUE if database exists
#' @keywords internal
db_exists <- function(test = FALSE) {
  db_path <- get_db_path(test = test)
  file.exists(db_path)
}

#' Delete Database (PROTECTED)
#'
#' Deletes a database with safety checks. Production database requires
#' explicit confirmation.
#'
#' @param test Logical, delete test database (default TRUE)
#' @param confirm Logical, must be TRUE to delete production database
#' @return Logical, TRUE if deleted successfully
#' @keywords internal
delete_db <- function(test = TRUE, confirm = FALSE) {

  if (!test && !confirm) {
    stop(
      "Cannot delete production database without confirmation!\n",
      "To delete production database, use: delete_db(test = FALSE, confirm = TRUE)\n",
      "This should ONLY be done if you know what you're doing."
    )
  }

  db_path <- get_db_path(test = test)

  if (!file.exists(db_path)) {
    message("Database does not exist: ", db_path)
    return(FALSE)
  }

  db_type <- if (test) "TEST" else "PRODUCTION"
  message("Deleting ", db_type, " database: ", db_path)

  unlink(db_path)

  if (file.exists(db_path)) {
    warning("Failed to delete database: ", db_path)
    return(FALSE)
  }

  message("Successfully deleted ", db_type, " database")
  return(TRUE)
}

#' Get Database Connection
#'
#' @param test Logical, connect to test database instead of production
#' @return DBI connection object
#' @keywords internal
get_db_connection <- function(test = FALSE) {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package 'DBI' required for database operations")
  }
  if (!requireNamespace("RSQLite", quietly = TRUE)) {
    stop("Package 'RSQLite' required for database operations")
  }

  db_path <- get_db_path(test = test)
  cache_dir <- dirname(db_path)

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  DBI::dbConnect(RSQLite::SQLite(), db_path)
}

#' Backup Production Database
#'
#' Creates a timestamped backup of the production database
#'
#' @return Path to backup file, or NULL if no database exists
#' @keywords internal
backup_db <- function() {
  prod_db <- get_db_path(test = FALSE)

  if (!file.exists(prod_db)) {
    message("No production database to backup")
    return(NULL)
  }

  # Create backup filename with timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_dir <- file.path(dirname(prod_db), "backups")
  dir.create(backup_dir, showWarnings = FALSE, recursive = TRUE)

  backup_file <- file.path(
    backup_dir,
    paste0("emburden_db_backup_", timestamp, ".sqlite")
  )

  # Copy database
  file.copy(prod_db, backup_file, overwrite = FALSE)

  if (file.exists(backup_file)) {
    size_mb <- round(file.size(backup_file) / 1024^2, 2)
    message("Database backed up successfully!")
    message("  Location: ", backup_file)
    message("  Size: ", size_mb, " MB")
    return(backup_file)
  } else {
    warning("Backup failed!")
    return(NULL)
  }
}

#' Clear Test Database and Cache
#'
#' Safe function to clear test database and cache for testing.
#' NEVER touches production database.
#'
#' @keywords internal
clear_test_environment <- function() {
  message("Clearing test environment...")

  # Delete test database
  test_db <- get_db_path(test = TRUE)
  if (file.exists(test_db)) {
    unlink(test_db)
    message("  - Deleted test database")
  }

  # Clear test cache (but not production!)
  cache_dir <- rappdirs::user_cache_dir("emburden")
  test_csv_pattern <- "test_.*\\.csv$"

  if (dir.exists(cache_dir)) {
    test_files <- list.files(
      cache_dir,
      pattern = test_csv_pattern,
      full.names = TRUE
    )

    if (length(test_files) > 0) {
      unlink(test_files)
      message("  - Deleted ", length(test_files), " test cache files")
    }
  }

  message("Test environment cleared (production data untouched)")
  invisible(TRUE)
}
