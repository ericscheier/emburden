# Manuscripts

This directory contains manuscript source files and development versions.

## Structure

```
manuscripts/
├── jss-draft/           # JSS article drafts (development versions)
├── nature-energy/       # Nature Energy manuscript (published)
├── build-jss.R          # Build script for JSS manuscript
└── README.md            # This file
```

## JSS Manuscript

The JSS manuscript for the `emburden` R package is included as a vignette in the package.

### Accessing the JSS manuscript

**After installing the package:**

```r
# Install with vignettes
remotes::install_github("ericscheier/emburden", build_vignettes = TRUE)

# View the JSS vignette in your browser
vignette("jss-emburden", package = "emburden")

# Get path to source
system.file("doc/jss-emburden.Rmd", package = "emburden")
```

### Building the JSS PDF manually

**One-liner (from fresh install):**

```r
remotes::install_github("ericscheier/emburden", build_vignettes = TRUE);
rmarkdown::render(
  system.file("doc/jss-emburden.Rmd", package = "emburden"),
  output_format = rticles::jss_article(keep_tex = TRUE)
)
```

**During development (from package root):**

```r
# Run build script
source("research/manuscripts/build-jss.R")

# Or manually
rmarkdown::render(
  "vignettes/jss-emburden.Rmd",
  output_format = rticles::jss_article(keep_tex = TRUE),
  output_dir = "research/manuscripts/jss-draft"
)
```

**From command line:**

```bash
Rscript research/manuscripts/build-jss.R
```

### Requirements

The JSS manuscript requires:

- **rticles** package: `install.packages("rticles")`
- **rmarkdown** package: `install.packages("rmarkdown")`
- LaTeX distribution (for PDF generation)

### Testing

The JSS vignette build is tested automatically in CI/CD:

```r
# Run tests
devtools::test()

# Specifically test JSS vignette
testthat::test_file("tests/testthat/test-jss-vignette.R")
```

## Nature Energy Manuscript

The Nature Energy manuscript is the published paper:

> Scheier, E., & Kittner, N. (2022). A measurement strategy to address disparities across household energy burdens. *Nature Communications*, 13, 1717. https://doi.org/10.1038/s41467-021-27673-y

Various versions are preserved in `nature-energy/versions/` for archival purposes.

## .gitignore

Both directories have specific `.gitignore` files that:
- **Track**: Source files (`.Rmd`, `.tex`, `.bib`)
- **Ignore**: Generated outputs (`.pdf`, `.html`) and build artifacts (`.aux`, `.log`)

This ensures source files are version-controlled while keeping the repository clean.
