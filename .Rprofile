# .Rprofile for netenergyequity package development

# Clean up any old sourced functions that conflict with package
.First <- function() {
  old_functions <- c(
    "calculate_weighted_metrics", "colorize", "dear_func",
    "energy_burden_func", "eroi_func", "ner_func", "to_big",
    "to_dollar", "to_million", "to_percent", "to_billion_dollar",
    "filter_graph_data", "grouped_weighted_metrics"
  )

  # Remove if they exist in global environment
  existing <- intersect(old_functions, ls(envir = .GlobalEnv))
  if (length(existing) > 0) {
    message("Removing old sourced functions: ", paste(existing, collapse = ", "))
    rm(list = existing, envir = .GlobalEnv)
  }
}

# Set default repository
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Helpful startup message
if (interactive()) {
  cat("\n")
  cat("netenergyequity development environment\n")
  cat("======================================\n")
  cat("Use: devtools::load_all() to load package\n")
  cat("     devtools::test() to run tests\n")
  cat("     devtools::check() to check package\n")
  cat("\n")
}
