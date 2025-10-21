# cleanup_conflicts.R
# Run this to remove old sourced functions that conflict with the package
# Usage: source("cleanup_conflicts.R")

cat("Cleaning up conflicts...\n")

old_functions <- c(
  "calculate_weighted_metrics", "colorize", "dear_func",
  "energy_burden_func", "eroi_func", "ner_func", "to_big",
  "to_dollar", "to_million", "to_percent", "to_billion_dollar",
  "filter_graph_data", "grouped_weighted_metrics"
)

# Remove if they exist in global environment
existing <- intersect(old_functions, ls(envir = .GlobalEnv))

if (length(existing) > 0) {
  cat("Removing:", paste(existing, collapse = ", "), "\n")
  rm(list = existing, envir = .GlobalEnv)
  cat("✓ Conflicts cleared!\n")
  cat("\nYou can now run: devtools::load_all()\n")
} else {
  cat("✓ No conflicts found. Environment is clean!\n")
}
