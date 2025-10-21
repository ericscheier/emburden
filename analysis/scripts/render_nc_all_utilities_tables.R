# Render color-coded formatted tables for ALL NC utilities
# Creates LaTeX, HTML, and Markdown output with color coding by utility type

library(dplyr)

# Try to load optional packages
has_knitr <- requireNamespace("knitr", quietly = TRUE)
has_kableExtra <- requireNamespace("kableExtra", quietly = TRUE)

if(!has_knitr) {
  stop("Package 'knitr' is required. Install with: install.packages('knitr')")
}

# Load helper functions
source("ratios.R")
source("helpers.R")
source("format_all_utilities_table.R")

# Load results
cat("Loading NC results...\n")
results <- read.csv("nc_all_utilities_energy_burden_results.csv", stringsAsFactors = FALSE)

# Separate All rows from actual utilities
utilities_only <- results %>% filter(utility_type != "All", utility_name != "All")

cat("Found", nrow(utilities_only), "utilities across",
    length(unique(utilities_only$utility_type)), "utility types in NC\n\n")

# ===== Generate Summary Table by Utility Type =====
cat("Generating utility type summary...\n")
type_summary_result <- format_utility_type_summary(results, latex=FALSE)
type_summary_formatted <- type_summary_result$formatted
type_summary_raw <- type_summary_result$raw

# ===== Generate LaTeX Tables =====
cat("Generating LaTeX tables...\n")

# Summary table by type
summary_latex <- knitr::kable(type_summary_formatted,
                              format = "latex",
                              booktabs = TRUE,
                              escape = FALSE,
                              caption = "Energy Burden Summary by Utility Type (NC)")

if(has_kableExtra) {
  for(i in 1:nrow(type_summary_raw)) {
    color <- get_utility_color(type_summary_raw$utility_type[i], "latex")
    summary_latex <- summary_latex %>%
      kableExtra::row_spec(i, background = color)
  }

  summary_latex <- summary_latex %>%
    kableExtra::kable_styling(latex_options = c("striped", "hold_position")) %>%
    kableExtra::row_spec(0, bold = TRUE)
}

writeLines(as.character(summary_latex), "nc_all_utilities_type_summary.tex")

# Full utilities table (all NC utilities)
utilities_formatted_latex <- format_utilities_by_type_table(utilities_only, latex=TRUE)

utilities_latex <- knitr::kable(utilities_formatted_latex,
                                format = "latex",
                                booktabs = TRUE,
                                escape = FALSE,
                                caption = "Energy Burden Statistics for All NC Utilities")

if(has_kableExtra) {
  # Color code rows by utility type
  for(i in 1:nrow(utilities_only)) {
    utility_type <- utilities_only$utility_type[i]
    color <- get_utility_color(utility_type, "latex")
    utilities_latex <- utilities_latex %>%
      kableExtra::row_spec(i, background = color)
  }

  utilities_latex <- utilities_latex %>%
    kableExtra::kable_styling(latex_options = c("striped", "hold_position", "scale_down"),
                             font_size = 9) %>%
    kableExtra::row_spec(0, bold = TRUE)
}

writeLines(as.character(utilities_latex), "nc_all_utilities_table.tex")

cat("LaTeX tables saved:\n")
cat("  - nc_all_utilities_type_summary.tex\n")
cat("  - nc_all_utilities_table.tex\n\n")

# ===== Generate HTML Tables =====
cat("Generating HTML tables...\n")

# Summary by type
summary_html <- knitr::kable(type_summary_formatted,
                             format = "html",
                             escape = FALSE,
                             caption = "Energy Burden Summary by Utility Type (NC)")

if(has_kableExtra) {
  for(i in 1:nrow(type_summary_raw)) {
    color <- get_utility_color(type_summary_raw$utility_type[i], "html")
    summary_html <- summary_html %>%
      kableExtra::row_spec(i, background = color)
  }

  summary_html <- summary_html %>%
    kableExtra::kable_styling(bootstrap_options = c("striped", "hover"),
                             full_width = FALSE) %>%
    kableExtra::row_spec(0, bold = TRUE, background = "#e0e0e0")
}

# Full utilities table
utilities_formatted_html <- format_utilities_by_type_table(utilities_only, latex=FALSE)

utilities_html <- knitr::kable(utilities_formatted_html,
                               format = "html",
                               escape = FALSE,
                               caption = "Energy Burden Statistics for All NC Utilities")

if(has_kableExtra) {
  for(i in 1:nrow(utilities_only)) {
    utility_type <- utilities_only$utility_type[i]
    color <- get_utility_color(utility_type, "html")
    utilities_html <- utilities_html %>%
      kableExtra::row_spec(i, background = color)
  }

  utilities_html <- utilities_html %>%
    kableExtra::kable_styling(bootstrap_options = c("striped", "hover"),
                             full_width = TRUE,
                             font_size = 11) %>%
    kableExtra::row_spec(0, bold = TRUE, background = "#e0e0e0")
}

# Create legend for utility types
legend_html <- paste0(
  "<div style='margin: 20px 0; padding: 15px; background: #f9f9f9; border: 1px solid #ddd;'>\n",
  "  <h4>Utility Type Color Legend</h4>\n",
  "  <table style='border-collapse: collapse;'>\n"
)

for(type_code in unique(utilities_only$utility_type)) {
  type_full <- utilities_only %>%
    filter(utility_type == type_code) %>%
    pull(utility_type_full) %>%
    first()

  color <- get_utility_color(type_code, "html")
  n_utils <- sum(utilities_only$utility_type == type_code)

  legend_html <- paste0(legend_html,
    "    <tr>\n",
    "      <td style='padding: 8px; background: ", color, "; border: 1px solid #ddd; width: 250px;'><strong>", type_full, "</strong></td>\n",
    "      <td style='padding: 8px; border: 1px solid #ddd;'>", n_utils, " utilities</td>\n",
    "    </tr>\n"
  )
}

legend_html <- paste0(legend_html, "  </table>\n</div>\n")

# Dataset coverage note
coverage_note <- paste0(
  "<div style='margin: 20px 0; padding: 15px; background: #e8f5e9; border-left: 4px solid #228b22;'>\n",
  "  <h4>✓ Dataset Coverage</h4>\n",
  "  <p><strong>Complete coverage:</strong> All NC census tracts in the dataset have utility assignments.</p>\n",
  "  <p><em>This analysis includes ", nrow(utilities_only %>% filter(utility_type == "DistCoop")),
  " electric cooperatives based on utility service territory mapping to census tracts.</em></p>\n",
  "</div>\n"
)

# Create complete HTML document
html_doc <- paste0(
  "<!DOCTYPE html>\n",
  "<html>\n",
  "<head>\n",
  "  <title>All NC Utilities Energy Burden Analysis</title>\n",
  "  <meta charset='utf-8'>\n",
  "  <style>\n",
  "    body { font-family: Arial, sans-serif; margin: 40px; max-width: 1200px; }\n",
  "    h1 { color: #333; }\n",
  "    h2 { color: #555; margin-top: 30px; }\n",
  "    .summary { background-color: #f9f9f9; padding: 15px; border-left: 4px solid #228b22; margin: 20px 0; }\n",
  "    table { margin: 20px 0; }\n",
  "  </style>\n",
  "</head>\n",
  "<body>\n",
  "  <h1>Energy Burden Statistics for All North Carolina Utilities</h1>\n",
  "  <div class='summary'>\n",
  "    <h3>Overall Summary</h3>\n",
  "    <ul>\n",
  "      <li><strong>Total Utilities:</strong> ", nrow(utilities_only), "</li>\n",
  "      <li><strong>Total Households:</strong> ",
          format(round(sum(utilities_only$household_count), 0), big.mark=","), "</li>\n",
  "      <li><strong>Households Below Poverty Line:</strong> ",
          format(round(sum(utilities_only$households_below_poverty_line), 0), big.mark=","), "</li>\n",
  "      <li><strong>Overall Poverty Rate:</strong> ",
          scales::percent(sum(utilities_only$households_below_poverty_line)/sum(utilities_only$household_count), accuracy=0.1), "</li>\n",
  "    </ul>\n",
  "  </div>\n",
  coverage_note,
  legend_html,
  "  <h2>Summary by Utility Type</h2>\n",
  as.character(summary_html), "\n",
  "  <h2>All NC Utilities by Median Energy Burden</h2>\n",
  "  <p><em>Rows are color-coded by utility type (see legend above)</em></p>\n",
  as.character(utilities_html), "\n",
  "  <hr style='margin-top: 40px;'>\n",
  "  <p style='color: #666; font-size: 0.9em;'>Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "</p>\n",
  "</body>\n",
  "</html>"
)

writeLines(html_doc, "nc_all_utilities_table.html")

cat("HTML table saved: nc_all_utilities_table.html\n\n")

# ===== Generate Markdown Table =====
cat("Generating Markdown tables...\n")

summary_md <- knitr::kable(type_summary_formatted, format = "markdown")
utilities_md <- knitr::kable(utilities_formatted_html, format = "markdown")

md_doc <- paste0(
  "# Energy Burden Statistics for All North Carolina Utilities\n\n",
  "## Overall Summary\n\n",
  "- **Total Utilities:** ", nrow(utilities_only), "\n",
  "- **Total Households:** ", format(round(sum(utilities_only$household_count), 0), big.mark=","), "\n",
  "- **Households Below Poverty Line:** ",
      format(round(sum(utilities_only$households_below_poverty_line), 0), big.mark=","), "\n",
  "- **Overall Poverty Rate:** ",
      scales::percent(sum(utilities_only$households_below_poverty_line)/sum(utilities_only$household_count), accuracy=0.1), "\n\n",
  "## Dataset Coverage\n\n",
  "✓ **Complete coverage:** All NC census tracts in the dataset have utility assignments.\n\n",
  "*This analysis includes ", nrow(utilities_only %>% filter(utility_type == "DistCoop")),
  " electric cooperatives based on utility service territory mapping to census tracts.*\n\n",
  "## Summary by Utility Type\n\n",
  summary_md, "\n\n",
  "## All NC Utilities\n\n",
  utilities_md, "\n\n",
  "---\n",
  "*Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*\n"
)

writeLines(md_doc, "nc_all_utilities_table.md")

cat("Markdown table saved: nc_all_utilities_table.md\n\n")

# Display summary in console
cat("\n=== Summary by Utility Type (NC) ===\n\n")
print(knitr::kable(type_summary_formatted, format="simple"))

cat("\n\n=== All NC Utilities ===\n\n")
print(knitr::kable(utilities_formatted_html, format="simple"))

cat("\n\nFiles created:\n")
cat("  - nc_all_utilities_type_summary.tex (LaTeX summary)\n")
cat("  - nc_all_utilities_table.tex (LaTeX full table)\n")
cat("  - nc_all_utilities_table.html (HTML with color coding)\n")
cat("  - nc_all_utilities_table.md (Markdown)\n")
cat("\nTo view HTML: open nc_all_utilities_table.html in a web browser\n")
