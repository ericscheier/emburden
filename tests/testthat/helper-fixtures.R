# Helper functions for creating test fixtures
# These functions generate sample data for testing without requiring
# external data sources or API calls

#' Create sample LEAD data for testing
#'
#' @param n Number of rows to generate
#' @param seed Random seed for reproducibility
#' @param dataset Either "ami" or "fpl"
#' @param vintage Either "2018" or "2022"
#' @return A data.frame with sample LEAD data
create_sample_lead_data <- function(n = 100, seed = 123, dataset = "ami", vintage = "2022") {
  set.seed(seed)

  # Generate realistic income brackets based on dataset
  if (dataset == "ami") {
    income_brackets <- c("0-30%", "30-60%", "60-80%", "80-100%", "100%+")
    # Income ranges by bracket (rough estimates)
    income_ranges <- list(
      "0-30%" = c(0, 25000),
      "30-60%" = c(25000, 50000),
      "60-80%" = c(50000, 65000),
      "80-100%" = c(65000, 85000),
      "100%+" = c(85000, 200000)
    )
  } else {  # fpl
    income_brackets <- c("0-100%", "100-150%", "150-200%", "200%+")
    income_ranges <- list(
      "0-100%" = c(0, 27000),
      "100-150%" = c(27000, 40000),
      "150-200%" = c(40000, 54000),
      "200%+" = c(54000, 150000)
    )
  }

  # Generate data
  data <- data.frame(
    geoid = sprintf("37%03d%06d",
                    sample(1:100, n, replace = TRUE),
                    sample(1:999999, n, replace = TRUE)),
    state_abbr = "NC",
    county_name = sample(c("Wake", "Mecklenburg", "Durham", "Guilford", "Forsyth"),
                        n, replace = TRUE),
    income_bracket = sample(income_brackets, n, replace = TRUE),
    stringsAsFactors = FALSE
  )

  # Generate income based on bracket
  data$income <- mapply(function(bracket) {
    range <- income_ranges[[bracket]]
    runif(1, range[1], range[2])
  }, data$income_bracket)

  # Energy costs correlate weakly with income (but not perfectly)
  data$energy_cost <- pmax(800, data$income * runif(n, 0.02, 0.08) + rnorm(n, 0, 300))

  # Other fields
  data$electricity_spend <- data$energy_cost * runif(n, 0.5, 0.7)
  data$gas_spend <- data$energy_cost * runif(n, 0.2, 0.4)
  data$other_spend <- data$energy_cost - data$electricity_spend - data$gas_spend

  data$households <- pmax(1, round(rnorm(n, 100, 50)))
  data$housing_tenure <- sample(c("OWNER", "RENTER"), n, replace = TRUE, prob = c(0.65, 0.35))
  data$primary_heating_fuel <- sample(
    c("Electricity", "Natural gas", "Fuel oil", "Propane"),
    n, replace = TRUE, prob = c(0.5, 0.3, 0.1, 0.1)
  )
  data$building_type <- ifelse(
    sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.7, 0.3)),
    "Single-Family", "Multi-Family"
  )

  # Calculate derived metrics
  data$net_income <- data$income - data$energy_cost
  data$ner <- data$net_income / data$energy_cost
  data$energy_burden <- data$energy_cost / data$income

  # Add vintage identifier
  data$vintage <- vintage

  return(data)
}

#' Create corrupted test data with all-NA income_bracket
#'
#' This replicates the bug reported in issue #15
create_corrupted_fpl_data <- function(n = 100, seed = 456) {
  data <- create_sample_lead_data(n, seed, dataset = "fpl")
  data$income_bracket <- NA_character_
  return(data)
}

#' Create incomplete schema data (missing required columns)
create_incomplete_schema_data <- function(n = 100, seed = 789) {
  data <- create_sample_lead_data(n, seed)
  # Remove critical column
  data$income <- NULL
  return(data)
}

#' Create test data with edge cases
create_edge_case_data <- function() {
  data.frame(
    geoid = c("37001000001", "37001000002", "37001000003", "37001000004"),
    income_bracket = c("0-30%", "0-30%", "100%+", "0-30%"),
    income = c(0, 5000, 150000, -1000),  # Zero, low, high, negative
    energy_cost = c(1000, 0, 3000, 2000),  # Normal, zero, high, normal
    households = c(100, 200, 50, 0),  # Normal, normal, low, zero (invalid)
    housing_tenure = c("OWNER", "RENTER", "OWNER", NA),
    stringsAsFactors = FALSE
  )
}

#' Create a temporary test cache directory
#'
#' @return Path to temporary directory
create_test_cache <- function() {
  cache_dir <- file.path(tempdir(), "emburden_test_cache", paste0("test_", Sys.getpid()))
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  return(cache_dir)
}

#' Write sample data to CSV file
#'
#' @param data Data frame to write
#' @param filename Filename (will be placed in temp directory)
#' @return Path to created file
write_test_csv <- function(data, filename) {
  filepath <- file.path(tempdir(), filename)
  write.csv(data, filepath, row.names = FALSE)
  return(filepath)
}

#' Create sample database for testing
#'
#' @return Path to created SQLite database
create_test_database <- function() {
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RSQLite", quietly = TRUE)) {
    skip("DBI and RSQLite required for database tests")
  }

  db_path <- file.path(tempdir(), paste0("test_emburden_", Sys.getpid(), ".db"))

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # Create tables for different datasets/vintages
  DBI::dbWriteTable(con, "ami_2022", create_sample_lead_data(500, seed = 1, dataset = "ami", vintage = "2022"))
  DBI::dbWriteTable(con, "ami_2018", create_sample_lead_data(500, seed = 2, dataset = "ami", vintage = "2018"))
  DBI::dbWriteTable(con, "fpl_2022", create_sample_lead_data(500, seed = 3, dataset = "fpl", vintage = "2022"))
  DBI::dbWriteTable(con, "fpl_2018", create_sample_lead_data(500, seed = 4, dataset = "fpl", vintage = "2018"))

  DBI::dbDisconnect(con)

  return(db_path)
}

#' Clean up test files and directories
#'
#' @param paths Character vector of paths to remove
cleanup_test_files <- function(paths) {
  for (path in paths) {
    if (file.exists(path)) {
      if (dir.exists(path)) {
        unlink(path, recursive = TRUE)
      } else {
        file.remove(path)
      }
    }
  }
}

#' Skip test if offline (no internet connection)
skip_if_offline <- function() {
  # Simple internet connectivity check without external dependencies
  has_internet <- tryCatch({
    con <- url("http://www.google.com", open = "rb", timeout = 2)
    close(con)
    TRUE
  }, error = function(e) {
    FALSE
  })

  if (!has_internet) {
    skip("No internet connection available")
  }
}

#' Skip test if specific package not available
skip_if_not_installed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    skip(paste0("Package '", pkg, "' not available"))
  }
}
