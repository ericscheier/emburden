# Render formatted tables for NC Cooperatives results
# Creates both LaTeX and HTML output without requiring rmarkdown

library(dplyr)

# Try to load optional packages
has_knitr <- requireNamespace("knitr", quietly = TRUE)
has_kableExtra <- requireNamespace("kableExtra", quietly = TRUE)

if(!has_knitr) {
  stop("Package 'knitr' is required. Install with: install.packages('knitr')")
}

if(!has_kableExtra) {
  warning("Package 'kableExtra' not found. Tables will be basic. Install with: install.packages('kableExtra')")
}

# Load helper functions
source("ratios.R")
source("helpers.R")
source("format_nc_cooperatives_table.R")

# Load results
cat("Loading results...\n")
results <- read.csv("nc_cooperatives_energy_burden_results.csv", stringsAsFactors = FALSE)

# Separate All row from cooperatives
all_row <- results %>% filter(cooperative == "All")
coops_only <- results %>% filter(cooperative != "All")

cat("Found", nrow(coops_only), "cooperatives\n\n")

# ===== Generate LaTeX Table =====
cat("Generating LaTeX table...\n")

formatted_latex <- format_nc_cooperatives_table_compact(coops_only, latex=TRUE)

latex_table <- knitr::kable(formatted_latex,
                            format = "latex",
                            booktabs = TRUE,
                            escape = FALSE,
                            caption = "Energy Burden Statistics by NC Electric Cooperative",
                            label = "nc-coops")

if(has_kableExtra) {
  latex_table <- latex_table %>%
    kableExtra::kable_styling(latex_options = c("striped", "scale_down")) %>%
    kableExtra::row_spec(0, bold = TRUE) %>%
    kableExtra::footnote(general = c(
      "\\\\% Below 6\\\\% = Percentage of households with energy burden >= 6\\\\%",
      "$E_b$ = Energy Burden (proportion of income spent on energy)",
      "$N_h$ = Net Energy Return ([G-S]/S, where G=income, S=energy spending)"
    ),
    general_title = "Notes: ",
    footnote_as_chunk = TRUE,
    escape = FALSE)
}

# Write LaTeX to file
writeLines(as.character(latex_table), "nc_cooperatives_table.tex")
cat("LaTeX table saved to: nc_cooperatives_table.tex\n\n")

# ===== Generate HTML Table =====
cat("Generating HTML table...\n")

formatted_html <- format_nc_cooperatives_table_compact(coops_only, latex=FALSE)

html_table <- knitr::kable(formatted_html,
                           format = "html",
                           caption = "Energy Burden Statistics by NC Electric Cooperative",
                           escape = FALSE)

if(has_kableExtra) {
  html_table <- html_table %>%
    kableExtra::kable_styling(bootstrap_options = c("striped", "hover", "condensed"),
                             full_width = FALSE,
                             position = "left") %>%
    kableExtra::row_spec(0, bold = TRUE, background = "#f0f0f0") %>%
    kableExtra::footnote(general = c(
      "% Below 6% = Percentage of households with energy burden >= 6%",
      "E[b] = Energy Burden (proportion of income spent on energy)",
      "N[h] = Net Energy Return ([G-S]/S, where G=income, S=energy spending)"
    ),
    general_title = "Notes: ")
}

# Create complete HTML document
html_doc <- paste0(
  "<!DOCTYPE html>\n",
  "<html>\n",
  "<head>\n",
  "  <title>NC Electric Cooperatives Energy Burden Analysis</title>\n",
  "  <meta charset='utf-8'>\n",
  "  <style>\n",
  "    body { font-family: Arial, sans-serif; margin: 40px; }\n",
  "    h1 { color: #333; }\n",
  "    .summary { background-color: #f9f9f9; padding: 15px; border-left: 4px solid #228b22; margin: 20px 0; }\n",
  "    table { margin: 20px 0; }\n",
  "  </style>\n",
  "</head>\n",
  "<body>\n",
  "  <h1>Energy Burden Statistics for North Carolina Electric Cooperatives</h1>\n",
  "  <div class='summary'>\n",
  "    <h3>Summary Statistics</h3>\n",
  "    <ul>\n",
  "      <li><strong>Total Cooperatives:</strong> ", nrow(coops_only), "</li>\n",
  "      <li><strong>Total Households:</strong> ", format(round(sum(coops_only$household_count), 0), big.mark=","), "</li>\n",
  "      <li><strong>Households Below Poverty Line:</strong> ",
          format(round(sum(coops_only$households_below_poverty_line), 0), big.mark=","), "</li>\n",
  "      <li><strong>Overall Poverty Rate:</strong> ",
          scales::percent(sum(coops_only$households_below_poverty_line)/sum(coops_only$household_count), accuracy=0.1), "</li>\n",
  "    </ul>\n",
  "  </div>\n",
  "  <h2>Results by Cooperative</h2>\n",
  "  <p><em>Cooperatives are sorted by median energy burden (highest to lowest)</em></p>\n",
  as.character(html_table), "\n",
  "  <hr style='margin-top: 40px;'>\n",
  "  <p style='color: #666; font-size: 0.9em;'>Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "</p>\n",
  "</body>\n",
  "</html>"
)

# Write HTML to file
writeLines(html_doc, "nc_cooperatives_table.html")
cat("HTML table saved to: nc_cooperatives_table.html\n\n")

# ===== Generate Markdown Table =====
cat("Generating Markdown table...\n")

formatted_md <- format_nc_cooperatives_table_compact(coops_only, latex=FALSE)

md_table <- knitr::kable(formatted_md, format = "markdown")

# Create complete Markdown document
md_doc <- paste0(
  "# Energy Burden Statistics for North Carolina Electric Cooperatives\n\n",
  "## Summary Statistics\n\n",
  "- **Total Cooperatives:** ", nrow(coops_only), "\n",
  "- **Total Households:** ", format(round(sum(coops_only$household_count), 0), big.mark=","), "\n",
  "- **Households Below Poverty Line:** ",
      format(round(sum(coops_only$households_below_poverty_line), 0), big.mark=","), "\n",
  "- **Overall Poverty Rate:** ",
      scales::percent(sum(coops_only$households_below_poverty_line)/sum(coops_only$household_count), accuracy=0.1), "\n\n",
  "## Results by Cooperative\n\n",
  "*Cooperatives are sorted by median energy burden (highest to lowest)*\n\n",
  md_table, "\n\n",
  "## Notes\n\n",
  "- **% Below 6%**: Percentage of households with energy burden >= 6%\n",
  "- **E[b]**: Energy Burden (proportion of income spent on energy)\n",
  "- **N[h]**: Net Energy Return ([G-S]/S, where G=income, S=energy spending)\n\n",
  "---\n",
  "*Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*\n"
)

# Write Markdown to file
writeLines(md_doc, "nc_cooperatives_table.md")
cat("Markdown table saved to: nc_cooperatives_table.md\n\n")

# ===== Display Simple Table in Console =====
cat("\n=== NC Cooperatives Energy Burden (Compact View) ===\n\n")
print(knitr::kable(formatted_md, format="simple"))

cat("\n\nFiles created:\n")
cat("  - nc_cooperatives_table.tex (LaTeX)\n")
cat("  - nc_cooperatives_table.html (HTML)\n")
cat("  - nc_cooperatives_table.md (Markdown)\n")
cat("\nTo view HTML: open nc_cooperatives_table.html in a web browser\n")
cat("To use LaTeX: include in document with \\input{nc_cooperatives_table.tex}\n")
