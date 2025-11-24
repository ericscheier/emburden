#!/usr/bin/env Rscript

# Direct HTTP POST submission to CRAN
# Bypasses devtools::submit_cran() to avoid menu() interactivity issues
# Based on devtools source code: https://github.com/r-lib/devtools/blob/main/R/release.R

cat("\n")
cat("========================================\n")
cat("CRAN Direct HTTP POST Submission Script\n")
cat("========================================\n\n")

# Load required packages
if (!requireNamespace("httr", quietly = TRUE)) {
  cat("Installing httr package...\n")
  install.packages("httr", repos = "https://cloud.r-project.org")
}
library(httr)

# Get package tarball path from command line or find it
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  tarball_path <- args[1]
} else {
  # Find the most recent tarball in current directory
  tarballs <- list.files(".", pattern = "\\.tar\\.gz$", full.names = TRUE)
  if (length(tarballs) == 0) {
    stop("No tarball found. Please specify path as argument or build package first.")
  }
  tarball_path <- tarballs[which.max(file.info(tarballs)$mtime)]
}

if (!file.exists(tarball_path)) {
  stop(sprintf("Tarball not found: %s", tarball_path))
}

cat(sprintf("Using tarball: %s\n\n", tarball_path))

# Extract maintainer information from DESCRIPTION
desc_file <- "DESCRIPTION"
if (!file.exists(desc_file)) {
  stop("DESCRIPTION file not found")
}

desc_lines <- readLines(desc_file)

# Extract maintainer name and email
maintainer_line <- grep("^Maintainer:", desc_lines, value = TRUE)
if (length(maintainer_line) == 0) {
  # Try to get from Authors@R
  authors_line_idx <- grep("^Authors@R:", desc_lines)
  if (length(authors_line_idx) > 0) {
    # Parse Authors@R field (simplified - assumes single line or can eval)
    authors_text <- desc_lines[authors_line_idx]
    authors_text <- sub("^Authors@R:\\s*", "", authors_text)

    # Try to evaluate if it's R code
    tryCatch({
      authors_obj <- eval(parse(text = authors_text))
      maintainer_info <- authors_obj[sapply(authors_obj, function(x) "cre" %in% x$role)]
      if (length(maintainer_info) > 0) {
        maintainer_name <- paste(maintainer_info[[1]]$given, maintainer_info[[1]]$family)
        maintainer_email <- maintainer_info[[1]]$email
      } else {
        stop("No maintainer found in Authors@R")
      }
    }, error = function(e) {
      stop(sprintf("Could not parse Authors@R field: %s", e$message))
    })
  } else {
    stop("No Maintainer field found in DESCRIPTION")
  }
} else {
  # Parse "Name <email>" format
  maintainer_line <- sub("^Maintainer:\\s*", "", maintainer_line)
  if (grepl("<.*>", maintainer_line)) {
    maintainer_name <- trimws(sub("<.*", "", maintainer_line))
    maintainer_email <- sub(".*<(.*)>.*", "\\1", maintainer_line)
  } else {
    stop("Could not parse Maintainer field")
  }
}

cat(sprintf("Maintainer: %s <%s>\n\n", maintainer_name, maintainer_email))

# Read CRAN comments if available
cran_comments <- ""
if (file.exists("cran-comments.md")) {
  cran_comments <- paste(readLines("cran-comments.md"), collapse = "\n")
  cat("Found cran-comments.md\n\n")
}

# CRAN submission URL
cran_url <- "https://xmpalantir.wu.ac.at/cransubmit/index2.php"

cat("Step 1: Uploading package to CRAN...\n")

# First POST request: Upload package
response1 <- POST(
  url = cran_url,
  body = list(
    pkg_id = "",
    name = maintainer_name,
    email = maintainer_email,
    uploaded_file = upload_file(tarball_path, type = "application/x-gzip"),
    comment = cran_comments,
    upload = "Upload package"
  ),
  encode = "multipart"
)

if (http_error(response1)) {
  stop(sprintf("Upload failed with status %d: %s",
               status_code(response1),
               content(response1, "text", encoding = "UTF-8")))
}

cat(sprintf("Upload response status: %d\n", status_code(response1)))

# Parse response to extract pkg_id
# The response should redirect or contain the pkg_id
response_text <- content(response1, "text", encoding = "UTF-8")

# Extract pkg_id from response (it's in a hidden form field or URL parameter)
pkg_id_match <- regexpr('name="pkg_id"[^>]*value="([^"]+)"', response_text, perl = TRUE)
if (pkg_id_match[1] == -1) {
  # Try URL parameter format
  pkg_id_match <- regexpr('pkg_id=([^&"]+)', response_text, perl = TRUE)
  if (pkg_id_match[1] == -1) {
    cat("\nWarning: Could not extract pkg_id from response.\n")
    cat("Response preview:\n")
    cat(substr(response_text, 1, 500), "\n")
    stop("Could not find pkg_id in upload response")
  }
}

pkg_id <- regmatches(response_text, pkg_id_match)
pkg_id <- sub('.*=([^&"]+).*', '\\1', pkg_id)
pkg_id <- sub('.*value="([^"]+)".*', '\\1', pkg_id)

cat(sprintf("Extracted pkg_id: %s\n\n", pkg_id))

cat("Step 2: Confirming submission...\n")

# Second POST request: Confirm submission
response2 <- POST(
  url = cran_url,
  body = list(
    pkg_id = pkg_id,
    name = maintainer_name,
    email = maintainer_email,
    policy_check = "1/",
    submit = "Submit package"
  ),
  encode = "form"
)

if (http_error(response2)) {
  stop(sprintf("Confirmation failed with status %d: %s",
               status_code(response2),
               content(response2, "text", encoding = "UTF-8")))
}

cat(sprintf("Confirmation response status: %d\n\n", status_code(response2)))

# Check for success message in response
response2_text <- content(response2, "text", encoding = "UTF-8")

if (grepl("successfully submitted|thank you", response2_text, ignore.case = TRUE)) {
  cat("========================================\n")
  cat("SUCCESS: Package submitted to CRAN!\n")
  cat("========================================\n\n")
  cat("Next steps:\n")
  cat("1. Check your email (%s) for CRAN confirmation\n", maintainer_email)
  cat("2. Click the confirmation link in the email (REQUIRED!)\n")
  cat("3. Wait for CRAN maintainer review (typically 1-2 weeks)\n")
  cat("4. Respond to any reviewer feedback\n\n")
} else if (grepl("error|failed|invalid", response2_text, ignore.case = TRUE)) {
  cat("\n========================================\n")
  cat("POSSIBLE ERROR in submission\n")
  cat("========================================\n")
  cat("Response preview:\n")
  cat(substr(response2_text, 1, 1000), "\n\n")
  stop("Submission may have failed - check response above")
} else {
  cat("\n========================================\n")
  cat("Submission completed (check response)\n")
  cat("========================================\n")
  cat("Response preview:\n")
  cat(substr(response2_text, 1, 500), "\n\n")
  cat("Please verify submission by checking your email.\n\n")
}

cat("Submission process complete.\n")
