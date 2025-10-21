# Publication Templates

This directory contains shared publication infrastructure for all research papers, presentations, and posters in the net_energy_equity project.

## Directory Structure

```
research/templates/
├── latex/              # LaTeX document classes and styles
├── lua-filters/        # Pandoc Lua filters for advanced processing
├── html/              # HTML templates
├── bibliography/      # Shared bibliography databases
├── csl/              # Citation Style Language files
└── README.md         # This file
```

## Contents

### LaTeX Files (`latex/`)

**Springer Journal Templates:**
- `svjour3.cls` - Springer journal document class
- `svglov3.clo` - Springer journal class options
- `spphys.bst` - Springer Physics bibliography style

**Custom Headers:**
- `preamble-latex.tex` - Custom LaTeX preamble with package imports and settings
  - Includes: booktabs, lineno, setspace, xcolor, mathtools

### Lua Filters (`lua-filters/`)

Pandoc Lua filters for document processing:
- `color-text.lua` - Text colorization support
- `scholarly-metadata.lua` - Enhanced metadata handling
- `author-info-blocks.lua` - Author affiliation processing

### HTML Templates (`html/`)

- `poster_template.html` - HTML template for academic posters

### Bibliography (`bibliography/`)

**Main References:**
- `references.bib` - Primary bibliography database
  - Used by: Main research papers (net_energy_equity.Rmd, etc.)

**Poster References:**
- `poster.bib` - Poster-specific bibliography
  - Used by: Posters (MES_2022_poster.Rmd, etc.)

### Citation Styles (`csl/`)

- `nature-no-et-al.csl` - Nature journal citation style (modified to show all authors)
  - Used across all papers and presentations

## Usage in R Markdown

### Basic Paper Setup

```yaml
---
title: "Your Paper Title"
bibliography: research/templates/bibliography/references.bib
csl: research/templates/csl/nature-no-et-al.csl
output:
  bookdown::pdf_document2:
    includes:
      in_header: research/templates/latex/preamble-latex.tex
    pandoc_args:
      - '--lua-filter=research/templates/lua-filters/color-text.lua'
      - '--lua-filter=research/templates/lua-filters/scholarly-metadata.lua'
      - '--lua-filter=research/templates/lua-filters/author-info-blocks.lua'
---
```

### Springer Journal Format

```yaml
---
output:
  bookdown::pdf_book:
    base_format: rticles::springer_article
    keep_tex: true
bibliography: research/templates/bibliography/references.bib
csl: research/templates/csl/nature-no-et-al.csl
---
```

### HTML Poster

```yaml
---
bibliography: research/templates/bibliography/poster.bib
csl: research/templates/csl/nature-no-et-al.csl
output:
  pagedown::poster_relaxed:
    template: research/templates/html/poster_template.html
---
```

## Updating Existing Papers

If you have existing .Rmd files that reference old paths in the root directory, update them:

**Before:**
```yaml
bibliography: references.bib
csl: nature-no-et-al.csl
```

**After:**
```yaml
bibliography: research/templates/bibliography/references.bib
csl: research/templates/csl/nature-no-et-al.csl
```

## Backward Compatibility

During the transition period, symbolic links exist in the root directory pointing to these template files. This allows old .Rmd files to continue working without modification.

To check if links exist:
```bash
ls -la *.bib *.csl *.lua *.tex 2>/dev/null
```

## Adding New References

To add new citations to the shared bibliography:

1. Open `research/templates/bibliography/references.bib`
2. Add your BibTeX entry
3. The reference will be available to all papers using this bibliography

## Package Exclusion

The entire `research/` directory (including these templates) is excluded from the `netenergyequity` R package via `.Rbuildignore`. These files are only for producing research papers, not for package distribution.

## Common Patterns

### All Documents Use Nature Citation Style
All papers, presentations, and posters use `nature-no-et-al.csl` for consistent citation formatting.

### Papers vs Posters
- **Papers** use `references.bib` (comprehensive bibliography)
- **Posters** use `poster.bib` (subset for poster citations)

### LaTeX Customization
The `preamble-latex.tex` file provides standard packages for all papers:
- Line numbers (`lineno`)
- Tables (`booktabs`)
- Spacing control (`setspace`)
- Colors (`xcolor`)
- Math enhancements (`mathtools`)

## Troubleshooting

### "File not found" errors
Check that paths are relative to your .Rmd file location. If your .Rmd is in root, use:
```yaml
bibliography: research/templates/bibliography/references.bib
```

If your .Rmd is in a subdirectory, adjust accordingly:
```yaml
bibliography: ../research/templates/bibliography/references.bib
```

### Springer class not found
Make sure `rticles` package is installed:
```r
install.packages("rticles")
```

The Springer class files in `latex/` are used by `rticles::springer_article` automatically.

---

**Maintained as part of the net_energy_equity project**
For questions about the R package itself, see the main README.md
