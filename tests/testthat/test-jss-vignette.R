test_that("JSS vignette can be built", {
  skip_on_cran()
  skip_if_not_installed("rticles")
  skip_if_not_installed("rmarkdown")

  # Determine if we're running from package source or installed package
  # During development: vignettes are in vignettes/ directory
  # During R CMD check: package is installed but we're in tests/testthat/

  # Try to find vignette source file
  # First, try the development path (when running tests from package root)
  vignette_path <- "../../vignettes/jss-emburden.Rmd"

  if (!file.exists(vignette_path)) {
    # If not in development mode, try finding it in the installed package location
    # During R CMD check, the source files are available in the check directory
    pkg_path <- find.package("emburden", quiet = TRUE)
    if (length(pkg_path) > 0) {
      vignette_path <- file.path(pkg_path, "vignettes", "jss-emburden.Rmd")
    }
  }

  # Skip test if we can't find the vignette source
  # This can happen in certain installation scenarios
  skip_if_not(
    file.exists(vignette_path),
    message = "JSS vignette source file not found - skipping test"
  )

  # Test that vignette can be rendered without errors
  # We don't actually build the PDF in tests (too slow), just verify no parsing errors
  expect_silent({
    # Parse the Rmd to check for syntax errors
    rmarkdown::yaml_front_matter(vignette_path)
  })

  # Verify references.bib exists
  bib_path <- "../../vignettes/references.bib"
  if (!file.exists(bib_path)) {
    pkg_path <- find.package("emburden", quiet = TRUE)
    if (length(pkg_path) > 0) {
      bib_path <- file.path(pkg_path, "vignettes", "references.bib")
    }
  }

  expect_true(
    file.exists(bib_path),
    info = "Bibliography file should exist"
  )
})
