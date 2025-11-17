#!/usr/bin/env Rscript
# install-tinytex.R
# Helper script to install TinyTeX for building PDF vignettes
#
# Usage: Rscript .dev/install-tinytex.R

cat(strrep("=", 60), "\n")
cat("Installing TinyTeX for PDF vignette building\n")
cat(strrep("=", 60), "\n\n")

# Install tinytex package if not already installed
if (!requireNamespace("tinytex", quietly = TRUE)) {
  cat("Installing tinytex package...\n")
  install.packages("tinytex", repos = "https://cran.rstudio.com")
} else {
  cat("tinytex package already installed.\n")
}

# Check if TinyTeX is already installed
if (tinytex::is_tinytex()) {
  cat("\nTinyTeX is already installed at:\n")
  cat(" ", tinytex:::tinytex_root(), "\n\n")

  # Update TinyTeX packages
  cat("Updating TinyTeX packages...\n")
  tinytex::tlmgr_update()

  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("TinyTeX is ready!\n")
  cat(strrep("=", 60), "\n")

} else {
  # Install TinyTeX
  cat("\nInstalling TinyTeX...\n")
  cat("This will download ~100MB and may take a few minutes.\n\n")

  tinytex::install_tinytex()

  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("TinyTeX installation complete!\n")
  cat("Installed at:", tinytex:::tinytex_root(), "\n")
  cat(strrep("=", 60), "\n")
}

cat("\nYou can now build PDF vignettes with:\n")
cat("  R CMD build .\n")
cat("  or\n")
cat("  devtools::build_vignettes()\n\n")
