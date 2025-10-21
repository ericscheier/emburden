# Calculate Energy Burden Statistics for ALL Utilities (Generalized)
# Groups by utility type and colors output accordingly

# Load only required libraries
library(dplyr)
library(scales)
library(spatstat)  # Provides weighted.quantile and weighted.median

# Source only required helper files
source("ratios.R")
source("helpers.R")

# Parameters
state_filter <- NULL  # Set to state abbreviation(s) to filter, e.g., "NC" or c("NC", "SC")
energy_burden_poverty_line <- 0.06

# Load data
cat("Loading data...\n")
clean_data_ami_all <- read.csv("CohortData_AreaMedianIncome.csv", stringsAsFactors = FALSE)
replica_sup <- read.csv("CensusTractData.csv", stringsAsFactors = FALSE)

# Join AMI data with supplemental census tract data to get utility information
clean_data_ami_all_sup <- left_join(clean_data_ami_all, replica_sup,
                                     by=c("geoid","state_abbr","state_fips",
                                          "company_ty","locale"))

# Filter by state if specified
if(!is.null(state_filter)) {
  all_utilities_data <- clean_data_ami_all_sup %>%
    filter(state_abbr %in% state_filter)
  cat("Filtered to state(s):", paste(state_filter, collapse=", "), "\n")
} else {
  all_utilities_data <- clean_data_ami_all_sup
  cat("Analyzing all states\n")
}

cat("Found", length(unique(all_utilities_data$company_na)), "unique utilities\n")
cat("Utility types:", paste(sort(unique(all_utilities_data$company_ty)), collapse=", "), "\n\n")

# Set parameters
ner_poverty_line <- ner_func(g = 1, s = energy_burden_poverty_line)

cat("Energy burden poverty line:", energy_burden_poverty_line, "\n")
cat("Corresponding Nh (NER) poverty line:", ner_poverty_line, "\n\n")

# Calculate weighted metrics by utility (company_na) AND utility type (company_ty)
cat("Calculating weighted metrics by utility and type...\n")
utility_nh_metrics <- calculate_weighted_metrics(
  graph_data = all_utilities_data,
  group_columns = c("company_ty", "company_na"),
  metric_name = "ner",
  metric_cutoff_level = ner_poverty_line,
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)

# Convert Nh metrics back to energy_burden
utility_energy_burden_metrics <- utility_nh_metrics %>%
  mutate(
    energy_burden_mean = 1 / (metric_mean + 1),
    energy_burden_median = 1 / (metric_median + 1),
    energy_burden_upper_95 = 1 / (metric_lower + 1),
    energy_burden_lower_05 = 1 / (metric_upper + 1),
    energy_burden_min = 1 / (metric_max + 1),
    energy_burden_max = 1 / (metric_min + 1)
  ) %>%
  select(
    utility_type = company_ty,
    utility_name = company_na,
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
  arrange(utility_type, desc(energy_burden_median))

# Recode utility types to full names
utility_energy_burden_metrics <- utility_energy_burden_metrics %>%
  mutate(
    utility_type_full = case_when(
      utility_type == "IOU" ~ "Investor-Owned Utility",
      utility_type == "DistCoop" ~ "Distribution Cooperative",
      utility_type == "Coop" ~ "Cooperative",
      utility_type == "Muni" ~ "Municipal Utility",
      utility_type == "Federal" ~ "Federal Utility",
      utility_type == "State" ~ "State Utility",
      utility_type == "Private" ~ "Private Utility",
      utility_type == "PSubdiv" ~ "Political Subdivision",
      utility_type == "All" ~ "All Utilities",
      TRUE ~ as.character(utility_type)
    )
  )

# Display results
cat("\n=== Energy Burden Statistics for All Utilities ===\n\n")
print(utility_energy_burden_metrics, n=Inf)

# Save results
write.csv(utility_energy_burden_metrics, "all_utilities_energy_burden_results.csv", row.names = FALSE)
cat("\nResults saved to: all_utilities_energy_burden_results.csv\n")

# Create summary by utility type
cat("\n=== Summary by Utility Type ===\n\n")
type_summary <- utility_energy_burden_metrics %>%
  filter(utility_type != "All", utility_name != "All") %>%
  group_by(utility_type_full) %>%
  summarise(
    n_utilities = n(),
    total_households = sum(household_count),
    total_below_poverty = sum(households_below_poverty_line),
    overall_poverty_rate = total_below_poverty / total_households,
    median_of_medians = median(energy_burden_median, na.rm=TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(median_of_medians))

print(type_summary, n=Inf)

# Overall summary (excluding "All" rows)
utilities_only <- utility_energy_burden_metrics %>%
  filter(utility_type != "All", utility_name != "All")

cat("\n=== Overall Summary ===\n")
cat("Total unique utilities analyzed:", nrow(utilities_only), "\n")
cat("Total households:",
    format(round(sum(utilities_only$household_count), 0), big.mark=","), "\n")
cat("Total households below poverty line:",
    format(round(sum(utilities_only$households_below_poverty_line), 0), big.mark=","), "\n")
cat("Overall rate below poverty line:",
    scales::percent(sum(utilities_only$households_below_poverty_line) /
                    sum(utilities_only$household_count), accuracy=0.1), "\n")

cat("\nUtility with highest median energy burden:\n")
cat("  ", as.character(utilities_only$utility_name[1]),
    "(", as.character(utilities_only$utility_type_full[1]), ")",
    "-", scales::percent(utilities_only$energy_burden_median[1], accuracy=0.1), "\n")
cat("Utility with lowest median energy burden:\n")
cat("  ", as.character(utilities_only$utility_name[nrow(utilities_only)]),
    "(", as.character(utilities_only$utility_type_full[nrow(utilities_only)]), ")",
    "-", scales::percent(utilities_only$energy_burden_median[nrow(utilities_only)], accuracy=0.1), "\n")
