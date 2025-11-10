#!/usr/bin/env Rscript
# Build JSS manuscript PDF from vignette source
#
# Usage:
#   Rscript research/manuscripts/build-jss.R
#
# Or from R console:
#   source("research/manuscripts/build-jss.R")

library(rmarkdown)

message("Building JSS manuscript from vignettes/jss-emburden.Rmd...")

# Build from vignette (which is included in package)
render(
  input = "vignettes/jss-emburden.Rmd",
  output_format = rticles::jss_article(keep_tex = TRUE),
  output_dir = "research/manuscripts/jss-draft",
  output_file = "jss-emburden.pdf"
)

message("✓ PDF generated at: research/manuscripts/jss-draft/jss-emburden.pdf")
