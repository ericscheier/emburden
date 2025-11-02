# Research Papers

This directory contains core reproducible research papers integrated with the **emburden** R package.

## Core Papers

- **net_energy_equity.Rmd** - Main paper: "Net energy metrics reveal striking disparities across United States household energy burdens"
- **net_energy_equity_state.Rmd** - State-level analysis extension

These papers demonstrate the package functionality and provide reproducible research that users can run themselves.

## Templates

The `templates/` directory contains shared resources for rendering papers:
- `bibliography/` - Reference files
- `csl/` - Citation Style Language files
- `latex/` - LaTeX templates and styles
- `lua-filters/` - Pandoc Lua filters for custom formatting

## Compiling Papers

Papers can be rendered using rmarkdown:

```r
rmarkdown::render("research/papers/net_energy_equity.Rmd",
                  output_format = "bookdown::pdf_document2")
```

## Development Work

Exploratory research, drafts, and works-in-progress are kept in `.private/research/` (not included in public releases).
