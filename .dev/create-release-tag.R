#!/usr/bin/env Rscript

# create-release-tag.R
# Helper script to create and push release tags after version bumps
# Usage: Rscript .dev/create-release-tag.R [--dry-run]
#
# This script:
# 1. Verifies all version numbers are consistent
# 2. Checks that the current version doesn't already have a tag
# 3. Extracts release notes from NEWS.md
# 4. Creates an annotated git tag
# 5. Pushes the tag to trigger the controlled release workflow

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

# Color output functions
red <- function(x) paste0("\033[31m", x, "\033[0m")
green <- function(x) paste0("\033[32m", x, "\033[0m")
yellow <- function(x) paste0("\033[33m", x, "\033[0m")
blue <- function(x) paste0("\033[34m", x, "\033[0m")
bold <- function(x) paste0("\033[1m", x, "\033[0m")

cat(bold(blue("=== Release Tag Creator ===\n\n")))

if (dry_run) {
  cat(yellow("Running in DRY RUN mode - no tags will be created or pushed\n\n"))
}

# Step 1: Check version consistency
cat("Step 1: Checking version consistency...\n")
check_result <- system("Rscript .dev/check-version-consistency.R", intern = FALSE)

if (check_result != 0) {
  cat(red("\n✖ Version consistency check failed!\n"))
  cat("Please ensure all metadata files have matching versions.\n")
  cat("Use: Rscript .dev/bump-version.R <new_version>\n")
  quit(status = 1)
}

# Step 2: Get current version
version <- as.character(desc::desc_get_version())
tag_name <- paste0("v", version)

cat(blue(sprintf("\nCurrent version: %s\n", version)))
cat(blue(sprintf("Tag to create: %s\n\n", tag_name)))

# Step 3: Check if tag already exists locally
existing_tags <- system("git tag -l", intern = TRUE)
if (tag_name %in% existing_tags) {
  cat(red(sprintf("✖ Tag %s already exists locally!\n", tag_name)))
  cat("If you need to recreate it:\n")
  cat(sprintf("  1. Delete local tag: git tag -d %s\n", tag_name))
  cat(sprintf("  2. Delete remote tag: git push scheier --delete %s\n", tag_name))
  cat("  3. Run this script again\n")
  quit(status = 1)
}

# Step 4: Check if tag exists on remote
remote_tags <- system("git ls-remote --tags scheier", intern = TRUE)
if (any(grepl(tag_name, remote_tags))) {
  cat(red(sprintf("✖ Tag %s already exists on remote!\n", tag_name)))
  cat("This version has already been released.\n")
  cat("To create a new release, bump the version first:\n")
  cat("  Rscript .dev/bump-version.R <new_version>\n")
  quit(status = 1)
}

# Step 5: Extract release notes from NEWS.md
cat("Step 2: Extracting release notes from NEWS.md...\n")

if (!file.exists("NEWS.md")) {
  cat(red("✖ NEWS.md not found!\n"))
  cat("Please ensure NEWS.md exists and has notes for this version.\n")
  quit(status = 1)
}

news_content <- readLines("NEWS.md", warn = FALSE)

# Find the section for this version
version_pattern <- paste0("^#+ .*", gsub("\\.", "\\\\.", version))
version_line_idx <- grep(version_pattern, news_content)

if (length(version_line_idx) == 0) {
  cat(red(sprintf("✖ No section found in NEWS.md for version %s\n", version)))
  cat("Please add release notes to NEWS.md before creating the tag.\n")
  quit(status = 1)
}

# Extract notes until the next version heading
start_idx <- version_line_idx[1] + 1
next_version_idx <- grep("^#+ .*[0-9]+\\.[0-9]+\\.[0-9]+", news_content[start_idx:length(news_content)])

if (length(next_version_idx) > 0) {
  end_idx <- start_idx + next_version_idx[1] - 2
} else {
  end_idx <- length(news_content)
}

release_notes <- paste(news_content[start_idx:end_idx], collapse = "\n")
release_notes <- trimws(release_notes)

if (nchar(release_notes) == 0) {
  cat(yellow("⚠ Warning: No release notes found for this version in NEWS.md\n"))
  release_notes <- sprintf("Release version %s\n\nSee NEWS.md for details.", version)
}

# Create tag message
tag_message <- sprintf("Release version %s\n\n%s", version, release_notes)

cat(green("✓ Release notes extracted\n\n"))

# Step 6: Verify we're on main branch
current_branch <- trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE))

if (current_branch != "main") {
  cat(red(sprintf("✖ Not on main branch (currently on: %s)\n", current_branch)))
  cat("Please switch to main branch before creating release tags:\n")
  cat("  git checkout main\n")
  cat("  git pull scheier main\n")
  quit(status = 1)
}

# Step 7: Check if working tree is clean
git_status <- system("git status --porcelain", intern = TRUE)

if (length(git_status) > 0) {
  cat(red("✖ Working tree is not clean!\n"))
  cat("Please commit or stash your changes before creating a release tag.\n")
  cat("\nUncommitted changes:\n")
  cat(paste(git_status, collapse = "\n"), "\n")
  quit(status = 1)
}

cat(green("✓ On main branch with clean working tree\n\n"))

# Step 8: Preview and confirm
cat(bold("=== Release Tag Summary ===\n"))
cat(sprintf("Tag: %s\n", tag_name))
cat(sprintf("Version: %s\n", version))
cat(sprintf("Branch: %s\n", current_branch))
cat("\nTag message:\n")
cat("---\n")
cat(tag_message)
cat("\n---\n\n")

if (dry_run) {
  cat(yellow("DRY RUN: Would create and push tag, but skipping due to --dry-run flag\n"))
  cat("\nTo create the tag for real, run:\n")
  cat("  Rscript .dev/create-release-tag.R\n")
  quit(status = 0)
}

cat(yellow("This will create and push the tag, triggering the controlled release workflow.\n"))
cat(yellow("The workflow requires manual approval at two gates before publishing.\n\n"))

# Interactive confirmation
cat("Proceed with creating and pushing the tag? [y/N]: ")
response <- tolower(trimws(readLines("stdin", n = 1)))

if (response != "y" && response != "yes") {
  cat("\nAborted by user.\n")
  quit(status = 0)
}

# Step 9: Create the tag
cat("\nStep 3: Creating annotated tag...\n")

# Write tag message to temporary file to handle multi-line messages properly
tmp_file <- tempfile()
writeLines(tag_message, tmp_file)

tag_cmd <- sprintf("git tag -a %s -F %s", tag_name, tmp_file)
tag_result <- system(tag_cmd, intern = FALSE)
unlink(tmp_file)

if (tag_result != 0) {
  cat(red("✖ Failed to create tag!\n"))
  quit(status = 1)
}

cat(green(sprintf("✓ Tag %s created\n\n", tag_name)))

# Step 10: Push the tag
cat("Step 4: Pushing tag to trigger release workflow...\n")

push_result <- system(sprintf("git push scheier %s", tag_name), intern = FALSE)

if (push_result != 0) {
  cat(red("\n✖ Failed to push tag!\n"))
  cat(yellow(sprintf("\nThe tag was created locally but not pushed. To try again:\n")))
  cat(sprintf("  git push scheier %s\n", tag_name))
  cat(sprintf("\nOr to delete the local tag and start over:\n"))
  cat(sprintf("  git tag -d %s\n", tag_name))
  quit(status = 1)
}

cat(green(sprintf("\n✓ Tag %s pushed successfully!\n\n", tag_name)))

# Step 11: Provide next steps
cat(bold("=== Next Steps ===\n\n"))
cat("The Controlled Release workflow has been triggered.\n\n")
cat("Monitor progress:\n")
cat("  gh run list --workflow='Controlled Release' --limit 3\n")
cat("  gh run watch --workflow='Controlled Release'\n\n")
cat("The workflow stages:\n")
cat("  1. Validation: Running quality checks (automatic)\n")
cat("  2. Gate 1: Pre-release review (requires manual approval)\n")
cat("  3. Create draft release (automatic after approval)\n")
cat("  4. Gate 2: Production release approval (requires manual approval)\n")
cat("  5. Publish release (automatic after approval, triggers Zenodo archival)\n\n")
cat(sprintf("View the workflow at:\n"))
cat(sprintf("  https://github.com/ScheierVentures/emburden/actions/workflows/controlled-release.yaml\n\n"))
cat(green("✓ Release process initiated successfully!\n"))
