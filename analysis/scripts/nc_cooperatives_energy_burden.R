# Calculate Energy Burden Statistics for NC Electric Cooperatives
# Using existing helper functions and AMI data

# Load only required libraries
library(dplyr)
library(scales)
library(spatstat)  # Provides weighted.quantile and weighted.median

# Source only required helper files
source("ratios.R")
source("helpers.R")

# Load data
cat("Loading data...\n")
clean_data_ami_all <- read.csv("CohortData_AreaMedianIncome.csv", stringsAsFactors = FALSE)
replica_sup <- read.csv("CensusTractData.csv", stringsAsFactors = FALSE)

# Join AMI data with supplemental census tract data to get utility information
clean_data_ami_all_sup <- left_join(clean_data_ami_all, replica_sup,
                                     by=c("geoid","state_abbr","state_fips",
                                          "company_ty","locale"))

# Filter for North Carolina electric cooperatives
nc_coops_data <- clean_data_ami_all_sup %>%
  filter(state_abbr == "NC",
         company_ty == "DistCoop")

cat("Found", length(unique(nc_coops_data$company_na)), "NC electric cooperatives\n")
cat("Cooperatives:", paste(sort(unique(nc_coops_data$company_na)), collapse=", "), "\n\n")

# Set parameters
energy_burden_poverty_line <- 0.06
ner_poverty_line <- ner_func(g = 1, s = energy_burden_poverty_line)

cat("Energy burden poverty line:", energy_burden_poverty_line, "\n")
cat("Corresponding Nh (NER) poverty line:", ner_poverty_line, "\n\n")

# Calculate weighted metrics by cooperative using Nh (ner)
cat("Calculating weighted metrics by cooperative...\n")
coop_nh_metrics <- calculate_weighted_metrics(
  graph_data = nc_coops_data,
  group_columns = "company_na",
  metric_name = "ner",
  metric_cutoff_level = ner_poverty_line,
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)

# Convert Nh metrics back to energy_burden
# energy_burden = 1 / (Nh + 1)
coop_energy_burden_metrics <- coop_nh_metrics %>%
  mutate(
    energy_burden_mean = 1 / (metric_mean + 1),
    energy_burden_median = 1 / (metric_median + 1),
    energy_burden_upper_95 = 1 / (metric_lower + 1),  # Note: reversed because of inverse relationship
    energy_burden_lower_05 = 1 / (metric_upper + 1),  # Note: reversed because of inverse relationship
    energy_burden_min = 1 / (metric_max + 1),
    energy_burden_max = 1 / (metric_min + 1)
  ) %>%
  select(
    cooperative = company_na,
    household_count,
    households_below_poverty_line = households_below_cutoff,
    pct_below_poverty_line = pct_in_group_below_cutoff,
    energy_burden_mean,
    energy_burden_median,
    energy_burden_lower_05,
    energy_burden_upper_95,
    energy_burden_min,
    energy_burden_max,
    nh_mean = metric_mean,
    nh_median = metric_median
  ) %>%
  arrange(desc(energy_burden_median))

# Display results
cat("\n=== Energy Burden Statistics for NC Electric Cooperatives ===\n\n")
print(coop_energy_burden_metrics, n=Inf)

# Save results
write.csv(coop_energy_burden_metrics, "nc_cooperatives_energy_burden_results.csv", row.names = FALSE)
cat("\nResults saved to: nc_cooperatives_energy_burden_results.csv\n")

# Filter out the "All" row for summary stats
coops_only <- coop_energy_burden_metrics %>% filter(cooperative != "All")

# Also create formatted table output if knitr/kableExtra available
if(requireNamespace("knitr", quietly = TRUE) && requireNamespace("kableExtra", quietly = TRUE)) {
  source("format_nc_cooperatives_table.R")

  cat("\nGenerating formatted tables...\n")

  # Create compact formatted table
  formatted_compact <- format_nc_cooperatives_table_compact(coops_only, latex=FALSE)

  # Display in console
  cat("\n=== Compact Formatted Table ===\n")
  print(knitr::kable(formatted_compact, format="simple"))

  cat("\nTo render PDF/HTML table, run: rmarkdown::render('nc_cooperatives_table.Rmd')\n")
}

# Create a summary

cat("\n=== Summary ===\n")
cat("Total NC cooperatives analyzed:", nrow(coops_only), "\n")
cat("Total households across all NC cooperatives:",
    format(round(sum(coops_only$household_count), 0), big.mark=","), "\n")
cat("Total households below poverty line:",
    format(round(sum(coops_only$households_below_poverty_line), 0), big.mark=","), "\n")
cat("Overall rate below poverty line:",
    scales::percent(sum(coops_only$households_below_poverty_line) /
                    sum(coops_only$household_count), accuracy=0.1), "\n")
cat("\nCooperative with highest median energy burden:\n")
cat("  ", as.character(coops_only$cooperative[1]),
    "-", scales::percent(coops_only$energy_burden_median[1], accuracy=0.1), "\n")
cat("Cooperative with lowest median energy burden:\n")
cat("  ", as.character(coops_only$cooperative[nrow(coops_only)]),
    "-", scales::percent(coops_only$energy_burden_median[nrow(coops_only)], accuracy=0.1), "\n")
