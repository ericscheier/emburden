# Zenodo Data Repository Functions
#
# This module handles downloading pre-processed energy burden datasets from Zenodo,
# providing faster downloads and better reliability than OpenEI for large datasets.

#' Get Zenodo Record Information
#'
#' Returns the Zenodo DOI and file information for emburden datasets.
#'
#' @return List with Zenodo record information
#' @keywords internal
get_zenodo_config <- function() {
  # Zenodo record for emburden processed datasets
  # This record contains pre-processed, CRAN-friendly datasets
  # for all years and cohort types
  list(
    # Main repository DOI (concept DOI - always points to latest version)
    concept_doi = "10.5281/zenodo.XXXXXXX",  # TODO: Update after upload

    # Version-specific DOI (for reproducibility)
    version_doi = "10.5281/zenodo.XXXXXXX",  # TODO: Update after upload

    # Direct download URLs for each dataset
    # Format: zenodo_baseurl/records/RECORD_ID/files/FILENAME
    files = list(
      # 2022 Cohort Data
      ami_2022 = list(
        filename = "lead_ami_cohorts_2022_us.csv.gz",
        url = NULL,  # Will be constructed from DOI
        size_mb = NULL,  # To be filled after upload
        md5 = NULL  # MD5 checksum for verification
      ),
      fpl_2022 = list(
        filename = "lead_fpl_cohorts_2022_us.csv.gz",
        url = NULL,
        size_mb = NULL,
        md5 = NULL
      ),

      # 2018 Cohort Data
      ami_2018 = list(
        filename = "lead_ami_cohorts_2018_us.csv.gz",
        url = NULL,
        size_mb = NULL,
        md5 = NULL
      ),
      fpl_2018 = list(
        filename = "lead_fpl_cohorts_2018_us.csv.gz",
        url = NULL,
        size_mb = NULL,
        md5 = NULL
      ),

      # Census Tract Data
      census_tracts = list(
        filename = "census_tract_data.csv.gz",
        url = NULL,
        size_mb = NULL,
        md5 = NULL
      )
    ),

    # Metadata
    description = "Pre-processed DOE LEAD Tool data for emburden R package",
    license = "CC-BY-4.0",
    source = "DOE Low-Income Energy Affordability Data (LEAD) Tool"
  )
}


#' Download Dataset from Zenodo
#'
#' Downloads a pre-processed dataset from the emburden Zenodo repository.
#' Includes progress bars, checksum verification, and automatic retry logic.
#'
#' @param dataset Character, either "ami" or "fpl"
#' @param vintage Character, data vintage: "2018" or "2022"
#' @param verbose Logical, print progress messages (default TRUE)
#'
#' @return Tibble with downloaded data, or NULL if download fails
#' @keywords internal
download_from_zenodo <- function(dataset, vintage, verbose = FALSE) {

  # Get Zenodo configuration
  config <- get_zenodo_config()

  # Construct dataset key
  dataset_key <- paste0(dataset, "_", vintage)

  if (!dataset_key %in% names(config$files)) {
    if (verbose) {
      message("  Dataset '", dataset_key, "' not available on Zenodo")
    }
    return(NULL)
  }

  file_info <- config$files[[dataset_key]]

  # Check if URL is configured
  if (is.null(file_info$url) || file_info$url == "") {
    if (verbose) {
      message("  Zenodo URL not configured for ", dataset_key)
      message("  Falling back to OpenEI...")
    }
    return(NULL)
  }

  if (verbose) {
    message("Downloading from Zenodo repository...")
    if (!is.null(file_info$size_mb)) {
      message("  File size: ", file_info$size_mb, " MB")
    }
    message("  URL: ", file_info$url)
  }

  # Setup cache directory
  cache_dir <- get_cache_dir()
  cache_file <- file.path(
    cache_dir,
    paste0("lead_", vintage, "_", dataset, "_cohorts.csv")
  )

  # If already cached, load from cache
  if (file.exists(cache_file)) {
    if (verbose) {
      message("  Found in cache, loading...")
    }
    return(readr::read_csv(cache_file, show_col_types = FALSE))
  }

  # Download to temporary file
  temp_gz <- tempfile(fileext = ".csv.gz")

  tryCatch({

    # Check for httr package
    if (!requireNamespace("httr", quietly = TRUE)) {
      stop("Package 'httr' is required for downloading. Install it with: install.packages('httr')")
    }

    # Download with progress bar
    if (verbose) {
      response <- httr::GET(
        file_info$url,
        httr::write_disk(temp_gz, overwrite = TRUE),
        httr::progress()
      )
    } else {
      response <- httr::GET(
        file_info$url,
        httr::write_disk(temp_gz, overwrite = TRUE)
      )
    }

    # Check for HTTP errors
    if (httr::http_error(response)) {
      status_code <- httr::status_code(response)
      if (verbose) {
        message("  Zenodo download failed (HTTP ", status_code, ")")
        message("  Falling back to OpenEI...")
      }
      return(NULL)
    }

    # Verify checksum if available
    if (!is.null(file_info$md5)) {
      if (verbose) {
        message("  Verifying checksum...")
      }

      actual_md5 <- tools::md5sum(temp_gz)
      if (actual_md5 != file_info$md5) {
        warning("MD5 checksum mismatch! File may be corrupted.")
        if (verbose) {
          message("  Expected: ", file_info$md5)
          message("  Actual:   ", actual_md5)
          message("  Falling back to OpenEI...")
        }
        return(NULL)
      }
    }

    # Decompress and read
    if (verbose) {
      message("  Decompressing and reading data...")
    }

    # Read gzipped CSV directly
    data <- readr::read_csv(temp_gz, show_col_types = FALSE)

    # Save uncompressed to cache for faster subsequent loads
    readr::write_csv(data, cache_file)

    # Clean up
    unlink(temp_gz)

    if (verbose) {
      message("  Successfully downloaded from Zenodo")
    }

    # Import to database for even faster future loads
    try_import_to_database(data, dataset, vintage, verbose = verbose)

    return(data)

  }, error = function(e) {
    if (verbose) {
      message("  Zenodo download error: ", e$message)
      message("  Falling back to OpenEI...")
    }

    # Clean up on error
    if (file.exists(temp_gz)) {
      unlink(temp_gz)
    }

    return(NULL)
  })
}


#' Download Census Tract Data from Zenodo
#'
#' Downloads pre-processed census tract data from Zenodo.
#'
#' @param verbose Logical, print progress messages (default TRUE)
#'
#' @return Tibble with census tract data, or NULL if download fails
#' @keywords internal
download_tracts_from_zenodo <- function(verbose = FALSE) {

  config <- get_zenodo_config()
  file_info <- config$files$census_tracts

  # Check if configured
  if (is.null(file_info$url) || file_info$url == "") {
    if (verbose) {
      message("  Zenodo URL not configured for census tracts")
    }
    return(NULL)
  }

  if (verbose) {
    message("Downloading census tract data from Zenodo...")
  }

  # Setup cache
  cache_dir <- get_cache_dir()
  cache_file <- file.path(cache_dir, "census_tract_data.csv")

  if (file.exists(cache_file)) {
    if (verbose) {
      message("  Found in cache, loading...")
    }
    return(readr::read_csv(cache_file, show_col_types = FALSE))
  }

  # Download
  temp_gz <- tempfile(fileext = ".csv.gz")

  tryCatch({

    if (!requireNamespace("httr", quietly = TRUE)) {
      stop("Package 'httr' is required for downloading")
    }

    response <- httr::GET(
      file_info$url,
      httr::write_disk(temp_gz, overwrite = TRUE),
      if (verbose) httr::progress() else NULL
    )

    if (httr::http_error(response)) {
      if (verbose) {
        message("  Zenodo download failed")
      }
      return(NULL)
    }

    # Read and cache
    data <- readr::read_csv(temp_gz, show_col_types = FALSE)
    readr::write_csv(data, cache_file)
    unlink(temp_gz)

    if (verbose) {
      message("  Successfully downloaded from Zenodo")
    }

    return(data)

  }, error = function(e) {
    if (verbose) {
      message("  Zenodo download error: ", e$message)
    }
    if (file.exists(temp_gz)) unlink(temp_gz)
    return(NULL)
  })
}
