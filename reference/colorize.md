# Colorize Text for Knitted Documents

Wraps text in color formatting appropriate for the output format (LaTeX
or HTML). This function is intended for use within R Markdown/knitr
documents.

## Usage

``` r
colorize(x, color)
```

## Arguments

- x:

  Character string to colorize

- color:

  Character string specifying the color name (e.g., "red", "blue")

## Value

Character string wrapped in LaTeX or HTML color commands, or unchanged
if output format is neither

## Details

This function detects the knitr output format and applies appropriate
color formatting. For LaTeX output, it uses `\\textcolor{}`. For HTML
output, it uses `<span style='color: ...'>`.

## Examples

``` r
if (FALSE) { # \dontrun{
# In an R Markdown document:
colorize("Important text", "red")
} # }
```
