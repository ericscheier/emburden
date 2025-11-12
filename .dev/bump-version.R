#!/usr/bin/env Rscript

# bump-version.R
# Automatically updates package version across all metadata files
# Usage: Rscript .dev/bump-version.R <new_version>
# Example: Rscript .dev/bump-version.R 0.3.0

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  cat("Usage: Rscript .dev/bump-version.R <new_version>\n")
  cat("Example: Rscript .dev/bump-version.R 0.3.0\n")
  quit(status = 1)
}

new_version <- args[1]

# Validate semantic versioning format (X.Y.Z or X.Y.Z.9XXX for dev)
if (!grepl("^\\d+\\.\\d+\\.\\d+(\\.9\\d{3})?$", new_version)) {
  cat("Error: Version must follow semantic versioning format (e.g., 0.3.0 or 0.3.0.9001)\n")
  quit(status = 1)
}

cat("Updating package version to:", new_version, "\n\n")

# Function to update version in a file
update_version <- function(file_path, pattern, replacement, description) {
  if (!file.exists(file_path)) {
    cat("Warning:", file_path, "not found. Skipping.\n")
    return(FALSE)
  }

  content <- readLines(file_path, warn = FALSE)
  original_content <- content

  # Apply replacements
  content <- gsub(pattern, replacement, content)

  if (identical(content, original_content)) {
    cat("No changes needed in:", file_path, "\n")
    return(FALSE)
  }

  writeLines(content, file_path)
  cat("✓ Updated", description, "in", file_path, "\n")
  return(TRUE)
}

updated_files <- character()

# 1. Update DESCRIPTION
if (update_version(
  "DESCRIPTION",
  "^Version: .*",
  paste0("Version: ", new_version),
  "Version"
)) {
  updated_files <- c(updated_files, "DESCRIPTION")
}

# 2. Update inst/CITATION (two locations)
citation_file <- "inst/CITATION"
if (file.exists(citation_file)) {
  content <- readLines(citation_file, warn = FALSE)
  original_content <- content

  # Update both version references
  content <- gsub(
    'note\\s*=\\s*"R package version [0-9.]+',
    paste0('note     = "R package version ', new_version),
    content
  )
  content <- gsub(
    '"R package version [0-9.]+"',
    paste0('"R package version ', new_version, '"'),
    content
  )

  if (!identical(content, original_content)) {
    writeLines(content, citation_file)
    cat("✓ Updated version in inst/CITATION\n")
    updated_files <- c(updated_files, "inst/CITATION")
  } else {
    cat("No changes needed in: inst/CITATION\n")
  }
} else {
  cat("Warning: inst/CITATION not found. Skipping.\n")
}

# 3. Update .zenodo.json
zenodo_file <- ".zenodo.json"
if (file.exists(zenodo_file)) {
  # Use jsonlite for proper JSON handling
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    zenodo <- jsonlite::read_json(zenodo_file, simplifyVector = FALSE)
    old_version <- zenodo$version
    zenodo$version <- new_version

    if (old_version != new_version) {
      jsonlite::write_json(
        zenodo,
        zenodo_file,
        pretty = TRUE,
        auto_unbox = TRUE
      )
      cat("✓ Updated version in .zenodo.json\n")
      updated_files <- c(updated_files, ".zenodo.json")
    } else {
      cat("No changes needed in: .zenodo.json\n")
    }
  } else {
    # Fallback to regex if jsonlite not available
    if (update_version(
      zenodo_file,
      '"version"\\s*:\\s*"[0-9.]+"',
      paste0('"version": "', new_version, '"'),
      "version"
    )) {
      updated_files <- c(updated_files, ".zenodo.json")
    }
  }
} else {
  cat("Warning: .zenodo.json not found. Skipping.\n")
}

# Summary
cat("\n" , rep("=", 60), "\n", sep = "")
cat("Version bump complete!\n")
cat("New version:", new_version, "\n")
cat("Files updated:", length(updated_files), "\n")

if (length(updated_files) > 0) {
  cat("\nUpdated files:\n")
  for (f in updated_files) {
    cat("  -", f, "\n")
  }

  cat("\n" , rep("-", 60), "\n", sep = "")
  cat("IMPORTANT REMINDERS:\n")
  cat("1. Update NEWS.md with version", new_version, "and changes\n")
  cat("2. Review changes: git diff\n")
  cat("3. Stage changes: git add", paste(updated_files, collapse = " "), "\n")
  cat("4. Commit: git commit -m 'Bump version to", new_version, "'\n")
  cat("5. Create git tag: git tag v", new_version, "\n", sep = "")
  cat(rep("=", 60), "\n", sep = "")
}

quit(status = 0)
