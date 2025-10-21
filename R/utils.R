# Import pipe operator from dplyr
#' @importFrom dplyr %>%
#' @export
dplyr::`%>%`

# Declare global variables to avoid R CMD check NOTEs
utils::globalVariables(c(
  ".",
  "households",
  "group_households",
  "group_household_weights",
  "household_count",
  "households_below_cutoff"
))
