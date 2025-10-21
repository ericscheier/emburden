# Calculate Energy Burden Statistics for ALL NC Utilities (Generalized)
# Groups by utility type with color coding
#
# This script demonstrates using the netenergyequity package for analysis.
# Run from project root or install package first with: devtools::install()

# Load the netenergyequity package (use devtools::load_all() for development)
if (requireNamespace("netenergyequity", quietly = TRUE)) {
  library(netenergyequity)
} else {
  # For development: load package functions from source
  devtools::load_all()
}

# Load additional required libraries
library(dplyr)
library(scales)

# Parameters
state_filter <- "NC"
energy_burden_poverty_line <- 0.06

# Load data
cat("Loading data...\n")
clean_data_ami_all <- read.csv("CohortData_AreaMedianIncome.csv", stringsAsFactors = FALSE)
replica_sup <- read.csv("CensusTractData.csv", stringsAsFactors = FALSE)

# Join AMI data with supplemental census tract data to get utility information
# Join ONLY on geoid to avoid losing rows due to mismatches in other columns
clean_data_ami_all_sup <- left_join(clean_data_ami_all, replica_sup,
                                     by=c("geoid"))

# Filter for NC only
# Use state_abbr.x from AMI data (more complete)
nc_utilities_data <- clean_data_ami_all_sup %>%
  filter(state_abbr.x == "NC") %>%
  # Use company_ty and company_na from census tract data where available
  mutate(
    company_ty = ifelse(!is.na(company_ty.y), company_ty.y, company_ty.x),
    company_na = company_na
  )

cat("Filtered to North Carolina\n")
cat("Found", length(unique(nc_utilities_data$company_na)), "unique utilities in NC\n")
cat("Utility types:", paste(sort(unique(nc_utilities_data$company_ty)), collapse=", "), "\n\n")

# Set parameters
ner_poverty_line <- ner_func(g = 1, s = energy_burden_poverty_line)

cat("Energy burden poverty line:", energy_burden_poverty_line, "\n")
cat("Corresponding Nh (NER) poverty line:", ner_poverty_line, "\n\n")

# Calculate weighted metrics by utility (company_na) AND utility type (company_ty)
cat("Calculating weighted metrics by utility and type...\n")
utility_nh_metrics <- calculate_weighted_metrics(
  graph_data = nc_utilities_data,
  group_columns = c("company_ty", "company_na"),
  metric_name = "ner",
  metric_cutoff_level = ner_poverty_line,
  upper_quantile_view = 0.95,
  lower_quantile_view = 0.05
)

# Convert Nh metrics back to energy_burden
nc_utility_energy_burden_metrics <- utility_nh_metrics %>%
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
  arrange(desc(energy_burden_median))

# Recode utility types to full names
nc_utility_energy_burden_metrics <- nc_utility_energy_burden_metrics %>%
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
cat("\n=== Energy Burden Statistics for All NC Utilities ===\n\n")
print(nc_utility_energy_burden_metrics, n=Inf)

# Save results to analysis/outputs directory
output_file <- "analysis/outputs/nc_all_utilities_energy_burden_results.csv"
write.csv(nc_utility_energy_burden_metrics, output_file, row.names = FALSE)
cat("\nResults saved to:", output_file, "\n")

# Create summary by utility type
cat("\n=== Summary by Utility Type (NC) ===\n\n")
type_summary <- nc_utility_energy_burden_metrics %>%
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
utilities_only <- nc_utility_energy_burden_metrics %>%
  filter(utility_type != "All", utility_name != "All")

cat("\n=== Overall Summary (NC) ===\n")
cat("Total unique utilities analyzed:", nrow(utilities_only), "\n")
cat("Total households:",
    format(round(sum(utilities_only$household_count), 0), big.mark=","), "\n")
cat("Total households below poverty line:",
    format(round(sum(utilities_only$households_below_poverty_line), 0), big.mark=","), "\n")
cat("Overall rate below poverty line:",
    scales::percent(sum(utilities_only$households_below_poverty_line) /
                    sum(utilities_only$household_count), accuracy=0.1), "\n")

# List cooperatives found
cat("\n=== NC Electric Cooperatives in Dataset ===\n")
nc_coops <- nc_utility_energy_burden_metrics %>%
  filter(utility_type == "DistCoop", utility_name != "All") %>%
  arrange(utility_name)

cat("Found", nrow(nc_coops), "electric cooperatives serving NC:\n")
for(i in 1:nrow(nc_coops)) {
  cat(sprintf("%2d. %s\n", i, nc_coops$utility_name[i]))
}

cat("\nNote: This represents the complete utility service territory mapping from the dataset.\n")
cat("All NC census tracts in the AMI data have utility assignments.\n")
