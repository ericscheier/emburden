#!/usr/bin/env Rscript

# check-version-consistency.R
# Validates that version numbers are consistent across all package metadata files
# Used in pre-push git hook to catch manual version editing mistakes
# Exit code 0 = consistent, Exit code 1 = inconsistent

# Extract version from DESCRIPTION
get_desc_version <- function() {
  if (!file.exists("DESCRIPTION")) {
    cat("Error: DESCRIPTION file not found\n")
    return(NULL)
  }
  content <- readLines("DESCRIPTION", warn = FALSE)
  version_line <- grep("^Version:", content, value = TRUE)
  if (length(version_line) == 0) {
    return(NULL)
  }
  sub("^Version:\\s*", "", version_line[1])
}

# Extract version from inst/CITATION
get_citation_version <- function() {
  citation_file <- "inst/CITATION"
  if (!file.exists(citation_file)) {
    cat("Warning: inst/CITATION file not found\n")
    return(NULL)
  }
  content <- readLines(citation_file, warn = FALSE)
  # Look for "R package version X.Y.Z" pattern
  version_matches <- regmatches(
    content,
    gregexpr('R package version [0-9.]+', content)
  )
  # Flatten and get unique versions
  versions <- unique(unlist(version_matches))
  if (length(versions) == 0) {
    return(NULL)
  }
  # Extract just the version number
  version <- sub("R package version ", "", versions[1])
  version
}

# Extract version from .zenodo.json
get_zenodo_version <- function() {
  zenodo_file <- ".zenodo.json"
  if (!file.exists(zenodo_file)) {
    cat("Warning: .zenodo.json file not found\n")
    return(NULL)
  }

  # Try using jsonlite if available (more robust)
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    tryCatch({
      zenodo <- jsonlite::read_json(zenodo_file, simplifyVector = FALSE)
      return(zenodo$version)
    }, error = function(e) {
      cat("Warning: Failed to parse .zenodo.json with jsonlite\n")
    })
  }

  # Fallback to regex parsing
  content <- paste(readLines(zenodo_file, warn = FALSE), collapse = "\n")
  version_match <- regmatches(
    content,
    regexpr('"version"\\s*:\\s*"[0-9.]+"', content)
  )
  if (length(version_match) == 0) {
    return(NULL)
  }
  # Extract version from "version": "X.Y.Z"
  version <- sub('.*"version"\\s*:\\s*"([0-9.]+)".*', '\\1', version_match)
  version
}

# Main validation
cat("======================================\n")
cat("  Pre-push: Version Consistency Check\n")
cat("======================================\n\n")

desc_ver <- get_desc_version()
citation_ver <- get_citation_version()
zenodo_ver <- get_zenodo_version()

cat("Version found in DESCRIPTION:  ", if(is.null(desc_ver)) "NOT FOUND" else desc_ver, "\n")
cat("Version found in inst/CITATION:", if(is.null(citation_ver)) "NOT FOUND" else citation_ver, "\n")
cat("Version found in .zenodo.json: ", if(is.null(zenodo_ver)) "NOT FOUND" else zenodo_ver, "\n")
cat("\n")

# Check if all versions are present
versions <- list(
  DESCRIPTION = desc_ver,
  CITATION = citation_ver,
  ZENODO = zenodo_ver
)

# Filter out NULL values
versions <- Filter(Negate(is.null), versions)

if (length(versions) == 0) {
  cat("❌ ERROR: Could not extract version from any file\n")
  quit(status = 1)
}

# Check if all non-NULL versions match
unique_versions <- unique(unlist(versions))

if (length(unique_versions) == 1) {
  cat("✅ Version consistency check PASSED\n")
  cat("   All files have version:", unique_versions[1], "\n")
  quit(status = 0)
} else {
  cat("❌ VERSION MISMATCH DETECTED!\n\n")
  cat("Found", length(unique_versions), "different versions:\n")
  for (file in names(versions)) {
    cat("  ", file, ":", versions[[file]], "\n")
  }
  cat("\n")
  cat("PLEASE USE THE OFFICIAL VERSION BUMP SCRIPT:\n")
  cat("  Rscript .dev/bump-version.R <new_version>\n\n")
  cat("Example:\n")
  cat("  Rscript .dev/bump-version.R", max(unique_versions), "\n\n")
  cat("Push cancelled due to version inconsistency.\n")
  quit(status = 1)
}
