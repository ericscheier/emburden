# Development Scripts

This directory contains helper scripts for package development and maintenance.

## Setup Scripts

### `install-tinytex.R`

Installs TinyTeX for building PDF vignettes. Required for package development but **not** for end users.

```r
# Install TinyTeX
Rscript .dev/install-tinytex.R
```

TinyTeX is a lightweight LaTeX distribution (~100MB) needed to build the JSS (Journal of Statistical Software) PDF vignette. End users get pre-built vignettes with the package and don't need LaTeX installed.

## Version Management

### `bump-version.R`

Automatically bumps package version across all metadata files (DESCRIPTION, NEWS.md, inst/CITATION, .zenodo.json).

```bash
# Bump to a specific version
Rscript .dev/bump-version.R 0.5.2
```

## Data Management

### `prepare-zenodo-data-nationwide.R`

Prepares nationwide cohort data files for upload to Zenodo.

```bash
# Prepare all 4 datasets (AMI/FPL for 2018/2022)
Rscript .dev/prepare-zenodo-data-nationwide.R --nationwide-only
```

### `zenodo-upload.sh`

Uploads prepared datasets to Zenodo. Requires `ZENODO_TOKEN` environment variable.

```bash
# Upload to Zenodo
export ZENODO_TOKEN="your_token_here"
bash .dev/zenodo-upload.sh
```

## Workflow Notes

### Building Vignettes

**For developers:**
1. Install TinyTeX once: `Rscript .dev/install-tinytex.R`
2. Build package normally: `R CMD build .`
3. Vignettes are built automatically

**For end users:**
- Vignettes are pre-built and included in the package tarball
- No LaTeX installation required
- Just install the package: `install.packages("emburden")`

### CI/CD

GitHub Actions already has TinyTeX installed, so vignettes build automatically in CI.
