#' North Carolina Complete Energy Burden Sample Data
#'
#' A comprehensive dataset containing energy burden data for all counties in North Carolina.
#' This dataset includes both Federal Poverty Line (FPL) and Area Median Income (AMI) cohort
#' data for 2018 and 2022 vintages, aggregated to the census tract × income bracket level.
#'
#' This sample data provides full state coverage for more comprehensive analysis, testing,
#' and demonstrations. For lightweight quick demos, see \code{\link{orange_county_sample}}.
#'
#' @format A named list with 4 data frames:
#' \describe{
#'   \item{fpl_2018}{Federal Poverty Line cohort data for 2018 (~10,805 rows)}
#'   \item{fpl_2022}{Federal Poverty Line cohort data for 2022 (~13,185 rows)}
#'   \item{ami_2018}{Area Median Income cohort data for 2018 (~6,484 rows)}
#'   \item{ami_2022}{Area Median Income cohort data for 2022 (~5,091 rows)}
#' }
#'
#' Each data frame contains:
#' \describe{
#'   \item{geoid}{11-digit census tract identifier (character)}
#'   \item{income_bracket}{Income bracket category (character)}
#'   \item{households}{Number of households in this cohort (numeric)}
#'   \item{total_income}{Total household income in dollars (numeric)}
#'   \item{total_electricity_spend}{Total electricity spending in dollars (numeric)}
#'   \item{total_gas_spend}{Total gas spending in dollars (numeric)}
#'   \item{total_other_spend}{Total other fuel spending in dollars (numeric)}
#' }
#'
#' @details
#' **North Carolina** (all 100 counties):
#' \itemize{
#'   \item 2018: 2,163 census tracts
#'   \item 2022: 2,642 census tracts (tract boundaries changed)
#' }
#'
#' **Income Brackets**:
#' \itemize{
#'   \item FPL: 0-100%, 100-150%, 150-200%, 200-400%, 400%+
#'   \item AMI: Varies by vintage (4-6 categories)
#' }
#'
#' **Size**: 1.3 MB compressed (.rda)
#'
#' @source
#' U.S. Department of Energy Low-Income Energy Affordability Data (LEAD) Tool
#' \itemize{
#'   \item 2018 vintage: \url{https://data.openei.org/submissions/573}
#'   \item 2022 vintage: \url{https://data.openei.org/submissions/6219}
#' }
#'
#' @examples
#' # Load sample data
#' data(nc_sample)
#'
#' # View structure
#' names(nc_sample)
#'
#' # Analyze energy burden by county
#' library(dplyr)
#'
#' # Extract county FIPS (first 5 digits of geoid)
#' nc_sample$fpl_2022 %>%
#'   mutate(county_fips = substr(geoid, 1, 5)) %>%
#'   group_by(county_fips, income_bracket) %>%
#'   summarise(
#'     households = sum(households),
#'     avg_energy_burden = sum(total_electricity_spend + total_gas_spend + total_other_spend) /
#'                         sum(total_income),
#'     .groups = "drop"
#'   ) %>%
#'   filter(county_fips == "37183")  # Wake County
#'
#' # Compare urban vs rural counties
#' urban_counties <- c("37119", "37063", "37183")  # Mecklenburg, Durham, Wake
#' rural_counties <- c("37069", "37095", "37131")  # Franklin, Hyde, Northampton
#'
#' nc_sample$fpl_2022 %>%
#'   mutate(
#'     county_fips = substr(geoid, 1, 5),
#'     region = case_when(
#'       county_fips %in% urban_counties ~ "Urban",
#'       county_fips %in% rural_counties ~ "Rural",
#'       TRUE ~ "Other"
#'     )
#'   ) %>%
#'   filter(region != "Other") %>%
#'   group_by(region, income_bracket) %>%
#'   summarise(
#'     households = sum(households),
#'     energy_burden = sum(total_electricity_spend + total_gas_spend + total_other_spend) /
#'                     sum(total_income),
#'     .groups = "drop"
#'   )
#'
#' @seealso
#' \itemize{
#'   \item \code{\link{orange_county_sample}} - Lightweight sample (94 KB) for quick demos
#'   \item \code{\link{load_cohort_data}} - Load data for any state with county filtering
#'   \item \code{\link{compare_energy_burden}} - Compare energy burden across vintages
#'   \item \code{\link{calculate_weighted_metrics}} - Calculate weighted metrics with grouping
#' }
"nc_sample"
