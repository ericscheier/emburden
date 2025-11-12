#!/usr/bin/env Rscript

# check-version-consistency.R
# Validates that version numbers are consistent across all metadata files
# Usage: Rscript .dev/check-version-consistency.R
# Exit codes: 0 = consistent, 1 = inconsistent

# Function to extract version from DESCRIPTION
get_description_version <- function() {
  if (!file.exists("DESCRIPTION")) {
    return(NULL)
  }
  desc <- readLines("DESCRIPTION", warn = FALSE)
  version_line <- grep("^Version:", desc, value = TRUE)
  if (length(version_line) == 0) return(NULL)
  sub("^Version:\\s*", "", version_line[1])
}

# Function to extract version from CITATION
get_citation_versions <- function() {
  if (!file.exists("inst/CITATION")) {
    return(NULL)
  }
  content <- readLines("inst/CITATION", warn = FALSE)

  # Extract from note field
  note_match <- grep('note\\s*=\\s*"R package version ([0-9.]+)"', content, value = TRUE)
  note_version <- if (length(note_match) > 0) {
    sub('.*note\\s*=\\s*"R package version ([0-9.]+)".*', "\\1", note_match[1])
  } else NULL

  # Extract from textVersion
  text_match <- grep('"R package version ([0-9.]+)"', content, value = TRUE)
  text_version <- if (length(text_match) > 0) {
    sub('.*"R package version ([0-9.]+)".*', "\\1", text_match[1])
  } else NULL

  list(note = note_version, text = text_version)
}

# Function to extract version from .zenodo.json
get_zenodo_version <- function() {
  if (!file.exists(".zenodo.json")) {
    return(NULL)
  }

  # Try jsonlite first
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    zenodo <- jsonlite::read_json(".zenodo.json", simplifyVector = FALSE)
    return(zenodo$version)
  }

  # Fallback to regex
  content <- readLines(".zenodo.json", warn = FALSE)
  version_line <- grep('"version"\\s*:', content, value = TRUE)
  if (length(version_line) == 0) return(NULL)
  sub('.*"version"\\s*:\\s*"([0-9.]+)".*', "\\1", version_line[1])
}

# Function to extract version from NEWS.md header
get_news_version <- function() {
  if (!file.exists("NEWS.md")) {
    return(NULL)
  }
  content <- readLines("NEWS.md", warn = FALSE, n = 20)
  # Look for pattern like "# emburden 0.2.0" or "## Version 0.2.0"
  version_line <- grep("^#+ .*(emburden |Version |v)?([0-9]+\\.[0-9]+\\.[0-9]+)", content, value = TRUE)
  if (length(version_line) == 0) return(NULL)
  sub("^#+ .*(emburden |Version |v)?([0-9]+\\.[0-9]+\\.[0-9]+).*", "\\2", version_line[1])
}

# Main validation
cat("Checking version consistency across files...\n\n")

versions <- list(
  DESCRIPTION = get_description_version(),
  CITATION_note = get_citation_versions()$note,
  CITATION_text = get_citation_versions()$text,
  zenodo = get_zenodo_version(),
  NEWS = get_news_version()
)

# Print all versions
cat("Found versions:\n")
max_width <- max(nchar(names(versions)))
for (name in names(versions)) {
  version <- versions[[name]]
  status <- if (is.null(version)) "NOT FOUND" else version
  padding <- paste(rep(" ", max_width - nchar(name)), collapse = "")
  cat(sprintf("  %s:%s %s\n", name, padding, status))
}

cat("\n")

# Check consistency
available_versions <- versions[!sapply(versions, is.null)]
if (length(available_versions) == 0) {
  cat("Error: No versions found in any file!\n")
  quit(status = 1)
}

unique_versions <- unique(unlist(available_versions))

if (length(unique_versions) == 1) {
  cat("✓ All versions are consistent:", unique_versions, "\n")
  quit(status = 0)
} else {
  cat("✖ VERSION MISMATCH DETECTED!\n\n")
  cat("Found", length(unique_versions), "different versions:\n")
  for (v in unique_versions) {
    files_with_version <- names(available_versions)[sapply(available_versions, function(x) x == v)]
    cat("  Version", v, "in:", paste(files_with_version, collapse = ", "), "\n")
  }

  cat("\nRECOMMENDED ACTION:\n")
  cat("1. Use .dev/bump-version.R to update all files to the same version\n")
  cat("2. Or manually update the mismatched files\n")
  cat("3. Re-run this script to verify consistency\n")

  quit(status = 1)
}
