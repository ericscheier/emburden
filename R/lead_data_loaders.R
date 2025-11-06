# Global variable bindings to satisfy R CMD check
utils::globalVariables(c("geoid", "income_bracket"))

#' Load DOE LEAD Tool Cohort Data
#'
#' Load household energy burden cohort data with automatic fallback:
#' 1. Try local database (emrgi_db.sqlite)
#' 2. Fall back to local CSV files
#' 3. Auto-download from OpenEI if neither exists
#' 4. Auto-import downloaded data to database for future use
#'
#' @param dataset Character, either "ami" (Area Median Income) or "fpl"
#'   (Federal Poverty Line)
#' @param states Character vector of state abbreviations to filter by (optional)
#' @param vintage Character, data vintage: "2018" or "2022" (default "2022")
#' @param income_brackets Character vector of income brackets to filter by (optional)
#' @param verbose Logical, print status messages (default TRUE)
#'
#' @return A tibble with columns:
#'   - geoid: Census tract identifier
#'   - income_bracket: Income bracket label
#'   - households: Number of households
#'   - total_income: Total household income ($)
#'   - total_electricity_spend: Total electricity spending ($)
#'   - total_gas_spend: Total gas spending ($)
#'   - total_other_spend: Total other fuel spending ($)
#'   - Additional demographic columns depending on vintage
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load latest (2022) NC AMI data - auto-downloads if needed!
#' nc_ami <- load_cohort_data(dataset = "ami", states = "NC")
#'
#' # Load specific vintage
#' nc_ami_2018 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2018")
#'
#' # Load multiple states
#' southeast <- load_cohort_data(dataset = "fpl", states = c("NC", "SC", "GA"))
#'
#' # Filter to specific income brackets
#' low_income <- load_cohort_data(
#'   dataset = "ami",
#'   states = "NC",
#'   income_brackets = c("0-30% AMI", "30-50% AMI")
#' )
#' }
load_cohort_data <- function(dataset = c("ami", "fpl"),
                              states = NULL,
                              vintage = "2022",
                              income_brackets = NULL,
                              verbose = TRUE) {

  # Validate inputs
  dataset <- match.arg(dataset)
  if (!vintage %in% c("2018", "2022")) {
    stop("vintage must be '2018' or '2022'")
  }

  if (verbose) {
    message("Loading ", vintage, " ", toupper(dataset), " cohort data...")
  }

  # Try database first
  data <- try_load_from_database(
    dataset = dataset,
    vintage = vintage,
    verbose = verbose
  )

  # If database fails, try CSV
  if (is.null(data)) {
    data <- try_load_from_csv(
      dataset = dataset,
      vintage = vintage,
      verbose = verbose
    )
  }

  # If CSV fails, download from OpenEI
  if (is.null(data)) {
    if (verbose) {
      message("Data not found locally. Downloading from OpenEI...")
    }
    data <- download_lead_data(
      dataset = dataset,
      vintage = vintage,
      states = states,
      verbose = verbose
    )

    # Try to import to database for future use
    if (!is.null(data)) {
      try_import_to_database(
        data = data,
        dataset = dataset,
        vintage = vintage,
        verbose = verbose
      )
    }
  }

  if (is.null(data)) {
    stop("Failed to load data from any source (database, CSV, or OpenEI)")
  }

  # Filter by states if requested
  if (!is.null(states)) {
    # Extract state FIPS from geoid (first 2 digits)
    state_fips <- get_state_fips(states)
    data <- data |>
      dplyr::filter(substr(as.character(geoid), 1, 2) %in% state_fips)

    if (verbose) {
      message("Filtered to state(s): ", paste(states, collapse = ", "))
    }
  }

  # Filter by income brackets if requested
  if (!is.null(income_brackets)) {
    data <- data |>
      dplyr::filter(income_bracket %in% income_brackets)

    if (verbose) {
      message("Filtered to ", length(income_brackets), " income bracket(s)")
    }
  }

  if (verbose) {
    message("Loaded ", nrow(data), " cohort records")
  }

  return(data)
}


#' Load Census Tract Data
#'
#' Load census tract demographics and utility service territory information
#' with automatic fallback to CSV or OpenEI download.
#'
#' @param states Character vector of state abbreviations to filter by (optional)
#' @param verbose Logical, print status messages (default TRUE)
#'
#' @return A tibble with columns:
#'   - geoid: Census tract identifier
#'   - state_abbr: State abbreviation
#'   - county_name: County name
#'   - tract_name: Tract name
#'   - utility_name: Electric utility serving this tract
#'   - Additional demographic columns
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load all NC census tracts
#' nc_tracts <- load_census_tract_data(states = "NC")
#'
#' # Load multiple states
#' southeast <- load_census_tract_data(states = c("NC", "SC", "GA"))
#' }
load_census_tract_data <- function(states = NULL, verbose = TRUE) {

  if (verbose) {
    message("Loading census tract data...")
  }

  # Try database first
  data <- try_load_tracts_from_database(verbose = verbose)

  # If database fails, try CSV
  if (is.null(data)) {
    data <- try_load_tracts_from_csv(verbose = verbose)
  }

  # If CSV fails, download from OpenEI
  if (is.null(data)) {
    if (verbose) {
      message("Data not found locally. Downloading from OpenEI...")
    }
    data <- download_census_tract_data(verbose = verbose)

    # Try to import to database for future use
    if (!is.null(data)) {
      try_import_tracts_to_database(data = data, verbose = verbose)
    }
  }

  if (is.null(data)) {
    stop("Failed to load census tract data from any source")
  }

  # Filter by states if requested
  if (!is.null(states)) {
    data <- data |>
      dplyr::filter(state_abbr %in% states)

    if (verbose) {
      message("Filtered to state(s): ", paste(states, collapse = ", "))
    }
  }

  if (verbose) {
    message("Loaded ", nrow(data), " census tracts")
  }

  return(data)
}


#' Check Available Data Sources
#'
#' Check which data sources are available locally (database, CSV files, or
#' will require download from OpenEI).
#'
#' @param verbose Logical, print detailed status (default TRUE)
#'
#' @return A list with status of each data source
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Check what data is available
#' check_data_sources()
#' }
check_data_sources <- function(verbose = TRUE) {

  # Check database
  db_path <- find_emrgi_db()
  db_available <- !is.null(db_path) && file.exists(db_path)

  if (db_available && requireNamespace("DBI", quietly = TRUE) &&
      requireNamespace("RSQLite", quietly = TRUE)) {
    tryCatch({
      conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      tables <- DBI::dbListTables(conn)
      DBI::dbDisconnect(conn)
      db_tables <- tables
    }, error = function(e) {
      db_available <- FALSE
      db_tables <- character(0)
    })
  } else {
    db_tables <- character(0)
  }

  # Check CSV files
  csv_files <- list.files(
    path = "data",
    pattern = "^(CohortData|CensusTractData|very_clean_data).*\\.csv$",
    full.names = TRUE
  )

  result <- list(
    database = list(
      available = db_available,
      path = if (db_available) db_path else NULL,
      tables = db_tables
    ),
    csv_files = list(
      available = length(csv_files) > 0,
      files = basename(csv_files)
    ),
    download_required = !db_available && length(csv_files) == 0
  )

  if (verbose) {
    cat("\n")
    cat("Data Source Status\n")
    cat(strrep("=", 60), "\n")

    cat("\nDatabase (emrgi_db.sqlite):\n")
    if (result$database$available) {
      cat("  \u2713 Available at:", result$database$path, "\n")
      if (length(result$database$tables) > 0) {
        cat("  Tables:", paste(result$database$tables, collapse = ", "), "\n")
      }
    } else {
      cat("  \u2717 Not found\n")
    }

    cat("\nCSV Files (data/):\n")
    if (result$csv_files$available) {
      cat("  \u2713 Found", length(csv_files), "CSV file(s):\n")
      for (f in result$csv_files$files) {
        cat("    -", f, "\n")
      }
    } else {
      cat("  \u2717 No CSV files found\n")
    }

    cat("\n")
    if (result$download_required) {
      cat("\u26A0 No local data found. Data will be downloaded from OpenEI on first use.\n")
    } else {
      cat("\u2713 Local data available! No download required.\n")
    }
    cat("\n")
  }

  invisible(result)
}


# Internal helper functions ------------------------------------------------

#' Try to load cohort data from database
#' @keywords internal
try_load_from_database <- function(dataset, vintage, verbose = FALSE) {

  # Check if database packages are available
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RSQLite", quietly = TRUE)) {
    if (verbose) {
      message("  DBI/RSQLite not available, skipping database")
    }
    return(NULL)
  }

  # Find database
  db_path <- find_emrgi_db()
  if (is.null(db_path) || !file.exists(db_path)) {
    if (verbose) {
      message("  Database not found, trying CSV...")
    }
    return(NULL)
  }

  # Determine table name
  table_name <- paste0("lead_", vintage, "_", dataset, "_cohorts")

  tryCatch({
    conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(conn))

    # Check if table exists
    if (!DBI::dbExistsTable(conn, table_name)) {
      if (verbose) {
        message("  Table '", table_name, "' not found in database")
      }
      return(NULL)
    }

    # Load data
    data <- DBI::dbReadTable(conn, table_name) |>
      tibble::as_tibble()

    # Standardize column names (create total_* columns if needed)
    data <- standardize_cohort_columns(data, dataset, vintage)

    if (verbose) {
      message("  \u2713 Loaded from database")
    }

    return(data)

  }, error = function(e) {
    if (verbose) {
      message("  Database error: ", e$message)
    }
    return(NULL)
  })
}


#' Try to load cohort data from CSV
#' @keywords internal
try_load_from_csv <- function(dataset, vintage, verbose = FALSE) {

  # Construct possible CSV filenames
  dataset_upper <- toupper(dataset)

  # Get cache directory for downloaded files
  cache_dir <- get_cache_dir()

  # Try multiple naming conventions used in different data sources
  # ORDER MATTERS: Try most specific/processed formats first
  possible_files <- c(
    # very_clean_data format (with vintage) - THIS IS THE CORRECT FORMAT, TRY FIRST!
    # Matches: "very_clean_data_ami_census tracts_2022.csv", "very_clean_data_ami_census tracts_2022_nc.csv", etc.
    list.files("data", pattern = paste0("^very_clean_data_", dataset, "_census tracts_", vintage, ".*\\.csv$"),
               full.names = TRUE, ignore.case = TRUE),
    # Legacy CohortData format (no vintage)
    file.path("data", paste0("CohortData_",
                             ifelse(dataset == "ami", "AreaMedianIncome", "FederalPovertyLine"),
                             ".csv")),
    # Downloaded files in cache directory (from download_lead_data function)
    # Format: "lead_2022_ami.csv", "lead_2018_fpl.csv"
    file.path(cache_dir, paste0("lead_", vintage, "_", dataset, ".csv")),
    # replica_lead format: "replica_lead_AMI_CENSUS TRACTS_2022_NC.csv"
    list.files("data", pattern = paste0("^replica_lead_", dataset_upper, "_CENSUS TRACTS_", vintage, ".*\\.csv$"),
               full.names = TRUE, ignore.case = TRUE),
    # in_poverty format: "in_poverty_data_FPL_CENSUS TRACTS_2022_NC.csv"
    list.files("data", pattern = paste0("^in_poverty_data_", dataset_upper, "_CENSUS TRACTS_", vintage, ".*\\.csv$"),
               full.names = TRUE, ignore.case = TRUE),
    # State-prefixed format: "NC AMI Census Tracts 2022.csv" - TRY LAST (raw data format)
    list.files("data", pattern = paste0("^[A-Z]{2} ", dataset_upper, " Census Tracts ", vintage, "\\.csv$"),
               full.names = TRUE, ignore.case = TRUE)
  )

  # Flatten list (list.files returns vectors, c() can nest them)
  possible_files <- unlist(possible_files)

  for (csv_file in possible_files) {
    if (file.exists(csv_file)) {
      tryCatch({
        if (verbose) {
          message("  Reading CSV: ", basename(csv_file))
        }

        data <- readr::read_csv(
          csv_file,
          show_col_types = FALSE,
          col_types = readr::cols(
            geoid = readr::col_character(),
            FIP = readr::col_character(),  # Raw data uses FIP instead of geoid
            .default = readr::col_guess()
          )
        )

        # Standardize column names
        data <- standardize_cohort_columns(data, dataset, vintage)

        if (verbose) {
          message("  \u2713 Loaded from CSV")
        }

        return(data)

      }, error = function(e) {
        if (verbose) {
          message("  CSV read error: ", e$message)
        }
      })
    }
  }

  if (verbose) {
    message("  No CSV files found, will download...")
  }

  return(NULL)
}


#' Download LEAD data from OpenEI
#' @keywords internal
download_lead_data <- function(dataset, vintage, states = NULL, verbose = FALSE) {

  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("Package 'httr' required for downloading from OpenEI. Install with: install.packages('httr')")
  }

  # For 2018, data is distributed as state-specific ZIP files
  # For 2022, data is available as direct CSV downloads
  if (vintage == "2018") {
    # 2018 requires state parameter
    if (is.null(states) || length(states) == 0) {
      stop("2018 vintage requires 'states' parameter (state abbreviation, e.g., 'NC')")
    }

    # Use first state (2018 ZIP files are per-state)
    state <- toupper(states[1])

    # ZIP file URL pattern
    zip_url <- paste0("https://data.openei.org/files/573/", state, "-2018-LEAD-data.zip")

    #CSV file name inside ZIP
    dataset_upper <- toupper(dataset)
    csv_filename <- paste0(state, " ", dataset_upper, " Census Tracts 2018.csv")

    if (verbose) {
      message("  Downloading 2018 ZIP from: ", zip_url)
      message("  Will extract: ", csv_filename)
    }

    url <- zip_url
    is_zip <- TRUE

  } else if (vintage == "2022") {
    # 2022: AMI uses direct CSV, FPL uses state ZIP files
    if (dataset == "fpl") {
      # FPL data is only available in state ZIP files (like 2018)
      if (is.null(states) || length(states) == 0) {
        stop("2022 FPL data requires 'states' parameter (state abbreviation, e.g., 'NC')")
      }

      # Use first state
      state <- toupper(states[1])

      # ZIP file URL pattern for 2022
      zip_url <- paste0("https://data.openei.org/files/6219/", state, "-2022-LEAD-data.zip")

      # CSV file name inside ZIP (note the space in filename)
      dataset_upper <- toupper(dataset)
      csv_filename <- paste0(state, " ", dataset_upper, " Census Tracts 2022.csv")

      if (verbose) {
        message("  Downloading 2022 FPL ZIP from: ", zip_url)
        message("  Will extract: ", csv_filename)
      }

      url <- zip_url
      is_zip <- TRUE

    } else {
      # AMI: Direct CSV download
      openei_urls_2022 <- list(
        ami = "https://data.openei.org/files/6219/lead_ami_tracts_2022.csv"
      )

      url <- openei_urls_2022[[dataset]]
      if (is.null(url)) {
        stop("No OpenEI URL configured for ", dataset, " ", vintage)
      }

      if (verbose) {
        message("  Downloading from: ", url)
      }

      is_zip <- FALSE
    }

  } else {
    stop("Unsupported vintage: ", vintage, ". Supported: 2018, 2022")
  }

  # Get cache directory
  cache_dir <- get_cache_dir()
  temp_file <- file.path(cache_dir, paste0("lead_", vintage, "_", dataset, "_raw.csv"))
  cache_file <- file.path(cache_dir, paste0("lead_", vintage, "_", dataset, ".csv"))

  # Download with progress
  tryCatch({
    if (is_zip) {
      # Download ZIP file first
      zip_file <- file.path(cache_dir, paste0("lead_", vintage, "_", dataset, "_temp.zip"))

      if (verbose) {
        message("  Downloading ZIP file...")
      }

      response <- httr::GET(
        url,
        httr::progress(),
        httr::write_disk(zip_file, overwrite = TRUE)
      )

      if (httr::http_error(response)) {
        stop("Download failed with status ", httr::status_code(response))
      }

      # Extract specific CSV from ZIP
      if (verbose) {
        message("  Extracting: ", csv_filename)
      }

      # List files in ZIP to verify
      zip_contents <- utils::unzip(zip_file, list = TRUE)

      if (!csv_filename %in% zip_contents$Name) {
        # Try to find a matching file (case-insensitive)
        matching_files <- grep(csv_filename, zip_contents$Name, ignore.case = TRUE, value = TRUE)
        if (length(matching_files) > 0) {
          csv_filename <- matching_files[1]
          if (verbose) {
            message("  Using matched file: ", csv_filename)
          }
        } else {
          stop("CSV file '", csv_filename, "' not found in ZIP. Available files: ",
               paste(zip_contents$Name, collapse = ", "))
        }
      }

      # Extract to temp_file location
      utils::unzip(zip_file, files = csv_filename, exdir = cache_dir, overwrite = TRUE)

      # Move extracted file to expected location
      extracted_path <- file.path(cache_dir, csv_filename)
      if (file.exists(extracted_path)) {
        file.rename(extracted_path, temp_file)
      } else {
        stop("Failed to extract ", csv_filename, " from ZIP")
      }

      # Clean up ZIP file
      unlink(zip_file)

    } else {
      # Direct CSV download (2022 behavior)
      response <- httr::GET(
        url,
        httr::progress(),
        httr::write_disk(temp_file, overwrite = TRUE)
      )

      if (httr::http_error(response)) {
        stop("Download failed with status ", httr::status_code(response))
      }
    }

    # Read the downloaded file
    raw_data <- readr::read_csv(
      temp_file,
      show_col_types = FALSE,
      col_types = readr::cols(
        .default = readr::col_guess()
      )
    )

    # Check if data needs processing (has raw microdata format)
    # Raw microdata has: FIP, HINCP, ELEP, GASP (individual records)
    # Aggregated cohort has: FIP, HINCP*UNITS, ELEP*UNITS (pre-aggregated)
    is_raw_microdata <- "HINCP" %in% names(raw_data) && !"HINCP*UNITS" %in% names(raw_data)
    is_aggregated_cohort <- "FIP" %in% names(raw_data) && any(grepl("\\*UNITS$", names(raw_data)))

    if (is_raw_microdata) {
      if (verbose) {
        message("  Processing raw microdata into cohort format...")
      }

      # Process raw → clean format using the pipeline
      data <- process_lead_cohort_data(
        data = raw_data,
        dataset = dataset,
        vintage = vintage,
        aggregate_poverty = FALSE  # Keep cohort-level detail
      )

    } else if (is_aggregated_cohort) {
      if (verbose) {
        message("  Data is aggregated cohort format, standardizing columns...")
      }

      # Data is already aggregated, just standardize column names
      data <- standardize_cohort_columns(raw_data, dataset, vintage)

      # Ensure geoid is character and properly padded
      if ("geoid" %in% names(data)) {
        data$geoid <- stringr::str_pad(as.character(data$geoid), width = 11, side = "left", pad = "0")
      }

    } else {
      if (verbose) {
        message("  Data appears pre-processed, using as-is...")
      }

      # Data is already processed, use as-is
      data <- raw_data

      # Ensure geoid is character and properly padded
      if ("geoid" %in% names(data)) {
        data$geoid <- stringr::str_pad(as.character(data$geoid), width = 11, side = "left", pad = "0")
      }
    }

    # Save processed data to cache
    readr::write_csv(data, cache_file)

    # Clean up temporary raw file
    if (file.exists(temp_file)) {
      unlink(temp_file)
    }

    # Import to database for faster subsequent loads
    if (verbose) {
      message("  Importing to database...")
    }
    try_import_to_database(data, dataset, vintage, verbose = verbose)

    if (verbose) {
      message("  \u2713 Downloaded, processed, and cached successfully")
    }

    return(data)

  }, error = function(e) {
    if (verbose) {
      message("  Download error: ", e$message)
    }
    return(NULL)
  })
}


#' Try to load census tract data from database
#' @keywords internal
try_load_tracts_from_database <- function(verbose = FALSE) {

  # Check if database packages are available
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RSQLite", quietly = TRUE)) {
    if (verbose) {
      message("  DBI/RSQLite not available, skipping database")
    }
    return(NULL)
  }

  # Find database
  db_path <- find_emrgi_db()
  if (is.null(db_path) || !file.exists(db_path)) {
    if (verbose) {
      message("  Database not found, trying CSV...")
    }
    return(NULL)
  }

  tryCatch({
    conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(conn))

    # Check for census tract table
    possible_tables <- c("census_tracts", "lead_census_tracts", "CensusTractData")

    for (table_name in possible_tables) {
      if (DBI::dbExistsTable(conn, table_name)) {
        data <- DBI::dbReadTable(conn, table_name) |>
          tibble::as_tibble()

        if (verbose) {
          message("  \u2713 Loaded from database table '", table_name, "'")
        }

        return(data)
      }
    }

    if (verbose) {
      message("  No census tract table found in database")
    }
    return(NULL)

  }, error = function(e) {
    if (verbose) {
      message("  Database error: ", e$message)
    }
    return(NULL)
  })
}


#' Try to load census tract data from CSV
#' @keywords internal
try_load_tracts_from_csv <- function(verbose = FALSE) {

  csv_file <- file.path("data", "CensusTractData.csv")

  if (!file.exists(csv_file)) {
    if (verbose) {
      message("  CSV file not found: ", csv_file)
    }
    return(NULL)
  }

  tryCatch({
    if (verbose) {
      message("  Reading CSV: ", basename(csv_file))
    }

    data <- readr::read_csv(
      csv_file,
      show_col_types = FALSE,
      col_types = readr::cols(
        geoid = readr::col_character(),
        .default = readr::col_guess()
      )
    )

    if (verbose) {
      message("  \u2713 Loaded from CSV")
    }

    return(data)

  }, error = function(e) {
    if (verbose) {
      message("  CSV read error: ", e$message)
    }
    return(NULL)
  })
}


#' Download census tract data from OpenEI
#' @keywords internal
download_census_tract_data <- function(verbose = FALSE) {

  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("Package 'httr' required for downloading. Install with: install.packages('httr')")
  }

  # OpenEI URL for census tract data (using 2022 as latest)
  url <- "https://data.openei.org/files/6219/lead_census_tracts_2022.csv"

  if (verbose) {
    message("  Downloading from: ", url)
  }

  # Get cache directory
  cache_dir <- get_cache_dir()
  cache_file <- file.path(cache_dir, "lead_census_tracts.csv")

  tryCatch({
    response <- httr::GET(
      url,
      httr::progress(),
      httr::write_disk(cache_file, overwrite = TRUE)
    )

    if (httr::http_error(response)) {
      stop("Download failed with status ", httr::status_code(response))
    }

    # Read the downloaded file
    data <- readr::read_csv(
      cache_file,
      show_col_types = FALSE,
      col_types = readr::cols(
        geoid = readr::col_character(),
        .default = readr::col_guess()
      )
    )

    if (verbose) {
      message("  \u2713 Downloaded and cached successfully")
    }

    return(data)

  }, error = function(e) {
    if (verbose) {
      message("  Download error: ", e$message)
    }
    return(NULL)
  })
}


#' Try to import cohort data to database
#' @keywords internal
try_import_to_database <- function(data, dataset, vintage, verbose = FALSE) {

  # Check if database packages are available
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RSQLite", quietly = TRUE)) {
    if (verbose) {
      message("  DBI/RSQLite not available, skipping database import")
    }
    return(FALSE)
  }

  # Find or create database
  db_path <- find_emrgi_db()
  if (is.null(db_path)) {
    # Create in default location
    db_path <- file.path("data", "emrgi_db.sqlite")
    dir.create("data", showWarnings = FALSE, recursive = TRUE)
  }

  table_name <- paste0("lead_", vintage, "_", dataset, "_cohorts")

  tryCatch({
    conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(conn))

    DBI::dbWriteTable(conn, table_name, data, overwrite = TRUE)

    if (verbose) {
      message("  \u2713 Imported to database table '", table_name, "'")
    }

    return(TRUE)

  }, error = function(e) {
    if (verbose) {
      message("  Database import error: ", e$message)
    }
    return(FALSE)
  })
}


#' Try to import census tract data to database
#' @keywords internal
try_import_tracts_to_database <- function(data, verbose = FALSE) {

  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RSQLite", quietly = TRUE)) {
    return(FALSE)
  }

  db_path <- find_emrgi_db()
  if (is.null(db_path)) {
    db_path <- file.path("data", "emrgi_db.sqlite")
    dir.create("data", showWarnings = FALSE, recursive = TRUE)
  }

  tryCatch({
    conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(conn))

    DBI::dbWriteTable(conn, "census_tracts", data, overwrite = TRUE)

    if (verbose) {
      message("  \u2713 Imported to database table 'census_tracts'")
    }

    return(TRUE)

  }, error = function(e) {
    if (verbose) {
      message("  Database import error: ", e$message)
    }
    return(FALSE)
  })
}


#' Find emrgi_db.sqlite database
#' @keywords internal
find_emrgi_db <- function() {

  # Check environment variable first
  env_path <- Sys.getenv("EMRGI_DB_PATH")
  if (nzchar(env_path) && file.exists(env_path)) {
    return(env_path)
  }

  # Check local data directory
  local_path <- file.path("data", "emrgi_db.sqlite")
  if (file.exists(local_path)) {
    return(local_path)
  }

  return(NULL)
}


#' Get cache directory for downloaded files
#' @keywords internal
get_cache_dir <- function() {

  if (requireNamespace("rappdirs", quietly = TRUE)) {
    cache_dir <- rappdirs::user_cache_dir("emburden")
  } else {
    cache_dir <- file.path(tempdir(), "emburden_cache")
  }

  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  return(cache_dir)
}


#' Standardize cohort column names across vintages
#' @keywords internal
standardize_cohort_columns <- function(data, dataset, vintage) {

  # Handle raw data that uses FIP instead of geoid
  if ("FIP" %in% names(data) && !"geoid" %in% names(data)) {
    data <- data |>
      dplyr::rename(geoid = FIP)
  }

  # Ensure geoid is character
  if ("geoid" %in% names(data)) {
    data$geoid <- as.character(data$geoid)
  }

  # Handle aggregated cohort format column names
  # These columns come from 2022 FPL ZIP files (aggregated format)
  if ("FPL150" %in% names(data) && !"income_bracket" %in% names(data)) {
    data <- data |>
      dplyr::rename(income_bracket = FPL150)
  }

  if ("UNITS" %in% names(data) && !"households" %in% names(data)) {
    data <- data |>
      dplyr::rename(households = UNITS)
  }

  if ("HINCP*UNITS" %in% names(data) && !"total_income" %in% names(data)) {
    data <- data |>
      dplyr::rename(total_income = `HINCP*UNITS`)
  }

  if ("ELEP*UNITS" %in% names(data) && !"total_electricity_spend" %in% names(data)) {
    data <- data |>
      dplyr::rename(total_electricity_spend = `ELEP*UNITS`)
  }

  if ("GASP*UNITS" %in% names(data) && !"total_gas_spend" %in% names(data)) {
    data <- data |>
      dplyr::rename(total_gas_spend = `GASP*UNITS`)
  }

  if ("FULP*UNITS" %in% names(data) && !"total_other_spend" %in% names(data)) {
    data <- data |>
      dplyr::rename(total_other_spend = `FULP*UNITS`)
  }

  # Standardize income bracket column name (for processed data)
  income_col <- if (dataset == "ami") "ami_bracket" else "fpl_bracket"
  if (income_col %in% names(data) && !"income_bracket" %in% names(data)) {
    data <- data |>
      dplyr::rename(income_bracket = !!income_col)
  }

  # Standardize income bracket values across vintages
  # Map 2018 percentage-based brackets to 2022 categorical brackets
  if ("income_bracket" %in% names(data)) {
    data <- data |>
      dplyr::mutate(
        income_bracket = dplyr::case_when(
          # Map 2018 AMI percentage brackets to standard categories
          income_bracket == "0-30%" ~ "very_low",
          income_bracket == "30-60%" ~ "low_mod",
          income_bracket == "60-80%" ~ "low_mod",
          income_bracket == "80-100%" ~ "mid_high",
          income_bracket == "100%+" ~ "mid_high",
          # Keep 2022 brackets as-is
          income_bracket %in% c("very_low", "low_mod", "mid_high") ~ income_bracket,
          # For FPL brackets, keep as-is (not standardizing FPL yet)
          TRUE ~ income_bracket
        )
      )
  }

  # Create total_* columns from per-household columns if needed
  # The "total" columns represent household-weighted sums for proper aggregation
  if ("income" %in% names(data) && !"total_income" %in% names(data)) {
    data$total_income <- data$income * data$households
  }

  if ("electricity_spend" %in% names(data) && !"total_electricity_spend" %in% names(data)) {
    data$total_electricity_spend <- data$electricity_spend * data$households
  }

  if ("gas_spend" %in% names(data) && !"total_gas_spend" %in% names(data)) {
    data$total_gas_spend <- data$gas_spend * data$households
  }

  if ("other_spend" %in% names(data) && !"total_other_spend" %in% names(data)) {
    data$total_other_spend <- data$other_spend * data$households
  }

  # Ensure required columns exist
  required_cols <- c("geoid", "income_bracket", "households",
                     "total_income", "total_electricity_spend")

  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    warning("Missing expected columns: ", paste(missing_cols, collapse = ", "))
  }

  return(data)
}


#' Get state FIPS codes from abbreviations
#' @keywords internal
get_state_fips <- function(state_abbrs) {

  # State FIPS lookup table
  state_fips_table <- c(
    AL = "01", AK = "02", AZ = "04", AR = "05", CA = "06",
    CO = "08", CT = "09", DE = "10", FL = "12", GA = "13",
    HI = "15", ID = "16", IL = "17", IN = "18", IA = "19",
    KS = "20", KY = "21", LA = "22", ME = "23", MD = "24",
    MA = "25", MI = "26", MN = "27", MS = "28", MO = "29",
    MT = "30", NE = "31", NV = "32", NH = "33", NJ = "34",
    NM = "35", NY = "36", NC = "37", ND = "38", OH = "39",
    OK = "40", OR = "41", PA = "42", RI = "44", SC = "45",
    SD = "46", TN = "47", TX = "48", UT = "49", VT = "50",
    VA = "51", WA = "53", WV = "54", WI = "55", WY = "56",
    DC = "11", PR = "72"
  )

  fips <- state_fips_table[toupper(state_abbrs)]

  if (any(is.na(fips))) {
    missing <- state_abbrs[is.na(fips)]
    stop("Invalid state abbreviation(s): ", paste(missing, collapse = ", "))
  }

  return(unname(fips))
}
